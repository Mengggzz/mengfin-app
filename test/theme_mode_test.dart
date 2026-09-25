import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mengfin/constants/app_colors.dart';
import 'package:mengfin/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppColors ganti nilai antara mode gelap dan terang', () {
    AppColors.applyBrightness(Brightness.dark);
    final bgGelap = AppColors.bg;
    final teksGelap = AppColors.textPrimary;

    AppColors.applyBrightness(Brightness.light);
    final bgTerang = AppColors.bg;
    final teksTerang = AppColors.textPrimary;

    expect(bgGelap, isNot(bgTerang),
        reason: 'latar harus berbeda antara mode gelap dan terang');
    expect(teksGelap, isNot(teksTerang),
        reason: 'warna teks harus berbeda antara mode gelap dan terang');

    // Mode terang harus punya latar terang dan teks gelap (bukan sebaliknya).
    expect(bgTerang.computeLuminance(), greaterThan(bgGelap.computeLuminance()));
    expect(teksTerang.computeLuminance(),
        lessThan(teksGelap.computeLuminance()));
  });

  test('ThemeService.cycle memutar mode dan memperbarui AppColors', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = ThemeService.instance;
    await svc.init();

    // init() memberi mode tersimpan; mulai dari Gelap supaya urutannya pasti.
    await svc.setMode(ThemeMode.dark);
    expect(svc.mode, ThemeMode.dark);
    expect(AppColors.isDark, isTrue, reason: 'mode gelap → AppColors gelap');

    await svc.cycle(); // dark → system
    expect(svc.mode, ThemeMode.system);

    await svc.cycle(); // system → light
    expect(svc.mode, ThemeMode.light);
    expect(AppColors.isDark, isFalse, reason: 'mode terang → AppColors terang');

    await svc.cycle(); // light → dark
    expect(svc.mode, ThemeMode.dark);
    expect(AppColors.isDark, isTrue);
  });

  test('Pilihan mode tersimpan dan dibaca ulang', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = ThemeService.instance;
    await svc.init();

    await svc.setMode(ThemeMode.light);
    // Baca ulang dari penyimpanan (simulasi app dibuka lagi).
    await svc.init();
    expect(svc.mode, ThemeMode.light,
        reason: 'mode terang harus tetap tersimpan setelah app dibuka ulang');
  });
}
