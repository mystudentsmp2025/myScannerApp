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
          // Expose a clean testing dialog since true HID keyboards don't show soft keyboards
          showDialog(
            context: context,
            builder: (ctx) {
              final testController = TextEditingController();
              return AlertDialog(
                title: const Text('Simulate RFID Scan'),
                content: TextField(
                  controller: testController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter student code (e.g. MOCK-S-13)',
                  ),
                  onSubmitted: (val) {
                    Navigator.pop(ctx);
                    if (val.trim().isNotEmpty) {
                      onScanned(val.trim());
                    }
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final val = testController.text.trim();
                      if (val.isNotEmpty) {
                        onScanned(val);
                      }
                    },
                    child: const Text('Simulate'),
                  ),
                ],
              );
            },
          ).then((_) {
            // Re-claim true hardware focus after dialog closes
            if (!_focusNode.hasFocus) {
              _focusNode.requestFocus();
            }
          });
        },
        child: Container(
          color: Colors.blueGrey.shade900,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.wifi_tethering, size: 80, color: Colors.white70),
              SizedBox(height: 20),
              Text(
                'Ready to Scan',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Tap here to simulate a scan',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 16),
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
