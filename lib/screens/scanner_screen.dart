import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Opens the camera and returns the first scanned barcode (or null).
Future<String?> scanBarcode(BuildContext context, {String? title}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => ScannerScreen(title: title ?? 'مسح الباركود'),
    ),
  );
}

/// Camera barcode scanner.
///
/// In single mode it pops with the scanned code. When [onScan] is provided it
/// stays open (continuous mode, used at the checkout) and reports each code.
class ScannerScreen extends StatefulWidget {
  final String title;
  final Future<String?> Function(String code)? onScan;

  const ScannerScreen({super.key, required this.title, this.onScan});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.itf2of5,
      BarcodeFormat.codabar,
      BarcodeFormat.qrCode,
    ],
  );

  String? _lastCode;
  DateTime _lastTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busy = false;
  bool _done = false;
  String? _message;
  int _count = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handle(String code) async {
    if (_busy || _done) return;
    final now = DateTime.now();
    // Ignore the same code read repeatedly while it stays in front of the lens.
    if (code == _lastCode && now.difference(_lastTime).inMilliseconds < 1800) {
      return;
    }
    _lastCode = code;
    _lastTime = now;

    if (widget.onScan == null) {
      _done = true;
      Navigator.of(context).pop(code);
      return;
    }
    _busy = true;
    final message = await widget.onScan!(code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _count++;
      _message = message;
      _lastTime = DateTime.now();
    });
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _handle(value.trim());
        return;
      }
    }
  }

  Future<void> _manualEntry() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إدخال الباركود يدويا'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'الباركود'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (code != null && code.trim().isNotEmpty) {
      _lastCode = null;
      await _handle(code.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(const Offset(0, -60)),
      width: 300,
      height: 180,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'الفلاش',
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'تبديل الكاميرا',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            tooltip: 'إدخال يدوي',
            icon: const Icon(Icons.keyboard),
            onPressed: _manualEntry,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'تعذر تشغيل الكاميرا. تأكد من منح إذن الكاميرا للتطبيق.\n'
                  '${error.errorCode.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ScanWindowPainter(scanWindow),
            ),
          ),
          if (widget.onScan != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(child: Text('$_count')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_message ?? 'وجّه الكاميرا نحو الباركود'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('إنهاء'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanWindowPainter extends CustomPainter {
  final Rect window;

  _ScanWindowPainter(this.window);

  @override
  void paint(Canvas canvas, Size size) {
    final background = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(12)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, background, hole),
      Paint()..color = Colors.black54,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(window, const Radius.circular(12)),
      Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      Offset(window.left + 12, window.center.dy),
      Offset(window.right - 12, window.center.dy),
      Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ScanWindowPainter oldDelegate) =>
      oldDelegate.window != window;
}
