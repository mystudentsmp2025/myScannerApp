import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myscannerapp/features/scanner/data/scanner_repository.dart';
import 'package:myscannerapp/features/sync/sync_providers.dart';

final scannerRepositoryProvider = Provider<ScannerRepository>((ref) {
  return ScannerRepository(
    ref.watch(rosterDaoProvider),
    ref.watch(syncDaoProvider),
    ref.watch(logSyncServiceProvider),
  );
});
