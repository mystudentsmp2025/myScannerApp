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

  void _search(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final dao = ref.read(rosterDaoProvider);
    print('Searching for: $query');
    final results = await dao.searchStudents(query);
    print('Found ${results.length} results');
    setState(() => _searchResults = results);
  }

  @override
  Widget build(BuildContext context) {
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
                subtitle: Text('ID: ${student['student_custom_id']} | Grade: ${student['grade']}'),
                onTap: () {
                  _showActionSheet(context, student);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showActionSheet(BuildContext context, Map<String, dynamic> student) {
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
              Text('ID: ${student['student_custom_id']}'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onScanned(student['student_custom_id'] ?? student['student_id'], forcedStatus: 'onboarded');
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                         Navigator.pop(context);
                         widget.onScanned(student['student_custom_id'] ?? student['student_id'], forcedStatus: 'offboarded');
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
