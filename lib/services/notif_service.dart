import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'app_events.dart';
import 'app_prefs.dart';
import 'local_db.dart';
import 'notif_parser.dart';

/// Auto-catat dari notifikasi.
///
/// Membaca notifikasi lewat plugin `notification_listener_service`, menyaring
/// teksnya dengan [NotifParser] (bagian murni yang diuji terpisah), lalu
/// menyimpan transaksinya lewat [ApiService] sehingga aturan offline tetap
/// berlaku sama seperti input manual.
///
/// Hanya jalan di Android. Di web/desktop layanan ini nonaktif dan
/// [tersedia] bernilai false, jadi UI bisa bilang terus terang.
class NotifService {
  NotifService._();
  static final NotifService instance = NotifService._();

  /// Satu transaksi tercatat otomatis (untuk pemberitahuan ke pengguna).
  final ValueNotifier<NotifTransaksi?> terakhir =
      ValueNotifier<NotifTransaksi?>(null);

  /// Jumlah baris yang berhasil disimpan sejak app dibuka.
  final ValueNotifier<int> jumlahTercatat = ValueNotifier<int>(0);

  /// Teks notifikasi yang terakhir terlihat, untuk diagnosis saat pengguna
  /// mengira fitur ini tidak bekerja. Disimpan di memori saja.
  final ValueNotifier<String?> contohTerakhir = ValueNotifier<String?>(null);

  StreamSubscription<dynamic>? _langganan;
  bool _jalan = false;

  static bool get tersedia => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get aktif => _jalan;

