import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myscannerapp/core/database/daos/sync_dao.dart';

class LogSyncService {
  final SupabaseClient _supabase;
  final SyncDao _syncDao;

  LogSyncService(this._supabase, this._syncDao);

  Future<void> syncPendingLogs() async {
    print('Starting sync cycle...');
    final pendingLogs = await _syncDao.getPendingLogs();

    if (pendingLogs.isEmpty) return;

    for (var log in pendingLogs) {
      final logId = log['id'] as int;
      
      try {
        await _syncDao.updateSyncStatus(logId, 'syncing');

        // Insert into Supabase transport.boarding_logs
        final payload = {
          'student_id': log['student_id'],
          'parent_user_id': log['parent_user_id'],
          'status': log['status'],
          // Send separate lat/long as requested by new schema
          'latitude': log['latitude'],
          'longitude': log['longitude'],
          // 'location': ... (Removed in favor of explicit columns)
          'scanned_at': log['scanned_at'],
        };
        print('Syncing payload: $payload');

        await _supabase.schema('transport').from('boarding_logs').insert(payload);

        // If successful, mark as synced (don't delete, so they show in Recent Activity)
        await _syncDao.updateSyncStatus(logId, 'synced');
        
      } catch (e) {
        print('CRITICAL SYNC ERROR for log $logId: $e');
        if (e is PostgrestException) {
          print('Supabase Error Code: ${e.code}');
          print('Supabase Error Message: ${e.message}');
          print('Supabase Error Details: ${e.details}');
        }
        await _syncDao.updateSyncStatus(logId, 'failed');
        // Optional: Increment retry count
      }
    }
  }
}
