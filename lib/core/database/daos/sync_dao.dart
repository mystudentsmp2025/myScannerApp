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
}
