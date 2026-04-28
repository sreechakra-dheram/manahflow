class ProjectItem {
  final String id;
  final String name;
  final String? code;
  final bool isActive;

  const ProjectItem({
    required this.id,
    required this.name,
    this.code,
    this.isActive = true,
  });

  factory ProjectItem.fromJson(Map<String, dynamic> j) => ProjectItem(
        id: j['id'],
        name: j['name'],
        code: j['code'],
        isActive: j['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (code != null && code!.isNotEmpty) 'code': code,
      };
}

class VendorItem {
  final String id;
  final String name;
  final String? contact;
  final bool isActive;

  const VendorItem({
    required this.id,
    required this.name,
    this.contact,
    this.isActive = true,
  });

  factory VendorItem.fromJson(Map<String, dynamic> j) => VendorItem(
        id: j['id'],
        name: j['name'],
        contact: j['contact'],
        isActive: j['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (contact != null && contact!.isNotEmpty) 'contact': contact,
      };
}

class SiteItem {
  final String id;
  final String name;
  final String? projectId;
  final bool isActive;

  const SiteItem({
    required this.id,
    required this.name,
    this.projectId,
    this.isActive = true,
  });

  factory SiteItem.fromJson(Map<String, dynamic> j) => SiteItem(
        id: j['id'],
        name: j['name'],
        projectId: j['project_id'],
        isActive: j['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (projectId != null) 'project_id': projectId,
      };
}

class ExpenseReport {
  final String id;
  final String name;
  final String? description;
  final String status;
  final String createdBy;
  final String createdByName;
  final String createdAt;

  const ExpenseReport({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  factory ExpenseReport.fromJson(Map<String, dynamic> j) => ExpenseReport(
        id: j['id'],
        name: j['name'],
        description: j['description'],
        status: j['status'] ?? 'open',
        createdBy: j['created_by'],
        createdByName: j['created_by_name'],
        createdAt: j['created_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null && description!.isNotEmpty) 'description': description,
        'status': status,
      };

  String get statusLabel => status == 'open' ? 'Open' : 'Closed';
}
