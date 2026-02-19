import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myscannerapp/features/sync/sync_providers.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();
  final Ref _ref;
  StreamSubscription? _subscription;
  Timer? _periodicSyncTimer;

  NetworkService(this._ref) {
    _init();
  }

  void _init() {
    // 1. Check current status immediately
    _checkInitialConnection();

    // 2. Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });

    // 3. Periodic Safety Sync (Every 5 minutes)
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final results = await _connectivity.checkConnectivity();
      if (results.contains(ConnectivityResult.none)) return;
      
      print('NetworkService: Periodic sync check...');
      _triggerSync();
    });
  }

  Future<void> _checkInitialConnection() async {
    final results = await _connectivity.checkConnectivity();
    _handleConnectivityChange(results);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.mobile) || 
        results.contains(ConnectivityResult.wifi) || 
        results.contains(ConnectivityResult.ethernet)) {
      print('NetworkService: Online (${results.first}). Triggering sync...');
      _triggerSync();
    } else {
      print('NetworkService: Offline');
    }
  }

  Future<void> _triggerSync() async {
    try {
      await _ref.read(logSyncServiceProvider).syncPendingLogs();
    } catch (e) {
      print('NetworkService: Sync failed - $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _periodicSyncTimer?.cancel();
  }
}

// Provider
final networkServiceProvider = Provider<NetworkService>((ref) {
  return NetworkService(ref);
});
