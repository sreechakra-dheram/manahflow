import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../core/app_colors.dart';

class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key});

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final _repaintKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];

  bool get hasSignature => _strokes.isNotEmpty;

  void clear() => setState(() {
        _strokes.clear();
        _current = [];
      });

  Future<Uint8List?> toImage() async {
    try {
      final rb = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final img = await rb.toImage(pixelRatio: 2.0);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          key: _repaintKey,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) =>
                    setState(() => _current = [d.localPosition]),
                onPanUpdate: (d) =>
                    setState(() => _current.add(d.localPosition)),
                onPanEnd: (_) => setState(() {
                  if (_current.isNotEmpty) {
                    _strokes.add(List.from(_current));
                    _current = [];
                  }
                }),
                child: CustomPaint(
                  painter: _SignaturePainter(
                      strokes: _strokes, current: _current),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.draw_outlined,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              hasSignature ? 'Signature captured' : 'Draw your signature above',
              style: TextStyle(
                fontSize: 11,
                color: hasSignature
                    ? AppColors.statusGreen
                    : AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: clear,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Clear', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> current;

  _SignaturePainter({required this.strokes, required this.current});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // baseline guide
    final guide = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(16, size.height * 0.75),
        Offset(size.width - 16, size.height * 0.75),
        guide);

    final ink = Paint()
      ..color = const Color(0xFF1A237E)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void drawStroke(List<Offset> pts) {
      if (pts.length < 2) {
        if (pts.length == 1) {
          canvas.drawCircle(pts[0], 1.5, ink..style = PaintingStyle.fill);
          ink.style = PaintingStyle.stroke;
        }
        return;
      }
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, ink);
    }

    for (final s in strokes) drawStroke(s);
    if (current.isNotEmpty) drawStroke(current);
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}

/// Shows a full-screen signature capture dialog and returns PNG bytes.
Future<Uint8List?> captureSignature(BuildContext context,
    {String title = 'Sign Here'}) async {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SignatureDialog(title: title),
  );
}

class _SignatureDialog extends StatefulWidget {
  final String title;
  const _SignatureDialog({required this.title});

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  final _padKey = GlobalKey<SignaturePadState>();

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isDesktop = screenW > 800;
    return Dialog(
      insetPadding: isDesktop
          ? const EdgeInsets.symmetric(horizontal: 200, vertical: 80)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              SignaturePad(key: _padKey),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final state = _padKey.currentState;
                      if (state == null || !state.hasSignature) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please draw your signature.')),
                        );
                        return;
                      }
                      final bytes = await state.toImage();
                      if (context.mounted) Navigator.pop(context, bytes);
                    },
                    child: const Text('Confirm Signature'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
