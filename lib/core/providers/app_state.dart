// import 'dart:io'; // REMOVED: Crashes on Web
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/user_model.dart';
import '../../core/models/invoice_model.dart' show InvoiceModel, InvoiceStatus, CommentItem;
import '../../core/models/master_data_model.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/master_data_service.dart';
import '../../core/services/supabase_service.dart';

class AppState extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService();
  final MasterDataService _masterDataService = MasterDataService();
  UserModel? _currentUser;
  bool _isLoading = false;

  AppState() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_session');
    if (userJson != null) {
      try {
        final decoded = jsonDecode(userJson);
        _currentUser = UserModel.fromJson(decoded);
        // ignore: avoid_print
        print('SESSION RESTORED: ${_currentUser?.email} role=${_currentUser?.role}');
      } catch (e) {
        await prefs.remove('user_session');
      }
    }

    _isLoading = false;
    notifyListeners();

    // Start realtime and load notifications for restored sessions
    if (_currentUser != null) {
      startRealtime();
      loadNotifications();
    }
  }

  UserModel? get currentUser => _currentUser;
  UserRole? get currentRole => _currentUser?.role;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  // Debug info exposed for the debug overlay
  String? lastLoginDebug;

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> login() async {
    // ignore: avoid_print
    print('DEBUG: AppState.login() CALLED');
    _isLoading = true;
    notifyListeners();

    try {
      // ignore: avoid_print
      print('DEBUG: Calling _authService.login()...');
      final credentials = await _authService.login();
      // ignore: avoid_print
      print('DEBUG: _authService.login() returned: ${credentials != null ? "SUCCESS" : "NULL"}');
      if (credentials != null) {
        final claims = credentials.user.customClaims ?? {};
        final roleStr = _authService.getRole() ?? '(null — fallback)';
        final role = _mapStringToRole(roleStr);

        // Build a readable debug string visible on screen
        final claimKeys = claims.keys.join(', ');
        final claimValues = claims.entries.map((e) => '${e.key}: ${e.value}').join('\n');
        lastLoginDebug =
            'EMAIL: ${credentials.user.email}\n'
            'SUB: ${credentials.user.sub}\n'
            'NAME: ${credentials.user.name}\n'
            'ROLE_STR: $roleStr\n'
            'MAPPED_ROLE: $role\n'
            'CLAIM_KEYS: [$claimKeys]\n'
            'ALL_CLAIMS:\n$claimValues';

        // ignore: avoid_print
        print('==================== AUTH DEBUG ====================');
        // ignore: avoid_print
        print(lastLoginDebug);
        // ignore: avoid_print
        print('====================================================');

        final resolvedName = _resolveName(credentials);
        _currentUser = UserModel(
          id: credentials.user.sub,
          name: resolvedName,
          role: role,
          company: 'ManahFlow',
          email: credentials.user.email ?? '',
          avatarInitials: resolvedName.isNotEmpty ? resolvedName[0].toUpperCase() : 'U',
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_session', jsonEncode(_currentUser!.toJson()));
        startRealtime();
        loadNotifications();
      } else {
        lastLoginDebug = 'LOGIN RETURNED NULL — auth cancelled or failed';
      }
    } catch (e) {
      lastLoginDebug = 'LOGIN EXCEPTION: $e';
      // ignore: avoid_print
      print('LOGIN EXCEPTION: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    stopRealtime();
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session');
    notifyListeners();
  }

  Future<void> clearSessionAndRelogin(BuildContext context) async {
    // Wipe cached session so _init() can't restore stale role
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session');
    _currentUser = null;
    lastLoginDebug = null;
    notifyListeners();
    // Trigger fresh login
    await login();
  }

  Future<void> updateInvoiceStatus(
    String id,
    InvoiceStatus status,
    UserRole assignedTo, {
    String? signatureUrl,
  }) async {
    await _supabaseService.updateStatus(
      'invoices',
      id,
      status.toString().split('.').last,
      assignedTo,
      actorId: _currentUser?.id,
      actorName: _currentUser?.name,
      actorRole: _currentUser?.roleDisplayName,
      signatureUrl: signatureUrl,
    );
    // Notify the submitter of status changes
    try {
      final inv = await _supabaseService.fetchInvoiceById(id);
      if (inv != null) {
        final statusLabel = status.toString().split('.').last;
        String title, body;
        switch (status) {
          case InvoiceStatus.pmApproved:
            title = 'Invoice PM Approved';
            body = '${inv.invoiceNumber} approved by PM — sent to Finance';
            break;
          case InvoiceStatus.approved:
            title = 'Invoice Approved ✓';
            body = '${inv.invoiceNumber} has been fully approved';
            break;
          case InvoiceStatus.paymentInitiated:
            title = 'Payment Initiated';
            body = '${inv.invoiceNumber} — payment has been initiated';
            break;
          case InvoiceStatus.paid:
            title = 'Invoice Paid ✓';
            body = '${inv.invoiceNumber} has been marked as paid';
            break;
          case InvoiceStatus.rejected:
            title = 'Invoice Rejected';
            body = '${inv.invoiceNumber} was rejected and returned';
            break;
          default:
            title = 'Invoice Updated';
            body = '${inv.invoiceNumber} status changed to $statusLabel';
        }
        // Notify the original submitter
        await _supabaseService.createNotification(
          userId: inv.submittedBy,
          title: title,
          body: body,
          invoiceId: id,
        );
        // Notify current user if they're different (e.g. PM gets notified when finance acts)
        if (_currentUser?.id != inv.submittedBy) {
          await _supabaseService.createNotification(
            userId: _currentUser!.id,
            title: title,
            body: body,
            invoiceId: id,
          );
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<String> getNextInvoiceNumber() async {
    final seq = await _supabaseService.fetchNextInvoiceNumber();
    final now = DateTime.now();
    return 'INV-${now.year}-${seq.toString().padLeft(4, '0')}';
  }

  Future<void> submitInvoice({
    required String projectName,
    required String siteName,
    required String vendorName,
    required String invoiceNumber,
    required String date,
    required String dueDate,
    required double subtotal,
    required double gstPercent,
    required String remarks,
    required List<Map<String, dynamic>> lineItems,
    List<String> attachmentUrls = const [],
    String? noteType,
    String? bankAccountHolder,
    String? bankAccountNumber,
    String? bankName,
    String? bankIfsc,
    String? submitterSignatureUrl,
    String? reportId,
    String? beneficiaryName,
  }) async {
    if (_currentUser == null) return;

    String initialStatus;
    String assignedTo;
    String? pmApprovedByName;
    String? financeApprovedByName;

    switch (_currentUser!.role) {
      case UserRole.finance:
        initialStatus = 'approved';
        assignedTo = 'finance';
        financeApprovedByName = _currentUser!.name;
        break;
      case UserRole.projectManager:
        initialStatus = 'pmApproved';
        assignedTo = 'finance';
        pmApprovedByName = _currentUser!.name;
        break;
      case UserRole.siteEngineer:
      default:
        initialStatus = 'submitted';
        assignedTo = 'projectManager';
        break;
    }

    await _supabaseService.submitInvoice(
      projectName: projectName,
      siteName: siteName,
      vendorName: vendorName,
      invoiceNumber: invoiceNumber,
      date: date,
      dueDate: dueDate,
      subtotal: subtotal,
      gstPercent: gstPercent,
      submittedBy: _currentUser!.id,
      submittedByName: _currentUser!.name,
      submittedByEmail: _currentUser!.email,
      remarks: remarks,
      lineItems: lineItems,
      attachmentUrls: attachmentUrls,
      initialStatus: initialStatus,
      assignedTo: assignedTo,
      pmApprovedByName: pmApprovedByName,
      financeApprovedByName: financeApprovedByName,
      noteType: noteType,
      fromRole: _currentUser!.roleDisplayName,
      toRole: _currentUser!.role == UserRole.siteEngineer
          ? 'Project Manager'
          : 'Finance',
      bankAccountHolder: bankAccountHolder,
      bankAccountNumber: bankAccountNumber,
      bankName: bankName,
      bankIfsc: bankIfsc,
      submitterSignatureUrl: submitterSignatureUrl,
      reportId: reportId,
      beneficiaryName: beneficiaryName,
    );
  }

  Future<String?> uploadSignatureBytes(
          Uint8List bytes, String invoiceId, String role) =>
      _supabaseService.uploadSignatureBytes(bytes, invoiceId, role);

  Future<Map<String, dynamic>> getMonthlySpend() =>
      _supabaseService.fetchMonthlySpend();

  Future<Map<String, dynamic>> getProfileStats() =>
      _supabaseService.fetchProfileStats(_currentUser!.id);

  Future<List<InvoiceModel>> getInvoices() => _supabaseService.fetchAllInvoices();

  Future<InvoiceModel?> getInvoiceById(String id) => _supabaseService.fetchInvoiceById(id);
  Future<Map<String, dynamic>> getDashboardStats() => _supabaseService.fetchDashboardStats();
  Future<Map<String, dynamic>> getReportData() => _supabaseService.fetchReportData();

  Future<List<CommentItem>> getComments(String recordId, String recordType) =>
      _supabaseService.fetchComments(recordId, recordType);

  Future<void> addComment(String recordId, String recordType, String text) async {
    final user = _currentUser;
    if (user == null || text.trim().isEmpty) return;
    await _supabaseService.addComment(
      recordId: recordId,
      recordType: recordType,
      authorId: user.id,
      authorName: user.name,
      authorRole: user.roleDisplayName,
      text: text.trim(),
    );
  }

  Future<void> loadNotifications() async {
    if (_currentUser == null) return;
    try {
      _notifications = await _supabaseService.fetchNotifications(_currentUser!.id);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markNotificationRead(String id) async {
    await _supabaseService.markNotificationRead(id);
    await loadNotifications();
  }

  Future<void> markAllRead() async {
    if (_currentUser == null) return;
    await _supabaseService.markAllNotificationsRead(_currentUser!.id);
    await loadNotifications();
  }

  void startRealtime() {
    _supabaseService.subscribeToInvoices((record) {
      loadNotifications();
      notifyListeners();
    });
  }

  void stopRealtime() {
    _supabaseService.unsubscribeAll();
  }

  Future<String?> uploadAttachment(Uint8List bytes, String fileName) =>
      _supabaseService.uploadImageBytes(bytes, fileName, 'invoices');

  String _resolveName(dynamic credentials) {
    // 1. Custom claim 'name' that isn't an email
    final claims = credentials.user.customClaims as Map<String, dynamic>? ?? {};
    final claimName = claims['name'] as String?;
    if (claimName != null && claimName.isNotEmpty && !claimName.contains('@')) {
      return claimName;
    }
    // 2. OIDC name field if it's not an email
    final oidcName = credentials.user.name as String?;
    if (oidcName != null && oidcName.isNotEmpty && !oidcName.contains('@')) {
      return oidcName;
    }
    // 3. Nickname
    final nick = credentials.user.nickname as String?;
    if (nick != null && nick.isNotEmpty && !nick.contains('@')) return nick;
    // 4. Derive from email (part before @)
    final email = credentials.user.email as String? ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  // ── Master Data ───────────────────────────────────────────────────────────

  Future<List<ProjectItem>> getProjects() => _masterDataService.fetchProjects();
  Future<List<VendorItem>> getVendors() => _masterDataService.fetchVendors();
  Future<List<SiteItem>> getSites() => _masterDataService.fetchSites();

  Future<void> addProject(String name, {String? code}) => _masterDataService.addProject(name, code: code);
  Future<void> updateProject(String id, String name, {String? code}) => _masterDataService.updateProject(id, name, code: code);
  Future<void> deleteProject(String id) => _masterDataService.deleteProject(id);

  Future<void> addVendor(String name, {String? contact}) => _masterDataService.addVendor(name, contact: contact);
  Future<void> updateVendor(String id, String name, {String? contact}) => _masterDataService.updateVendor(id, name, contact: contact);
  Future<void> deleteVendor(String id) => _masterDataService.deleteVendor(id);

  Future<void> addSite(String name, {String? projectId}) => _masterDataService.addSite(name, projectId: projectId);
  Future<void> updateSite(String id, String name, {String? projectId}) => _masterDataService.updateSite(id, name, projectId: projectId);
  Future<void> deleteSite(String id) => _masterDataService.deleteSite(id);

  // ── Expense Reports ───────────────────────────────────────────────────────

  Future<List<ExpenseReport>> getExpenseReports() => _masterDataService.fetchExpenseReports();
  Future<ExpenseReport?> getExpenseReportById(String id) => _masterDataService.fetchExpenseReportById(id);

  Future<void> addExpenseReport(String name, {String? description}) =>
      _masterDataService.addExpenseReport(name, _currentUser!.id, _currentUser!.name, description: description);

  Future<void> updateExpenseReport(String id, String name, {String? description, String? status}) =>
      _masterDataService.updateExpenseReport(id, name, description: description, status: status);

  Future<void> deleteExpenseReport(String id) => _masterDataService.deleteExpenseReport(id);

  Future<List<InvoiceModel>> getInvoicesByReport(String reportId) =>
      _supabaseService.fetchInvoicesByReportId(reportId);

  UserRole _mapStringToRole(String roleStr) {
    final s = roleStr.toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');
    if (s.contains('admin')) return UserRole.admin;
    if (s.contains('projectmanager') || s.contains('pm')) return UserRole.projectManager;
    if (s.contains('finance') || s.contains('accounts')) return UserRole.finance;
    if (s.contains('siteengineer') || s.contains('engineer')) return UserRole.siteEngineer;
    return UserRole.siteEngineer;
  }
}
