import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mengfin/constants/app_colors.dart';
import 'package:mengfin/widgets/kazz_illustrations.dart';
import 'package:mengfin/widgets/widgets.dart';

/// Golden ini bukan untuk membandingkan pixel, tapi supaya tampilan menu
/// Kazz bisa diperiksa mata tanpa harus menjalankan APK.
/// Perbarui dengan: flutter test --update-goldens test/kazz_golden_test.dart
void main() {
  testWidgets('tampilan tab Dompet menu Kazz', (tester) async {
    tester.view.physicalSize = const Size(1080, 1500);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Kazz',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 16),
              // Panel Saldo bergaris putus-putus.
              DashedBox(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Saldo',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        )),
                    Text('-Rp 6.164',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Empat ilustrasi Kazz berdampingan.
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (final j in ['cashflow', 'tabungan', 'kredit', 'aset'])
                  KazzIllustration(jenis: j, size: 56),
              ]),
              const SizedBox(height: 20),
              // Kartu dompet + kartu Tambah Kazz.
              Row(children: [
                Expanded(
                  child: KazzWalletCard(
                    name: 'Dompet Utama',
                    balance: -6164,
                    jenis: 'cashflow',
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: AddKazzCard(compact: true, height: 130),
                ),
              ]),
            ]),
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/kazz_dompet.png'),
    );
  });
}
