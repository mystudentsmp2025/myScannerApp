import 'package:myscannerapp/core/database/daos/roster_dao.dart';
import 'package:myscannerapp/core/database/daos/sync_dao.dart';
import 'package:myscannerapp/features/sync/log_sync_service.dart';
import 'package:uuid/uuid.dart';

enum ScanStatus {
  success,
  studentNotFound,
  duplicateScan, // If needed in future logic
}

class ScanResult {
  final ScanStatus status;
  final Map<String, dynamic>? student;
  final String? message;
  final String boardingStatus; // 'onboarded' or 'offboarded'

  ScanResult({
    required this.status,
    this.student,
    this.message,
    required this.boardingStatus,
  });
}

class ScannerRepository {
  final RosterDao _rosterDao;
  final SyncDao _syncDao;
  final LogSyncService _logSyncService;

  ScannerRepository(this._rosterDao, this._syncDao, this._logSyncService);

  Future<ScanResult> processScan({
    required String code, 
    required double? latitude, 
    required double? longitude,
    String? forcedStatus,
  }) async {
    // 1. Look up student in local roster
    // Try by student_id or custom_id
    var student = await _rosterDao.getStudentByCustomId(code);
    if (student == null) {
      // Fallback: Code might be the UUID itself (QR)
      student = await _rosterDao.getStudentById(code);
    }

    if (student == null) {
      return ScanResult(
        status: ScanStatus.studentNotFound,
        message: 'Student not found for code: $code',
        boardingStatus: 'unknown',
      );
    }

    // 2. Determine Logic (Onboard vs Offboard)
    final lastLog = await _syncDao.getLastLogForStudent(student['student_id']);
    
    // Prevent double scan (debounce 5 seconds)
    if (lastLog != null) {
      final lastTime = DateTime.parse(lastLog['scanned_at']);
      if (DateTime.now().difference(lastTime).inSeconds < 5) {
         return ScanResult(
          status: ScanStatus.duplicateScan,
          message: 'Already scanned just now',
          boardingStatus: lastLog['status'],
          student: student,
        );
      }
    }

    // Toggle Status
    String status = forcedStatus ?? 'onboarded';
    
    if (forcedStatus == null) {
      if (lastLog != null && lastLog['status'] == 'onboarded') {
        status = 'offboarded';
      }
    }

    // 3. Create Log Entry
    final log = {
      'student_id': student['student_id'],
      'parent_user_id': student['parent_user_id'],
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'scanned_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
    };

    // 4. Save to Offline DB
    await _syncDao.insertPendingLog(log);

    // 5. Trigger Backup Sync (Fire and Forget)
    // We don't await this so UI is snappy
    _logSyncService.syncPendingLogs();

    return ScanResult(
      status: ScanStatus.success,
      student: student,
      boardingStatus: status,
    );
  }
}
