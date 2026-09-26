import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mengfin/screens/more_screen.dart';
import 'package:mengfin/screens/transaction_input_screen.dart';
import 'package:mengfin/services/theme_service.dart';
import 'package:mengfin/widgets/widgets.dart';

/// Regresi untuk kontrol yang dulu tidak bereaksi sama sekali:
///  - tile "Tentang MengFin" (onTap kosong)
///  - tombol × dan ÷ di numpad (teks hiasan)
///  - tombol "=" (onEquals: () {})
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> siapkanLayar(WidgetTester tester, Widget child) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(child);
    await tester.pump();
  }

  Finder diNumpad(String teks) => find.descendant(
        of: find.byType(CalcNumpad),
        matching: find.text(teks),
      );

  Finder ikonNumpad(IconData icon) => find.descendant(
        of: find.byType(CalcNumpad),
        matching: find.byIcon(icon),
      );

  testWidgets('tile Tentang MengFin membuka sheet dan punya Cek pembaruan',
      (tester) async {
    // SharedPreferences harus di-mock SEBELUM init: kalau tidak, init
    // memanggil plugin asli, melempar MissingPluginException, dan
    // menghentikan seluruh berkas uji ini.
    SharedPreferences.setMockInitialValues({});
    await ThemeService.instance.init();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: ThemeService.instance,
          child: const MaterialApp(home: MoreScreen()),
        ));
    await tester.pump();

    // Tile ini ada di bawah lipatan layar di ListView yang malas membangun,
    // jadi harus digulir dulu sebelum bisa diketuk.
    await tester.scrollUntilVisible(
      find.text('Tentang MengFin'), 200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tentang MengFin'));
    await tester.pumpAndSettle();

    expect(find.text('Personal Finance Manager'), findsWidgets);
    expect(find.text('Cek pembaruan'), findsOneWidget,
        reason: 'sheet Tentang harus punya jalan ke cek pembaruan');
  });

  testWidgets('tombol × dan ÷ ada dan bisa ditekan', (tester) async {
    await siapkanLayar(tester, const MaterialApp(home: TransactionInputScreen()));

    expect(diNumpad('×'), findsOneWidget);
    expect(diNumpad('÷'), findsOneWidget);

    // Dulu × dan ÷ cuma Text di dalam pembungkus mati: tidak ada
    // GestureDetector yang menaunginya.
    expect(
      find.ancestor(of: diNumpad('×'), matching: find.byType(GestureDetector)),
      findsWidgets,
    );
    expect(
      find.ancestor(of: diNumpad('÷'), matching: find.byType(GestureDetector)),
      findsWidgets,
    );
  });

  testWidgets('"25 + 10" ditampilkan apa adanya dan dihitung 35', (tester) async {
    await siapkanLayar(tester, const MaterialApp(home: TransactionInputScreen()));

    for (final k in ['2', '5', '+', '1', '0']) {
      await tester.tap(diNumpad(k));
      await tester.pump();
    }

    // Angka besar menampilkan ekspresi yang sedang diketik...
    expect(find.text('25 + 10'), findsOneWidget);
    // ...dan baris "=" menampilkan hasil hitung sungguhan (35), bukan 2510
    // hasil penggabungan digit seperti bug lama.
    expect(find.text('= 35'), findsOneWidget);
    expect(find.text('= 2,510'), findsNothing);
  });

  testWidgets('tombol "=" mengubah ekspresi jadi hasilnya', (tester) async {
    await siapkanLayar(tester, const MaterialApp(home: TransactionInputScreen()));

    for (final k in ['1', '0', '0', '0', '÷', '4']) {
      await tester.tap(diNumpad(k));
      await tester.pump();
    }
    expect(find.text('1000 ÷ 4'), findsOneWidget);

    await tester.tap(ikonNumpad(Icons.drag_handle));
    await tester.pump();

    // "=" menjadikan hasil hitung sebagai isi input, jadi yang disimpan
    // sama dengan yang dilihat.
    expect(find.text('250'), findsOneWidget);
    expect(find.text('= 250'), findsOneWidget);
  });

  testWidgets('operator kedua menggantikan operator yang menggantung',
      (tester) async {
    await siapkanLayar(tester, const MaterialApp(home: TransactionInputScreen()));

    for (final k in ['2', '5', '+', '×', '1', '0']) {
      await tester.tap(diNumpad(k));
      await tester.pump();
    }

    // Bukan "25 + × 10" — ekspresi yang tidak bisa dihitung.
    expect(find.text('25 × 10'), findsOneWidget);
    expect(find.text('= 250'), findsOneWidget);

    // "=" merapikan tampilan jadi hasilnya saja.
    await tester.tap(ikonNumpad(Icons.drag_handle));
    await tester.pump();
    expect(find.text('250'), findsOneWidget);
    expect(find.text('= 250'), findsOneWidget);
  });
}
