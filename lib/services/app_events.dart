import 'package:flutter/foundation.dart';

/// Bus perubahan data antar-layar.
///
/// Dipakai supaya daftar transaksi di Home dan tab View ikut menyegarkan
/// diri begitu ada data baru (scan struk, input manual, voice, hapus).
/// Tanpa ini, layar yang sudah dibuka tidak pernah tahu ada data baru dan
/// user harus pull-to-refresh manual.
class AppEvents {
  AppEvents._();
  static final AppEvents instance = AppEvents._();

  /// Nilai bertambah setiap kali data transaksi berubah.
  final ValueNotifier<int> transaksi = ValueNotifier<int>(0);

  /// Nilai bertambah setiap kali data anggaran berubah.
  final ValueNotifier<int> anggaran = ValueNotifier<int>(0);

  /// Nilai bertambah setiap kali data goals berubah.
  final ValueNotifier<int> goals = ValueNotifier<int>(0);

  void transaksiBerubah() => transaksi.value++;
  void anggaranBerubah() => anggaran.value++;
  void goalsBerubah() => goals.value++;
}
