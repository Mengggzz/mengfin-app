import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../constants/config.dart';

/// Informasi tentang release terbaru dari GitHub
class ReleaseInfo {
  final String tag;        // e.g. "v20260923-1210"
  final String name;       // e.g. "MengFin v20260923-1210"
  final String body;       // Changelog / release notes
  final String apkUrl;     // URL langsung ke APK (asset release)
  final String htmlUrl;    // URL halaman release di GitHub
  final DateTime publishedAt;

  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.body,
    required this.apkUrl,
    required this.htmlUrl,
    required this.publishedAt,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) => ReleaseInfo(
        tag: json['tag'] as String? ?? '',
        name: json['name'] as String? ?? '',
        body: json['body'] as String? ?? '',
        apkUrl: json['apk_url'] as String? ?? '',
        htmlUrl: json['html_url'] as String? ?? '',
        publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
      );

  /// Label versi yang enak dibaca: v20260923-1210 → 23 Sep 2026 · 12:10
  String get readableVersion {
    final m = RegExp(r'^v?(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})$').firstMatch(tag);
    if (m == null) return tag;
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
                    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final mm = int.parse(m.group(2)!);
    return '${int.parse(m.group(3)!)} ${months[mm]} ${m.group(1)} · ${m.group(4)}:${m.group(5)}';
  }
}

/// Hasil pengecekan update
class UpdateCheckResult {
  final bool hasUpdate;
  final String currentTag;   // build tag yang terinstall
  final String? latestTag;   // build tag terbaru di GitHub
  final ReleaseInfo? release;
  final bool unknownCurrent; // build tag app tidak diketahui (build lokal)
  final String? error;

  const UpdateCheckResult({
    required this.hasUpdate,
    required this.currentTag,
    this.latestTag,
    this.release,
    this.unknownCurrent = false,
    this.error,
  });
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// Build tag yang tertanam di aplikasi ini (di-set saat build).
  final String _currentTag = kAppBuildTag;
  bool _hasChecked = false;

  String get currentTag => _currentTag;
  String get currentVersion => _currentTag;

  /// Kompatibilitas dengan pemanggilan lama di main.dart.
  /// Build tag di-inject saat compile lewat
  /// `--dart-define=APP_BUILD_TAG=vYYYYMMDD-HHMM`, jadi tidak ada yang
  /// perlu dibaca dari PackageInfo.
  Future<void> init() async {}

  /// Cek update lewat backend (backend yang query GitHub, jadi tidak kena
  /// rate-limit client dan tidak perlu token di app).
  Future<UpdateCheckResult> checkForUpdate() async {
    // Di web, aplikasi selalu menyajikan versi terbaru dari server —
    // konsep "update APK" tidak berlaku.
    if (kIsWeb) {
      return UpdateCheckResult(
        hasUpdate: false, currentTag: _currentTag, unknownCurrent: true);
    }

    if (_hasChecked) {
      return UpdateCheckResult(hasUpdate: false, currentTag: _currentTag);
    }
    _hasChecked = true;

    try {
      final uri = Uri.parse('$kApiBaseUrl/update/check?current=$_currentTag');
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        return UpdateCheckResult(
          hasUpdate: false, currentTag: _currentTag,
          error: 'Server membalas ${res.statusCode}');
      }

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final hasUpdate = j['has_update'] == true;
      final unknownCurrent = j['unknown_current'] == true;
      final latestTag = j['latest_version'] as String?;

      ReleaseInfo? release;
      if (hasUpdate && j['release'] is Map) {
        release = ReleaseInfo.fromJson(Map<String, dynamic>.from(j['release'] as Map));
      }

      return UpdateCheckResult(
        hasUpdate: hasUpdate,
        currentTag: (j['current_version'] as String?) ?? _currentTag,
        latestTag: latestTag,
        release: release,
        unknownCurrent: unknownCurrent,
        error: j['error'] as String?,
      );
    } catch (e) {
      // Tidak ada internet / error → jangan ganggu user
      return UpdateCheckResult(
        hasUpdate: false, currentTag: _currentTag, error: e.toString());
    }
  }

  /// Reset pengecekan (supaya tombol notifikasi bisa cek ulang)
  void resetCheck() => _hasChecked = false;
}
