import 'package:flutter/material.dart';

abstract class ScannerInputStrategy {
  /// Returns the widget that renders the input method (e.g. Camera preview)
  Widget buildInputWidget(BuildContext context, Function(String, {String? forcedStatus}) onScanned);

  /// Called when this strategy is activated
  void onActivate();

  /// Called when this strategy is deactivated
  void onDeactivate();
  
  String get label;
  IconData get icon;
}
