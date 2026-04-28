import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice_model.dart';

class ExpensePdfService {
  static Future<void> downloadExpense(
    InvoiceModel inv, {
    Future<String> Function(String path)? getSignedUrl,
  }) async {
    final bytes = await _build(inv, getSignedUrl: getSignedUrl);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${inv.invoiceNumber}.pdf',
    );
  }

  static Future<Uint8List> _build(
    InvoiceModel inv, {
    Future<String> Function(String path)? getSignedUrl,
  }) async {
    final doc = pw.Document();

    // Load logo asset
    final logoBytes = await rootBundle.load('manah.jpg');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // Resolve signature paths to signed URLs if a resolver is provided
    Future<String?> resolveUrl(String? raw) async {
      if (raw == null || raw.isEmpty) return null;
      if (raw.startsWith('data:') || raw.startsWith('http')) return raw;
      if (getSignedUrl != null) {
        try { return await getSignedUrl(raw); } catch (_) {}
      }
      return null;
    }

    // Load signature images (best-effort)
    final submitterSig = await _networkImage(await resolveUrl(inv.submitterSignatureUrl));
    final pmSig = await _networkImage(await resolveUrl(inv.pmSignatureUrl));
    final financeSig = await _networkImage(await resolveUrl(inv.financeSignatureUrl));

    final baseStyle = pw.TextStyle(fontSize: 9, font: pw.Font.helvetica());
    final boldStyle =
        pw.TextStyle(fontSize: 9, font: pw.Font.helveticaBold());
    final titleStyle =
        pw.TextStyle(fontSize: 11, font: pw.Font.helveticaBold());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // ── Header ──────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 70,
                height: 70,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      alignment: pw.Alignment.center,
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                      ),
                      child: pw.Text(
                        inv.noteType ?? 'Material Purchase',
                        style: titleStyle,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey400),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3),
                        1: const pw.FlexColumnWidth(1.5),
                        2: const pw.FlexColumnWidth(1),
                      },
                      children: [
                        pw.TableRow(children: [
                          _cell('Ref No: ${inv.invoiceNumber}', boldStyle),
                          _cell('Project: ${inv.projectName}', baseStyle),
                          _cell('Date: ${inv.date}', baseStyle),
                        ]),
                        pw.TableRow(children: [
                          _cell(
                              'From: ${inv.fromRole ?? inv.submittedByName}',
                              baseStyle),
                          _cell('To: ${inv.toRole ?? "Finance"}', baseStyle),
                          _cell('Due: ${inv.dueDate}', baseStyle),
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          // ── Letter body ──────────────────────────────────────
          pw.Text('Dear Sir,', style: baseStyle),
          pw.SizedBox(height: 6),
          if (_isTrips(inv.noteType)) ...[
            pw.Text(
              'Subject: Travel & Site Visit Expense Reimbursement - ${inv.projectName}',
              style: boldStyle,
            ),
            pw.SizedBox(height: 4),
            pw.Text('Project Code: ${inv.projectName}', style: baseStyle),
            pw.SizedBox(height: 8),
            if (inv.remarks != null && inv.remarks!.isNotEmpty) ...[
              pw.Text('Reason: ${inv.remarks}', style: baseStyle),
              pw.SizedBox(height: 6),
            ],
            pw.Text(
              'Please approve the reimbursement of Rs. ${_fmt(inv.subtotal)} towards '
              'miscellaneous / travel expenses incurred by ${inv.beneficiaryName ?? inv.submittedByName} '
              'for ${inv.projectName}. '
              'All supporting bills have been enclosed. '
              'Kindly process the reimbursement at the earliest.',
              style: baseStyle,
            ),
          ] else ...[
            pw.Text(
              'Subject: Payment Required - ${inv.noteType ?? 'Material Purchase'} from ${inv.vendorName}',
              style: boldStyle,
            ),
            pw.SizedBox(height: 4),
            pw.Text('Project Code: ${inv.projectName}', style: baseStyle),
            pw.SizedBox(height: 8),
            pw.Text(
              'Please approve the payment of Rs. ${_fmt(inv.subtotal)} towards '
              'Purchase of products from ${inv.vendorName.toUpperCase()}. '
              'The material has been received as per the requirement, and the '
              'vendor invoice has been verified. Kindly process the payment at '
              'the earliest to ensure smooth continuation of project activities.',
              style: baseStyle,
            ),
          ],

          pw.SizedBox(height: 14),

          // ── Line items table ──────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FixedColumnWidth(28),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(40),
              3: const pw.FixedColumnWidth(36),
              4: const pw.FixedColumnWidth(52),
              5: const pw.FixedColumnWidth(60),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('S No.', boldStyle),
                  _cell('Product Name', boldStyle),
                  _cell('Unit', boldStyle),
                  _cell('Qty.', boldStyle),
                  _cell('Rate per qty.', boldStyle),
                  _cell('Total cost', boldStyle, align: pw.Alignment.centerRight),
                ],
              ),
              // Item rows
              ...List.generate(inv.lineItems.length, (i) {
                final item = inv.lineItems[i];
                return pw.TableRow(children: [
                  _cell('${i + 1}', baseStyle),
                  _cell(item.description, baseStyle),
                  _cell(item.unit, baseStyle),
                  _cell('${item.qty}', baseStyle,
                      align: pw.Alignment.centerRight),
                  _cell(_fmt(item.rate), baseStyle,
                      align: pw.Alignment.centerRight),
                  _cell('Rs. ${_fmt(item.amount)}', baseStyle,
                      align: pw.Alignment.centerRight),
                ]);
              }),
              // Empty filler rows
              ...List.generate(
                  (inv.lineItems.length < 4) ? 4 - inv.lineItems.length : 0,
                  (_) => pw.TableRow(children: [
                        _cell('', baseStyle),
                        _cell('', baseStyle),
                        _cell('', baseStyle),
                        _cell('', baseStyle),
                        _cell('', baseStyle),
                        _cell('', baseStyle),
                      ])),
              // Total row
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _cell('', baseStyle),
                  _cell('', baseStyle),
                  _cell('', baseStyle),
                  _cell('', baseStyle),
                  _cell('Accumulated Total', boldStyle,
                      align: pw.Alignment.centerRight),
                  _cell('Rs. ${_fmt(inv.subtotal)}', boldStyle,
                      align: pw.Alignment.centerRight),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 14),

          // ── Bank details ──────────────────────────────────────
          if (_hasBankDetails(inv)) ...[
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FixedColumnWidth(110),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                _bankRow('Account Holder Name:', inv.bankAccountHolder ?? '', baseStyle, boldStyle),
                _bankRow('Account Number:', inv.bankAccountNumber ?? '', baseStyle, boldStyle),
                _bankRow('Bank and Branch:', inv.bankName ?? '', baseStyle, boldStyle),
                _bankRow('IFSC:', inv.bankIfsc ?? '', baseStyle, boldStyle),
              ],
            ),
            pw.SizedBox(height: 8),
          ],

          pw.Text('Enclosed: Detailed statement with supporting documents',
              style: pw.TextStyle(
                  fontSize: 8,
                  font: pw.Font.helveticaOblique(),
                  color: PdfColors.grey600)),

          pw.SizedBox(height: 16),

          // ── Regards / submitter signature ────────────────────
          pw.Text('Regards,', style: baseStyle),
          pw.SizedBox(height: 4),
          _sigBlock(submitterSig, inv.submittedByName, inv.fromRole ?? 'Site Engineer'),

          pw.SizedBox(height: 20),

          // ── Footer: Prepared / Recommended / Approved ────────
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(children: [
                _cell('Prepared by', boldStyle),
                _cell('Recommended by', boldStyle),
                _cell('Approved by', boldStyle),
              ]),
              pw.TableRow(children: [
                _sigCell(submitterSig, inv.submittedByName, inv.fromRole ?? 'Site Engineer'),
                _sigCell(pmSig, inv.pmApprovedByName ?? '[PM Approved person name]', 'Project Manager'),
                _sigCell(financeSig, inv.financeApprovedByName ?? '[Approved person name]', 'Finance'),
              ]),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool _isTrips(String? noteType) {
    if (noteType == null) return false;
    final n = noteType.toLowerCase();
    return n.contains('trip') || n.contains('travel') || n.contains('miscellaneous');
  }

  static bool _hasBankDetails(InvoiceModel inv) =>
      (inv.bankAccountHolder?.isNotEmpty ?? false) ||
      (inv.bankAccountNumber?.isNotEmpty ?? false) ||
      (inv.bankName?.isNotEmpty ?? false) ||
      (inv.bankIfsc?.isNotEmpty ?? false);

  static pw.Widget _cell(String text, pw.TextStyle style,
      {pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Align(
        alignment: align,
        child: pw.Text(text, style: style),
      ),
    );
  }

  static pw.TableRow _bankRow(String label, String value,
      pw.TextStyle base, pw.TextStyle bold) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(label, style: bold),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(value, style: base),
      ),
    ]);
  }

  static pw.Widget _sigBlock(
      pw.MemoryImage? sig, String name, String role) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (sig != null)
          pw.Container(
            height: 50,
            width: 150,
            child: pw.Image(sig, fit: pw.BoxFit.contain),
          )
        else
          pw.Container(
            height: 50,
            width: 150,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
            ),
          ),
        pw.Text(name,
            style: pw.TextStyle(
                fontSize: 9, font: pw.Font.helveticaBold())),
        pw.Text(role,
            style: pw.TextStyle(
                fontSize: 8,
                font: pw.Font.helvetica(),
                color: PdfColors.grey600)),
      ],
    );
  }

  static pw.Widget _sigCell(
      pw.MemoryImage? sig, String name, String role) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (sig != null)
            pw.Container(
              height: 50,
              child: pw.Image(sig, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              height: 50,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
            ),
          pw.SizedBox(height: 4),
          pw.Text(name,
              style: pw.TextStyle(
                  fontSize: 8, font: pw.Font.helveticaBold())),
          pw.Text(role,
              style: pw.TextStyle(
                  fontSize: 7,
                  font: pw.Font.helvetica(),
                  color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static Future<pw.MemoryImage?> _networkImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      // Legacy base64 data URI
      const prefix = 'data:image/png;base64,';
      if (url.startsWith(prefix)) {
        return pw.MemoryImage(base64Decode(url.substring(prefix.length)));
      }
      // HTTPS signed URL — fetch bytes via HTTP
      if (url.startsWith('http')) {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) return pw.MemoryImage(res.bodyBytes);
      }
    } catch (_) {}
    return null;
  }

  static String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},');
}
