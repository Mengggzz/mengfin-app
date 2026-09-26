import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import 'api_service.dart';
import 'app_events.dart';
import 'app_prefs.dart';
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

    await simpan(hasil);
  }

  /// Simpan hasil bacaan sebagai transaksi. Terpisah dari [_tangani] supaya
  /// bisa diuji tanpa plugin dan supaya tombol "Catat sekarang" di layar
  /// pengaturan memakai jalur yang persis sama.
  Future<bool> simpan(NotifTransaksi t) async {
    // Notifikasi yang sama bisa dikirim ulang; lewati kalau persis sama
    // dalam waktu dekat.
    final kunci = '${t.sumber}|${t.nominal}|${t.teks}';
    final sekarang = DateTime.now();
    if (_terakhirKunci == kunci &&
        _terakhirWaktu != null &&
        sekarang.difference(_terakhirWaktu!).inSeconds < 60) {
      return false;
    }

    try {
      await ApiService.createTransaksi({
        'tanggal': _tanggalHariIni(),
        'jenis': t.jenis,
        'nominal': t.nominal,
        'kategori': t.kategori,
        'deskripsi': t.deskripsi,
        'metode_pembayaran': 'auto-notifikasi',
      });
      _terakhirKunci = kunci;
      _terakhirWaktu = sekarang;
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
  static int get warnaAktif => AppColors.primary.value;
}
