import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/master_data_model.dart';

class MasterDataService {
  final _db = Supabase.instance.client;

  // ── Projects ──────────────────────────────────────────────────────────────

  Future<List<ProjectItem>> fetchProjects() async {
    final res = await _db
        .from('projects')
        .select()
        .eq('is_active', true)
        .order('name');
    return (res as List).map((e) => ProjectItem.fromJson(e)).toList();
  }

  Future<void> addProject(String name, {String? code}) async {
    await _db.from('projects').insert({'name': name, if (code != null && code.isNotEmpty) 'code': code});
  }

  Future<void> updateProject(String id, String name, {String? code}) async {
    await _db.from('projects').update({'name': name, 'code': code}).eq('id', id);
  }

  Future<void> deleteProject(String id) async {
    await _db.from('projects').update({'is_active': false}).eq('id', id);
  }

  // ── Vendors ───────────────────────────────────────────────────────────────

  Future<List<VendorItem>> fetchVendors() async {
    final res = await _db
        .from('vendors')
        .select()
        .eq('is_active', true)
        .order('name');
    return (res as List).map((e) => VendorItem.fromJson(e)).toList();
  }

  Future<void> addVendor(String name, {String? contact}) async {
    await _db.from('vendors').insert({'name': name, if (contact != null && contact.isNotEmpty) 'contact': contact});
  }

  Future<void> updateVendor(String id, String name, {String? contact}) async {
    await _db.from('vendors').update({'name': name, 'contact': contact}).eq('id', id);
  }

  Future<void> deleteVendor(String id) async {
    await _db.from('vendors').update({'is_active': false}).eq('id', id);
  }

  // ── Sites ─────────────────────────────────────────────────────────────────

  Future<List<SiteItem>> fetchSites() async {
    final res = await _db
        .from('sites')
        .select()
        .eq('is_active', true)
        .order('name');
    return (res as List).map((e) => SiteItem.fromJson(e)).toList();
  }

  Future<void> addSite(String name, {String? projectId}) async {
    await _db.from('sites').insert({'name': name, if (projectId != null) 'project_id': projectId});
  }

  Future<void> updateSite(String id, String name, {String? projectId}) async {
    await _db.from('sites').update({'name': name, 'project_id': projectId}).eq('id', id);
  }

  Future<void> deleteSite(String id) async {
    await _db.from('sites').update({'is_active': false}).eq('id', id);
  }

  // ── Expense Reports ───────────────────────────────────────────────────────

  Future<List<ExpenseReport>> fetchExpenseReports() async {
    final res = await _db
        .from('expense_reports')
        .select()
        .order('created_at', ascending: false);
    return (res as List).map((e) => ExpenseReport.fromJson(e)).toList();
  }

  Future<ExpenseReport?> fetchExpenseReportById(String id) async {
    final res = await _db
        .from('expense_reports')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return ExpenseReport.fromJson(res);
  }

  Future<void> addExpenseReport(String name, String createdBy, String createdByName, {String? description, String? startDate, String? endDate}) async {
    await _db.from('expense_reports').insert({
      'name': name,
      'created_by': createdBy,
      'created_by_name': createdByName,
      if (description != null && description.isNotEmpty) 'description': description,
      if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
      if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
    });
  }

  Future<void> updateExpenseReport(String id, String name, {String? description, String? status, String? startDate, String? endDate}) async {
    await _db.from('expense_reports').update({
      'name': name,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    }).eq('id', id);
  }

  Future<void> deleteExpenseReport(String id) async {
    await _db.from('expense_reports').delete().eq('id', id);
  }
}
