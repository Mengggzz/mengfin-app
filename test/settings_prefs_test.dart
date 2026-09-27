import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mengfin/models/models.dart';
import 'package:mengfin/screens/settings_screen.dart';
import 'package:mengfin/services/app_prefs.dart';

/// Layar pengaturan dulu cuma state lokal: menekan "Simpan" hanya menutup
/// layar, jadi pilihan dompet utama, kata kunci, dan toggle notifikasi
/// hilang begitu layar ditutup. Tes ini menuntut pilihan benar-benar
/// tersimpan ke AppPrefs (yang membaca/menulis SharedPreferences).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Akun akun(dynamic id, String nama, double saldo) => Akun(
      id: id, nama: nama, jenis: 'bank', saldo: saldo,
      warna: '#2563EB', ikon: 'bank');

  Future<void> buka(
    WidgetTester tester,
    Widget layar, {
    Map<String, Object> awal = const {},
  }) async {
    SharedPreferences.setMockInitialValues(awal);
    await AppPrefs.instance.reset();
    // reset() menghapus mock values, jadi set ulang setelahnya — kalau
    // tidak nilai awal yang dimaksudkan tes hilang begitu layar dibuka.
    if (awal.isNotEmpty) SharedPreferences.setMockInitialValues(awal);
    await AppPrefs.instance.init();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: layar));
    await tester.pumpAndSettle();
  }

  testWidgets('toggle notifikasi tersimpan setelah Simpan', (tester) async {
    await buka(tester,
        const SettingsScreen(page: SettingsPage.autoNotif, muatAkun: _tanpaAkun));

    expect(AppPrefs.instance.notifAktif, isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Simpan'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Muat ulang dari storage seolah app direstart.
    final baru = AppPrefs();
    await baru.init();
    expect(baru.notifAktif, isTrue,
        reason: 'toggle harus bertahan, bukan cuma state layar');
  });

  testWidgets('tombol + menambahkan kata kunci ke daftar', (tester) async {
    await buka(tester,
        const SettingsScreen(page: SettingsPage.autoNotif, muatAkun: _tanpaAkun));

    await tester.enterText(find.byType(TextField), 'shopee');
    await tester.pumpAndSettle();
    // Kotak "+" tadinya cuma ikon: menekannya tidak melakukan apa-apa.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('shopee'), findsOneWidget);
  });

  testWidgets('kata kunci tersimpan dan menggantikan daftar bawaan',
      (tester) async {
    await buka(tester,
        const SettingsScreen(page: SettingsPage.autoNotif, muatAkun: _tanpaAkun));

    await tester.enterText(find.byType(TextField), 'shopee');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Simpan'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final baru = AppPrefs();
    await baru.init();
    expect(baru.kataKunci, contains('shopee'));
  });

  testWidgets('kata kunci bawaan muncul dari AppPrefs, bukan tulisan mati',
      (tester) async {
    await buka(tester, const SettingsScreen(page: SettingsPage.autoNotif, muatAkun: _tanpaAkun),
        awal: {'notif_kata_kunci': ['gojek', 'dana']});

    expect(find.text('gojek'), findsOneWidget);
    expect(find.text('dana'), findsOneWidget);
    expect(find.text('pembayaran'), findsNothing);
  });

  testWidgets('chevron "Aplikasi yang dipantau" membuka pemilih', (tester) async {
    await buka(tester,
        const SettingsScreen(page: SettingsPage.autoNotif, muatAkun: _tanpaAkun));

    // Barisnya di bawah lipatan layar 360dp — harus discroll dulu.
    await tester.scrollUntilVisible(find.byIcon(Icons.chevron_right), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Pilih aplikasi yang dipantau'), findsOneWidget);
  });

  testWidgets('Kazz utama: dompet utama & dompet tampil tersimpan',
      (tester) async {
    await buka(
      tester,
      SettingsScreen(
        page: SettingsPage.kazzUtama,
        muatAkun: () async => [akun(1, 'BCA', 100), akun(2, 'Mandiri', 50)],
      ),
    );

    expect(find.text('BCA'), findsOneWidget);
    expect(find.text('Mandiri'), findsOneWidget);

    // Pilih Mandiri sebagai dompet utama: ketuk barisnya.
    await tester.tap(find.text('Mandiri'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final baru = AppPrefs();
    await baru.init();
    expect(baru.dompetUtama, '2');
    expect(baru.dompetTampil, contains('2'));
  });
}

Future<List<Akun>> _tanpaAkun() async => const [];
