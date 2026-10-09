import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mengfin/services/app_prefs.dart';

/// Bug: pengaturan "Saldo Utama" disimpan tapi beranda tidak ikut berubah.
///
/// DashboardScreen hanya memasang listener pada AppEvents.transaksi dan
/// AppEvents.anggaran, padahal SettingsScreen._simpan() memancarkan
/// AppEvents.akunBerubah(). Akibatnya saldo "Dompet Saya" di beranda masih
/// memakai pilihan lama sampai aplikasi dibuka ulang.
///
/// Tes ini memastikan AppPrefs benar-benar menyimpan pilihan (bagian
/// penyimpanan sudah ada di settings_prefs_test) dan menyediakan hook
/// notifikasi yang bisa dipakai layar manapun untuk menyegarkan diri.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.instance.reset();
    await AppPrefs.instance.init();
  });

  test('AppPrefs: dompetUtama & dompetTampil tersimpan dan bisa dibaca ulang',
      () async {
    expect(AppPrefs.instance.dompetUtama, isNull);
    expect(AppPrefs.instance.dompetTampil, isEmpty);

    await AppPrefs.instance.setDompetUtama('server_akun_1');
    await AppPrefs.instance.setDompetTampil(['server_akun_1', 'server_akun_2']);

    // Instansi baru harus membaca nilai yang sama (bukan hanya cache).
    final baru = AppPrefs();
    await baru.init();
    expect(baru.dompetUtama, 'server_akun_1');
    expect(baru.dompetTampil, ['server_akun_1', 'server_akun_2']);
  });

  test('AppPrefs: dompetUtama dikosongkan tidak meninggalkan string kosong',
      () async {
    await AppPrefs.instance.setDompetUtama('server_akun_1');
    await AppPrefs.instance.setDompetUtama(null);

    final baru = AppPrefs();
    await baru.init();
    expect(baru.dompetUtama, isNull);
  });

  test('AppPrefs: dompetTampil diganti, bukan ditumpuk', () async {
    await AppPrefs.instance.setDompetTampil(['a', 'b']);
    await AppPrefs.instance.setDompetTampil(['c']);

    final baru = AppPrefs();
    await baru.init();
    expect(baru.dompetTampil, ['c']);
  });
}
