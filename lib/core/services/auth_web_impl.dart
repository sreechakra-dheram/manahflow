// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart';

// Initializes the Auth0 JS client — MUST be called before loginWeb()
Future<void> initAuth0Web(String domain, String clientId) async {
  final auth0 = Auth0Web(domain, clientId);
  // onLoad() initializes the Auth0 SPA JS client and handles redirect callbacks
  await auth0.onLoad();
}

// Web implementation using Auth0Web (the correct API for Flutter Web builds)
Future<Credentials?> loginWeb(String domain, String clientId) async {
  final auth0 = Auth0Web(domain, clientId);
  return auth0.loginWithPopup(
    scopes: {'openid', 'profile', 'email', 'offline_access'},
  );
}

Future<void> logoutWeb(String domain, String clientId) async {
  final auth0 = Auth0Web(domain, clientId);
  await auth0.logout(returnToUrl: html.window.location.origin);
}
