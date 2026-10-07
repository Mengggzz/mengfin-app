import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricStatus {
  success,
  failed,
  canceled,
  notAvailable,
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
  error,
}

class BiometricResult {
  final BiometricStatus status;
  final String message;

  const BiometricResult({required this.status, required this.message});

  bool get isSuccess => status == BiometricStatus.success;
}

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

  /// Minta verifikasi biometrik dengan detail status respons
  Future<BiometricResult> authenticateWithDetails({
    String localizedReason = 'Pindai sidik jari atau wajah untuk membuka MengFin',
  }) async {
    if (kIsWeb) {
      return const BiometricResult(
        status: BiometricStatus.success,
        message: 'Web platform: bypassed',
      );
    }

    try {
      final canCheck = await canAuthenticate();
      if (!canCheck) {
        return const BiometricResult(
          status: BiometricStatus.notAvailable,
          message: 'Perangkat tidak mendukung atau belum mengaktifkan kunci biometrik/PIN.',
        );
      }

      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        return const BiometricResult(
          status: BiometricStatus.success,
          message: 'Verifikasi berhasil.',
        );
      } else {
        return const BiometricResult(
          status: BiometricStatus.canceled,
          message: 'Verifikasi biometrik dibatalkan.',
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Biometric PlatformException: code=${e.code}, message=${e.message}');
      switch (e.code) {
        case 'NotAvailable':
        case 'PasscodeNotSet':
          return const BiometricResult(
            status: BiometricStatus.notAvailable,
            message: 'Kunci keamanan atau PIN belum diatur di pengaturan HP.',
          );
        case 'NotEnrolled':
          return const BiometricResult(
            status: BiometricStatus.notEnrolled,
            message: 'Sidik jari atau wajah belum didaftarkan di pengaturan HP.',
          );
        case 'LockedOut':
          return const BiometricResult(
            status: BiometricStatus.lockedOut,
            message: 'Terlalu banyak percobaan gagal. Silakan coba lagi nanti.',
          );
        case 'PermanentlyLockedOut':
          return const BiometricResult(
            status: BiometricStatus.permanentlyLockedOut,
            message: 'Sensor biometrik terkunci. Buka HP dengan PIN/pola utama.',
          );
        default:
          return BiometricResult(
            status: BiometricStatus.error,
            message: e.message ?? 'Terjadi kesalahan pada verifikasi biometrik.',
          );
      }
    } catch (e) {
      return BiometricResult(
        status: BiometricStatus.error,
        message: 'Gagal melakukan verifikasi: $e',
      );
    }
  }

  /// Minta verifikasi biometrik sederhana (mengembalikan true/false)
  Future<bool> authenticate({
    String localizedReason = 'Pindai sidik jari atau wajah untuk membuka MengFin',
  }) async {
    final result = await authenticateWithDetails(localizedReason: localizedReason);
    return result.isSuccess;
  }
}
