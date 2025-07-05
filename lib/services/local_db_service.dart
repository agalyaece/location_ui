// lib/services/local_db_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

// Data model for local storage
class LocalLocation {
  final int? id; // Primary key, auto-incremented by SQLite
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LocalLocation({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  // Convert a LocalLocation object into a Map object
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(), // Store as ISO string
    };
  }

  // Convert a Map object into a LocalLocation object
  factory LocalLocation.fromMap(Map<String, dynamic> map) {
    return LocalLocation(
      id: map['id'] as int?,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}

class LocalDbService {
  static Database? _database; // Private static instance of the database

  // Getter to provide the database instance, initializing if necessary
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb(); // Initialize the database
    return _database!;
  }

  // Initializes the database
  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'location_tracker.db'); // Database file name

    return await openDatabase(
      path,
      version: 1, // Database version
      onCreate: (db, version) async {
        // Create the 'locations' table
        await db.execute('''
          CREATE TABLE locations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Insert a new location into the database
  Future<void> insertLocation(LocalLocation location) async {
    final db = await database;
    await db.insert(
      'locations', // Table name
      location.toMap(), // Location data as a Map
      conflictAlgorithm: ConflictAlgorithm.replace, // Replace if id exists
    );
    print('Location saved to local DB: ${location.latitude}, ${location.longitude}');
  }

  // Retrieve all pending locations from the database
  Future<List<LocalLocation>> getPendingLocations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('locations', orderBy: 'timestamp ASC'); // Order oldest first
    return List.generate(maps.length, (i) {
      return LocalLocation.fromMap(maps[i]);
    });
  }

  // Delete a location by its ID after successful sync
  Future<void> deleteLocation(int id) async {
    final db = await database;
    await db.delete(
      'locations',
      where: 'id = ?',
      whereArgs: [id],
    );
    print('Location deleted from local DB: ID $id');
  }

  // Clear all locations from the database (for testing/reset)
  Future<void> clearAllLocations() async {
    final db = await database;
    await db.delete('locations');
    print('All local locations cleared.');
  }

  // Close the database (optional, usually handled by OS)
  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}