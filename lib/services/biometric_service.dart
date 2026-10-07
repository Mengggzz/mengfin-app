import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Layanan otentikasi biometrik (Fingerprint / Face ID).
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Apakah perangkat mendukung dan memiliki biometrik aktif?
  Future<bool> canAuthenticate() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('BiometricService canAuthenticate error: $e');
      return false;
    }
  }

  /// Daftar jenis sensor biometrik yang terpasang
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return const [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('BiometricService getAvailableBiometrics error: $e');
      return const [];
    }
  }

  /// Minta verifikasi biometrik dari pengguna
  Future<bool> authenticate({
    String localizedReason = 'Pindai sidik jari atau wajah untuk membuka MengFin',
  }) async {
    if (kIsWeb) return true;
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('BiometricService authenticate error: $e');
      return false;
    }
  }
}
