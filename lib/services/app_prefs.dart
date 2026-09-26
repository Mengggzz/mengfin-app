import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi pengguna yang benar-benar dipakai aplikasi.
///
/// Sebelumnya layar pengaturan hanya menyimpan pilihannya di variabel lokal:
/// menekan "Simpan" cuma menutup layar, jadi pilihan dompet utama, daftar
/// kata kunci notifikasi, dan toggle auto-notifikasi hilang begitu layar
/// ditutup. Semua yang di sini disimpan ke SharedPreferences.
class AppPrefs {
  /// Boleh dibuat berkali-kali: tiap instance membaca ulang dari
  /// SharedPreferences, jadi uji "muat ulang seperti habis restart" bisa
  /// memakai instance baru tanpa merusak yang sedang dipakai aplikasi.
  AppPrefs();

  static final AppPrefs instance = AppPrefs();

  static const _kDompetUtama = 'dompet_utama_id';
  static const _kDompetTampil = 'dompet_tampil_ids';
  static const _kNotifAktif = 'notif_auto_aktif';
  static const _kKataKunci = 'notif_kata_kunci';
  static const _kAppPantau = 'notif_app_dipantau';

  List<String> _kataKunci = List.of(kKataKunciBawaan);
  List<String> _appDipantau = const [];
  List<String> _dompetTampil = const [];
  String? _dompetUtama;
  bool _notifAktif = false;

  List<String> get kataKunci => List.unmodifiable(_kataKunci);
  List<String> get appDipantau => List.unmodifiable(_appDipantau);
  List<String> get dompetTampil => List.unmodifiable(_dompetTampil);
  String? get dompetUtama => _dompetUtama;
  bool get notifAktif => _notifAktif;

  /// Kata kunci awal — dipakai parser kalau pengguna membiarkannya.
  static const List<String> kKataKunciBawaan = [
    'pembayaran', 'transaksi', 'berhasil', 'debit', 'transfer', 'qris',
  ];

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _notifAktif = p.getBool(_kNotifAktif) ?? false;
    _dompetUtama = p.getString(_kDompetUtama);

    final kw = p.getStringList(_kKataKunci);
    _kataKunci = kw == null || kw.isEmpty ? List.of(kKataKunciBawaan) : kw;

    _appDipantau = p.getStringList(_kAppPantau) ?? const [];
    _dompetTampil = p.getStringList(_kDompetTampil) ?? const [];
  }

  Future<void> setDompetUtama(String? id) async {
    _dompetUtama = id;
    final p = await SharedPreferences.getInstance();
    if (id == null) {
      await p.remove(_kDompetUtama);
    } else {
      await p.setString(_kDompetUtama, id);
    }
  }

  Future<void> setDompetTampil(List<String> ids) async {
    _dompetTampil = List.of(ids);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kDompetTampil, _dompetTampil);
  }

  Future<void> setNotifAktif(bool aktif) async {
    _notifAktif = aktif;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifAktif, aktif);
  }

  Future<void> setKataKunci(List<String> kata) async {
    _kataKunci = List.of(kata);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kKataKunci, _kataKunci);
  }

  Future<void> setAppDipantau(List<String> paket) async {
    _appDipantau = List.of(paket);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kAppPantau, _appDipantau);
  }

  /// Paket yang boleh dibaca. Kosong = semua aplikasi (kecuali aplikasi ini).
  bool bolehPantau(String packageName) {
    if (_appDipantau.isEmpty) return true;
    return _appDipantau.contains(packageName);
  }

  /// Perbandingan id yang aman: id bisa int (lokal) atau String (ObjectId).
  static String idKeTeks(dynamic id) => id?.toString() ?? '';

  @visibleForTesting
  Future<void> reset() async {
    _kataKunci = List.of(kKataKunciBawaan);
    _appDipantau = const [];
    _dompetTampil = const [];
    _dompetUtama = null;
    _notifAktif = false;
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }
}
