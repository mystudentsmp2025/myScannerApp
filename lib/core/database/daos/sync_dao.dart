import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class SyncDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertPendingLog(Map<String, dynamic> log) async {
    final db = await _dbHelper.database;
    return await db.insert('pending_sync', log);
  }

  Future<List<Map<String, dynamic>>> getPendingLogs() async {
    final db = await _dbHelper.database;
    return await db.query(
      'pending_sync',
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'scanned_at ASC',
    );
  }

  Future<void> updateSyncStatus(int id, String status) async {
    final db = await _dbHelper.database;
    await db.update(
      'pending_sync',
      {'sync_status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteLog(int id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'pending_sync',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<int> getPendingCount() async {
    final db = await _dbHelper.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM pending_sync WHERE sync_status != "synced"')) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getRecentLogsWithNames({int limit = 10}) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        l.id,
        l.student_id,
        l.status as boarding_status,
        l.scanned_at,
        l.sync_status,
        r.first_name,
        r.last_name,
        r.student_custom_id,
        r.grade,
        r.local_image_path
      FROM pending_sync l
      LEFT JOIN local_roster r ON l.student_id = r.student_id
      ORDER BY l.scanned_at DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<Map<String, dynamic>?> getLastLogForStudent(String studentId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'pending_sync',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'scanned_at DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> deleteLogsOlderThan(DateTime date) async {
    final db = await _dbHelper.database;
    await db.delete(
      'pending_sync',
      where: 'scanned_at < ?',
      whereArgs: [date.toIso8601String()],
    );
  }

  Future<int> getStudentsOnBusCount() async {
    final db = await _dbHelper.database;
    // We need to find the latest status for each student today
    // and count how many are 'onboarded'
    
    // Group by student_id, get the max scanned_at for each, then check if that status is 'onboarded'
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT COUNT(*) as current_onboard_count
      FROM (
        SELECT student_id, status
        FROM pending_sync
        WHERE id IN (
          SELECT id
          FROM pending_sync
          GROUP BY student_id
          HAVING scanned_at = MAX(scanned_at)
        )
      ) current_status
      WHERE current_status.status = 'onboarded'
    ''');
    
    if (result.isNotEmpty) {
      return Sqflite.firstIntValue(result) ?? 0;
    }
    return 0;
  }

  Future<List<String>> getOnboardedPassengerIds() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT student_id
      FROM (
        SELECT student_id, status
        FROM pending_sync
        WHERE id IN (
          SELECT id
          FROM pending_sync
          GROUP BY student_id
          HAVING scanned_at = MAX(scanned_at)
        )
      ) current_status
      WHERE current_status.status = 'onboarded'
    ''');
    
    return result.map((row) => row['student_id'] as String).toList();
  }
}
