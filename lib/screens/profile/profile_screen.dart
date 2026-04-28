import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/providers/app_state.dart';
import '../../shared/widgets/section_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifyEmail = true;
  bool _notifyPush = true;
  bool _notifyInvoiceUpdate = false;
  bool _notifyInvoice = true;
  bool _notifyPayment = true;

  String _fmtAmount(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue,
                    AppColors.accentBlue,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      user.avatarInitials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(user.roleDisplayName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 6),
                        Text(user.company,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Stats row
            FutureBuilder<Map<String, dynamic>>(
              future: context.read<AppState>().getProfileStats(),
              builder: (context, snap) {
                final submitted = snap.data?['submitted']?.toString() ?? '—';
                final approved = snap.data?['approved']?.toString() ?? '—';
                final paid = snap.data != null
                    ? 'Rs. ${_fmtAmount((snap.data!['totalPaid'] as double))}'
                    : '—';
                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                          label: 'Submitted', value: submitted, icon: Icons.receipt_long_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                          label: 'Approved', value: approved, icon: Icons.check_circle_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                          label: 'Total Paid', value: paid, icon: Icons.account_balance_wallet_rounded),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            // Notification preferences
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Notification Preferences'),
                  const SizedBox(height: 16),
                  _Toggle(
                    label: 'Email Notifications',
                    subtitle: 'Receive alerts via email',
                    value: _notifyEmail,
                    onChanged: (v) => setState(() => _notifyEmail = v),
                  ),
                  _Toggle(
                    label: 'Push Notifications',
                    subtitle: 'In-app alerts',
                    value: _notifyPush,
                    onChanged: (v) => setState(() => _notifyPush = v),
                  ),
                  const Divider(color: AppColors.borderColor, height: 24),
                  _Toggle(
                    label: 'Invoice Status Updates',
                    subtitle: 'When invoices are approved or rejected',
                    value: _notifyInvoiceUpdate,
                    onChanged: (v) => setState(() => _notifyInvoiceUpdate = v),
                  ),
                  _Toggle(
                    label: 'Invoice Alerts',
                    subtitle: 'New invoices and approval requests',
                    value: _notifyInvoice,
                    onChanged: (v) => setState(() => _notifyInvoice = v),
                  ),
                  _Toggle(
                    label: 'Payment Notifications',
                    subtitle: 'When payments are released',
                    value: _notifyPayment,
                    onChanged: (v) => setState(() => _notifyPayment = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Account settings
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Account'),
                  const SizedBox(height: 8),
                  _MenuTile(
                      icon: Icons.lock_outline_rounded,
                      label: 'Change Password',
                      onTap: () {}),
                  _MenuTile(
                      icon: Icons.language_rounded,
                      label: 'Language & Region',
                      onTap: () {}),
                  _MenuTile(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                      onTap: () {}),
                  _MenuTile(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy Policy',
                      onTap: () {}),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded,
                    color: AppColors.statusRed),
                label: const Text('Sign Out',
                    style: TextStyle(color: AppColors.statusRed)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.statusRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  await context.read<AppState>().logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _DebugLoginPanel extends StatefulWidget {
  @override
  State<_DebugLoginPanel> createState() => _DebugLoginPanelState();
}

class _DebugLoginPanelState extends State<_DebugLoginPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final debug = context.watch<AppState>().lastLoginDebug;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF444466)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.bug_report_rounded, size: 16, color: Color(0xFF7DD3FC)),
                  const SizedBox(width: 8),
                  const Text('DEBUG — Auth0 Login Data',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7DD3FC))),
                  const Spacer(),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: const Color(0xFF7DD3FC)),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    debug ?? 'No login recorded yet — log out and log back in.',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFE2E8F0),
                        fontFamily: 'monospace',
                        height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                      label: const Text('Clear Cached Session & Force Re-login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () async {
                        final appState = context.read<AppState>();
                        await appState.clearSessionAndRelogin(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accentBlue, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accentBlue,
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(label,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textSecondary, size: 18),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}
