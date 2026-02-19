import 'package:flutter/material.dart';
import 'package:myscannerapp/core/supabase_service.dart';
import 'package:myscannerapp/features/home/presentation/home_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myscannerapp/features/scanner/presentation/scanner_dashboard_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Scanner App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      home: ScannerDashboardPage(),
    );
  }
}
