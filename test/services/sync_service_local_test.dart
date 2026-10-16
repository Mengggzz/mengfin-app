import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/constants/config.dart';
import 'package:mengfin/services/sync_service.dart';

void main() {
  test('SyncService tidak melakukan pengiriman di kLocalMode', () async {
    expect(kLocalMode, isTrue);
    final res = await SyncService.instance.syncToServer();
    expect(res.terkirim, equals(0));
    expect(res.gagal, equals(0));
  });

  test('SyncService triggerManualSync mengembalikan SyncResult kosong saat kLocalMode', () async {
    final res = await SyncService.instance.triggerManualSync();
    expect(res.terkirim, equals(0));
    expect(res.gagal, equals(0));
  });
}
