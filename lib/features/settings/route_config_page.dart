import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myscannerapp/features/sync/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myscannerapp/features/scanner/presentation/app_setup_page.dart';

class RouteConfigPage extends ConsumerStatefulWidget {
  const RouteConfigPage({super.key});

  @override
  ConsumerState<RouteConfigPage> createState() => _RouteConfigPageState();
}

class _RouteConfigPageState extends ConsumerState<RouteConfigPage> {
  String? _selectedRouteId;
  String? _selectedRouteName;
  bool _isLoading = false;
  bool _isFetchingRoutes = true;
  List<Map<String, dynamic>> _routes = [];

  @override
  void initState() {
    super.initState();
    _loadSavedRoute();
    _fetchRoutes();
  }

  Future<void> _loadSavedRoute() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedRouteId = prefs.getString('route_id');
      _selectedRouteName = prefs.getString('route_name');
    });
  }

  Future<void> _fetchRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final schoolId = prefs.getString('school_id');
      final busId = prefs.getString('bus_id');

      if (schoolId == null || busId == null) {
        throw Exception('Device is not configured with a School or Bus ID.');
      }

      final routes = await ref.read(studentSyncServiceProvider).getRoutes(schoolId, busId);
      setState(() {
        _routes = routes;
        _isFetchingRoutes = false;
      });
      
      // If saved route exists but not in list (rare), we still keep ID but maybe can't show name in dropdown if not found
      // Check if selected ID is in list
      if (_selectedRouteId != null) {
        final exists = _routes.any((r) => r['id'] == _selectedRouteId);
        if (!exists) {
          // If not found in list, maybe keep it or clear it? 
          // Let's keep it but user might need to re-select
        }
      }
    } catch (e) {
      setState(() {
        _isFetchingRoutes = false;
        _errorMessage = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load routes: $e')),
        );
      }
    }
  }

  String? _errorMessage;

  Future<void> _saveAndDownload() async {
    if (_selectedRouteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a route')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Save to Prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('route_id', _selectedRouteId!);
      // Find name
      final route = _routes.firstWhere((r) => r['id'] == _selectedRouteId, orElse: () => {});
      if (route.isNotEmpty) {
        await prefs.setString('route_name', route['route_name']);
      }

      // 2. Trigger Sync
      final syncService = ref.read(studentSyncServiceProvider);
      await syncService.syncRoster(_selectedRouteId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Roster downloaded successfully!')),
        );
        Navigator.of(context).pop(); // Go back to dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Configuration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Select the Route assigned to this device to download the student roster.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            if (_isFetchingRoutes)
              const CircularProgressIndicator()
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
              )
            else if (_routes.isEmpty)
              const Text('No routes found in school_shared.bus_routes.')
            else
              DropdownButtonFormField<String>(
                value: _favoritesContains(_selectedRouteId) ? _selectedRouteId : null,
                decoration: const InputDecoration(
                  labelText: 'Select Route',
                  border: OutlineInputBorder(),
                ),
                items: _routes.map((route) {
                  return DropdownMenuItem<String>(
                    value: route['id'],
                    child: Text(
                      '${route['route_name']} (${route['route_number'] ?? 'N/A'})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRouteId = value;
                  });
                },
              ),

            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _saveAndDownload,
                icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                    : const Icon(Icons.download),
                label: Text(_isLoading ? 'Downloading...' : 'Download Roster'),
              ),
            ),
            
            if (_selectedRouteId != null) ...[
               const SizedBox(height: 20),
               Text('Selected ID: $_selectedRouteId', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],

            const Spacer(),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Need to switch to a different bus?',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Confirm dialog
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Re-configure Device?'),
                      content: const Text('This will clear the current school and bus association. You will need to enter a School Code and Bus PIN again.\n\nAre you sure?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true), 
                          child: const Text('Proceed')
                        ),
                      ],
                    )
                  );

                  if (confirm == true) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear(); // Clear all saved device data
                    
                    if (!mounted) return;

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AppSetupPage()),
                      (route) => false, // Remove all previous routes
                    );
                  }
                },
                icon: const Icon(Icons.phonelink_setup),
                label: const Text('Re-configure Device'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  bool _favoritesContains(String? id) {
    if (id == null) return false;
    return _routes.any((element) => element['id'] == id);
  }
}
