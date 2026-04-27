import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_colors.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  late AnimationController _lineCtrl;
  late Animation<double> _lineAnim;

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _lineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    super.dispose();
  }

  void _capture() {
    setState(() => _isProcessing = true);
    Timer(const Duration(seconds: 2), () {
      if (mounted) context.push('/scan/review');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Scan Invoice',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Position the invoice within the frame',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              // Viewfinder
              AspectRatio(
                aspectRatio: 3 / 4,
                child: Stack(
                  children: [
                    // Dark background
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    // Corner guides
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CornerGuidesPainter(),
                      ),
                    ),
                    // Scanning line
                    if (!_isProcessing)
                      AnimatedBuilder(
                        animation: _lineAnim,
                        builder: (_, __) => Positioned(
                          left: 20,
                          right: 20,
                          top: 20 +
                              (_lineAnim.value *
                                  (MediaQuery.of(context).size.height *
                                          0.4 -
                                      40)),
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.accentBlue,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Processing overlay
                    if (_isProcessing)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: AppColors.accentBlue,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Processing OCR…',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Extracting invoice data',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Center label
                    if (!_isProcessing)
                      const Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Place invoice within this frame',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Capture button
              GestureDetector(
                onTap: _isProcessing ? null : _capture,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isProcessing ? Colors.grey.shade300 : Colors.white,
                    border: Border.all(
                        color: _isProcessing
                            ? Colors.grey
                            : AppColors.accentBlue,
                        width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentBlue.withOpacity(0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isProcessing
                            ? Colors.grey
                            : AppColors.accentBlue,
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Tap to capture',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: const Text('Upload from Files'),
                onPressed: _isProcessing ? null : _capture,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerGuidesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentBlue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const len = 28.0;
    const margin = 16.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(margin, margin + len)
        ..lineTo(margin, margin)
        ..lineTo(margin + len, margin),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - margin - len, margin)
        ..lineTo(size.width - margin, margin)
        ..lineTo(size.width - margin, margin + len),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(margin, size.height - margin - len)
        ..lineTo(margin, size.height - margin)
        ..lineTo(margin + len, size.height - margin),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - margin - len, size.height - margin)
        ..lineTo(size.width - margin, size.height - margin)
        ..lineTo(size.width - margin, size.height - margin - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
