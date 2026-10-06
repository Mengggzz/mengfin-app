import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/api_service.dart';
import 'package:mengfin/services/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDb.overridePathForTest(
      '${Directory.systemTemp.path}/mengfin_accuracy_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    // Seed mock account & transactions
    await LocalDb.insertAkunLocal({
      'nama': 'BCA Utama',
      'jenis': 'bank',
      'saldo': 6500000,
      'warna': '#2563EB',
      'ikon': 'bank',
    }, 'akun_test_1');

    await LocalDb.insertTransaksiLocal({
      'tanggal': DateTime.now().toIso8601String().substring(0, 10),
      'jenis': 'pengeluaran',
      'nominal': 50000.0,
      'kategori': 'Makan & Minum',
      'deskripsi': 'Nasi Padang',
      'metode_pembayaran': 'tunai',
      'akun_id': 'akun_test_1',
    }, 'tx_test_1');

    await LocalDb.insertTransaksiLocal({
      'tanggal': DateTime.now().toIso8601String().substring(0, 10),
      'jenis': 'pengeluaran',
      'nominal': 25000.0,
      'kategori': 'Transportasi',
      'deskripsi': 'Bensin',
      'metode_pembayaran': 'tunai',
      'akun_id': 'akun_test_1',
    }, 'tx_test_2');
  });

  tearDownAll(() async {
    await LocalDb.closeForTest();
  });

  group('MengFin AI Dialog Accuracy & Contextual Relevance', () {
    test('Sapaan murni ("tes", "halo") dijawab dengan sapaan/welcome', () async {
      final resTes = await ApiService.chat('tes');
      expect(resTes['tipe'], 'jawaban');
      expect(resTes['pesan'], contains('MengFin AI'));

      final resHalo = await ApiService.chat('halo');
      expect(resHalo['tipe'], 'jawaban');
      expect(resHalo['pesan'], contains('MengFin AI'));
    });

    test('Pertanyaan diawali "Halo..." TIDAK dibajak sapaan, melainkan menjawab isi pertanyaan', () async {
      final res = await ApiService.chat('Halo, berapa pengeluaran makan saya?');
      expect(res['tipe'], 'jawaban');
      // Harus menjawab tentang kategori Makan & Minum, BUKAN teks template sapaan
      expect(res['pesan'], contains('Makan & Minum'));
      expect(res['pesan'], contains('50.000'));
    });

    test('Perintah catat transaksi murni ("beli kopi 25rb") dideteksi sebagai transaksi_preview', () async {
      final res = await ApiService.chat('beli kopi 25rb');
      expect(res['tipe'], 'transaksi_preview');
      expect(res['data']['nominal'], 25000);
    });

    test('Pertanyaan evaluasi tentang pembelian ("Kemarin saya beli baju 500rb, apakah boros?") BUKAN input transaksi baru', () async {
      final res = await ApiService.chat('Kemarin saya beli baju 500rb, apakah boros?');
      expect(res['tipe'], 'jawaban');
      // Menjawab kontekstual kategori Pakaian atau tips, bukan modal preview simpan transaksi
      expect(res['pesan'], isNot(contains('Konfirmasi untuk menyimpan?')));
    });

    test('Pertanyaan kategori spesifik ("pengeluaran bensin bulan ini")', () async {
      final res = await ApiService.chat('pengeluaran bensin bulan ini');
      expect(res['tipe'], 'jawaban');
      expect(res['pesan'], contains('Transportasi'));
      expect(res['pesan'], contains('25.000'));
    });

    test('Pertanyaan konsep keuangan ("apa itu dana darurat?") dijawab dengan panduan dana darurat', () async {
      final res = await ApiService.chat('apa itu dana darurat?');
      expect(res['tipe'], 'jawaban');
      expect(res['pesan'], contains('Dana Darurat'));
    });

    test('Pertanyaan status hari ini ("berapa pengeluaran hari ini?") dijawab dengan data hari ini', () async {
      final res = await ApiService.chat('berapa pengeluaran hari ini?');
      expect(res['tipe'], 'jawaban');
      expect(res['pesan'], contains('Hari Ini'));
      expect(res['pesan'], contains('75.000')); // 50k + 25k
    });

    test('Pertanyaan saldo ("berapa saldo saya?") dijawab dengan rincian saldo dan dompet', () async {
      final res = await ApiService.chat('berapa saldo saya?');
      expect(res['tipe'], 'jawaban');
      expect(res['pesan'], contains('Saldo'));
      expect(res['pesan'], contains('BCA Utama'));
    });
  });
}
