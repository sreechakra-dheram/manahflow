import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:logger/logger.dart';

class AuthService {
  final Auth0 auth0 = Auth0(
    dotenv.env['AUTH0_DOMAIN']!,
    dotenv.env['AUTH0_CLIENT_ID']!,
  );

  final Logger _logger = Logger();
  Credentials? _credentials;

  Credentials? get credentials => _credentials;

  Future<Credentials?> login() async {
    // ignore: avoid_print
    print('DEBUG: AuthService.login() started');
    // ignore: avoid_print
    print('DEBUG: Using Domain: ${dotenv.env['AUTH0_DOMAIN']}');
    
    try {
      final auth = auth0.webAuthentication(
        scheme: kIsWeb ? null : 'com.example.manahflow',
      );

      // ignore: avoid_print
      print('DEBUG: Triggering auth.login()...');
      _credentials = await auth.login(
        parameters: {'prompt': 'login'},
        scopes: {'openid', 'profile', 'email', 'offline_access'},
      );
      _logger.i('Login successful: ${_credentials?.user.email}');
      _logger.d('Custom Claims: ${_credentials?.user.customClaims}');
      return _credentials;
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG: Auth0 LOGIN EXCEPTION: $e');
      _logger.e('Login failed: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await auth0
          .webAuthentication(scheme: kIsWeb ? null : 'com.example.manahflow')
          .logout();
      _credentials = null;
      _logger.i('Logout successful');
    } catch (e) {
      _logger.e('Logout failed: $e');
    }
  }

  String? getRole() {
    final credentials = _credentials;
    if (credentials == null) return null;
    
    final Map<String, dynamic> claims = credentials.user.customClaims ?? {};
    _logger.d('Extracting role from claims: $claims');
    
    // 1. Check direct 'role' or 'roles' claim
    if (claims.containsKey('role')) return _firstOrString(claims['role']);
    if (claims.containsKey('roles')) return _firstOrString(claims['roles']);
    
    // 2. Check namespaced role claim (common pattern in Auth0 Actions/Rules)
    for (final key in claims.keys) {
      if (key.toLowerCase().contains('role')) {
        final val = claims[key];
        final extracted = _firstOrString(val);
        if (extracted != null) return extracted;
      }
    }
    
    // 3. Check for app_metadata explicitly if nested
    final appMetadata = claims['app_metadata'] ?? claims['https://manahflow.com/app_metadata'];
    if (appMetadata is Map<String, dynamic>) {
      if (appMetadata.containsKey('role')) return _firstOrString(appMetadata['role']);
      if (appMetadata.containsKey('roles')) return _firstOrString(appMetadata['roles']);
    }

    // 4. Check user_metadata
    final userMetadata = claims['user_metadata'] ?? claims['https://manahflow.com/user_metadata'];
    if (userMetadata is Map<String, dynamic>) {
      if (userMetadata.containsKey('role')) return _firstOrString(userMetadata['role']);
    }

    return null;
  }

  String? _firstOrString(dynamic val) {
    if (val is String) return val;
    if (val is List && val.isNotEmpty) return val.first.toString();
    return null;
  }
}
