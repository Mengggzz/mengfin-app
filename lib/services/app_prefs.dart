import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_events.dart';

/// Preferensi pengguna yang benar-benar dipakai aplikasi.
///
/// Menyimpan pilihan dompet utama, notifikasi, serta kustomisasi beranda
/// (mode data 7 hari / siklus aktif, toggle grafik, budget harian,
/// urutan aksi cepat, dan judul beranda yang dapat dikustomisasi).
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

  // Pengaturan beranda & kustomisasi
  static const _kHomeDataMode = 'home_data_mode';
  static const _kHomeShowChart = 'home_show_chart';
  static const _kHomeShowBudget = 'home_show_budget';
  static const _kQuickActionOrder = 'quick_action_order';
  static const _kHomeTitle = 'home_title';

  static const List<String> kDefaultQuickActions = ['voice', 'ai', 'scan', 'budget'];

  List<String> _kataKunci = List.of(kKataKunciBawaan);
  List<String> _appDipantau = const [];
  List<String> _dompetTampil = const [];
  String? _dompetUtama;
  bool _notifAktif = false;

  int _homeDataMode = 0; // 0 = 7 hari terakhir, 1 = siklus aktif
  bool _homeShowChart = true;
  bool _homeShowBudget = true;
  List<String> _quickActionOrder = List.of(kDefaultQuickActions);
  String _homeTitle = 'Home';

  List<String> get kataKunci => List.unmodifiable(_kataKunci);
  List<String> get appDipantau => List.unmodifiable(_appDipantau);
  List<String> get dompetTampil => List.unmodifiable(_dompetTampil);
  String? get dompetUtama => _dompetUtama;
  bool get notifAktif => _notifAktif;

  int get homeDataMode => _homeDataMode;
  bool get homeShowChart => _homeShowChart;
  bool get homeShowBudget => _homeShowBudget;
  List<String> get quickActionOrder => List.unmodifiable(_quickActionOrder);
  String get homeTitle => _homeTitle;

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

    _homeDataMode = p.getInt(_kHomeDataMode) ?? 0;
    _homeShowChart = p.getBool(_kHomeShowChart) ?? true;
    _homeShowBudget = p.getBool(_kHomeShowBudget) ?? true;
    final qao = p.getStringList(_kQuickActionOrder);
    _quickActionOrder = (qao != null && qao.isNotEmpty) ? List.of(qao) : List.of(kDefaultQuickActions);
    _homeTitle = p.getString(_kHomeTitle) ?? 'Home';
  }

  Future<void> setHomeDataMode(int mode) async {
    _homeDataMode = mode;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kHomeDataMode, mode);
    AppEvents.instance.berandaSettingsBerubah();
  }

  Future<void> setHomeShowChart(bool show) async {
    _homeShowChart = show;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kHomeShowChart, show);
    AppEvents.instance.berandaSettingsBerubah();
  }

  Future<void> setHomeShowBudget(bool show) async {
    _homeShowBudget = show;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kHomeShowBudget, show);
    AppEvents.instance.berandaSettingsBerubah();
  }

  Future<void> setQuickActionOrder(List<String> order) async {
    _quickActionOrder = List.of(order);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kQuickActionOrder, _quickActionOrder);
    AppEvents.instance.berandaSettingsBerubah();
  }

  Future<void> setHomeTitle(String title) async {
    _homeTitle = title.trim().isEmpty ? 'Home' : title.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHomeTitle, _homeTitle);
    AppEvents.instance.berandaSettingsBerubah();
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
    _homeDataMode = 0;
    _homeShowChart = true;
    _homeShowBudget = true;
    _quickActionOrder = List.of(kDefaultQuickActions);
    _homeTitle = 'Home';
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }
}
