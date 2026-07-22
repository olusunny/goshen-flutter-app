import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PrayerSessionAttendanceQrScanner extends StatefulWidget {
  const PrayerSessionAttendanceQrScanner({super.key, required this.title});

  final String title;

  @override
  State<PrayerSessionAttendanceQrScanner> createState() =>
      _PrayerSessionAttendanceQrScannerState();
}

class _PrayerSessionAttendanceQrScannerState
    extends State<PrayerSessionAttendanceQrScanner> {
  late final MobileScannerController _controller;
  bool _handled = false;
  bool _cameraUnavailable = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  Future<void> _retryCamera() async {
    setState(() => _cameraUnavailable = false);
    try {
      await _controller.start();
    } catch (_) {
      if (mounted) setState(() => _cameraUnavailable = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Stack(
          children: [
            if (!_cameraUnavailable)
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _cameraUnavailable = true);
                  });
                  return const SizedBox.shrink();
                },
              ),
            if (_cameraUnavailable)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera access is needed to scan the QR code. Allow camera access in your phone settings, then try again.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _retryCamera,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try camera again'),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_cameraUnavailable)
              const Positioned(
                left: 24,
                right: 24,
                bottom: 36,
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Allow camera access, then hold the QR code inside the frame.',
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
