import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mengfin/screens/more_screen.dart';
import 'package:mengfin/services/theme_service.dart';
import 'package:mengfin/widgets/feedback_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('FeedbackSheet menampilkan elemen form lengkap dan validasi', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FeedbackSheet(),
        ),
      ),
    );
    await tester.pump();

    // Verifikasi judul dan form
    expect(find.text('Laporkan Bug / Saran'), findsOneWidget);
    expect(find.text('Bug'), findsOneWidget);
    expect(find.text('Saran'), findsOneWidget);
    expect(find.text('Judul Singkat *'), findsOneWidget);
    expect(find.text('Deskripsi Detail * (min. 10 karakter)'), findsOneWidget);
    expect(find.text('Kirim Laporan'), findsOneWidget);

    // Toggle chip ke "Saran"
    await tester.tap(find.text('Saran'));
    await tester.pumpAndSettle();

    // Coba kirim saat judul masih kosong -> muncul snackbar validasi
    await tester.tap(find.text('Kirim Laporan'));
    await tester.pumpAndSettle();

    expect(find.text('Judul laporan wajib diisi'), findsOneWidget);

    // Isi judul saja, deskripsi masih kosong
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.first, 'Fitur export csv baru');
    await tester.tap(find.text('Kirim Laporan'));
    await tester.pumpAndSettle();

    expect(find.text('Deskripsi minimal 10 karakter'), findsOneWidget);
  });

  testWidgets('MoreScreen tile Laporkan Bug / Saran membuka FeedbackSheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ThemeService.instance.init();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeService>.value(
        value: ThemeService.instance,
        child: const MaterialApp(
          home: MoreScreen(),
        ),
      ),
    );
    await tester.pump();

    // Scroll until tile visible
    await tester.scrollUntilVisible(
      find.text('Laporkan Bug / Saran'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Laporkan Bug / Saran'), findsOneWidget);

    await tester.tap(find.text('Laporkan Bug / Saran'));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackSheet), findsOneWidget);
  });
}
