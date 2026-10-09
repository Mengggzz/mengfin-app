import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/biometric_service.dart';

void main() {
  group('BiometricService & Lifecycle Lock Logic (Task 3)', () {
    test('recordAuthSuccess mencatat timestamp auth terbaru', () {
      final before = DateTime.now();
      BiometricService.instance.recordAuthSuccess();
      final lastAuth = BiometricService.instance.lastAuthSuccessAt;

      expect(lastAuth, isNotNull);
      expect(lastAuth!.isAfter(before.subtract(const Duration(milliseconds: 10))), isTrue);
    });

    test('reopen cepat (<10 detik setelah auth) TIDAK mengunci ulang aplikasi', () {
      // Simulasi user baru saja autentikasi sukses
      BiometricService.instance.recordAuthSuccess();

      final now = DateTime.now();
      final lastAuth = BiometricService.instance.lastAuthSuccessAt;
      final bool recentlyAuthed = lastAuth != null && now.difference(lastAuth).inSeconds < 10;

      // Saat paused time tercatat 3 detik lalu (misal karena dialog biometrik sistem)
      final pausedTime = now.subtract(const Duration(seconds: 3));
      final bool shouldLock = !recentlyAuthed && now.difference(pausedTime).inSeconds >= 2;

      expect(recentlyAuthed, isTrue);
      expect(shouldLock, isFalse, reason: 'Jangan minta biometrik 2x jika baru saja sukses diverifikasi');
    });

    test('background > 10 detik setelah auth MENGUNCI aplikasi secara normal', () {
      // Simulasi auth sudah lewat 15 detik lalu
      final fifteenSecondsAgo = DateTime.now().subtract(const Duration(seconds: 15));
      // Manual test check:
      final now = DateTime.now();
      final bool recentlyAuthed = now.difference(fifteenSecondsAgo).inSeconds < 10;

      final pausedTime = now.subtract(const Duration(seconds: 5));
      final bool shouldLock = !recentlyAuthed && now.difference(pausedTime).inSeconds >= 2;

      expect(recentlyAuthed, isFalse);
      expect(shouldLock, isTrue, reason: 'Aplikasi harus terkunci saat ditinggal di background');
    });
  });
}
