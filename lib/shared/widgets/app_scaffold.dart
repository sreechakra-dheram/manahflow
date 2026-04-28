import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/providers/app_state.dart';
import 'notification_panel.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return _WidescreenLayout(child: child);
        }
        return _MobileLayout(child: child);
      },
    );
  }
}

// ─── NAV ITEMS ────────────────────────────────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

const _navItems = [
  _NavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
    route: '/dashboard',
  ),
  _NavItem(
    label: 'Expenses',
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long_rounded,
    route: '/invoices',
  ),
  _NavItem(
    label: 'Reports',
    icon: Icons.folder_outlined,
    activeIcon: Icons.folder_rounded,
    route: '/expense-reports',
  ),
  _NavItem(
    label: 'Analytics',
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart_rounded,
    route: '/reports',
  ),
  _NavItem(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    route: '/profile',
  ),
];

const _adminNavItem = _NavItem(
  label: 'Admin',
  icon: Icons.admin_panel_settings_outlined,
  activeIcon: Icons.admin_panel_settings_rounded,
  route: '/admin',
);

List<_NavItem> _visibleNavItems(bool isAdmin) =>
    isAdmin ? [..._navItems, _adminNavItem] : _navItems;

int _navIndex(String location, bool isAdmin) {
  final items = _visibleNavItems(isAdmin);
  if (location.startsWith('/invoices') ||
      location.startsWith('/scan') ||
      location.startsWith('/approval')) return 1;
  if (location.startsWith('/expense-reports')) return 2;
  if (location.startsWith('/reports')) return 3;
  if (location.startsWith('/admin')) return isAdmin ? items.length - 2 : 0;
  if (location.startsWith('/profile')) return items.length - 1;
  return 0;
}

// ─── WIDESCREEN ───────────────────────────────────────────────────────────────

class _WidescreenLayout extends StatelessWidget {
  final Widget child;

  const _WidescreenLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final user = context.watch<AppState>().currentUser;
    final isAdmin = user?.isAdmin ?? false;
    final navItems = _visibleNavItems(isAdmin);
    final selectedIndex = _navIndex(location, isAdmin);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            color: AppColors.sidebarBg,
            child: Column(
              children: [
                // Logo area
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.asset(
                          'logo.jpg',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ManahFlow',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Expense Approvals',
                              style: TextStyle(
                                color: AppColors.sidebarText,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),
                // Nav items
                ...List.generate(navItems.length, (i) {
                  final item = navItems[i];
                  final isActive = i == selectedIndex;
                  return _SidebarItem(
                    item: item,
                    isActive: isActive,
                    onTap: () => context.go(item.route),
                  );
                }),
                const Spacer(),
                // User chip at bottom
                if (user != null)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.accentBlue,
                          child: Text(
                            user.avatarInitials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user.roleDisplayName,
                                style: const TextStyle(
                                  color: AppColors.sidebarText,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: Column(
              children: [
                _TopBar(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.sidebarActive.withOpacity(0.9)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              color: isActive ? Colors.white : AppColors.sidebarText,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              item.label,
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.sidebarText,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TOP BAR ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          Text(
            _pageTitle(GoRouterState.of(context).uri.toString()),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Builder(builder: (context) {
            final user = context.watch<AppState>().currentUser;
            if (user == null) return const SizedBox.shrink();
            return _RoleTag(roleDisplayName: user.roleDisplayName);
          }),
          const SizedBox(width: 12),
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Sign out',
            onPressed: () async {
              await context.read<AppState>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  String _pageTitle(String location) {
    if (location.startsWith('/invoices/new')) return 'New Expense';
    if (location.startsWith('/invoices') && location.length > 9) return 'Expense Detail';
    if (location.startsWith('/invoices')) return 'Expenses';
    if (location.startsWith('/scan/review')) return 'Review Extracted Data';
    if (location.startsWith('/scan')) return 'Scan Expense';
    if (location.startsWith('/approval')) return 'Approval Workflow';
    if (location.startsWith('/expense-reports') && location.length > 17) return 'Report Detail';
    if (location.startsWith('/expense-reports')) return 'Expense Reports';
    if (location.startsWith('/reports')) return 'Analytics';
    if (location.startsWith('/admin')) return 'Admin — Master Data';
    if (location.startsWith('/profile')) return 'Profile & Settings';
    return 'Dashboard';
  }
}

// ─── MOBILE ───────────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final Widget child;

  const _MobileLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final user = context.watch<AppState>().currentUser;
    final isAdmin = user?.isAdmin ?? false;
    final navItems = _visibleNavItems(isAdmin);
    final selectedIndex = _navIndex(location, isAdmin);

    return Scaffold(
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            final logoSize = constraints.maxWidth < 300 ? 20.0 : 26.0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    'logo.jpg',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('ManahFlow',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            );
          },
        ),
        actions: [
          if (user != null)
            _RoleTag(roleDisplayName: user.roleDisplayName),
          const NotificationBell(),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex.clamp(0, navItems.length - 1),
        onDestinationSelected: (i) => context.go(navItems[i].route),
        backgroundColor: AppColors.cardWhite,
        indicatorColor: AppColors.accentBlue.withOpacity(0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: navItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.activeIcon, color: AppColors.accentBlue),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  final String roleDisplayName;
  const _RoleTag({required this.roleDisplayName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
      ),
      child: Text(
        roleDisplayName,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.accentBlue,
        ),
      ),
    );
  }
}
