import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/constants/config.dart';

void main() {
  test('kLocalMode bernilai true secara default saat API_BASE_URL tidak diset', () {
    expect(kLocalMode, isTrue);
  });

  test('kApiBaseUrl kosong saat mode lokal aktif', () {
    expect(kApiBaseUrl, isEmpty);
  });
}
