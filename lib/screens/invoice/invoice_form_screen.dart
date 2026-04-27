import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/providers/app_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/signature_pad.dart';

const _noteTypes = [
  'Material Purchase',
  'Service Expense',
  'Equipment Hire',
  'Labour Payment',
  'Subcontractor Bill',
  'Miscellaneous',
];

const _maxAttachmentBytes = 10 * 1024 * 1024; // 10 MB total

class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({super.key});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _projectCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  final _invoiceNumberCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _bankHolderCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankIfscCtrl = TextEditingController();

  String _noteType = _noteTypes.first;
  DateTime _date = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 15));
  final List<_LineItemRow> _items = [_LineItemRow()];

  // Attachments — File + mime hint
  final List<_Attachment> _attachments = [];
  int get _totalAttachmentBytes =>
      _attachments.fold(0, (s, a) => s + a.size);

  bool _submitting = false;
  bool _signed = false;

  @override
  void initState() {
    super.initState();
    _invoiceNumberCtrl.text = 'Loading…';
    context.read<AppState>().getNextInvoiceNumber().then((n) {
      if (mounted) setState(() => _invoiceNumberCtrl.text = n);
    });
  }

  @override
  void dispose() {
    _projectCtrl.dispose();
    _siteCtrl.dispose();
    _vendorCtrl.dispose();
    _invoiceNumberCtrl.dispose();
    _remarksCtrl.dispose();
    _bankHolderCtrl.dispose();
    _bankAccountCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankIfscCtrl.dispose();
    for (final row in _items) row.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _items.fold(0.0, (s, r) => s + r.amount);

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')} ${_months[dt.month - 1]} ${dt.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  // ── Attachment picking ────────────────────────────────────────────────────

  Future<void> _pickAttachment() async {
    final choice = await showModalBottomSheet<_PickChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, _PickChoice.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose Image from Gallery'),
              onTap: () => Navigator.pop(ctx, _PickChoice.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Attach PDF'),
              onTap: () => Navigator.pop(ctx, _PickChoice.pdf),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    switch (choice) {
      case _PickChoice.camera:
        final picked = await ImagePicker()
            .pickImage(source: ImageSource.camera, imageQuality: 80);
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          _addFile(picked, bytes, 'image/jpeg');
        }
        break;
      case _PickChoice.gallery:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
          withData: true,
        );
        if (result != null) {
          for (final f in result.files) {
            if (f.bytes != null) {
              _addFile(XFile.fromData(f.bytes!, name: f.name), f.bytes!, 'image/*');
            }
          }
        }
        break;
      case _PickChoice.pdf:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: true,
          withData: true,
        );
        if (result != null) {
          for (final f in result.files) {
            if (f.bytes != null) {
              _addFile(XFile.fromData(f.bytes!, name: f.name), f.bytes!, 'application/pdf');
            }
          }
        }
        break;
    }
  }

  void _addFile(XFile xFile, Uint8List bytes, String mime) {
    final size = bytes.length;
    if (_totalAttachmentBytes + size > _maxAttachmentBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Total attachments must not exceed 10 MB.'),
          backgroundColor: AppColors.statusRed,
        ),
      );
      return;
    }
    setState(() => _attachments.add(_Attachment(xFile: xFile, bytes: bytes, mime: mime, size: size)));
  }

  // ── Submit flow ───────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.every((r) => r.descCtrl.text.trim().isEmpty)) {
      _snack('Add at least one line item.');
      return;
    }
    if (!_signed) {
      _snack('Please confirm your declaration to proceed.');
      return;
    }

    // Capture signature
    final sigBytes = await captureSignature(context, title: 'Your Signature');
    if (sigBytes == null) return; // cancelled

    setState(() => _submitting = true);
    try {
      final appState = context.read<AppState>();

      // Upload attachments
      final urls = <String>[];
      for (final att in _attachments) {
        try {
          final url = await appState.uploadAttachment(att.xFile);
          if (url != null) urls.add(url);
        } catch (_) {}
      }

      // Upload signature — use a temp ID prefix; will be keyed on invoice number
      String? sigUrl;
      try {
        sigUrl = await appState.uploadSignatureBytes(
          sigBytes,
          _invoiceNumberCtrl.text.replaceAll('/', '-'),
          'submitter',
        );
      } catch (_) {}

      await appState.submitInvoice(
        projectName: _projectCtrl.text.trim(),
        siteName: _siteCtrl.text.trim(),
        vendorName: _vendorCtrl.text.trim(),
        invoiceNumber: _invoiceNumberCtrl.text.trim(),
        date: _fmtDate(_date),
        dueDate: _fmtDate(_dueDate),
        subtotal: _subtotal,
        gstPercent: 0,
        remarks: _remarksCtrl.text.trim(),
        lineItems: _items
            .where((r) => r.descCtrl.text.trim().isNotEmpty)
            .map((r) => {
                  'description': r.descCtrl.text.trim(),
                  'unit': r.unitCtrl.text.trim(),
                  'quantity': r.quantity,
                  'unitPrice': r.rate,
                  'amount': r.amount,
                })
            .toList(),
        attachmentUrls: urls,
        noteType: _noteType,
        bankAccountHolder: _bankHolderCtrl.text.trim(),
        bankAccountNumber: _bankAccountCtrl.text.trim(),
        bankName: _bankNameCtrl.text.trim(),
        bankIfsc: _bankIfscCtrl.text.trim(),
        submitterSignatureUrl: sigUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense submitted for approval!'),
            backgroundColor: AppColors.statusGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.statusRed : null,
      ));

  Future<void> _pickDate(bool isDue) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDue ? _dueDate : _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => isDue ? _dueDate = picked : _date = picked);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Expense'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _submitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : TextButton(
                    onPressed: _submit,
                    child: const Text('Submit',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Expense Details ──────────────────────────────
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Expense Details'),
                      const SizedBox(height: 16),
                      // Note type
                      DropdownButtonFormField<String>(
                        value: _noteType,
                        decoration:
                            const InputDecoration(labelText: 'Note Type *'),
                        items: _noteTypes
                            .map((t) => DropdownMenuItem(
                                value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _noteType = v ?? _noteType),
                      ),
                      const SizedBox(height: 16),
                      _twoCol(
                        _field(_invoiceNumberCtrl, 'Ref No.',
                            validator: _required),
                        _field(_vendorCtrl, 'Vendor / Contractor Name *',
                            validator: _required),
                      ),
                      const SizedBox(height: 16),
                      _twoCol(
                        _field(_projectCtrl, 'Project Name *',
                            validator: _required),
                        _field(_siteCtrl, 'Site Name *',
                            validator: _required),
                      ),
                      const SizedBox(height: 16),
                      _twoCol(
                        _readOnly(
                          label: 'From (Submitted By)',
                          value: user?.name ?? '—',
                          icon: Icons.person_outline_rounded,
                        ),
                        _readOnly(
                          label: 'Role',
                          value: user?.roleDisplayName ?? '—',
                          icon: Icons.badge_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _twoCol(
                        _dateField(
                          label: 'Expense Date *',
                          value: _fmtDate(_date),
                          onTap: () => _pickDate(false),
                        ),
                        _dateField(
                          label: 'Due Date *',
                          value: _fmtDate(_dueDate),
                          onTap: () => _pickDate(true),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Line Items ───────────────────────────────────
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                              child: SectionHeader(title: 'Items / Products')),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _items.add(_LineItemRow())),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Row'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(builder: (context, c) {
                        if (c.maxWidth > 560) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints:
                                  BoxConstraints(minWidth: c.maxWidth),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _ItemHeader(),
                                  const Divider(
                                      color: AppColors.borderColor),
                                  ...List.generate(
                                    _items.length,
                                    (i) => _ItemRowWidget(
                                      row: _items[i],
                                      canDelete: _items.length > 1,
                                      onChanged: () => setState(() {}),
                                      onDelete: () => setState(
                                          () => _items.removeAt(i)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: List.generate(
                            _items.length,
                            (i) => _ItemCardMobile(
                              index: i,
                              row: _items[i],
                              canDelete: _items.length > 1,
                              onChanged: () => setState(() {}),
                              onDelete: () =>
                                  setState(() => _items.removeAt(i)),
                            ),
                          ),
                        );
                      }),
                      const Divider(
                          color: AppColors.borderColor, height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 320),
                          child: Column(
                            children: [
                              const Divider(height: 16),
                              _TotalRow(
                                label: 'Total Amount',
                                value: '₹${_fmt(_subtotal)}',
                                bold: true,
                                color: AppColors.accentBlue,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Bank Details ─────────────────────────────────
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Bank Details'),
                      const SizedBox(height: 16),
                      _twoCol(
                        _field(_bankHolderCtrl, 'Account Holder Name'),
                        _field(_bankAccountCtrl, 'Account Number'),
                      ),
                      const SizedBox(height: 16),
                      _twoCol(
                        _field(_bankNameCtrl, 'Bank and Branch'),
                        _field(_bankIfscCtrl, 'IFSC Code'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Attachments ──────────────────────────────────
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                              child: SectionHeader(title: 'Attachments')),
                          TextButton.icon(
                            onPressed: _pickAttachment,
                            icon: const Icon(Icons.attach_file_rounded,
                                size: 16),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      // Size bar
                      if (_attachments.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: _totalAttachmentBytes /
                                    _maxAttachmentBytes,
                                backgroundColor:
                                    AppColors.borderColor,
                                color: _totalAttachmentBytes >
                                        _maxAttachmentBytes * 0.85
                                    ? AppColors.statusOrange
                                    : AppColors.accentBlue,
                                minHeight: 4,
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${(_totalAttachmentBytes / 1024 / 1024).toStringAsFixed(1)} / 10 MB',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (_attachments.isEmpty)
                        Text(
                          'Attach images or PDFs (max 10 MB total).',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500),
                        )
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(
                            _attachments.length,
                            (i) {
                              final att = _attachments[i];
                              return Stack(
                                children: [
                                  att.mime.contains('pdf')
                                      ? _PdfThumb(
                                          name: att.xFile.name,
                                          size: 90,
                                        )
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.memory(
                                            att.bytes,
                                            width: 90,
                                            height: 90,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => _attachments.removeAt(i)),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            size: 12,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Remarks ──────────────────────────────────────
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Remarks'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remarksCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText:
                              'Special instructions or notes…',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Declaration ──────────────────────────────────
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Declaration'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: AppColors.borderColor),
                        ),
                        child: Text(
                          'I, ${user?.name ?? 'the undersigned'}, hereby declare that '
                          'the above information is true and accurate to the best of '
                          'my knowledge, and this expense is submitted for approval.',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: _signed,
                            activeColor: AppColors.accentBlue,
                            onChanged: (v) =>
                                setState(() => _signed = v ?? false),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _signed = !_signed),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary),
                                  children: [
                                    const TextSpan(
                                        text: 'I confirm as '),
                                    TextSpan(
                                      text: user?.name ?? 'User',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accentBlue),
                                    ),
                                    TextSpan(
                                      text:
                                          ' (${user?.roleDisplayName ?? ''})',
                                      style: const TextStyle(
                                          color:
                                              AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You will be asked to sign digitally when you tap Submit.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_submitting
                        ? 'Submitting…'
                        : 'Submit for Approval'),
                    style: ElevatedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Layout helpers ────────────────────────────────────────────────────────

  Widget _twoCol(Widget a, Widget b) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth > 500) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 16),
            Expanded(child: b),
          ],
        );
      }
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [a, const SizedBox(height: 16), b]);
    });
  }

  Widget _field(TextEditingController ctrl, String label,
      {String? Function(String?)? validator, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }

  Widget _readOnly(
      {required String label,
      required String value,
      required IconData icon}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            Icon(icon, size: 18, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.backgroundLight,
      ),
      child: Text(value,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
    );
  }

  Widget _dateField(
      {required String label,
      required String value,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined,
              size: 16, color: AppColors.textSecondary),
        ),
        child: Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ── Attachment model ─────────────────────────────────────────────────────────

enum _PickChoice { camera, gallery, pdf }

class _Attachment {
  final XFile xFile;
  final Uint8List bytes;
  final String mime;
  final int size;
  _Attachment({required this.xFile, required this.bytes, required this.mime, required this.size});
}

class _PdfThumb extends StatelessWidget {
  final String name;
  final double size;
  const _PdfThumb({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf_rounded,
              color: AppColors.statusRed, size: 28),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
                fontSize: 9, color: AppColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Line item data model ──────────────────────────────────────────────────────

class _LineItemRow {
  final descCtrl = TextEditingController();
  final unitCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final rateCtrl = TextEditingController();

  double get quantity => double.tryParse(qtyCtrl.text) ?? 0;
  double get rate => double.tryParse(rateCtrl.text) ?? 0;
  double get amount => quantity * rate;

  void dispose() {
    descCtrl.dispose();
    unitCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
  }
}

// ── Line item widgets ─────────────────────────────────────────────────────────

class _ItemCardMobile extends StatelessWidget {
  final int index;
  final _LineItemRow row;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _ItemCardMobile({
    required this.index,
    required this.row,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Item ${index + 1}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentBlue)),
              const Spacer(),
              if (canDelete)
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.remove_circle_outline,
                      size: 18, color: AppColors.statusRed),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: row.descCtrl,
            decoration: const InputDecoration(
              labelText: 'Product Name',
              hintText: 'Product or service description',
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.unitCtrl,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: row.qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'))
                  ],
                  decoration: const InputDecoration(labelText: 'Qty.'),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: row.rateCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'))
                  ],
                  decoration:
                      const InputDecoration(labelText: 'Rate per qty.'),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Total: ',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary)),
              Text('₹${_fmt(row.amount)}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentBlue)),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _ItemHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('PRODUCT NAME', style: style)),
          SizedBox(width: 8),
          SizedBox(width: 60, child: Text('UNIT', style: style)),
          SizedBox(width: 8),
          SizedBox(
              width: 60,
              child: Text('QTY.', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 8),
          SizedBox(
              width: 90,
              child: Text('RATE PER QTY.', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 8),
          SizedBox(
              width: 100,
              child: Text('TOTAL COST', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _ItemRowWidget extends StatelessWidget {
  final _LineItemRow row;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _ItemRowWidget({
    required this.row,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: TextFormField(
              controller: row.descCtrl,
              decoration: const InputDecoration(
                hintText: 'Product name',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextFormField(
              controller: row.unitCtrl,
              decoration: const InputDecoration(
                hintText: 'pcs',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextFormField(
              controller: row.qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: '0',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextFormField(
              controller: row.rateCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: '0.00',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              '₹${_fmt(row.amount)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            child: canDelete
                ? IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        size: 18, color: AppColors.statusRed),
                    padding: EdgeInsets.zero,
                    onPressed: onDelete,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: child,
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _TotalRow(
      {required this.label,
      required this.value,
      this.bold = false,
      this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: bold ? 14 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? AppColors.textPrimary)),
      ],
    );
  }
}
