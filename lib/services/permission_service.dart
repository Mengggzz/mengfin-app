import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notif_service.dart';

/// Layanan terpusat untuk memeriksa dan meminta izin sistem Android
/// (Penyimpanan, Notifikasi, dan Akses Notifikasi / Auto-Catat).
class PermissionService {
  PermissionService._();

  /// Periksa apakah izin penyimpanan / media sudah diberikan.
  static Future<bool> cekIzinPenyimpanan() async {
    if (kIsWeb) return true;
    try {
      final storageStatus = await Permission.storage.status;
      final photosStatus = await Permission.photos.status;
      return storageStatus.isGranted || photosStatus.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Minta izin penyimpanan dan akses media lokal.
  static Future<bool> mintaIzinPenyimpanan() async {
    if (kIsWeb) return true;
    try {
      final statuses = await [
        Permission.storage,
        Permission.photos,
      ].request();

      final storageGranted = statuses[Permission.storage]?.isGranted ?? false;
      final photosGranted = statuses[Permission.photos]?.isGranted ?? false;
      return storageGranted || photosGranted;
    } catch (_) {
      return false;
    }
  }

  /// Periksa status izin push notifikasi (Android 13+).
  static Future<bool> cekIzinNotifikasi() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Minta izin push notifikasi aplikasi.
  static Future<bool> mintaIzinNotifikasi() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Periksa izin akses pendengar notifikasi sistem (Notification Listener Service).
  static Future<bool> cekIzinAksesNotifikasi() async {
    if (kIsWeb) return false;
    return await NotifService.instance.izinDiberikan();
  }

  /// Minta izin akses pendengar notifikasi sistem ke pengguna (buka halaman setting Android).
  static Future<bool> mintaIzinAksesNotifikasi() async {
    if (kIsWeb) return false;
    return await NotifService.instance.mintaIzin();
  }

  /// Buka menu pengaturan aplikasi sistem Android.
  static Future<bool> bukaPengaturanApp() async {
    if (kIsWeb) return false;
    return await openAppSettings();
  }
}
