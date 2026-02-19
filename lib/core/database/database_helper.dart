import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'myscannerapp.db');
    
    return await openDatabase(
      path,
      version: 2, // Incremented version
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Local Roster Table
    await db.execute('''
      CREATE TABLE local_roster (
        student_id TEXT PRIMARY KEY,
        student_custom_id TEXT,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        grade TEXT,
        section TEXT,
        photo_url TEXT,
        local_image_path TEXT,
        
        route_id TEXT,
        route_name TEXT,
        bus_number TEXT,
        bus_id TEXT, -- Added column
        driver_name TEXT,
        driver_mobile TEXT,
        
        pickup_stop_id TEXT,
        pickup_stop_name TEXT,
        pickup_location TEXT,
        pickup_time TEXT,
        drop_stop_id TEXT,
        drop_stop_name TEXT,
        drop_location TEXT,
        drop_time TEXT,
        
        parent_user_id TEXT,
        parent_mobile TEXT,
        
        last_updated INTEGER
      )
    ''');

    // Pending Sync Table
    await db.execute('''
      CREATE TABLE pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL,
        parent_user_id TEXT,
        status TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        scanned_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0
      )
    ''');
  }

  // Migration Logic
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Add bus_id to local_roster
      try {
        await db.execute('ALTER TABLE local_roster ADD COLUMN bus_id TEXT');
      } catch (e) {
        // Find a way to check if column exists or ignore error?
        // Basic try/catch for "duplicate column name"
        print('Migration Info: bus_id might already exist or error: $e');
      }

      // 2. Ensure latitude/longitude in pending_sync (Safe add)
      try {
        await db.execute('ALTER TABLE pending_sync ADD COLUMN latitude REAL');
      } catch (_) {}
      
      try {
        await db.execute('ALTER TABLE pending_sync ADD COLUMN longitude REAL');
      } catch (_) {}
    }
  }
}
