import 'user_model.dart';

enum InvoiceStatus { submitted, pmApproved, approved, rejected, paymentInitiated, paid }

enum ApprovalStageStatus { pending, approved, rejected }

class ApprovalStage {
  final String stageName;
  final String personName;
  final String role;
  final ApprovalStageStatus status;
  final String? timestamp;
  final String? remark;

  const ApprovalStage({
    required this.stageName,
    required this.personName,
    required this.role,
    required this.status,
    this.timestamp,
    this.remark,
  });
}

class CommentItem {
  final String id;
  final String author;
  final String authorId;
  final String role;
  final String timestamp;
  final String text;

  const CommentItem({
    required this.id,
    required this.author,
    required this.authorId,
    required this.role,
    required this.timestamp,
    required this.text,
  });

  factory CommentItem.fromSupabase(Map<String, dynamic> json) => CommentItem(
        id: json['id'],
        author: json['author_name'],
        authorId: json['author_id'],
        role: json['author_role'],
        timestamp: _fmtTime(json['created_at']),
        text: json['text'],
      );

  static String _fmtTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final d = '${dt.day} ${_months[dt.month - 1]}';
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$d, $h:$m';
    } catch (_) {
      return iso;
    }
  }

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];
}

class InvoiceLineItem {
  final String description;
  final String unit;
  final int qty;
  final double rate;
  final double amount;

  const InvoiceLineItem({
    required this.description,
    this.unit = '',
    required this.qty,
    required this.rate,
    required this.amount,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) => InvoiceLineItem(
        description: json['description'] ?? '',
        unit: json['unit'] ?? '',
        qty: (json['quantity'] as num?)?.toInt() ?? 0,
        rate: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'description': description,
        'unit': unit,
        'quantity': qty,
        'unitPrice': rate,
        'amount': amount,
      };
}

class InvoiceModel {
  final String id;
  final String projectName;
  final String vendorName;
  final String invoiceNumber;
  final String date;
  final String dueDate;
  final double subtotal;
  final double gstPercent;
  final InvoiceStatus status;
  final List<InvoiceLineItem> lineItems;
  final List<ApprovalStage> approvalStages;
  final List<CommentItem> comments;
  final String submittedBy;
  final String submittedByName;
  final String? submittedByEmail;
  final String? pmApprovedByName;
  final String? financeApprovedByName;
  final String? imageUrl;
  final Map<String, dynamic>? data;
  final UserRole assignedTo;
  final String? noteType;
  final String? fromRole;
  final String? toRole;
  final String? bankAccountHolder;
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankIfsc;
  final String? submitterSignatureUrl;
  final String? pmSignatureUrl;
  final String? financeSignatureUrl;
  final String? reportId;

  const InvoiceModel({
    required this.id,
    required this.projectName,
    required this.vendorName,
    required this.invoiceNumber,
    required this.date,
    required this.dueDate,
    required this.subtotal,
    required this.gstPercent,
    required this.status,
    required this.lineItems,
    this.approvalStages = const [],
    this.comments = const [],
    required this.submittedBy,
    required this.submittedByName,
    this.submittedByEmail,
    this.pmApprovedByName,
    this.financeApprovedByName,
    this.imageUrl,
    this.data,
    required this.assignedTo,
    this.noteType,
    this.fromRole,
    this.toRole,
    this.bankAccountHolder,
    this.bankAccountNumber,
    this.bankName,
    this.bankIfsc,
    this.submitterSignatureUrl,
    this.pmSignatureUrl,
    this.financeSignatureUrl,
    this.reportId,
  });

  double get gstAmount => subtotal * (gstPercent / 100);
  double get total => subtotal + gstAmount;

  String? get beneficiaryName => data?['beneficiary_name'] as String?;

  String get statusLabel {
    switch (status) {
      case InvoiceStatus.submitted:
        return 'Submitted';
      case InvoiceStatus.pmApproved:
        return 'PM Approved';
      case InvoiceStatus.approved:
        return 'Approved';
      case InvoiceStatus.rejected:
        return 'Rejected';
      case InvoiceStatus.paymentInitiated:
        return 'Payment Initiated';
      case InvoiceStatus.paid:
        return 'Paid';
    }
  }

  factory InvoiceModel.fromSupabase(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'],
      projectName: json['project_name'] ?? 'N/A',
      vendorName: json['vendor_name'],
      invoiceNumber: json['invoice_number'],
      date: json['date'],
      dueDate: json['due_date'],
      subtotal: (json['subtotal'] as num).toDouble(),
      gstPercent: (json['gst_percent'] as num).toDouble(),
      status: InvoiceStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => InvoiceStatus.submitted,
      ),
      lineItems: ((json['data'] as Map?)?['line_items'] as List?)
              ?.map((i) => InvoiceLineItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      submittedBy: json['submitted_by'],
      submittedByName: json['submitted_by_name'] ?? 'Unknown',
      submittedByEmail: json['submitted_by_email'],
      pmApprovedByName: json['pm_approved_by_name'],
      financeApprovedByName: json['finance_approved_by_name'],
      imageUrl: json['image_url'],
      data: json['data'] as Map<String, dynamic>?,
      assignedTo: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['assigned_to'],
        orElse: () => UserRole.projectManager,
      ),
      noteType: json['note_type'],
      fromRole: json['from_role'],
      toRole: json['to_role'],
      bankAccountHolder: json['bank_account_holder'],
      bankAccountNumber: json['bank_account_number'],
      bankName: json['bank_name'],
      bankIfsc: json['bank_ifsc'],
      submitterSignatureUrl: json['submitter_signature_url'],
      pmSignatureUrl: json['pm_signature_url'],
      financeSignatureUrl: json['finance_signature_url'],
      reportId: json['report_id'],
    );
  }
}

const List<InvoiceModel> kInvoices = [
  InvoiceModel(
    id: 'inv1',
    projectName: 'Whitefield Residential',
    vendorName: 'Sharma Constructions',
    invoiceNumber: 'INV-2024-001',
    date: '12 Jan 2024',
    dueDate: '27 Jan 2024',
    subtotal: 45000,
    gstPercent: 18,
    status: InvoiceStatus.submitted,
    lineItems: [
      InvoiceLineItem(description: 'Cement Bags (Grade A)', unit: 'Bags', qty: 100, rate: 400, amount: 40000),
      InvoiceLineItem(description: 'Transport Charges', unit: 'Trip', qty: 1, rate: 5000, amount: 5000),
    ],
    submittedBy: 'u1',
    submittedByName: 'Site Engineer',
    assignedTo: UserRole.projectManager,
    approvalStages: [
      ApprovalStage(
        stageName: 'Submission',
        personName: 'Site Engineer',
        role: 'Site Engineer',
        status: ApprovalStageStatus.approved,
        timestamp: '12 Jan, 10:30 AM',
      ),
      ApprovalStage(
        stageName: 'PM Approval',
        personName: 'Project Manager',
        role: 'Project Manager',
        status: ApprovalStageStatus.pending,
      ),
      ApprovalStage(
        stageName: 'Finance Verification',
        personName: 'Finance Admin',
        role: 'Finance',
        status: ApprovalStageStatus.pending,
      ),
    ],
    comments: [
      CommentItem(
        id: 'c1',
        author: 'Site Engineer',
        authorId: 'u1',
        role: 'Site Engineer',
        timestamp: '12 Jan, 10:35 AM',
        text: 'Attached the quality certificate for the cement.',
      ),
    ],
  ),
];