  /// Izin "akses notifikasi" sudah diberikan pengguna?
  Future<bool> izinDiberikan() async {
    if (!tersedia) return false;
    try {
      return await _invoke<bool>('isPermissionGranted') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Buka layar pengaturan izin. Kembalian true kalau izin langsung diberikan
  /// (biasanya pengguna harus mengaktifkannya manual, jadi false itu normal).
  Future<bool> mintaIzin() async {
    if (!tersedia) return false;
    try {
      return await _invoke<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mulai mendengarkan notifikasi. Aman dipanggil berkali-kali.
  Future<void> mulai() async {
    if (!tersedia || _jalan) return;
    if (!await izinDiberikan()) return;

    try {
      final stream = await _stream();
      if (stream == null) return;
      _langganan = stream.listen(_tangani, onError: (Object e) {
        debugPrint('NotifService stream error: $e');
      });
      _jalan = true;
    } catch (e) {
      debugPrint('NotifService gagal mulai: $e');
    }
  }

  Future<void> berhenti() async {
    await _langganan?.cancel();
    _langganan = null;
    _jalan = false;
  }

  /// Dipakai saat pengguna menyalakan/mematikan toggle.
  Future<void> terapkanPreferensi() async {
    if (AppPrefs.instance.notifAktif) {
      await mulai();
    } else {
      await berhenti();
    }
  }

  Future<void> _tangani(dynamic event) async {
    if (!AppPrefs.instance.notifAktif) return;

    final map = _sebagaiMap(event);
    if (map == null) return;

    final paket = (map['packageName'] ?? '').toString();
    if (paket.isEmpty) return;
    // Jangan baca notifikasi kita sendiri (mengganggu dan bisa berulang).
    if (paket == _paketSendiri) return;
    if ((map['hasRemoved'] ?? false) == true) return;
    if (!AppPrefs.instance.bolehPantau(paket)) return;

    final title = (map['title'] ?? '').toString();
    final content = (map['content'] ?? '').toString();
    if (title.isEmpty && content.isEmpty) return;

    // Catat apa yang terlihat supaya pengguna bisa memeriksa kenapa
    // sebuah notifikasi tidak tertangkap.
    contohTerakhir.value = '$paket: $title — $content';

    final hasil = NotifParser.parse(
      title: title,
      content: content,
      packageName: paket,
      kataKunci: AppPrefs.instance.kataKunci.toSet(),
    );
    if (hasil == null) return;

    final draftId = 'draft_${DateTime.now().millisecondsSinceEpoch}_${hasil.hashCode.abs()}';
    final appName = _namaAplikasi(paket);
    final resolvedAkunId = await cariAkunId(paket);

    // Simpan draft notifikasi
    final draft = NotifDraft(
      id: draftId,
      packageName: paket,
      appName: appName,
      title: title,
      body: content,
      nominal: hasil.nominal,
      jenis: hasil.jenis,
      kategori: hasil.kategori,
      waktu: DateTime.now().toIso8601String(),
      status: AppPrefs.instance.notifReviewDraft ? 'draft' : 'approved',
      akunId: resolvedAkunId,
    );
    await LocalDb.insertNotifDraft(draft);
    AppEvents.instance.notifDraftBerubah();

    // Jika mode review draft tidak aktif, langsung masukkan ke transaksi resmi
    if (!AppPrefs.instance.notifReviewDraft) {
      await simpan(hasil, akunId: resolvedAkunId);
    } else {
      terakhir.value = hasil;
      jumlahTercatat.value = jumlahTercatat.value + 1;
    }
  }

  /// Konversi draft menjadi transaksi resmi
  Future<bool> setujuiDraft(NotifDraft draft) async {
    try {
      final targetAkunId = (draft.akunId != null && draft.akunId!.isNotEmpty)
          ? draft.akunId
          : await cariAkunId(draft.packageName);
      await ApiService.createTransaksi({
        'tanggal': _tanggalHariIni(),
        'jenis': draft.jenis,
        'nominal': draft.nominal,
        'kategori': draft.kategori,
        'deskripsi': draft.body.isNotEmpty ? draft.body : draft.title,
        'metode_pembayaran': 'auto-notifikasi (${draft.appName})',
        if (targetAkunId != null && targetAkunId.isNotEmpty) 'akun_id': targetAkunId,
      });
      await LocalDb.updateNotifDraftStatus(draft.id, 'approved');
      AppEvents.instance.notifDraftBerubah();
      AppEvents.instance.transaksiBerubah();
      return true;
    } catch (e) {
      debugPrint('Gagal setujui draft: $e');
      return false;
    }
  }

  /// Setujui semua draft pending
  Future<int> setujuiSemuaDraft() async {
    final drafts = await LocalDb.getNotifDrafts(status: 'draft');
    int berhasil = 0;
    for (final d in drafts) {
      final ok = await setujuiDraft(d);
      if (ok) berhasil++;
    }
    return berhasil;
  }

  /// Abaikan / tolak draft
  Future<void> abaikanDraft(String id) async {
    await LocalDb.updateNotifDraftStatus(id, 'ignored');
    AppEvents.instance.notifDraftBerubah();
  }

  static String _namaAplikasi(String packageName) {
    if (packageName.contains('gojek')) return 'GoPay / Gojek';
    if (packageName.contains('dana')) return 'DANA';
    if (packageName.contains('ovo')) return 'OVO';
    if (packageName.contains('shopee')) return 'ShopeePay';
    if (packageName.contains('bca')) return 'BCA';
    if (packageName.contains('brimo') || packageName.contains('bri')) return 'BRImo';
    if (packageName.contains('livin') || packageName.contains('bmri')) return 'Livin Mandiri';
    if (packageName.contains('bni')) return 'BNI Mobile';
    if (packageName.contains('jenius')) return 'Jenius';
    if (packageName.contains('seabank')) return 'SeaBank';
    if (packageName.contains('jago')) return 'Bank Jago';
    return packageName.split('.').last;
  }

  /// Cocokkan nama aplikasi bank / paket dengan daftar akun pengguna
  static Future<String?> cariAkunId(String paket) async {
    try {
      final akuns = await LocalDb.getAkunList();
      if (akuns.isEmpty) return AppPrefs.instance.dompetUtama;
      final namaApp = _namaAplikasi(paket).toLowerCase();
      final paketLower = paket.toLowerCase();

      final sorted = List<Akun>.from(akuns)
        ..sort((a, b) => b.nama.length.compareTo(a.nama.length));

      for (final a in sorted) {
        final aNama = a.nama.trim().toLowerCase();
        if (aNama.isEmpty) continue;
        if (namaApp.contains(aNama) || aNama.contains(namaApp) || paketLower.contains(aNama)) {
          return a.id.toString();
        }
      }

      final bankTokens = [
        'seabank', 'bca', 'brimo', 'bri', 'livin', 'mandiri', 'bni', 'jago', 'jenius',
        'dana', 'gopay', 'gojek', 'ovo', 'shopeepay'
      ];
      for (final token in bankTokens) {
        if (namaApp.contains(token) || paketLower.contains(token)) {
          for (final a in sorted) {
            final aNama = a.nama.trim().toLowerCase();
            if (aNama.contains(token)) {
              return a.id.toString();
            }
          }
        }
      }

      return AppPrefs.instance.dompetUtama;
    } catch (_) {
      return AppPrefs.instance.dompetUtama;
    }
  }

  /// Simpan hasil bacaan sebagai transaksi. Terpisah dari [_tangani] supaya
  /// bisa diuji tanpa plugin dan supaya tombol "Catat sekarang" di layar
  /// pengaturan memakai jalur yang persis sama.
  Future<bool> simpan(NotifTransaksi t, {String? akunId}) async {
    // Task 1g: Dedup 10 menit (600 detik) persisten via SharedPreferences
    final kunci = '${t.sumber}|${t.nominal}|${t.teks}';
    final sekarangMs = DateTime.now().millisecondsSinceEpoch;
    const durasiDedupMs = 10 * 60 * 1000;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawCache = prefs.getString('notif_dedup_cache');
      Map<String, dynamic> dedupMap = {};
      if (rawCache != null && rawCache.isNotEmpty) {
        try {
          dedupMap = Map<String, dynamic>.from(jsonDecode(rawCache) as Map);
        } catch (_) {}
      }

      dedupMap.removeWhere((k, v) => (v is num) && (sekarangMs - v > durasiDedupMs));

      final waktuLalu = dedupMap[kunci] as num?;
      if (waktuLalu != null && (sekarangMs - waktuLalu < durasiDedupMs)) {
        return false;
      }

      dedupMap[kunci] = sekarangMs;
      await prefs.setString('notif_dedup_cache', jsonEncode(dedupMap));
    } catch (_) {
      final sekarang = DateTime.now();
      if (_terakhirKunci == kunci &&
          _terakhirWaktu != null &&
          sekarang.difference(_terakhirWaktu!).inSeconds < 600) {
        return false;
      }
      _terakhirKunci = kunci;
      _terakhirWaktu = sekarang;
    }

    try {
      final targetAkunId = akunId ?? await cariAkunId(t.sumber);
      await ApiService.createTransaksi({
        'tanggal': _tanggalHariIni(),
        'jenis': t.jenis,
        'nominal': t.nominal,
        'kategori': t.kategori,
        'deskripsi': t.deskripsi,
        'metode_pembayaran': 'auto-notifikasi',
        if (targetAkunId != null && targetAkunId.isNotEmpty) 'akun_id': targetAkunId,
      });
      terakhir.value = t;
      jumlahTercatat.value = jumlahTercatat.value + 1;
      AppEvents.instance.transaksiBerubah();
      return true;
    } catch (e) {
      debugPrint('NotifService gagal simpan: $e');
      return false;
    }
  }

  String? _terakhirKunci;
  DateTime? _terakhirWaktu;

  static String _tanggalHariIni() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  /// Nama paket aplikasi ini, dibaca dari Android (tidak perlu ditulis mati
  /// di kode supaya tidak salah kalau applicationId berubah).
  String? _paketSendiriCache;
  String get _paketSendiri => _paketSendiriCache ?? '';

  /// Daftar nama paket aplikasi yang dipasang, buat pemilih "Aplikasi yang
  /// dipantau". Hanya Android; di luar Android mengembalikan daftar kosong.
  ///
  /// Diberi batas waktu: tanpa plugin yang menjawab, Future MethodChannel
  /// bisa menggantung selamanya dan membuat indikator loading berputar
  /// terus (terbukti lewat tes widget).
  Future<List<String>> daftarPaketTerpasang() async {
    if (!tersedia) return const [];
    try {
      final hasil = await _invoke<List<dynamic>>('getInstalledApps')
          .timeout(const Duration(seconds: 2));
      if (hasil == null) return const [];
      return hasil.map((e) => e.toString()).toList()..sort();
    } on TimeoutException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Buka layar pengaturan izin akses notifikasi (di Android: pengaturan
  /// Notification Listener). Kembali ke app setelah pengguna selesai.
  Future<void> bukaPengaturanIzin() async {
    if (!tersedia) return;
    try {
      await _invoke<void>('openNotificationSettings');
    } catch (_) {}
  }

  Future<void> muatPaketSendiri() async {
    if (!tersedia) return;
    try {
      _paketSendiriCache = await _invoke<String>('getApplicationId');
    } catch (_) {
      _paketSendiriCache = null;
    }
  }

  // ── Akses plugin ─────────────────────────────────────────────────────────
  // Dibungkus di satu tempat supaya kalau pluginnya berubah, hanya di sini
  // yang perlu disesuaikan, dan supaya kegagalan plugin (mis. di uji) tidak
  // menjatuhkan aplikasi.

  static const _kanalMetode = MethodChannel('x-slayer/notifications_channel');
  static const _kanalPeristiwa = EventChannel('x-slayer/notifications_event');

  Future<T?> _invoke<T>(String metode) async {
    try {
      return await _kanalMetode.invokeMethod<T>(metode);
    } on PlatformException catch (e) {
      debugPrint('NotifService $metode gagal: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<Stream<dynamic>?> _stream() async {
    try {
      return _kanalPeristiwa.receiveBroadcastStream();
    } on MissingPluginException {
      return null;
    }
  }

  Map<dynamic, dynamic>? _sebagaiMap(dynamic event) {
    if (event is Map) return event;
    return null;
  }

  /// Warna indikator di UI (dipakai layar pengaturan).
  static int get warnaAktif => AppColors.primary.toARGB32();
}
