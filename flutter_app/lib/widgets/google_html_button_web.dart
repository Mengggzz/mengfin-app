// Web-only: tombol Google Sign-In menggunakan HtmlElementView
// Klik pada elemen HTML native = trusted user gesture = popup diizinkan browser
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:ui_web' as ui;
import 'package:flutter/widgets.dart';

bool _registered = false;

/// Render tombol Google menggunakan HtmlElementView agar click-nya trusted
Widget buildGoogleHtmlButton() {
  if (!_registered) {
    _registered = true;
    ui.platformViewRegistry.registerViewFactory(
      'google-signin-native-btn',
      (int viewId) {
        final btn = html.DivElement();

        // Styling agar mirip tombol Flutter
        btn.setAttribute('style', [
          'display: flex',
          'align-items: center',
          'justify-content: center',
          'width: 100%',
          'height: 56px',
          'background: white',
          'border: 1px solid #3a3a5c',
          'border-radius: 16px',
          'cursor: pointer',
          'font-size: 16px',
          'font-weight: 600',
          'color: #1a1a2e',
          'font-family: Inter, sans-serif',
          'gap: 12px',
          'padding: 0 24px',
          'box-sizing: border-box',
          'user-select: none',
          'transition: background 0.15s, opacity 0.15s',
        ].join('; '));

        final img = html.ImageElement()
          ..src = 'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg'
          ..setAttribute('style', 'width: 22px; height: 22px; pointer-events: none;');

        final text = html.SpanElement()
          ..text = 'Masuk dengan Google'
          ..setAttribute('style', 'pointer-events: none;');

        btn.append(img);
        btn.append(text);

        // Hover effects
        btn.onMouseEnter.listen((_) => btn.style.background = '#f5f5f5');
        btn.onMouseLeave.listen((_) => btn.style.background = 'white');
        btn.onMouseDown.listen((_) => btn.style.opacity = '0.7');
        btn.onMouseUp.listen((_) => btn.style.opacity = '1');

        // ✅ KUNCI: click langsung dari HTML element = trusted user gesture
        // Browser mengizinkan popup karena tidak ada async gap
        btn.onClick.listen((_) {
          js.context.callMethod('triggerGoogleSignIn');
        });

        return btn;
      },
    );
  }

  return const SizedBox(
    width: double.infinity,
    height: 56,
    child: HtmlElementView(viewType: 'google-signin-native-btn'),
  );
}
