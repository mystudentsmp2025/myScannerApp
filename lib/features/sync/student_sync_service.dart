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

  Future<List<Map<String, dynamic>>> getRoutes(String schoolId, String busId) async {
    try {
      print('--- FETCHING ROUTES DEBUG ---');
      print('Input schoolId: $schoolId');
      print('Input busId: $busId');
      
      // Find the routes currently assigned to this specific bus via bus_assignments
      final response = await _supabase
          .schema('school_shared')
          .from('bus_assignments')
          .select('route_id, bus_routes(id, route_name, route_number)')
          .eq('bus_id', busId);
          
      print('Raw Bus Assignments Response: $response');

      // Extract unique routes from the assignments
      final Set<String> seenRouteIds = {};
      final List<Map<String, dynamic>> routes = [];

      for (var row in response) {
        final routeData = row['bus_routes'];
        if (routeData != null) {
          final id = routeData['id'].toString();
          if (!seenRouteIds.contains(id)) {
            seenRouteIds.add(id);
            routes.add(Map<String, dynamic>.from(routeData));
          }
        } else {
          print('Warning: Row has no bus_routes data: $row');
        }
      }

      print('Filtered Routes: $routes');
      routes.sort((a, b) => (a['route_name'] ?? '').compareTo(b['route_name'] ?? ''));
      return routes;
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
             await _dio.download(photoUrl, localPath);
             student['local_image_path'] = localPath;
          } catch (e) {
            if (e is DioException && (e.response?.statusCode == 400 || e.response?.statusCode == 404)) {
              // Expected if the student doesn't have a photo uploaded to the bucket yet
            } else {
              print('Failed to download photo for ${student['student_id']}: $e');
            }
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
