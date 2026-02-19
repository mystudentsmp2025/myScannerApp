import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myscannerapp/features/scanner/domain/scanner_strategy.dart';

class RfidScannerStrategy implements ScannerInputStrategy {
  final FocusNode _focusNode = FocusNode();
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastScanTime;
  static const Duration _debounceDuration = Duration(seconds: 2);

  @override
  String get label => 'RFID Reader';

  @override
  IconData get icon => Icons.nfc;

  @override
  void onActivate() {
    _focusNode.requestFocus();
  }

  @override
  void onDeactivate() {
    _focusNode.unfocus();
  }

  @override
  Widget buildInputWidget(BuildContext context, Function(String, {String? forcedStatus}) onScanned) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          final keyLabel = event.logicalKey.keyLabel;

          if (event.logicalKey == LogicalKeyboardKey.enter) {
            _processBuffer(onScanned);
          } else if (keyLabel.length == 1) {
             // Only append printable characters
            _buffer.write(keyLabel);
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          // Re-claim focus if user taps
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        },
        child: Container(
          color: Colors.blueGrey.shade900,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_tethering, size: 80, color: Colors.white70),
              const SizedBox(height: 20),
              const Text(
                'Ready to Scan',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tap card on reader',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 30),
              // Hidden TextField to ensure soft keyboard doesn't pop up unnecessarily but focus is kept? 
              // Actually KeyboardListener is better for HID. 
              // We add a visual indicator if focus is lost.
              AnimatedBuilder(
                animation: _focusNode,
                builder: (context, child) {
                  return _focusNode.hasFocus 
                    ? const SizedBox.shrink()
                    : const Text(
                        'Tap here to enable reader',
                        style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                      );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _processBuffer(Function(String, {String? forcedStatus}) onScanned) {
    final code = _buffer.toString().trim();
    _buffer.clear();

    if (code.isEmpty) return;

    // Debounce
    final now = DateTime.now();
    if (_lastScanTime != null && now.difference(_lastScanTime!) < _debounceDuration) {
       // Debounced
       return;
    }
    _lastScanTime = now;

    print('RFID Handler Scanned: $code');
    onScanned(code);
  }
}
