import 'package:auth0_flutter/auth0_flutter.dart';

// Stub: only used on non-web builds
Future<Credentials?> loginWeb(String domain, String clientId) {
  throw UnsupportedError('Web login not available on this platform');
}

Future<void> logoutWeb(String domain, String clientId) {
  throw UnsupportedError('Web logout not available on this platform');
}
