import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myscannerapp/core/database/daos/roster_dao.dart';
import 'package:myscannerapp/core/database/daos/sync_dao.dart';
import 'package:myscannerapp/features/sync/log_sync_service.dart';
import 'package:myscannerapp/features/sync/student_sync_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final rosterDaoProvider = Provider<RosterDao>((ref) => RosterDao());
final syncDaoProvider = Provider<SyncDao>((ref) => SyncDao());

final studentSyncServiceProvider = Provider<StudentSyncService>((ref) {
  return StudentSyncService(
    ref.watch(supabaseClientProvider),
    ref.watch(rosterDaoProvider),
  );
});

final logSyncServiceProvider = Provider<LogSyncService>((ref) {
  return LogSyncService(
    ref.watch(supabaseClientProvider),
    ref.watch(syncDaoProvider),
  );
});

// Used to trigger UI refreshes when the local roster is updated
class RosterUpdateNotifier extends Notifier<int> {
  @override
  int build() => 0;
  
  void increment() => state++;
}

final rosterUpdateProvider = NotifierProvider<RosterUpdateNotifier, int>(RosterUpdateNotifier.new);
