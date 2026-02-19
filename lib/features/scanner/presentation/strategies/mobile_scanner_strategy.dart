import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:myscannerapp/features/scanner/domain/scanner_strategy.dart';

class MobileScannerStrategy implements ScannerInputStrategy {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.code39],
  );

  @override
  Widget buildInputWidget(BuildContext context, Function(String, {String? forcedStatus}) onScanned) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        final List<Barcode> barcodes = capture.barcodes;
        for (final barcode in barcodes) {
          if (barcode.rawValue != null) {
            onScanned(barcode.rawValue!);
            // Simple debounce/cooldown could be added here if needed, 
            // but detectionSpeed.noDuplicates handles immediate spam.
            break; 
          }
        }
      },
    );
  }

  @override
  void onActivate() {
    _controller.start();
  }

  @override
  void onDeactivate() {
    _controller.stop();
  }

  @override
  String get label => 'Camera';

  @override
  IconData get icon => Icons.camera_alt;
}
