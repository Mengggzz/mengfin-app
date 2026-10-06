import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/api_service.dart';
import 'package:mengfin/services/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDb.overridePathForTest(
      '${Directory.systemTemp.path}/mengfin_ai_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  tearDownAll(() async {
    await LocalDb.closeForTest();
  });

  group('ApiService.chat Resilient AI Fallback & Parser', () {
    test('deteksi dan parse perintah transaksi instan', () async {
      final res = await ApiService.chat('beli kopi 25rb');
      expect(res['tipe'], 'transaksi_preview');
      expect(res['data']['nominal'], 25000);
      expect(res['data']['kategori'], 'Makan & Minum');
    });

    test('jawab pertanyaan status saldo tanpa error walau offline', () async {
      final res = await ApiService.chat('berapa saldo saya?');
      expect(res['tipe'], 'jawaban');
      expect(res['pesan'], contains('Informasi Saldo'));
    });

    test('jawab tips hemat berbasis data lokal tanpa error', () async {
      final res = await ApiService.chat('minta tips hemat');
      expect(res['tipe'], 'jawaban');
      expect(res['pesan'], contains('Tips Hemat'));
    });

    test('respons sapaan dan uji koneksi (tes/test/halo) ramah dan informatif', () async {
      final res = await ApiService.chat('tes');
      expect(res['tipe'], 'jawaban');
      expect(res['pesan'], contains('MengFin AI'));
      expect(res['pesan'], isNot(contains('tidak bisa memproses')));
    });

    test('respons fallback analisis keuangan jika pesan umum', () async {
      final res = await ApiService.chat('kondisi keuanganku');
      expect(res['tipe'], 'jawaban');
      expect(res['pesan'], contains('Analisis Keuangan'));
    });

    test('respons untuk input kosong', () async {
      final res = await ApiService.chat('   ');
      expect(res['tipe'], 'jawaban');
      expect(res['pesan'], isNotEmpty);
    });

    test('respons untuk pertanyaan budget & riwayat', () async {
      final resBudget = await ApiService.chat('cek budget hari ini');
      expect(resBudget['pesan'], contains('Budget'));

      final resRiwayat = await ApiService.chat('daftar transaksi terakhir');
      expect(resRiwayat['pesan'], contains('Transaksi'));
    });
  });
}
