import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// Menyimpan pilihan mode tampilan (Sistem / Terang / Gelap) dan memberi tahu
/// seluruh aplikasi saat berubah.
///
/// Perubahan ikut memperbarui [AppColors] karena layar-layar di aplikasi ini
/// memakai warna dari sana secara langsung, bukan dari ThemeData.
class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _key = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  /// Label singkat untuk ditampilkan di menu Lainnya.
  String get label {
    switch (_mode) {
      case ThemeMode.system:
        return 'Ikut sistem';
      case ThemeMode.light:
        return 'Terang';
      case ThemeMode.dark:
        return 'Gelap';
    }
  }

  IconData get icon {
    switch (_mode) {
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }

  bool get isDark {
    if (_mode == ThemeMode.system) {
      final p = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return p == Brightness.dark;
    }
    return _mode == ThemeMode.dark;
  }

  /// Baca preferensi tersimpan. Dipanggil sekali saat aplikasi mulai.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      _mode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
    } catch (_) {
      _mode = ThemeMode.dark;
    }
    AppColors.applyBrightnessForMode(_mode);
    notifyListeners();
  }

  /// Ganti mode: Sistem → Terang → Gelap → Sistem.
  Future<void> cycle() async {
    _mode = switch (_mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await _persist();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    await _persist();
  }

  Future<void> _persist() async {
    AppColors.applyBrightnessForMode(_mode);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, switch (_mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
    } catch (_) {
      // Gagal menyimpan preferensi bukan alasan menggagalkan ganti tema.
    }
  }

  /// ThemeData siap pakai untuk MaterialApp.
  ThemeData get lightTheme => AppTheme.light();
  ThemeData get darkTheme => AppTheme.dark();
}
