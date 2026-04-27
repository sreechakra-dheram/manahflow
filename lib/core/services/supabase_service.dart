import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/invoice_model.dart';
import '../models/notification_model.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  Future<void> updateStatus(
    String table,
    String id,
    String status,
    UserRole assignedTo, {
    String? actorId,
    String? actorName,
    String? actorRole,
    String? signatureUrl,
  }) async {
    final update = <String, dynamic>{
      'status': status,
      'assigned_to': assignedTo.toString().split('.').last,
    };
    if (actorId != null) {
      if (status == 'pmApproved') {
        update['pm_approved_by_id'] = actorId;
        update['pm_approved_by_name'] = actorName;
        if (signatureUrl != null) update['pm_signature_url'] = signatureUrl;
      } else if (status == 'approved') {
        update['finance_approved_by_id'] = actorId;
        update['finance_approved_by_name'] = actorName;
        if (signatureUrl != null) update['finance_signature_url'] = signatureUrl;
      } else if (status == 'paid') {
        if (signatureUrl != null) update['finance_signature_url'] = signatureUrl;
      }
    }
    await _client.from(table).update(update).eq('id', id);
  }

  Future<String?> uploadImage(File file, String path) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final fullPath = '$path/$fileName';
    await _client.storage.from('attachments').upload(fullPath, file);
    return _client.storage.from('attachments').getPublicUrl(fullPath);
  }

  Future<String?> uploadSignatureBytes(
      Uint8List bytes, String invoiceId, String role) async {
    return 'data:image/png;base64,${base64Encode(bytes)}';
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
    required String submittedBy,
    required String submittedByName,
    required String submittedByEmail,
    required String remarks,
    required List<Map<String, dynamic>> lineItems,
    List<String> attachmentUrls = const [],
    required String initialStatus,
    required String assignedTo,
    String? pmApprovedByName,
    String? financeApprovedByName,
    String? noteType,
    String? fromRole,
    String? toRole,
    String? bankAccountHolder,
    String? bankAccountNumber,
    String? bankName,
    String? bankIfsc,
    String? submitterSignatureUrl,
  }) async {
    await _client.from('invoices').insert({
      'project_name': projectName,
      'site_name': siteName,
      'vendor_name': vendorName,
      'invoice_number': invoiceNumber,
      'date': date,
      'due_date': dueDate,
      'subtotal': subtotal,
      'gst_percent': gstPercent,
      'submitted_by': submittedBy,
      'submitted_by_name': submittedByName,
      'submitted_by_email': submittedByEmail,
      'remarks': remarks,
      'assigned_to': assignedTo,
      'status': initialStatus,
      if (pmApprovedByName != null) 'pm_approved_by_name': pmApprovedByName,
      if (financeApprovedByName != null)
        'finance_approved_by_name': financeApprovedByName,
      if (noteType != null) 'note_type': noteType,
      if (fromRole != null) 'from_role': fromRole,
      if (toRole != null) 'to_role': toRole,
      if (bankAccountHolder != null)
        'bank_account_holder': bankAccountHolder,
      if (bankAccountNumber != null)
        'bank_account_number': bankAccountNumber,
      if (bankName != null) 'bank_name': bankName,
      if (bankIfsc != null) 'bank_ifsc': bankIfsc,
      if (submitterSignatureUrl != null)
        'submitter_signature_url': submitterSignatureUrl,
      'data': {'line_items': lineItems, 'attachments': attachmentUrls},
    });
  }

  Future<List<InvoiceModel>> fetchAllInvoices() async {
    final response = await _client.from('invoices').select().order('created_at', ascending: false);
    return (response as List).map((e) => InvoiceModel.fromSupabase(_normalise(e))).toList();
  }

  Future<InvoiceModel?> fetchInvoiceById(String id) async {
    final response = await _client.from('invoices').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return InvoiceModel.fromSupabase(_normalise(response));
  }

  // Normalise snake_case assigned_to values to camelCase for enum matching
  Map<String, dynamic> _normalise(Map<String, dynamic> row) {
    final at = row['assigned_to'] as String?;
    if (at == null) return row;
    final mapped = {
      'project_manager': 'projectManager',
      'site_engineer': 'siteEngineer',
      'finance_admin': 'finance',
      'finance': 'finance',
    }[at] ?? at;
    return {...row, 'assigned_to': mapped};
  }

  Future<List<CommentItem>> fetchComments(String recordId, String recordType) async {
    final response = await _client
        .from('comments')
        .select()
        .eq('record_id', recordId)
        .eq('record_type', recordType)
        .order('created_at');
    return (response as List).map((e) => CommentItem.fromSupabase(e)).toList();
  }

  Future<void> addComment({
    required String recordId,
    required String recordType,
    required String authorId,
    required String authorName,
    required String authorRole,
    required String text,
  }) async {
    await _client.from('comments').insert({
      'record_id': recordId,
      'record_type': recordType,
      'author_id': authorId,
      'author_name': authorName,
      'author_role': authorRole,
      'text': text,
    });
  }

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final invoices = await _client
        .from('invoices')
        .select('status, subtotal, project_name, created_at, vendor_name, due_date');
    final invoiceList = invoices as List;

    double totalPaid = 0;
    int pendingCount = 0;
    int approvedCount = 0;
    int overdueCount = 0;
    final projectSpend = <String, double>{};
    final now = DateTime.now();

    for (final inv in invoiceList) {
      final amount = (inv['subtotal'] as num?)?.toDouble() ?? 0.0;
      final status = inv['status'] as String? ?? '';
      final dueDateStr = inv['due_date'] as String?;

      if (status == 'paid') totalPaid += amount;
      if (status == 'submitted') pendingCount++;
      if (status == 'approved') approvedCount++;
      if (status != 'paid' && dueDateStr != null) {
        final due = DateTime.tryParse(dueDateStr);
        if (due != null && now.isAfter(due)) overdueCount++;
      }

      if (status == 'paid' || status == 'approved') {
        final name = inv['project_name'] as String? ?? 'General';
        projectSpend[name] = (projectSpend[name] ?? 0) + amount;
      }
    }

    return {
      'totalPaid': totalPaid,
      'pendingCount': pendingCount,
      'approvedCount': approvedCount,
      'overdueCount': overdueCount,
      'projectSpend': projectSpend,
      'recentActivity': invoiceList
          .take(10)
          .map((e) => {...e, 'type': 'invoice'})
          .toList()
        ..sort((a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String)),
    };
  }

  Future<Map<String, dynamic>> fetchMonthlySpend() async {
    final now = DateTime.now();
    final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

    final rows = await _client
        .from('invoices')
        .select('subtotal, created_at, status')
        .gte('created_at', sixMonthsAgo.toIso8601String());

    final List list = rows as List;
    // Build a map: 'yyyy-MM' -> total spend
    final monthlyMap = <String, double>{};

    for (var i = 0; i < 6; i++) {
      final m = DateTime(now.year, now.month - (5 - i), 1);
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      monthlyMap[key] = 0.0;
    }

    for (final row in list) {
      final createdAt = row['created_at'] as String?;
      if (createdAt == null) continue;
      final dt = DateTime.tryParse(createdAt);
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      if (monthlyMap.containsKey(key)) {
        monthlyMap[key] = (monthlyMap[key] ?? 0) +
            ((row['subtotal'] as num?)?.toDouble() ?? 0.0);
      }
    }

    final sortedKeys = monthlyMap.keys.toList()..sort();
    final months = <String>[];
    final values = <double>[];
    const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    for (final key in sortedKeys) {
      final month = int.parse(key.split('-')[1]);
      months.add(monthNames[month - 1]);
      values.add(monthlyMap[key]!);
    }

    return {'months': months, 'values': values};
  }

  Future<Map<String, dynamic>> fetchProfileStats(String userId) async {
    final rows = await _client
        .from('invoices')
        .select('status, subtotal, submitted_by')
        .eq('submitted_by', userId);
    final list = rows as List;

    int submitted = 0;
    int approved = 0;
    double totalPaid = 0;

    for (final row in list) {
      final status = row['status'] as String? ?? '';
      final amount = (row['subtotal'] as num?)?.toDouble() ?? 0.0;
      submitted++;
      if (status == 'approved' || status == 'paid' || status == 'pmApproved') approved++;
      if (status == 'paid') totalPaid += amount;
    }

    return {
      'submitted': submitted,
      'approved': approved,
      'totalPaid': totalPaid,
    };
  }

  Future<int> fetchNextInvoiceNumber() async {
    final response = await _client.from('invoices').select('id');
    return (response as List).length + 1;
  }

  Future<List<AppNotification>> fetchNotifications(String userId) async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (response as List).map((e) => AppNotification.fromSupabase(e)).toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllNotificationsRead(String userId) async {
    await _client.from('notifications').update({'is_read': true}).eq('user_id', userId);
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    String? invoiceId,
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'invoice_id': invoiceId,
      'is_read': false,
    });
  }

  void subscribeToInvoices(void Function(Map<String, dynamic>) onUpdate) {
    _client
        .channel('invoices_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'invoices',
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  void unsubscribeAll() {
    _client.removeAllChannels();
  }

  Future<Map<String, dynamic>> fetchReportData() async {
    final invoices = await _client
        .from('invoices')
        .select('project_name, vendor_name, subtotal, status, due_date, created_at');
    final invoiceList = invoices as List;
    final now = DateTime.now();

    final projectSpend = <String, double>{};
    final vendorOutstanding = <String, double>{};
    final aging = {
      '0–30 days': 0.0,
      '30–60 days': 0.0,
      '60–90 days': 0.0,
      '90+ days': 0.0,
    };

    for (final inv in invoiceList) {
      final amount = (inv['subtotal'] as num?)?.toDouble() ?? 0.0;
      final status = inv['status'] as String? ?? '';
      final projectName = inv['project_name'] as String? ?? 'General';
      final vendorName = inv['vendor_name'] as String? ?? 'Unknown';

      // Include all invoices (submitted/approved/paid) in project spend
      projectSpend[projectName] = (projectSpend[projectName] ?? 0) + amount;

      if (status != 'paid') {
        vendorOutstanding[vendorName] =
            (vendorOutstanding[vendorName] ?? 0) + amount;

        // Use created_at (ISO format) for aging since due_date may not be ISO
        final dateStr = inv['created_at'] as String? ?? inv['due_date'] as String?;
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            final days = now.difference(date).inDays;
            if (days <= 30) {
              aging['0–30 days'] = aging['0–30 days']! + amount;
            } else if (days <= 60) {
              aging['30–60 days'] = aging['30–60 days']! + amount;
            } else if (days <= 90) {
              aging['60–90 days'] = aging['60–90 days']! + amount;
            } else {
              aging['90+ days'] = aging['90+ days']! + amount;
            }
          }
        }
      }
    }

    return {
      'projectSpend': projectSpend,
      'vendorOutstanding': vendorOutstanding,
      'aging': aging,
    };
  }
}
