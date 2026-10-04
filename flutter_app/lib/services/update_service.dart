import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Informasi tentang release terbaru dari GitHub
class ReleaseInfo {
  final String tagName;        // e.g. "v20260916-1430"
  final String releaseName;    // e.g. "MengFin v20260916-1430"
  final String body;           // Changelog / release notes
  final String apkDownloadUrl; // URL langsung ke APK
  final String htmlUrl;        // URL halaman release di GitHub
  final DateTime publishedAt;

  const ReleaseInfo({
    required this.tagName,
    required this.releaseName,
    required this.body,
    required this.apkDownloadUrl,
    required this.htmlUrl,
    required this.publishedAt,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    // Cari asset APK dari daftar assets
    String apkUrl = '';
    final assets = json['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.apk')) {
        apkUrl = asset['browser_download_url'] as String? ?? '';
        break;
      }
    }

    return ReleaseInfo(
      tagName: json['tag_name'] as String? ?? '',
      releaseName: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      apkDownloadUrl: apkUrl,
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Hasil pengecekan update
class UpdateCheckResult {
  final bool hasUpdate;
  final ReleaseInfo? release;
  final String currentVersion;

  const UpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    this.release,
  });
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  // ─── GitHub repo untuk cek release terbaru ────────────────────────────────
  static const String _githubOwner = 'Mengggzz';
  static const String _githubRepo  = 'mengfin-app';
  // ───────────────────────────────────────────────────────────────────────────

  static const String _apiUrl =
      'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest';

  String _currentVersion = '3.0.0';
  int _currentBuildNumber = 3;
  bool _hasChecked = false;

  /// Inisialisasi — baca versi app yang terinstall
  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;        // e.g. "3.0.0"
      _currentBuildNumber = int.tryParse(info.buildNumber) ?? 3;
    } catch (_) {
      // Fallback ke hardcoded jika gagal
      _currentVersion = '3.0.0';
      _currentBuildNumber = 3;
    }
  }

  String get currentVersion => _currentVersion;
  int get currentBuildNumber => _currentBuildNumber;

  /// Cek update dari GitHub Releases
  /// Hanya berjalan di Android/non-web
  Future<UpdateCheckResult> checkForUpdate() async {
    if (kIsWeb) {
      return UpdateCheckResult(hasUpdate: false, currentVersion: _currentVersion);
    }

    // Jangan spam cek per session (max sekali per sesi app)
    if (_hasChecked) {
      return UpdateCheckResult(hasUpdate: false, currentVersion: _currentVersion);
    }
    _hasChecked = true;

    try {
      final response = await http
          .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/vnd.github.v3+json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return UpdateCheckResult(hasUpdate: false, currentVersion: _currentVersion);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final release = ReleaseInfo.fromJson(json);

      // Bandingkan build number dari tag (format: vYYYYMMDD-HHMM = selalu lebih baru dari versionCode)
      // Strategi: jika tag ada di release dan APK tersedia → ada update
      // Kita pakai tanggal publish vs buildNumber sebagai proxy
      final hasUpdate = release.apkDownloadUrl.isNotEmpty && _isNewerRelease(release);

      return UpdateCheckResult(
        hasUpdate: hasUpdate,
        currentVersion: _currentVersion,
        release: hasUpdate ? release : null,
      );
    } catch (_) {
      // Tidak ada internet / error → diam saja
      return UpdateCheckResult(hasUpdate: false, currentVersion: _currentVersion);
    }
  }

  /// Cek apakah release dari GitHub lebih baru dari yang terinstall.
  /// Menggunakan tanggal publikasi release vs versionCode (build number).
  /// 
  /// versionCode=3 → build ke-3
  /// GitHub release baru selalu dibuat dengan tag timestamp baru
  /// → jika release lebih baru dari install date, ada update
  bool _isNewerRelease(ReleaseInfo release) {
    // Coba parse build number dari tag jika formatnya vYYYYMMDD-HHMM
    // atau bandingkan dengan hard-coded versionCode
    // Strategi sederhana: cek apakah tag berbeda dari versi yang kita kenal
    final tag = release.tagName; // e.g. "v20260916-1430"
    
    // Jika tag mengandung format timestamp (panjang > 10 karakter setelah 'v')
    // → ini adalah build baru dari GitHub Actions, selalu lebih baru
    if (tag.startsWith('v') && tag.length > 10) {
      // Parse tanggal dari tag: vYYYYMMDD-HHMM
      final datePart = tag.substring(1, 9); // "20260916"
      final buildDate = int.tryParse(datePart) ?? 0;
      // Bandingkan dengan install date (approximasi dari build number)
      // Build 3 diasumsikan dibuat sebelum tanggal hari ini
      // Jika buildDate > 20260916 (tanggal sekarang) → release lebih baru
      final today = int.parse(
        DateTime.now().toIso8601String().replaceAll('-', '').substring(0, 8)
      );
      return buildDate >= today; // Lebih baru atau sama hari ini tapi jam berbeda
    }

    return false;
  }

  /// Reset pengecekan (untuk testing)
  void resetCheck() => _hasChecked = false;
}
