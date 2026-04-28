import 'package:go_router/go_router.dart';
import '../core/models/user_model.dart';
import '../core/providers/app_state.dart';
import '../screens/admin/admin_screen.dart';
import '../screens/approval/approval_workflow_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/expense_reports/expense_report_detail_screen.dart';
import '../screens/expense_reports/expense_report_list_screen.dart';
import '../screens/invoice/invoice_detail_screen.dart';
import '../screens/invoice/invoice_form_screen.dart';
import '../screens/invoice/invoice_list_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/scan/scan_review_screen.dart';
import '../screens/scan/scan_screen.dart';
import '../shared/widgets/app_scaffold.dart';

GoRouter createRouter(AppState appState) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: appState,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isLoggedIn = appState.isAuthenticated;
      if (loc == '/') return null;
      if (!isLoggedIn && loc != '/login') return '/login';
      if (isLoggedIn && loc == '/login') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/invoices',
            builder: (context, state) => const InvoiceListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const InvoiceFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => InvoiceDetailScreen(
                  invoiceId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/scan',
            builder: (context, state) => const ScanScreen(),
            routes: [
              GoRoute(
                path: 'review',
                builder: (context, state) => const ScanReviewScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/approval/:id',
            builder: (context, state) => ApprovalWorkflowScreen(
              invoiceId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/expense-reports',
            builder: (context, state) => const ExpenseReportListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => ExpenseReportDetailScreen(
                  reportId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/admin',
            redirect: (context, state) {
              if (!appState.isAuthenticated ||
                  appState.currentRole != UserRole.admin) {
                return '/dashboard';
              }
              return null;
            },
            builder: (context, state) => const AdminScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
}
