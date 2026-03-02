import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final studentHistoryProvider = Provider((ref) => StudentHistoryService());

class StudentHistoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getRecentHistory(String studentId) async {
    final fortyEightHoursAgo = DateTime.now().subtract(const Duration(hours: 48)).toUtc().toIso8601String();
    
    try {
      final response = await _supabase
          .schema('transport')
          .from('boarding_logs')
          .select()
          .eq('student_id', studentId)
          .gte('scanned_at', fortyEightHoursAgo)
          .order('scanned_at', ascending: false);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching student history for $studentId: $e');
      rethrow;
    }
  }
}
