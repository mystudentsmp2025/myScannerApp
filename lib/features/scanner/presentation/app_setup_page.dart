import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myscannerapp/core/supabase_service.dart';
import 'package:myscannerapp/features/scanner/presentation/scanner_dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSetupPage extends ConsumerStatefulWidget {
  const AppSetupPage({super.key});

  @override
  ConsumerState<AppSetupPage> createState() => _AppSetupPageState();
}

class _AppSetupPageState extends ConsumerState<AppSetupPage> {
  final _schoolCodeController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _schoolCodeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final schoolCode = _schoolCodeController.text.trim();
    final pin = _pinController.text.trim();
    
    if (schoolCode.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid School Code');
      return;
    }
    
    if (pin.isEmpty || pin.length < 4) {
      setState(() => _errorMessage = 'Please enter a valid 4-digit Bus PIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Verify School Code (branch_code)
      final schoolResponse = await SupabaseService.client
          .schema('school_shared')
          .from('schools')
          .select('id')
          .eq('branch_code', schoolCode)
          .maybeSingle();

      if (schoolResponse == null) {
        setState(() {
          _errorMessage = 'Invalid School Code. Please check and try again.';
          _isLoading = false;
        });
        return;
      }

      final resolvedSchoolId = schoolResponse['id'];

      // 2. Query the school_shared.buses table for the matching PIN & School
      final response = await SupabaseService.client
          .schema('school_shared')
          .from('buses')
          .select('id, school_id, bus_number')
          .eq('myscannerapp_pin', pin)
          .eq('school_id', resolvedSchoolId)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _errorMessage = 'Invalid Bus PIN for this school. Please check and try again.';
          _isLoading = false;
        });
        return;
      }

      // PIN is valid, extract ids
      final busId = response['id'];
      final schoolId = response['school_id'];
      final busNumber = response['bus_number'];

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('school_id', schoolId);
      await prefs.setString('bus_id', busId);
      await prefs.setString('bus_number', busNumber);

      if (!mounted) return;

      // Navigate to Scanner Dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ScannerDashboardPage()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error verifying details: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.directions_bus,
                size: 80,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 24),
              Text(
                'Device Setup',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the School Code and 4-digit Bus PIN provided by your administrator to configure this device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
              const SizedBox(height: 32),
              
              const Text('School Code', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const SizedBox(height: 8),
              TextField(
                controller: _schoolCodeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'e.g. SCH-001',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
              const SizedBox(height: 24),
              
              const Text('Bus PIN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const SizedBox(height: 8),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, letterSpacing: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '0000',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  errorText: _errorMessage, // Display error text at the bottom
                ),
                onChanged: (val) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _verifyPin,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verify & Proceed',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
