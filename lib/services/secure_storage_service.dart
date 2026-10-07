import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layanan penyimpanan terenkripsi hardware-backed (Android Keystore / iOS Keychain).
/// Menyimpan token JWT dan data akun sensitif dengan aman.
/// Mendukung fallback otomatis dan migrasi dari SharedPreferences lama.
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> write(String key, String value) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      } else {
        await _storage.write(key: key, value: value);
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
  }

  Future<String?> read(String key) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key);
      }
      final val = await _storage.read(key: key);
      if (val != null) return val;

      // Cek migrasi dari SharedPreferences lama jika ada
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(key);
      if (legacy != null) {
        try {
          await _storage.write(key: key, value: legacy);
        } catch (_) {}
        await prefs.remove(key);
        return legacy;
      }
      return null;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  Future<void> delete(String key) async {
    try {
      if (!kIsWeb) {
        await _storage.delete(key: key);
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> clearAll() async {
    try {
      if (!kIsWeb) {
        await _storage.deleteAll();
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
  }
}
