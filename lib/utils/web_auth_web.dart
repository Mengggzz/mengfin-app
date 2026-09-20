// Web-only: JS interop untuk Google OAuth redirect flow
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/widgets.dart';

/// Redirect halaman ke Google OAuth (tidak pakai popup)
void triggerGoogleSignIn() {
  js.context.callMethod('triggerGoogleSignIn');
}

/// Baca access token yang disimpan setelah redirect dari Google
String? checkPendingToken() {
  try {
    final result = js.context.callMethod('getPendingToken');
    if (result == null || result.toString().isEmpty) return null;
    return result.toString();
  } catch (e) {
    return null;
  }
}

/// Hapus pending token setelah dibaca
void clearPendingToken() {
  try {
    js.context.callMethod('clearPendingToken');
  } catch (e) {}
}

/// Tidak digunakan di redirect mode, tapi tersedia untuk kompatibilitas
void listenGoogleSignIn(void Function(String credential) callback) {}

/// Tidak digunakan di redirect mode
Widget buildGoogleHtmlButton() => const SizedBox.shrink();
