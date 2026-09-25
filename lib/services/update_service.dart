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

  /// Bangun dari respons GitHub Releases API (api.github.com).
  factory ReleaseInfo.fromGithub(Map<String, dynamic> json) {
    final assets = (json['assets'] as List?) ?? const [];
    String apk = '';
    for (final a in assets) {
      final m = a as Map;
      final name = (m['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apk = m['browser_download_url'] as String? ?? '';
        if (name.contains('release')) break; // utamakan app-release.apk
      }
    }
    return ReleaseInfo(
      tag: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? json['tag_name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      apkUrl: apk,
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt:
          DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

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
  final String source;       // 'github' | 'backend' | 'none'

  const UpdateCheckResult({
    required this.hasUpdate,
    required this.currentTag,
    this.latestTag,
    this.release,
    this.unknownCurrent = false,
    this.error,
    this.source = 'none',
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

  /// Build tag lokal tidak diset → app hasil build manual (flutter run).
  bool get _tagKosong => _currentTag.trim().isEmpty;

  /// Kompatibilitas dengan pemanggilan lama di main.dart.
  /// Build tag di-inject saat compile lewat
  /// `--dart-define=APP_BUILD_TAG=vYYYYMMDD-HHMM`, jadi tidak ada yang
  /// perlu dibaca dari PackageInfo.
  Future<void> init() async {}

  /// Cek update: query GitHub Releases LANGSUNG.
  ///
  /// Sebelumnya pengecekan lewat backend `GET /update/check`, tapi server
  /// produksi (Railway) masih versi lama dan membalas 404 — akibatnya
  /// notifikasi update selalu error dan tidak pernah menampilkan versi
  /// terbaru. Repo GitHub-nya publik, jadi app bisa query sendiri dan
  /// backend cuma dipakai sebagai cadangan.
  Future<UpdateCheckResult> checkForUpdate({bool force = false}) async {
    // Di web, aplikasi selalu menyajikan versi terbaru dari server —
    // konsep "update APK" tidak berlaku.
    if (kIsWeb) {
      return UpdateCheckResult(
        hasUpdate: false, currentTag: _currentTag, unknownCurrent: true);
    }

    // Hasil gagal tidak di-cache: tombol notifikasi harus bisa cek ulang.
    if (_hasChecked && !force) {
      return UpdateCheckResult(hasUpdate: false, currentTag: _currentTag);
    }

    // 1) GitHub Releases API (sumber utama)
    try {
      final hasil = await _cekGithub();
      _hasChecked = true;
      return hasil;
    } catch (_) {
      // lanjut ke backend
    }

    // 2) Backend sebagai cadangan
    try {
      final hasil = await _cekBackend();
      _hasChecked = true;
      return hasil;
    } catch (e) {
      _hasChecked = false;
      return UpdateCheckResult(
        hasUpdate: false,
        currentTag: _currentTag,
        unknownCurrent: _tagKosong,
        error: e.toString(),
      );
    }
  }

  Future<UpdateCheckResult> _cekGithub() async {
    final uri = Uri.parse(
        'https://api.github.com/repos/$kGithubOwner/$kGithubRepo/releases/latest');
    final res = await http.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'MengFin-App',
    }).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('GitHub membalas ${res.statusCode}');
    }

    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (j['tag_name'] as String? ?? '').trim();
    if (tag.isEmpty) throw Exception('Release terbaru tidak punya tag');

    final release = ReleaseInfo.fromGithub(j);
    final hasUpdate = _tagKosong ? false : _lebihBaru(tag, _currentTag);

    return UpdateCheckResult(
      hasUpdate: hasUpdate,
      currentTag: _currentTag,
      latestTag: tag,
      release: hasUpdate ? release : release,
      unknownCurrent: _tagKosong,
      source: 'github',
    );
  }

  Future<UpdateCheckResult> _cekBackend() async {
    final uri = Uri.parse('$kApiBaseUrl/update/check?current=$_currentTag');
    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Server membalas ${res.statusCode}');
    }

    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final hasUpdate = j['has_update'] == true;
    final latestTag = j['latest_version'] as String?;

    ReleaseInfo? release;
    if (j['release'] is Map) {
      release = ReleaseInfo.fromJson(Map<String, dynamic>.from(j['release'] as Map));
      // Beberapa versi backend tidak mengisi apk_url → lengkapi dari tag.
      if (release.apkUrl.isEmpty && latestTag != null && latestTag.isNotEmpty) {
        release = ReleaseInfo(
          tag: release.tag.isEmpty ? latestTag : release.tag,
          name: release.name,
          body: release.body,
          apkUrl: apkUrlFor(latestTag),
          htmlUrl: release.htmlUrl,
          publishedAt: release.publishedAt,
        );
      }
    }

    return UpdateCheckResult(
      hasUpdate: hasUpdate,
      currentTag: (j['current_version'] as String?) ?? _currentTag,
      latestTag: latestTag,
      release: release,
      unknownCurrent: j['unknown_current'] == true,
      error: j['error'] as String?,
      source: 'backend',
    );
  }

  /// URL APK untuk sebuah tag (pola nama file dari workflow CI).
  static String apkUrlFor(String tag) =>
      'https://github.com/$kGithubOwner/$kGithubRepo/releases/download/$tag/app-release.apk';

  /// Halaman rilis di GitHub (dipakai tombol "Buka di GitHub").
  static String get releasesPage =>
      'https://github.com/$kGithubOwner/$kGithubRepo/releases';

  /// Bandingkan tag format vYYYYMMDD-HHMM. Tag tanpa pola dianggap tidak
  /// lebih baru.
  static bool _lebihBaru(String kandidat, String sekarang) {
    int? num(String s) {
      final m = RegExp(r'^v?(\d{8})-(\d{4})$').firstMatch(s.trim());
      if (m == null) return null;
      return int.tryParse('${m.group(1)}${m.group(2)}');
    }

    final a = num(kandidat);
    final b = num(sekarang);
    if (a == null) return false;
    if (b == null) return true; // build tag lokal tidak dikenal → anggap ada update
    return a > b;
  }

  /// Reset pengecekan (supaya tombol notifikasi bisa cek ulang)
  void resetCheck() => _hasChecked = false;
}
