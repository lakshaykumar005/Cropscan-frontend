import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class ScanRecord {
  final int? id;
  final String imagePath;
  final String diseaseLabel;
  final double confidence;
  final double healthScore;
  final String healthStatus;
  final String severity;
  final String treatment;
  final double temperature;
  final double humidity;
  final double ndvi;
  final double weatherStress;
  final String top5Json;
  final String cafJson;
  final double? latitude;
  final double? longitude;
  final bool offline;
  final DateTime scanDate;

  ScanRecord({
    this.id,
    required this.imagePath,
    required this.diseaseLabel,
    required this.confidence,
    required this.healthScore,
    required this.healthStatus,
    required this.severity,
    required this.treatment,
    required this.temperature,
    required this.humidity,
    required this.ndvi,
    required this.weatherStress,
    required this.top5Json,
    required this.cafJson,
    this.latitude,
    this.longitude,
    required this.offline,
    required this.scanDate,
  });

  Map<String, dynamic> toMap() => {
    'imagePath': imagePath,
    'diseaseLabel': diseaseLabel,
    'confidence': confidence,
    'healthScore': healthScore,
    'healthStatus': healthStatus,
    'severity': severity,
    'treatment': treatment,
    'temperature': temperature,
    'humidity': humidity,
    'ndvi': ndvi,
    'weatherStress': weatherStress,
    'top5Json': top5Json,
    'cafJson': cafJson,
    'latitude': latitude,
    'longitude': longitude,
    'offline': offline ? 1 : 0,
    'scanDate': scanDate.toIso8601String(),
  };

  factory ScanRecord.fromMap(Map<String, dynamic> map) => ScanRecord(
    id: map['id'],
    imagePath: map['imagePath'],
    diseaseLabel: map['diseaseLabel'],
    confidence: map['confidence'],
    healthScore: map['healthScore'],
    healthStatus: map['healthStatus'],
    severity: map['severity'],
    treatment: map['treatment'],
    temperature: map['temperature'],
    humidity: map['humidity'],
    ndvi: map['ndvi'],
    weatherStress: map['weatherStress'],
    top5Json: map['top5Json'],
    cafJson: map['cafJson'],
    latitude: map['latitude'],
    longitude: map['longitude'],
    offline: map['offline'] == 1,
    scanDate: DateTime.parse(map['scanDate']),
  );

  /// Build a ScanRecord from the API response JSON
  factory ScanRecord.fromApiResponse(Map<String, dynamic> data, String imgPath, {double? lat, double? lon, bool isOffline = false}) {
    return ScanRecord(
      imagePath: imgPath,
      diseaseLabel: data['disease_label'] ?? 'Unknown',
      confidence: (data['confidence'] as num).toDouble(),
      healthScore: (data['health_score'] as num).toDouble(),
      healthStatus: data['health_status'] ?? '',
      severity: data['severity'] ?? 'unknown',
      treatment: data['treatment'] ?? '',
      temperature: (data['temperature'] as num).toDouble(),
      humidity: (data['humidity'] as num).toDouble(),
      ndvi: (data['ndvi_used'] as num?)?.toDouble() ?? 0.45,
      weatherStress: (data['weather_stress'] as num).toDouble(),
      top5Json: jsonEncode(data['top5'] ?? []),
      cafJson: jsonEncode(data['caf'] ?? {}),
      latitude: lat,
      longitude: lon,
      offline: isOffline,
      scanDate: DateTime.now(),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cropscan.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$filePath';
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        imagePath TEXT NOT NULL,
        diseaseLabel TEXT NOT NULL,
        confidence REAL NOT NULL,
        healthScore REAL NOT NULL,
        healthStatus TEXT NOT NULL,
        severity TEXT NOT NULL,
        treatment TEXT NOT NULL,
        temperature REAL NOT NULL,
        humidity REAL NOT NULL,
        ndvi REAL NOT NULL,
        weatherStress REAL NOT NULL,
        top5Json TEXT NOT NULL,
        cafJson TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        offline INTEGER NOT NULL DEFAULT 0,
        scanDate TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertScan(ScanRecord scan) async {
    final db = await database;
    return await db.insert('scans', scan.toMap());
  }

  Future<List<ScanRecord>> getAllScans() async {
    final db = await database;
    final maps = await db.query('scans', orderBy: 'scanDate DESC');
    return maps.map((m) => ScanRecord.fromMap(m)).toList();
  }

  Future<int> deleteScan(int id) async {
    final db = await database;
    return await db.delete('scans', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getScanCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM scans');
    return result.first['count'] as int;
  }
}
