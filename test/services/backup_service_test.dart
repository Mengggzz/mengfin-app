import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/backup_service.dart';

void main() {
  test('createBackupPayload menghasilkan struktur JSON valid dengan 6 tabel', () {
    final payload = BackupService.createBackupPayload({
      'akun': [{'id': 'a1', 'nama': 'Dompet'}],
      'anggaran': [],
      'goals': [],
      'notif_draft': [],
      'sync_queue': [],
      'transaksi': [{'id': 't1', 'nominal': 50000}],
    }, appVersion: '1.0.0');

    expect(payload['format'], equals('mengfin-backup'));
    expect(payload['version'], equals(1));
    expect(payload['appVersion'], equals('1.0.0'));
    expect(payload['exportedAt'], isNotNull);
    final tables = payload['tables'] as Map<String, dynamic>;
    expect(tables.keys, containsAll(['akun', 'anggaran', 'goals', 'notif_draft', 'sync_queue', 'transaksi']));
    expect((tables['transaksi'] as List).length, equals(1));
  });

  test('validateBackupJson menolak format non-json atau format asing', () {
    expect(() => BackupService.validateBackupJson('bukan json valid'), throwsA(isA<FormatException>()));
    expect(() => BackupService.validateBackupJson('{"format": "asing"}'), throwsA(isA<Exception>()));
    expect(() => BackupService.validateBackupJson('{"format": "mengfin-backup", "version": 99}'), throwsA(isA<Exception>()));
    expect(() => BackupService.validateBackupJson('{"format": "mengfin-backup", "version": 1}'), throwsA(isA<FormatException>()));
  });

  test('validateBackupJson berhasil mengekstrak ringkasan isi cadangan', () {
    final validJson = jsonEncode({
      'format': 'mengfin-backup',
      'version': 1,
      'appVersion': '1.0.0',
      'exportedAt': '2026-10-16T10:00:00.000Z',
      'tables': {
        'transaksi': [{'id': 't1', 'nominal': 10000}, {'id': 't2', 'nominal': 20000}],
        'akun': [{'id': 'a1', 'nama': 'Dompet'}],
        'anggaran': [],
        'goals': [],
        'notif_draft': [],
        'sync_queue': [],
      }
    });

    final summary = BackupService.validateBackupJson(validJson);
    expect(summary['transaksiCount'], equals(2));
    expect(summary['akunCount'], equals(1));
    expect(summary['anggaranCount'], equals(0));
    expect(summary['exportedAt'], equals('2026-10-16T10:00:00.000Z'));
  });
}
