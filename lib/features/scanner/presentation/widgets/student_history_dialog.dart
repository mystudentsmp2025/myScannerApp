import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:myscannerapp/features/scanner/domain/student_history_service.dart';

class StudentHistoryDialog extends ConsumerWidget {
  final String studentId;
  final String firstName;
  final String lastName;

  const StudentHistoryDialog({
    super.key,
    required this.studentId,
    required this.firstName,
    required this.lastName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(studentHistoryProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.history, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$firstName $lastName',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Text('Last 48 Hours', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 30),
            
            // Loading and List View
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: service.getRecentHistory(studentId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load history:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final logs = snapshot.data ?? [];
                  
                  if (logs.isEmpty) {
                    return const Center(
                      child: Text('No activity found in the last 48 hours.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isBoarding = log['status'] == 'onboarded';
                      final time = DateTime.parse(log['scanned_at']).toLocal();
                      final stopName = log['stop_name'] ?? 'Unknown Stop';
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isBoarding ? Colors.green.shade50 : Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isBoarding ? Icons.login : Icons.logout,
                              color: isBoarding ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            isBoarding ? 'Boarded Bus' : 'Deboarded Bus',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isBoarding ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(stopName, style: const TextStyle(fontSize: 13))),
                                ],
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                DateFormat('MMM d').format(time),
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                              ),
                              Text(
                                DateFormat('h:mm a').format(time),
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
