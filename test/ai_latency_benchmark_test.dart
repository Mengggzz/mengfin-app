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
      '${Directory.systemTemp.path}/mengfin_latency_bench_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    // Seed some mock data in LocalDb so fallback calculations have real work
    await LocalDb.insertAkunLocal({
      'nama': 'BCA Utama',
      'jenis': 'bank',
      'saldo': 5000000,
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
  });

  tearDownAll(() async {
    await LocalDb.closeForTest();
  });

  group('MengFin AI Latency & Responsiveness Benchmark', () {
    test('Benchmark setiap skenario pertanyaan dan ukur latency (ms)', () async {
      final testCases = <String, String>{
        'Greeting / Tes': 'tes',
        'Greeting / Halo': 'halo',
        'Catat Pengeluaran': 'beli kopi 25rb',
        'Catat Pemasukan': 'gajian 5jt transfer',
        'Tanya Saldo': 'berapa saldo saya?',
        'Tanya Riwayat': 'lihat riwayat transaksi terakhir',
        'Tanya Budget': 'cek status budget hari ini',
        'Minta Tips Hemat': 'tips hemat bulan ini',
        'Pertanyaan Umum / Analisis': 'kondisi keuanganku saat ini',
      };

      print('\n============================================================');
      print('          MENGFIN AI LATENCY BENCHMARK REPORT               ');
      print('============================================================');

      for (final entry in testCases.entries) {
        final label = entry.key;
        final prompt = entry.value;

        final stopwatch = Stopwatch()..start();
        final res = await ApiService.chat(prompt);
        stopwatch.stop();

        final elapsedMs = stopwatch.elapsedMilliseconds;
        final hasPesan = res['pesan'] != null && res['pesan'].toString().isNotEmpty;

        print('[$label]');
        print('  Prompt    : "$prompt"');
        print('  Latency   : ${elapsedMs}ms');
        print('  Tipe Res  : ${res['tipe']}');
        print('  Status    : ${hasPesan ? "OK (Responsif)" : "FAIL"}');
        print('------------------------------------------------------------');

        expect(hasPesan, isTrue);
        expect(elapsedMs, lessThan(3500), reason: 'Response harus < 3.5 detik');
      }
    });

    test('Stress test: 10 pesan beruntun tanpa jeda (Rapid Firing)', () async {
      final prompts = [
        'tes 1',
        'beli makan siang 35rb',
        'berapa saldo?',
        'tes 2',
        'beli bensin 50rb',
        'tips hemat',
        'gajian 8 juta',
        'cek budget',
        'riwayat transaksi',
        'terima kasih',
      ];

      print('\n============================================================');
      print('          RAPID FIRING TEST (10 PESAN BERUNTUN)             ');
      print('============================================================');

      final totalWatch = Stopwatch()..start();
      for (int i = 0; i < prompts.length; i++) {
        final p = prompts[i];
        final msgWatch = Stopwatch()..start();
        final res = await ApiService.chat(p);
        msgWatch.stop();

        print('  Pesan #${i + 1} ("$p") -> Selesai dalam ${msgWatch.elapsedMilliseconds}ms');
        expect(res['pesan'], isNotNull);
        expect(res['pesan'].toString().isNotEmpty, isTrue);
      }
      totalWatch.stop();

      print('============================================================');
      print('  TOTAL WAKTU (10 Pesan): ${totalWatch.elapsedMilliseconds}ms');
      print('  RATA-RATA PER PESAN  : ${(totalWatch.elapsedMilliseconds / 10).toStringAsFixed(1)}ms');
      print('============================================================\n');

      expect(totalWatch.elapsedMilliseconds, lessThan(5000));
    });
  });
}
