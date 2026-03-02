import 'package:flutter/material.dart';
import 'package:myscannerapp/core/supabase_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myscannerapp/features/scanner/presentation/scanner_dashboard_page.dart';
import 'package:myscannerapp/features/scanner/presentation/app_setup_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  
  // Check if device is configured
  final prefs = await SharedPreferences.getInstance();
  final isConfigured = prefs.getString('school_id') != null && prefs.getString('bus_id') != null;

  runApp(ProviderScope(child: MyApp(isConfigured: isConfigured)));
}

class MyApp extends StatelessWidget {
  final bool isConfigured;
  const MyApp({super.key, required this.isConfigured});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Scanner App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      home: isConfigured ? const ScannerDashboardPage() : const AppSetupPage(),
    );
  }
}
