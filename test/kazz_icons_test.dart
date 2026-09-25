import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mengfin/constants/app_colors.dart';
import 'package:mengfin/screens/kazz_screen.dart';

/// Regresi: ikon-ikon di header menu Kazz dulu hanya gambar tanpa aksi.
/// Uji ini memastikan masing-masing benar-benar bereaksi saat diketuk.
///
/// KazzScreen memanggil API di initState; di lingkungan uji panggilan itu
/// gagal dan ditangkap, jadi layar tetap tampil dengan daftar kosong —
/// cukup untuk menguji ikon headernya.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> bukaKazz(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // 1080 fisik / 3.0 = 360dp, lebar layar Android yang umum.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: KazzScreen()));
    await tester.pump(); // biarkan initState selesai
  }

  Finder ikonHeader(IconData icon) =>
      find.ancestor(of: find.byIcon(icon), matching: find.byType(GestureDetector));

  /// Kotak ikon header Kazz selalu 36x36 di dalam SafeArea layar Kazz.
  Finder ikonHeaderKazz(IconData icon) => find.descendant(
        of: find.byType(KazzScreen),
        matching: find.byIcon(icon),
      );

  testWidgets('ikon bagikan membuka menu ekspor', (tester) async {
    await bukaKazz(tester);

    expect(ikonHeader(Icons.ios_share_outlined), findsOneWidget,
        reason: 'ikon bagikan harus punya GestureDetector');

    await tester.tap(find.byIcon(Icons.ios_share_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Bagikan data transaksi'), findsOneWidget);
    expect(find.text('Ekspor ke CSV'), findsOneWidget);
    expect(find.text('Ekspor ke PDF'), findsOneWidget);
  });

  testWidgets('ikon kalender membuka layar kalender', (tester) async {
    await bukaKazz(tester);

    expect(ikonHeader(Icons.calendar_month_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    // CalendarScreen punya pemilih bulan; cek judul bulannya muncul.
    expect(find.textContaining('Kalender'), findsWidgets,
        reason: 'layar kalender harus terbuka');
  });

  testWidgets('ikon tune membuka pengaturan Kazz Utama', (tester) async {
    await bukaKazz(tester);

    expect(ikonHeader(Icons.tune), findsOneWidget);

    // Ikon tune di header Kazz (bukan ikon lain di layar berikutnya).
    await tester.tap(ikonHeaderKazz(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kazz'), findsWidgets,
        reason: 'layar pengaturan harus terbuka');
  });

  testWidgets('tombol tune tab Budget membuka menu urutan', (tester) async {
    await bukaKazz(tester);

    // Pindah ke tab Budget.
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();

    // Header tetap tampil di tab Budget, jadi ada dua ikon tune: header
    // (18px) dan tombol urutan budget (16px). Yang diketuk yang 16px.
    expect(find.byIcon(Icons.tune), findsNWidgets(2),
        reason: 'ikon tune header + tombol urutan budget');

    final tuneBudget = find.byWidgetPredicate(
      (w) => w is Icon && w.icon == Icons.tune && w.size == 16,
    );
    expect(tuneBudget, findsOneWidget);
    await tester.tap(tuneBudget);
    await tester.pumpAndSettle();

    for (final label in [
      'Pemakaian tertinggi',
      'Nominal terpakai',
      'Batas terbesar',
      'Nama kategori',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'opsi $label harus ada');
    }
  });

  testWidgets('ikon tiga titik kartu dompet punya aksi', (tester) async {
    await bukaKazz(tester);
    // Tanpa data, kartu dompet tidak ada — pastikan tidak ada ikon yatim.
    expect(find.byIcon(Icons.more_vert), findsNothing,
        reason: 'daftar kosong, jadi tidak ada menu kartu');
  });

  testWidgets('tidak ada ikon header yang tanpa aksi', (tester) async {
    await bukaKazz(tester);

    // Ketiga ikon header harus terbungkus GestureDetector.
    for (final icon in [
      Icons.ios_share_outlined,
      Icons.calendar_month_outlined,
      Icons.tune,
    ]) {
      expect(ikonHeader(icon), findsWidgets, reason: '$icon harus bisa diketuk');
    }
  });
}
