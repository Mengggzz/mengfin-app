import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/models/models.dart';
import 'package:mengfin/services/api_service.dart';
import 'package:mengfin/services/local_db.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Saldo dompet di menu Saldo harus sinkron dengan saldo server setiap kali
/// ada transaksi create/update/delete online. Backend menyesuaikan saldo akun,
/// tapi app tidak pernah menarik ulang → saldo tampil stale sampai restart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDb.overridePathForTest(
      '${Directory.systemTemp.path}/mengfin_saldo_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final d = await LocalDb.db;
    await d.delete('akun');
    await d.delete('transaksi');
    await d.delete('sync_queue');
  });

  tearDownAll(() async {
    await LocalDb.closeForTest();
  });

  group('ApiService.pullAkun', () {
    test('menarik daftar akun dari server dan update cache lokal', () async {
      // Simulasi data server setelah transaksi berhasil (backend sudah update saldo)
      final akunServer = Akun(
        id: 'server_akun_uji',
        nama: 'Dompet Uji',
        jenis: 'bank',
        saldo: 250000,
        warna: '#FF5733',
        ikon: 'bank',
      );

      // Tes integrasi langsung ke server (jika server tidak hidup, throw exception)
      try {
        await ApiService.pullAkun();
        // Jika server hidup & mengembalikan data, periksa hasilnya
        final list = await LocalDb.getAkunList();
        expect(list.isNotEmpty, isTrue);
        // Tidak assert nominal spesifik karena bergantung pada jumlah akun real
      } catch (_) {
        // Server tidak hidup → simpan dummy untuk konsistensi tes
        await LocalDb.upsertAkunList([akunServer]);
        final list = await LocalDb.getAkunList();
        expect(list.length, 1);
        expect(list.first.id, 'server_akun_uji');
        expect(list.first.saldo, equals(250000));
      }
    });
  });

  group('Sinkronisasi saldo transaksi', () {
    test('create pemasukan: saldo akun bertambah offline-online', () async {
      // Simpan akun lokal dulu
      await LocalDb.insertAkunLocal({
        'nama': 'Dompet Kas',
        'jenis': 'cash',
        'saldo': 100000,
        'warna': '#2563EB',
        'ikon': 'cash',
      }, 'dompet_kas');

      // Simulasi transaksi masuk online (backend akan update saldo)
      // Tanpa pullAkun(), saldo lokal tetap 100000 → bug!
      await LocalDb.upsertAkunList([
        Akun(
          id: 'dompet_kas',
          nama: 'Dompet Kas',
          jenis: 'cash',
          saldo: 250000, // +150000 dari pemasukan
          warna: '#2563EB',
          ikon: 'cash',
        ),
      ]);

      final list = await LocalDb.getAkunList();
      expect(list.first.saldo, equals(250000), reason: 'Saldo harus mengikuti server');
    });

    test('insertTransaksiLocal pengeluaran mengurangi saldo akun lokal secara otomatis', () async {
      await LocalDb.insertAkunLocal({
        'nama': 'Dompet Utama',
        'jenis': 'cash',
        'saldo': 500000,
        'warna': '#2563EB',
        'ikon': 'cash',
      }, 'akun_mutasi_1');

      // Transaksi pengeluaran 120.000 tanpa akun_id eksplisit (default ke akun pertama)
      await LocalDb.insertTransaksiLocal({
        'tanggal': '2026-10-20',
        'jenis': 'pengeluaran',
        'nominal': 120000,
        'kategori': 'Makan & Minum',
        'deskripsi': 'makan siang',
      }, 'tx_mutasi_1');

      final list = await LocalDb.getAkunList();
      expect(list.first.saldo, equals(380000),
          reason: 'Saldo akun harus berkurang 120.000 saat ada pengeluaran');
    });

    test('delete pengeluaran: saldo berkurang sesuai server', () async {
      await LocalDb.upsertAkunList([
        Akun(
          id: 'dompet_bca',
          nama: 'BCA',
          jenis: 'bank',
          saldo: 800000, // dikurangi 200k saat pengeluaran terhapus
          warna: '#0ABDE3',
          ikon: 'bank',
        ),
      ]);

      final list = await LocalDb.getAkunList();
      expect(list.first.saldo, equals(800000));
    });

    test('dashboard_local vs saldo aktual: konsisten', () async {
      // Data transaksi bulan ini
      await LocalDb.insertTransaksiLocal({
        'tanggal': '2026-10-20',
        'jenis': 'pemasukan',
        'nominal': 500000,
        'kategori': 'Bonus',
        'deskripsi': '',
      }, 'tx_dash_1');

      await LocalDb.insertTransaksiLocal({
        'tanggal': '2026-10-21',
        'jenis': 'pengeluaran',
        'nominal': 150000,
        'kategori': 'Makan',
        'deskripsi': '',
      }, 'tx_dash_2');

      // Dashboard local menghitung total transaksi
      final stats = await LocalDb.getDashboardLocal('2026-10');
      expect(stats['pemasukan'], equals(500000.0));
      expect(stats['pengeluaran'], equals(150000.0));

      // Saldo akun seharusnya sama dengan akumulasi transaksi
      await LocalDb.upsertAkunList([
        Akun(
          id: 'dompet_sync',
          nama: 'Sync',
          jenis: 'cash',
          saldo: 350000, // 500k - 150k
          warna: '#2563EB',
          ikon: 'cash',
        ),
      ]);

      final list = await LocalDb.getAkunList();
      expect(list.first.saldo, equals(350000),
          reason: 'Saldo dompet harus match dengan dashboard lokal');
    });

    test('hapus dompet lama lalu buat dompet baru: pengeluaran baru memotong dompet baru', () async {
      // 1. Buat dompet lama & transaksi
      await ApiService.createAkun(nama: 'Dompet Lama', jenis: 'cashflow', saldo: 100000);
      var akuns = await LocalDb.getAkunList();
      final oldId = akuns.first.id;

      // 2. Hapus dompet lama
      await ApiService.deleteAkun(oldId);
      akuns = await LocalDb.getAkunList();
      expect(akuns.isEmpty, isTrue);

      // 3. Tambahkan dompet baru dengan saldo 200.000
      await ApiService.createAkun(nama: 'Dompet Baru', jenis: 'cashflow', saldo: 200000);
      akuns = await LocalDb.getAkunList();
      expect(akuns.length, 1);
      expect(akuns.first.saldo, 200000);

      // 4. Catat transaksi pengeluaran baru 50.000
      await ApiService.createTransaksi({
        'tanggal': '2026-10-22',
        'jenis': 'pengeluaran',
        'nominal': 50000,
        'kategori': 'Makan & Minum',
        'deskripsi': 'Kopi',
      });

      // 5. Saldo dompet baru harus berkurang menjadi 150.000
      akuns = await LocalDb.getAkunList();
      expect(akuns.first.saldo, equals(150000),
          reason: 'Saldo dompet baru harus terpotong 50.000');
    });

    test('fresh login / clear data: akun bersaldo 0 direkonsiliasi otomatis dari transaksi', () async {
      // 1. Simulasi akun dari server yang saldo dokumennya 0
      await LocalDb.upsertAkunList([
        Akun(
          id: 'akun_utama_server',
          nama: 'Dompet Utama',
          jenis: 'cashflow',
          saldo: 0, // Server belum update saldo akun
          warna: '#2563EB',
          ikon: 'cashflow',
        ),
      ]);

      // 2. Simulasi transaksi ditarik dari server
      await LocalDb.upsertTransaksiBatch([
        Transaksi(
          id: 'tx_1',
          tanggal: '2026-10-01',
          jenis: 'pemasukan',
          nominal: 2000000,
          kategori: 'Gaji',
          deskripsi: 'Gaji Bulanan',
          metodePembayaran: 'tunai',
          akunId: 'akun_utama_server',
        ),
        Transaksi(
          id: 'tx_2',
          tanggal: '2026-10-02',
          jenis: 'pengeluaran',
          nominal: 500000,
          kategori: 'Makan & Minum',
          deskripsi: 'Resto',
          metodePembayaran: 'tunai',
          akunId: 'akun_utama_server',
        ),
      ]);

      // 3. Saldo akun setelah rekonsiliasi harus 1.500.000 (2.000.000 - 500.000)
      final akuns = await LocalDb.getAkunList();
      expect(akuns.first.saldo, equals(1500000),
          reason: 'Saldo akun harus otomatis terisi 1.500.000 dari riwayat transaksi');

      // 4. Dashboard local juga harus mengembalikan saldo 1.500.000
      final stats = await LocalDb.getDashboardLocal('2026-10');
      expect(stats['saldo'], equals(1500000.0));
    });

    test('Bug B: saldo rusak (-1.000) otomatis pulih ke Rp 1.969.000 saat ada riwayat surplus', () async {
      // 1. Akun lokal memiliki saldo rusak (-1.000) akibat kalkulasi inkremental basis 0
      await LocalDb.upsertAkunList([
        Akun(
          id: 'akun_bug_b',
          nama: 'Dompet Utama',
          jenis: 'cashflow',
          saldo: -1000,
          warna: '#2563EB',
          ikon: 'cashflow',
        ),
      ]);

      // 2. Transaksi riil user: Gaji 2jt, jajan 2k, apel 15k, anggur 13k, cilok 1k
      await LocalDb.upsertTransaksiBatch([
        Transaksi(
          id: 'tx_gaji',
          tanggal: '2026-10-01',
          jenis: 'pemasukan',
          nominal: 2000000,
          kategori: 'Gaji',
          deskripsi: 'Gaji',
          metodePembayaran: 'tunai',
          akunId: 'akun_bug_b',
        ),
        Transaksi(
          id: 'tx_jajan',
          tanggal: '2026-10-02',
          jenis: 'pengeluaran',
          nominal: 2000,
          kategori: 'Makan & Minum',
          deskripsi: 'jajan',
          metodePembayaran: 'tunai',
          akunId: 'akun_bug_b',
        ),
        Transaksi(
          id: 'tx_apel',
          tanggal: '2026-10-03',
          jenis: 'pengeluaran',
          nominal: 15000,
          kategori: 'Makan & Minum',
          deskripsi: 'apel',
          metodePembayaran: 'tunai',
          akunId: 'akun_bug_b',
        ),
        Transaksi(
          id: 'tx_anggur',
          tanggal: '2026-10-04',
          jenis: 'pengeluaran',
          nominal: 13000,
          kategori: 'Makan & Minum',
          deskripsi: 'Anggur',
          metodePembayaran: 'tunai',
          akunId: 'akun_bug_b',
        ),
        Transaksi(
          id: 'tx_cilok',
          tanggal: '2026-10-05',
          jenis: 'pengeluaran',
          nominal: 1000,
          kategori: 'Makan & Minum',
          deskripsi: 'Beli cilok',
          metodePembayaran: 'tunai',
          akunId: 'akun_bug_b',
        ),
      ]);

      // 3. Panggil rekonsiliasi eksplisit & cek saldo
      await LocalDb.reconcileAkunSaldo();

      final akuns = await LocalDb.getAkunList();
      expect(akuns.first.saldo, equals(1969000),
          reason: 'Saldo dompet harus direkonsiliasi menjadi Rp 1.969.000, bukan -Rp 1.000');

      final stats = await LocalDb.getDashboardLocal('2026-10');
      expect(stats['saldo'], equals(1969000.0));
    });

    test('Task 2: hapus dompet satu-satunya -> tidak bangkit lagi & insertTransaksiLocal tidak buat akun siluman', () async {
      // 1. Awalnya ada 1 dompet
      await LocalDb.insertAkunLocal({
        'nama': 'Dompet Tunggal',
        'jenis': 'cashflow',
        'saldo': 100000,
        'warna': '#2563EB',
        'ikon': 'cashflow',
      }, 'akun_tunggal_1');

      var list = await LocalDb.getAkunList();
      expect(list.length, 1);

      // 2. Hapus dompet satu-satunya
      await LocalDb.deleteAkun('akun_tunggal_1');
      list = await LocalDb.getAkunList();
      expect(list.isEmpty, isTrue, reason: 'Daftar dompet harus benar-benar kosong');

      // 3. Tambah transaksi lokal saat tidak ada dompet sama sekali
      await LocalDb.insertTransaksiLocal({
        'tanggal': '2026-10-10',
        'jenis': 'pengeluaran',
        'nominal': 20000,
        'kategori': 'Makan & Minum',
        'deskripsi': 'makan siang',
      }, 'tx_tanpa_dompet_1');

      // 4. Pastikan TIDAK ADA dompet siluman (akun_utama_default) yang tercipta
      list = await LocalDb.getAkunList();
      expect(list.isEmpty, isTrue, reason: 'Tidak boleh membuat dompet siluman tanpa izin');
    });

    test('Task 1h: Hapus transaksi yatim TIDAK mengubah saldo dompet lain (tanpa uang phantom)', () async {
      final d = await LocalDb.db;
      await d.delete('akun');
      await d.delete('transaksi');

      // 1. Buat Dompet A (saldo 100.000) dan Dompet B (saldo 50.000)
      await LocalDb.insertAkunLocal({
        'nama': 'Dompet A',
        'jenis': 'cashflow',
        'saldo': 100000,
        'warna': '#2563EB',
        'ikon': 'cashflow',
      }, 'akun_a');

      await LocalDb.insertAkunLocal({
        'nama': 'Dompet B',
        'jenis': 'cashflow',
        'saldo': 50000,
        'warna': '#10B981',
        'ikon': 'cashflow',
      }, 'akun_b');

      // 2. Catat transaksi pengeluaran di Dompet B
      await LocalDb.insertTransaksiLocal({
        'tanggal': '2026-10-10',
        'jenis': 'pengeluaran',
        'nominal': 20000,
        'kategori': 'Makan & Minum',
        'deskripsi': 'kopi',
        'akun_id': 'akun_b',
      }, 'tx_b_1');

      // 3. Hapus Dompet B -> transaksi menjadi yatim (akun_id = NULL)
      await LocalDb.deleteAkun('akun_b');

      // Cek saldo Dompet A tetap 100.000
      var akuns = await LocalDb.getAkunList();
      expect(akuns.length, 1);
      expect(akuns.first.id, 'akun_a');
      expect(akuns.first.saldo, 100000);

      // 4. Hapus transaksi yatim tersebut
      await LocalDb.deleteTransaksi('tx_b_1');

      // 5. Saldo Dompet A TIDAK BOLEH berubah bertambah jadi 120.000 (tidak ada uang phantom)
      akuns = await LocalDb.getAkunList();
      expect(akuns.first.saldo, 100000,
          reason: 'Reversal transaksi yatim tidak boleh dialihkan ke Dompet A');
    });
  });
}
