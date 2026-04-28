import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/models/master_data_model.dart';
import '../../core/providers/app_state.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.cardWhite,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.accentBlue,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accentBlue,
            tabs: const [
              Tab(text: 'Projects'),
              Tab(text: 'Vendors'),
              Tab(text: 'Sites'),
              Tab(text: 'Reports'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _ProjectsTab(),
              _VendorsTab(),
              _SitesTab(),
              _ReportsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Generic CRUD list ─────────────────────────────────────────────────────────

typedef _LoadFn<T> = Future<List<T>> Function();
typedef _ItemName<T> = String Function(T);
typedef _ItemSub<T> = String? Function(T);

class _MasterList<T> extends StatefulWidget {
  final String entityName;
  final _LoadFn<T> load;
  final _ItemName<T> name;
  final _ItemSub<T>? subtitle;
  final Future<void> Function(BuildContext ctx, T? existing) onAddEdit;
  final Future<void> Function(T item) onDelete;

  const _MasterList({
    super.key,
    required this.entityName,
    required this.load,
    required this.name,
    this.subtitle,
    required this.onAddEdit,
    required this.onDelete,
  });

  @override
  State<_MasterList<T>> createState() => _MasterListState<T>();
}

class _MasterListState<T> extends State<_MasterList<T>> {
  late Future<List<T>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _future = widget.load());

  Future<void> _delete(T item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${widget.entityName}'),
        content: Text('Remove "${widget.name(item)}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.statusRed))),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onDelete(item);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${widget.entityName}s',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Add ${widget.entityName}'),
                onPressed: () async {
                  await widget.onAddEdit(context, null);
                  _reload();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<T>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return Center(
                      child: Text('No ${widget.entityName.toLowerCase()}s yet.',
                          style: const TextStyle(
                              color: AppColors.textSecondary)));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.borderColor),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return ListTile(
                      title: Text(widget.name(item),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: widget.subtitle != null &&
                              widget.subtitle!(item) != null
                          ? Text(widget.subtitle!(item)!)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 18, color: AppColors.accentBlue),
                            tooltip: 'Edit',
                            onPressed: () async {
                              await widget.onAddEdit(context, item);
                              _reload();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18, color: AppColors.statusRed),
                            tooltip: 'Delete',
                            onPressed: () => _delete(item),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Projects tab ──────────────────────────────────────────────────────────────

class _ProjectsTab extends StatelessWidget {
  const _ProjectsTab();

  Future<void> _showDialog(BuildContext context, ProjectItem? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Project' : 'Edit Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Project Name *')),
            const SizedBox(height: 12),
            TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Project Code')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final appState = context.read<AppState>();
      if (existing == null) {
        await appState.addProject(nameCtrl.text.trim(),
            code: codeCtrl.text.trim());
      } else {
        await appState.updateProject(existing.id, nameCtrl.text.trim(),
            code: codeCtrl.text.trim());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    return _MasterList<ProjectItem>(
      entityName: 'Project',
      load: appState.getProjects,
      name: (p) => p.name,
      subtitle: (p) => p.code != null && p.code!.isNotEmpty ? 'Code: ${p.code}' : null,
      onAddEdit: (ctx, item) => _showDialog(ctx, item),
      onDelete: (item) => appState.deleteProject(item.id),
    );
  }
}

// ── Vendors tab ───────────────────────────────────────────────────────────────

class _VendorsTab extends StatelessWidget {
  const _VendorsTab();

  Future<void> _showDialog(BuildContext context, VendorItem? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final contactCtrl = TextEditingController(text: existing?.contact ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Vendor' : 'Edit Vendor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Vendor Name *')),
            const SizedBox(height: 12),
            TextField(
                controller: contactCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile Number')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final appState = context.read<AppState>();
      if (existing == null) {
        await appState.addVendor(nameCtrl.text.trim(),
            contact: contactCtrl.text.trim());
      } else {
        await appState.updateVendor(existing.id, nameCtrl.text.trim(),
            contact: contactCtrl.text.trim());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    return _MasterList<VendorItem>(
      entityName: 'Vendor',
      load: appState.getVendors,
      name: (v) => v.name,
      subtitle: (v) => v.contact != null && v.contact!.isNotEmpty ? v.contact : null,
      onAddEdit: (ctx, item) => _showDialog(ctx, item),
      onDelete: (item) => appState.deleteVendor(item.id),
    );
  }
}

// ── Sites tab ─────────────────────────────────────────────────────────────────

class _SitesTab extends StatelessWidget {
  const _SitesTab();

  Future<void> _showDialog(BuildContext context, SiteItem? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Site' : 'Edit Site'),
        content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Site Name *')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final appState = context.read<AppState>();
      if (existing == null) {
        await appState.addSite(nameCtrl.text.trim());
      } else {
        await appState.updateSite(existing.id, nameCtrl.text.trim());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    return _MasterList<SiteItem>(
      entityName: 'Site',
      load: appState.getSites,
      name: (s) => s.name,
      onAddEdit: (ctx, item) => _showDialog(ctx, item),
      onDelete: (item) => appState.deleteSite(item.id),
    );
  }
}

// ── Reports tab ───────────────────────────────────────────────────────────────

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  Future<void> _showDialog(BuildContext context, ExpenseReport? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime? startDate = existing?.startDate != null ? DateTime.tryParse(existing!.startDate!) : null;
    DateTime? endDate = existing?.endDate != null ? DateTime.tryParse(existing!.endDate!) : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Report' : 'Edit Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Report Name *')),
              const SizedBox(height: 12),
              TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(context: ctx, initialDate: startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (picked != null) setDialogState(() => startDate = picked);
                      },
                      child: Text(startDate == null ? 'Start Date' : '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(context: ctx, initialDate: endDate ?? startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (picked != null) setDialogState(() => endDate = picked);
                      },
                      child: Text(endDate == null ? 'End Date' : '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final appState = context.read<AppState>();
      final sDate = startDate != null ? '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}' : null;
      final eDate = endDate != null ? '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}' : null;

      if (existing == null) {
        await appState.addExpenseReport(nameCtrl.text.trim(),
            description: descCtrl.text.trim(), startDate: sDate, endDate: eDate);
      } else {
        await appState.updateExpenseReport(existing.id, nameCtrl.text.trim(),
            description: descCtrl.text.trim(), startDate: sDate, endDate: eDate);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    return _MasterList<ExpenseReport>(
      entityName: 'Report',
      load: appState.getExpenseReports,
      name: (r) => r.name,
      subtitle: (r) => r.description,
      onAddEdit: (ctx, item) => _showDialog(ctx, item),
      onDelete: (item) => appState.deleteExpenseReport(item.id),
    );
  }
}
