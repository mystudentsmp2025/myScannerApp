import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myscannerapp/core/database/daos/roster_dao.dart';

class StudentSyncService {
  final SupabaseClient _supabase;
  final RosterDao _rosterDao;
  final Dio _dio;

  StudentSyncService(this._supabase, this._rosterDao) : _dio = Dio();

  Future<List<Map<String, dynamic>>> getRoutes() async {
    try {
      final response = await _supabase
          .schema('school_shared')
          .from('bus_routes')
          .select('id, route_name, route_number')
          .order('route_name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('CRITICAL ERROR fetching routes: $e');
      rethrow;
    }
  }

  Future<void> syncRoster(String routeId) async {
    try {
      // 1. Fetch roster from Supabase View
      final List<dynamic> response = await _supabase
          .schema('transport') // Query the transport schema
          .from('roster_view') 
          .select()
          .eq('route_id', routeId);
      
      // Clear existing roster to avoid stale data
      await _rosterDao.clearRoster();

      // 2. Process and Download Photos
      final List<Map<String, dynamic>> students = [];
      
      final docDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(join(docDir.path, 'student_photos'));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      print('Fetched ${response.length} students from Supabase');

      for (var row in response) {
        final student = Map<String, dynamic>.from(row);
        
        // Handle Photo Download
        if (student['photo_url'] != null) {
          final photoUrl = student['photo_url'] as String;
          final fileName = '${student['student_id']}.jpg'; // Assuming id is UUID
          final localPath = join(photosDir.path, fileName);
          
          try {
            // Check if file exists or needs update (skip complex check for now, just download)
             await _dio.download(photoUrl, localPath);
             student['local_image_path'] = localPath;
          } catch (e) {
            print('Failed to download photo for ${student['student_id']}: $e');
            // Keep previous local path if available? Or set null.
            // For now, if download fails, we might still have the record.
          }
        }
        
        // Ensure data types match SQLite schema (e.g. converting nulls if needed)
        // SQLite supports nulls, so mostly fine.
        
        // Add timestamp
        student['last_updated'] = DateTime.now().millisecondsSinceEpoch;
        
        students.add(student);
      }

      // 3. Bulk Insert into SQLite
      await _rosterDao.bulkInsertStudents(students);
      print('Synced ${students.length} students for route $routeId');

    } catch (e) {
      print('Error syncing roster: $e');
      rethrow;
    }
  }
}
