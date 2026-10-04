// Stub untuk non-web
import 'package:flutter/widgets.dart';
void triggerGoogleSignIn() => throw UnsupportedError('Web only');
String? checkPendingToken() => null;
void clearPendingToken() {}
void listenGoogleSignIn(void Function(String credential) callback) {}
Widget buildGoogleHtmlButton() => const SizedBox.shrink();
