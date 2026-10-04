// Web-only: render tombol Google Sign-In via Google Identity Services (GIS)
// Tidak pakai popup - lebih aman dan tidak diblock browser
import 'package:flutter/widgets.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';

Widget renderGoogleButton() {
  final plugin = GoogleSignInPlatform.instance as GoogleSignInPlugin;
  return plugin.renderButton(
    configuration: GSIButtonConfiguration(
      size: GSIButtonSize.large,
      theme: GSIButtonTheme.outline,
      type: GSIButtonType.standard,
      text: GSIButtonText.signinWith,
      shape: GSIButtonShape.pill,
    ),
  );
}
