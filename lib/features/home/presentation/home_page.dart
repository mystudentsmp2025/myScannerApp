import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Scanner App'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
           // Basic responsive logic: check width to determine if it's a tablet or phone
           // For now, we just display center text
           return Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Icon(Icons.qr_code_scanner, size: 100, color: Colors.deepPurple),
                 const SizedBox(height: 20),
                 Text(
                   'Ready to Scan',
                   style: Theme.of(context).textTheme.headlineMedium,
                 ),
                 // Placeholder for actual scanner integration
               ],
             ),
           );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to scanner or trigger scan
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Scanner implementation pending')),
          );
        },
        label: const Text('Scan Now'),
        icon: const Icon(Icons.camera_alt),
      ),
    );
  }
}
