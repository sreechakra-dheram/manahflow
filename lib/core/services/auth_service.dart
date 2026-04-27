import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:logger/logger.dart';

// Conditional import: uses Auth0Web on web, stub on mobile
import 'auth_web_stub.dart' if (dart.library.html) 'auth_web_impl.dart';

class AuthService {
  // Auth0 instance used only for mobile
  Auth0 get _auth0 => Auth0(
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

    final domain = dotenv.env['AUTH0_DOMAIN']!;
    final clientId = dotenv.env['AUTH0_CLIENT_ID']!;

    try {
      // ignore: avoid_print
      print('DEBUG: Triggering auth.login() — kIsWeb=$kIsWeb...');

      if (kIsWeb) {
        // Web: use Auth0Web.loginWithPopup()
        _credentials = await loginWeb(domain, clientId);
      } else {
        // Mobile: use native browser authentication
        _credentials = await _auth0
            .webAuthentication(scheme: 'com.example.manahflow')
            .login(
              parameters: {'prompt': 'login'},
              scopes: {'openid', 'profile', 'email', 'offline_access'},
            );
      }

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
    final domain = dotenv.env['AUTH0_DOMAIN']!;
    final clientId = dotenv.env['AUTH0_CLIENT_ID']!;
    try {
      if (kIsWeb) {
        await logoutWeb(domain, clientId);
      } else {
        await _auth0
            .webAuthentication(scheme: 'com.example.manahflow')
            .logout();
      }
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

    if (claims.containsKey('role')) return _firstOrString(claims['role']);
    if (claims.containsKey('roles')) return _firstOrString(claims['roles']);

    for (final key in claims.keys) {
      if (key.toLowerCase().contains('role')) {
        final val = claims[key];
        final extracted = _firstOrString(val);
        if (extracted != null) return extracted;
      }
    }

    final appMetadata = claims['app_metadata'] ?? claims['https://manahflow.com/app_metadata'];
    if (appMetadata is Map<String, dynamic>) {
      if (appMetadata.containsKey('role')) return _firstOrString(appMetadata['role']);
      if (appMetadata.containsKey('roles')) return _firstOrString(appMetadata['roles']);
    }

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
