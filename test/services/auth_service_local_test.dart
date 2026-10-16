import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/constants/config.dart';
import 'package:mengfin/services/auth_service.dart';

void main() {
  test('AuthService menganggap user sudah login saat kLocalMode aktif', () {
    expect(kLocalMode, isTrue);
    expect(AuthService.instance.isLoggedIn, isTrue);
    expect(AuthService.instance.user?['nama'], equals('Pengguna Lokal'));
    expect(AuthService.instance.user?['email'], equals('lokal@mengfin.app'));
  });
}
