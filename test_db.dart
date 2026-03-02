import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://jqpahjeymfukkzwiapog.supabase.co/rest/v1';
  final key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxcGFoamV5bWZ1a2t6d2lhcG9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3ODIyODYsImV4cCI6MjA4MDM1ODI4Nn0.ioT-QXhteUcgpSVH_ZjSPGxWPfJqgACO3HbXYgjsTIc';
  
  final headers = {
    'apikey': key,
    'Authorization': 'Bearer \$key',
    'Accept-Profile': 'transport',
  };

  print('Fetching boarding logs...');
  final logRes = await http.get(Uri.parse('\$url/boarding_logs?select=*&order=scanned_at.desc&limit=3'), headers: headers);
  final logs = jsonDecode(logRes.body) as List;
  
  for (var log in logs) {
    print('-----------------');
    print('Log ID: \${log['id']}');
    print('Student ID: \${log['student_id']}');
    print('Parent ID on log: \${log['parent_user_id']}');
    print('Status: \${log['status']}');
    print('Stop Name processed: \${log['stop_name']}');
    
    // Check roster view
    final rosterRes = await http.get(
      Uri.parse('\$url/roster_view?select=first_name,last_name,parent_user_id&student_id=eq.\${log['student_id']}'), 
      headers: headers
    );
    print('Roster Data: \${rosterRes.body}');
  }

  print('\nFetching recent notifications queue directly...');
  final pubHeaders = {
    'apikey': key,
    'Authorization': 'Bearer \$key',
    'Accept-Profile': 'public',
  };
  
  final queueRes = await http.get(Uri.parse('\$url/notifications_queue?select=*&order=created_at.desc&limit=3'), headers: pubHeaders);
  print('Queue: \${queueRes.body}');
}
