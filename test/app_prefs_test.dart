import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mengfin/services/app_prefs.dart';

/// Pengaturan harus bertahan antar proses: sebelumnya layar pengaturan
/// hanya menyimpan di variabel lokal dan "Simpan" cuma menutup layar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.instance.reset();
  });

  test('nilai awal: notif mati, kata kunci bawaan, tanpa dompet terpilih', () async {
    await AppPrefs.instance.init();
    expect(AppPrefs.instance.notifAktif, isFalse);
    expect(AppPrefs.instance.kataKunci, AppPrefs.kKataKunciBawaan);
    expect(AppPrefs.instance.dompetUtama, isNull);
    expect(AppPrefs.instance.appDipantau, isEmpty);
  });

  test('kata kunci, toggle, dan aplikasi dipantau tersimpan', () async {
    await AppPrefs.instance.init();

    await AppPrefs.instance.setKataKunci(['gojek', 'dana']);
    await AppPrefs.instance.setNotifAktif(true);
    await AppPrefs.instance.setAppDipantau(['com.gojek.app', 'id.dana']);

    // Muat ulang dari storage — seolah app direstart.
    final baru = AppPrefs();
    await baru.init();
    expect(baru.kataKunci, ['gojek', 'dana']);
    expect(baru.notifAktif, isTrue);
    expect(baru.appDipantau, ['com.gojek.app', 'id.dana']);
  });

  test('dompet utama & dompet tampil tersimpan', () async {
    await AppPrefs.instance.init();
    await AppPrefs.instance.setDompetUtama('6841abc123');
    await AppPrefs.instance.setDompetTampil(['6841abc123', '6841def456']);

    final baru = AppPrefs();
    await baru.init();
    expect(baru.dompetUtama, '6841abc123');
    expect(baru.dompetTampil, ['6841abc123', '6841def456']);
  });

  test('setDompetUtama(null) menghapus pilihan', () async {
    await AppPrefs.instance.init();
    await AppPrefs.instance.setDompetUtama('x1');
    await AppPrefs.instance.setDompetUtama(null);

    final baru = AppPrefs();
    await baru.init();
    expect(baru.dompetUtama, isNull);
  });

  test('bolehPantau: daftar kosong artinya semua boleh', () async {
    await AppPrefs.instance.init();
    expect(AppPrefs.instance.bolehPantau('com.apa.aja'), isTrue);

    await AppPrefs.instance.setAppDipantau(['com.gojek.app']);
    expect(AppPrefs.instance.bolehPantau('com.gojek.app'), isTrue);
    expect(AppPrefs.instance.bolehPantau('com.lain.lain'), isFalse);
  });

  test('idKeTeks aman untuk int dan String (MongoDB ObjectId)', () {
    expect(AppPrefs.idKeTeks(12), '12');
    expect(AppPrefs.idKeTeks('abc'), 'abc');
    expect(AppPrefs.idKeTeks(null), '');
  });
}
