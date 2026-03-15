import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myscannerapp/core/database/daos/roster_dao.dart';
import 'package:myscannerapp/features/scanner/domain/scanner_strategy.dart';
import 'package:myscannerapp/features/sync/sync_providers.dart';

class ManualEntryStrategy implements ScannerInputStrategy {
  @override
  Widget buildInputWidget(BuildContext context, Function(String, {String? forcedStatus}) onScanned) {
    return ManualSearchWidget(onScanned: onScanned);
  }

  @override
  void onActivate() {}

  @override
  void onDeactivate() {}

  @override
  String get label => 'Manual';

  @override
  IconData get icon => Icons.keyboard;
}

class ManualSearchWidget extends ConsumerStatefulWidget {
  final Function(String, {String? forcedStatus}) onScanned;

  const ManualSearchWidget({super.key, required this.onScanned});

  @override
  ConsumerState<ManualSearchWidget> createState() => _ManualSearchWidgetState();
}

class _ManualSearchWidgetState extends ConsumerState<ManualSearchWidget> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    // Pre-populate students on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllStudents();
    });
  }
  
  void _loadAllStudents() async {
    final dao = ref.read(rosterDaoProvider);
    final results = await dao.getAllStudents();
    _sortAndDisplay(results);
  }

  void _search(String query) async {
    if (query.isEmpty) {
      _loadAllStudents();
      return;
    }
    final dao = ref.read(rosterDaoProvider);
    final results = await dao.searchStudents(query);
    _sortAndDisplay(results);
  }

  void _sortAndDisplay(List<Map<String, dynamic>> results) {
    // Sort by stop sequence (numerical order of the route)
    final sorted = List<Map<String, dynamic>>.from(results);
    sorted.sort((a, b) {
      final seqA = a['pickup_stop_sequence'] as int? ?? 999;
      final seqB = b['pickup_stop_sequence'] as int? ?? 999;
      
      if (seqA != seqB) {
        return seqA.compareTo(seqB);
      }
      
      // Secondary sort by name
      final nameA = '${a['first_name']} ${a['last_name']}';
      final nameB = '${b['first_name']} ${b['last_name']}';
      return nameA.compareTo(nameB);
    });

    if (mounted) {
      setState(() => _searchResults = sorted);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for roster updates (e.g. from RouteConfigPage download)
    ref.listen<int>(rosterUpdateProvider, (previous, next) {
      if (next > 0) {
        _loadAllStudents();
      }
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Search by Name or ID',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  _search('');
                },
              ),
            ),
            onChanged: _search,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final student = _searchResults[index];
              return ListTile(
                leading: CircleAvatar(
                  // Show local photo if available, else initial
                  backgroundImage: student['local_image_path'] != null 
                    ? FileImage(File(student['local_image_path'])) as ImageProvider
                    : null,
                  child: student['local_image_path'] == null 
                    ? Text(student['first_name'][0]) 
                    : null,
                ),
                title: Text('${student['first_name']} ${student['last_name']}'),
                subtitle: Text(
                  student['student_custom_id'] != null 
                    ? 'ID: ${student['student_custom_id']} | Grade: ${student['grade']} | Stop: ${student['pickup_stop_name'] ?? 'N/A'}'
                    : 'Role: ${student['grade']} | Stop: ${student['pickup_stop_name'] ?? 'N/A'}'
                ),
                onTap: () async {
                  final syncDao = ref.read(syncDaoProvider);
                  final lastLog = await syncDao.getLastLogForStudent(student['student_id'].toString());
                  final isCurrentlyOnboarded = lastLog != null && lastLog['status'] == 'onboarded';
                  
                  if (mounted) {
                    _showActionSheet(context, student, isCurrentlyOnboarded);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showActionSheet(BuildContext context, Map<String, dynamic> student, bool isCurrentlyOnboarded) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${student['first_name']} ${student['last_name']}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (student['student_custom_id'] != null)
                Text('ID: ${student['student_custom_id']}')
              else
                Text('Role: ${student['grade']}'),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (!isCurrentlyOnboarded)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onScanned(student['student_id'].toString(), forcedStatus: 'onboarded');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.login),
                        label: const Text('BOARD'),
                      ),
                    ),
                  if (isCurrentlyOnboarded)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                           Navigator.pop(context);
                           widget.onScanned(student['student_id'].toString(), forcedStatus: 'offboarded');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                           padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text('DEBOARD'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
