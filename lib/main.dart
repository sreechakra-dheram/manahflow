import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/app_theme.dart';
import 'core/providers/app_state.dart';
import 'core/routes.dart';
import 'core/services/auth_web_stub.dart'
    if (dart.library.html) 'core/services/auth_web_impl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Auth0 for web (calls onLoad to set up the Auth0 JS client)
  await initAuth0Web(
    dotenv.env['AUTH0_DOMAIN']!,
    dotenv.env['AUTH0_CLIENT_ID']!,
  );

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const BuildFlowApp());
}

class BuildFlowApp extends StatefulWidget {
  const BuildFlowApp({super.key});

  @override
  State<BuildFlowApp> createState() => _BuildFlowAppState();
}

class _BuildFlowAppState extends State<BuildFlowApp> {
  late final AppState _appState;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _router = createRouter(_appState);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appState,
      child: ListenableBuilder(
        listenable: _appState,
        builder: (context, _) {
          if (_appState.isLoading && !_appState.isAuthenticated) {
            return const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              debugShowCheckedModeBanner: false,
            );
          }
          return MaterialApp.router(
            title: 'ManahFlow — Invoice Approval System',
            theme: AppTheme.light,
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
