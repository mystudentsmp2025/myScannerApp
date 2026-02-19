import 'dart:io';
import 'package:myscannerapp/core/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:myscannerapp/core/database/daos/sync_dao.dart';
import 'package:myscannerapp/features/scanner/data/scanner_repository.dart';
import 'package:myscannerapp/features/scanner/domain/scanner_strategy.dart';
import 'package:myscannerapp/features/scanner/presentation/scanner_providers.dart';
import 'package:myscannerapp/features/scanner/presentation/strategies/rfid_scanner_strategy.dart';
import 'package:myscannerapp/features/scanner/presentation/strategies/manual_entry_strategy.dart';
import 'package:myscannerapp/features/scanner/presentation/strategies/mobile_scanner_strategy.dart';
import 'package:myscannerapp/features/settings/route_config_page.dart';
import 'package:myscannerapp/core/network/network_service.dart';
import 'package:myscannerapp/features/sync/sync_providers.dart';

class ScannerDashboardPage extends ConsumerStatefulWidget {
  const ScannerDashboardPage({super.key});

  @override
  ConsumerState<ScannerDashboardPage> createState() => _ScannerDashboardPageState();
}

class _ScannerDashboardPageState extends ConsumerState<ScannerDashboardPage> {
  // Config
  late ScannerInputStrategy _currentStrategy;
  final List<ScannerInputStrategy> _strategies = [
    MobileScannerStrategy(),
    RfidScannerStrategy(),
    ManualEntryStrategy(),
  ];

  // Logic
  bool _isProcessing = false;
  
  @override
  void initState() {
    super.initState();
    _currentStrategy = _strategies.first; // Default to Camera
    
    // Trigger sync on startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Cleanup old logs (Keep only today's)
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      await ref.read(syncDaoProvider).deleteLogsOlderThan(startOfDay);
      
      // 2. Refresh count
      ref.invalidate(recentLogsProvider);
      ref.invalidate(pendingCountProvider);

      // 3. Sync pending
      ref.read(logSyncServiceProvider).syncPendingLogs();
    });
  }

  void _toggleStrategy() {
    setState(() {
      final index = _strategies.indexOf(_currentStrategy);
      _currentStrategy = _strategies[(index + 1) % _strategies.length];
    });
  }

  void _handleScan(String code, {String? forcedStatus}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final repo = ref.read(scannerRepositoryProvider);
      
      // Fetch Location
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      
      final result = await repo.processScan(
        code: code,
        latitude: position?.latitude,
        longitude: position?.longitude,
        forcedStatus: forcedStatus,
      );

      if (!mounted) return;

      if (result.status == ScanStatus.success) {
        _showScanResult(result);
        // Refresh the list
        ref.invalidate(recentLogsProvider);
        ref.invalidate(pendingCountProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Scan failed')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showScanResult(ScanResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScanResultDialog(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingCountProvider);
    final recentLogs = ref.watch(recentLogsProvider);
    // Keep NetworkService alive to listen for connectivity changes
    ref.watch(networkServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Scanner'),
        actions: [
          IconButton(
            icon: Icon(_currentStrategy.icon),
            onPressed: _toggleStrategy,
            tooltip: 'Switch Input Mode',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RouteConfigPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Sync Status Bar
          // 1. Sync Status Bar
          Consumer(
            builder: (context, ref, _) {
              final asyncCount = ref.watch(pendingCountProvider);
              
              return asyncCount.when(
                data: (count) {
                  final isSynced = count == 0;
                  return InkWell(
                    onTap: () {
                      if (!isSynced) {
                         ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Syncing logs...')),
                        );
                        ref.read(logSyncServiceProvider).syncPendingLogs();
                      }
                    },
                    child: Container(
                      color: isSynced ? Colors.green.shade100 : Colors.orange.shade100,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            isSynced ? Icons.check_circle : Icons.cloud_upload, 
                            size: 16, 
                            color: isSynced ? Colors.green : Colors.orange
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isSynced ? 'All logs synced' : '$count pending logs (Tap to sync)',
                            style: TextStyle(
                              color: isSynced ? Colors.green.shade800 : Colors.deepOrange
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.all(8),
                  child: const Text('Checking sync status...'),
                ),
                error: (e, _) => Container(
                  color: Colors.red.shade100,
                  padding: const EdgeInsets.all(8),
                   child: Text('Sync Status Error: $e'),
                ),
              );
            }
          ),

          // 2. Input Area (Camera or Manual)
          Expanded(
            flex: 4,
            child: Container(
              color: _currentStrategy is ManualEntryStrategy ? Colors.white : Colors.black,
              child: _currentStrategy.buildInputWidget(context, _handleScan),
            ),
          ),

          // 3. Recent Activity List
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text(
                      'Recent Activity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: recentLogs.when(
                      data: (logs) => ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder: (_,__) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final isBoarding = log['boarding_status'] == 'onboarded';
                          final time = DateTime.parse(log['scanned_at']).toLocal();
                          final file = log['local_image_path'] != null 
                              ? File(log['local_image_path']) 
                              : null;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: file != null && file.existsSync() 
                                  ? FileImage(file) 
                                  : null,
                              child: file == null ? Text(log['first_name']?[0] ?? '?') : null,
                            ),
                            title: Text('${log['first_name']} ${log['last_name']}'),
                            subtitle: Text(DateFormat('h:mm a').format(time)),
                            trailing: Icon(
                              isBoarding ? Icons.login : Icons.logout,
                              color: isBoarding ? Colors.green : Colors.red,
                            ),
                          );
                        },
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Result Dialog
class ScanResultDialog extends StatelessWidget {
  final ScanResult result;

  const ScanResultDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    // Auto-close after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) Navigator.of(context).pop();
    });

    final student = result.student!;
    final isBoarding = result.boardingStatus == 'onboarded';
    final imagePath = student['local_image_path'];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null && File(imagePath).existsSync())
              CircleAvatar(
                radius: 50,
                backgroundImage: FileImage(File(imagePath)),
              )
            else
              const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            
            const SizedBox(height: 16),
            Text(
              '${student['first_name']} ${student['last_name']}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text('${student['grade']} - ${student['section'] ?? ''}'),
            
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isBoarding ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isBoarding ? Icons.login : Icons.logout, 
                      color: isBoarding ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    isBoarding ? 'BOARDED' : 'OFFBOARDED',
                    style: TextStyle(
                      color: isBoarding ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Providers for UI
final recentLogsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dao = ref.watch(syncDaoProvider);
  return dao.getRecentLogsWithNames(limit: 50);
});

final pendingCountProvider = StreamProvider<int>((ref) async* {
  final dao = ref.watch(syncDaoProvider);
  // Initial value
  yield await dao.getPendingCount();
  
  // Poll every 5 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
    yield await dao.getPendingCount();
  }
});
