import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart';

// Web implementation using Auth0Web (the correct API for web builds)
Future<Credentials?> loginWeb(String domain, String clientId) async {
  final auth0 = Auth0Web(domain, clientId);
  return auth0.loginWithPopup(
    parameters: PopupLoginOptions(
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    ),
  );
}

Future<void> logoutWeb(String domain, String clientId) async {
  final auth0 = Auth0Web(domain, clientId);
  await auth0.logout(returnToUrl: '');
}
