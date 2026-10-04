import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mengfin/constants/app_colors.dart';
import 'package:mengfin/main.dart';
import 'package:mengfin/services/theme_service.dart';

/// Uji end-to-end: widget aplikasi yang sebenarnya harus membangun ulang
/// MaterialApp (dan seluruh layar) saat mode tampilan diganti.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ganti mode tampilan membangun ulang MaterialApp & layar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ThemeService.instance.init();
    await ThemeService.instance.setMode(ThemeMode.dark);

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeService>.value(
        value: ThemeService.instance,
        child: const MengFinApp(),
      ),
    );
    await tester.pump();

    MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app().themeMode, ThemeMode.dark);
    expect(AppColors.isDark, isTrue);

    final bgGelap = AppColors.bg;
    final teksGelap = AppColors.textPrimary;

    // Ketuk siklus mode: gelap → ikut sistem → terang.
    await ThemeService.instance.setMode(ThemeMode.light);
    await tester.pumpAndSettle();

    expect(app().themeMode, ThemeMode.light,
        reason: 'MaterialApp harus ikut mode baru setelah rebuild');
    expect(AppColors.isDark, isFalse,
        reason: 'AppColors harus sudah memakai palet terang');
    expect(AppColors.bg, isNot(bgGelap),
        reason: 'warna latar layar harus berubah, bukan tetap gelap');
    expect(AppColors.textPrimary, isNot(teksGelap));
    expect(app().theme, isNotNull, reason: 'tema terang harus terpasang');
    expect(app().darkTheme, isNotNull, reason: 'tema gelap harus terpasang');
  });
}
