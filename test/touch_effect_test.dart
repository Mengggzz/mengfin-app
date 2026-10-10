import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/widgets/touch_effect.dart';

void main() {
  testWidgets('TouchEffect mengecil saat ditekan dan memanggil onTap', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TouchEffect(
              onTap: () => tapped = true,
              child: const SizedBox(width: 100, height: 100, key: Key('target')),
            ),
          ),
        ),
      ),
    );

    // Initial scale harus 1.0
    final animatedScaleFinder = find.byType(AnimatedScale);
    expect(animatedScaleFinder, findsOneWidget);
    AnimatedScale scaleWidget = tester.widget(animatedScaleFinder);
    expect(scaleWidget.scale, equals(1.0));

    // Tap down (tekan tanpa lepas)
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('target'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    scaleWidget = tester.widget(animatedScaleFinder);
    expect(scaleWidget.scale, equals(0.96));

    // Tap up (lepas)
    await gesture.up();
    await tester.pumpAndSettle();

    scaleWidget = tester.widget(animatedScaleFinder);
    expect(scaleWidget.scale, equals(1.0));
    expect(tapped, isTrue);
  });
}
