import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class RosterDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> insertOrUpdateStudent(Map<String, dynamic> student) async {
    final db = await _dbHelper.database;
    await db.insert(
      'local_roster',
      student,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<void> bulkInsertStudents(List<Map<String, dynamic>> students) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (var student in students) {
        await txn.insert(
          'local_roster',
          student,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<Map<String, dynamic>?> getStudentByCustomId(String customId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'local_roster',
      where: 'student_custom_id = ?',
      whereArgs: [customId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }
  
  Future<Map<String, dynamic>?> getStudentById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'local_roster',
      where: 'student_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    final db = await _dbHelper.database;
    return await db.query(
      'local_roster',
      where: 'first_name LIKE ? OR last_name LIKE ? OR student_custom_id LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      limit: 50,
    );
  }

  Future<void> clearRoster() async {
    final db = await _dbHelper.database;
    await db.delete('local_roster');
  }
}
