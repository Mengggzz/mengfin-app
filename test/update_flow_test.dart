import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/update_service.dart';
import 'package:mengfin/widgets/update_dialog.dart';

/// Bug: saat aplikasi dibuka, dialog "Sudah Versi Terbaru" muncul terus.
/// Akar: `DashboardScreen._autoCheckUpdate()` memanggil
/// `UpdateFlow.run(context)` TANPA `silentWhenNoUpdate: true`, padahal
/// dialog info (bukan update) muncul untuk semua hasil cek.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// UpdateFlow.run memanggil showDialog dan MENUNGGU sampai dialog ditutup.
  /// Karena itu test menjalankan alurnya tanpa ditunggu, lalu menutup
  /// dialog-nya supaya future-nya selesai dan tidak timeout.
  Future<void> tutupDialog(WidgetTester tester) async {
    // Dialog dipasang di rootNavigator MaterialApp, jadi pop dari sana.
    final state = tester.state(find.byType(Navigator).first);
    (state as NavigatorState).pop();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('UpdateFlow.run diam saat tidak ada update (silentWhenNoUpdate)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(body: SizedBox.shrink()),
    ));

    await UpdateFlow.run(
      tester.element(find.byType(Scaffold)),
      silentWhenNoUpdate: true,
      cek: ({bool force = false}) async => UpdateCheckResult(
        hasUpdate: false,
        currentTag: 'v20260927-1054',
        latestTag: 'v20260927-1054',
      ),
    );
    await tester.pump();

    expect(find.text('Sudah Versi Terbaru'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(UpdateDialog), findsNothing);
  });

  testWidgets('UpdateFlow.run tetap menampilkan dialog kalau ADA update',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(body: SizedBox.shrink()),
    ));

    unawaited(UpdateFlow.run(
      tester.element(find.byType(Scaffold)),
      silentWhenNoUpdate: true,
      cek: ({bool force = false}) async => UpdateCheckResult(
        hasUpdate: true,
        currentTag: 'v20260927-1002',
        latestTag: 'v20260927-2222',
        release: ReleaseInfo(
          tag: 'v20260927-2222',
          name: 'MengFin v20260927-2222',
          body: 'catatan',
          apkUrl: 'https://contoh/x.apk',
          htmlUrl: 'https://contoh',
          publishedAt: DateTime(2026, 9, 27),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(UpdateDialog), findsOneWidget);
    await tutupDialog(tester);
  });

  testWidgets('panggilan TANPA silentWhenNoUpdate tetap tampilkan info',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(body: SizedBox.shrink()),
    ));

    unawaited(UpdateFlow.run(
      tester.element(find.byType(Scaffold)),
      cek: ({bool force = false}) async => UpdateCheckResult(
        hasUpdate: false,
        currentTag: 'v20260927-1054',
        latestTag: 'v20260927-1054',
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Inilah yang dipakai tombol manual di layar "Lainnya":
    // pengguna memang ingin tahu hasilnya.
    expect(find.text('Sudah Versi Terbaru'), findsOneWidget);
    await tutupDialog(tester);
  });
}
