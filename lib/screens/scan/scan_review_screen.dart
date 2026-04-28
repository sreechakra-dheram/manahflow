import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_colors.dart';
import '../../shared/widgets/section_header.dart';

class ScanReviewScreen extends StatefulWidget {
  const ScanReviewScreen({super.key});

  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  final _vendorCtrl =
      TextEditingController(text: 'Sharma Constructions');
  final _invNoCtrl =
      TextEditingController(text: 'INV-SC-2024-003');
  final _dateCtrl =
      TextEditingController(text: '17 Jan 2024');
  final _dueDateCtrl =
      TextEditingController(text: '17 Feb 2024');
  final _totalCtrl = TextEditingController(text: '5,92,500');

  final List<Map<String, TextEditingController>> _lineItems = [
    {
      'desc': TextEditingController(text: 'RCC Slab Concreting — 5th floor'),
      'qty': TextEditingController(text: '80'),
      'rate': TextEditingController(text: '4800'),
      'amount': TextEditingController(text: '3,84,000'),
    },
    {
      'desc': TextEditingController(text: 'Steel Bar Bending & Fixing'),
      'qty': TextEditingController(text: '3'),
      'rate': TextEditingController(text: '42000'),
      'amount': TextEditingController(text: '1,26,000'),
    },
    {
      'desc': TextEditingController(text: 'Shuttering & Deshuttering'),
      'qty': TextEditingController(text: '200'),
      'rate': TextEditingController(text: '412'),
      'amount': TextEditingController(text: '82,500'),
    },
  ];

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _invNoCtrl.dispose();
    _dateCtrl.dispose();
    _dueDateCtrl.dispose();
    _totalCtrl.dispose();
    for (final row in _lineItems) {
      row.values.forEach((c) => c.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // OCR success banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.statusGreenBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.statusGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.statusGreen, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'OCR extraction complete! Review and edit the fields below before submitting.',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.statusGreen,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('94% Confidence',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Invoice details form
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
                  const SectionHeader(title: 'Invoice Details'),
                  const SizedBox(height: 20),
                  LayoutBuilder(builder: (context, c) {
                    if (c.maxWidth > 500) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: _Field(
                                      label: 'Vendor Name',
                                      ctrl: _vendorCtrl)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _Field(
                                      label: 'Invoice Number',
                                      ctrl: _invNoCtrl)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                  child: _Field(
                                      label: 'Invoice Date',
                                      ctrl: _dateCtrl)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _Field(
                                      label: 'Due Date',
                                      ctrl: _dueDateCtrl)),
                            ],
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _Field(label: 'Vendor Name', ctrl: _vendorCtrl),
                        const SizedBox(height: 12),
                        _Field(label: 'Invoice Number', ctrl: _invNoCtrl),
                        const SizedBox(height: 12),
                        _Field(label: 'Invoice Date', ctrl: _dateCtrl),
                        const SizedBox(height: 12),
                        _Field(label: 'Due Date', ctrl: _dueDateCtrl),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Line items
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
                  const SectionHeader(title: 'Line Items'),
                  const SizedBox(height: 16),
                  ..._lineItems.asMap().entries.map((e) => _LineItemRow(
                        index: e.key + 1,
                        controllers: e.value,
                      )),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Line Item'),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Total
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Row(
                children: [
                  const Text('Total Amount (incl. GST)',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _totalCtrl,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        prefixText: 'Rs.  ',
                        prefixStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentBlue),
                      ),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.accentBlue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Submit for Approval'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invoice submitted for approval!'),
                          backgroundColor: AppColors.statusGreen,
                        ),
                      );
                      Future.delayed(const Duration(seconds: 1), () {
                        if (context.mounted) context.go('/invoices');
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Re-scan'),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;

  const _Field({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  final int index;
  final Map<String, TextEditingController> controllers;

  const _LineItemRow({required this.index, required this.controllers});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('#$index',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controllers['desc'],
            decoration: const InputDecoration(
                labelText: 'Description', filled: false),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controllers['qty'],
                  decoration:
                      const InputDecoration(labelText: 'Qty', filled: false),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: controllers['rate'],
                  decoration: const InputDecoration(
                      labelText: 'Rate (Rs. )', filled: false),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: controllers['amount'],
                  decoration: const InputDecoration(
                      labelText: 'Amount (Rs. )', filled: false),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
