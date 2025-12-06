import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/project.dart';
import '../models/pile.dart';
import '../models/pile_session.dart';
import '../models/measurement.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('b24_torque.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // ✅ تغییر: از 1 به 2
      onCreate: _createDB,
      onUpgrade: _onUpgrade, // ✅ اضافه شد
    );
  }

  // ✅ تابع جدید برای migration
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration from version 1 to 2
      // Drop old tables and recreate (for development only)
      await db.execute('DROP TABLE IF EXISTS measurements');
      await db.execute('DROP TABLE IF EXISTS pile_sessions');
      await db.execute('DROP TABLE IF EXISTS piles');
      await db.execute('DROP TABLE IF EXISTS projects');
      
      // Recreate all tables with correct schema
      await _createDB(db, newVersion);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        location TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE piles (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        pileId TEXT NOT NULL,
        pileNumber TEXT NOT NULL,
        pileType TEXT NOT NULL,
        expectedTorque REAL NOT NULL,
        expectedDepth REAL NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE pile_sessions (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        pileId TEXT NOT NULL,
        operatorCode TEXT NOT NULL,
        startTime INTEGER NOT NULL,
        endTime INTEGER,
        status TEXT NOT NULL,
        FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE,
        FOREIGN KEY (pileId) REFERENCES piles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE measurements (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        pileId TEXT NOT NULL,
        operatorCode TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        torque REAL NOT NULL,
        force REAL NOT NULL,
        mass REAL NOT NULL,
        depth REAL NOT NULL,
        FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE,
        FOREIGN KEY (pileId) REFERENCES piles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_measurements_pile ON measurements(pileId)');
    await db.execute('CREATE INDEX idx_measurements_timestamp ON measurements(timestamp)');
  }

  // Project operations
  Future<void> insertProject(Project project) async {
    final db = await database;
    await db.insert('projects', project.toMap());
  }

  Future<List<Project>> getAllProjects() async {
    final db = await database;
    final maps = await db.query('projects', orderBy: 'createdAt DESC');
    return maps.map((map) => Project.fromMap(map)).toList();
  }

  Future<Project?> getProject(String id) async {
    final db = await database;
    final maps = await db.query('projects', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Project.fromMap(maps.first);
  }

  Future<void> deleteProject(String id) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  // Pile operations
  Future<void> insertPile(Pile pile) async {
    final db = await database;
    await db.insert('piles', pile.toMap());
  }

  Future<void> insertPiles(List<Pile> piles) async {
    final db = await database;
    final batch = db.batch();
    for (var pile in piles) {
      batch.insert('piles', pile.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<Pile>> getPilesByProject(String projectId) async {
    final db = await database;
    final maps = await db.query('piles', where: 'projectId = ?', whereArgs: [projectId]);
    return maps.map((map) => Pile.fromMap(map)).toList();
  }

  Future<void> updatePile(Pile pile) async {
    final db = await database;
    await db.update('piles', pile.toMap(), where: 'id = ?', whereArgs: [pile.id]);
  }

  // PileSession operations
  Future<void> insertPileSession(PileSession session) async {
    final db = await database;
    await db.insert('pile_sessions', session.toMap());
  }

  Future<void> updatePileSession(PileSession session) async {
    final db = await database;
    await db.update('pile_sessions', session.toMap(), where: 'id = ?', whereArgs: [session.id]);
  }

  Future<PileSession?> getActivePileSession(String pileId) async {
    final db = await database;
    final maps = await db.query(
      'pile_sessions',
      where: 'pileId = ? AND (status = ? OR status = ?)',
      whereArgs: [pileId, 'active', 'paused'],
      orderBy: 'startTime DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PileSession.fromMap(maps.first);
  }

  // Measurement operations
  Future<void> insertMeasurement(Measurement measurement) async {
    final db = await database;
    await db.insert('measurements', measurement.toMap());
  }

  Future<List<Measurement>> getMeasurementsByPile(String pileId) async {
    final db = await database;
    final maps = await db.query(
      'measurements',
      where: 'pileId = ?',
      whereArgs: [pileId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => Measurement.fromMap(map)).toList();
  }

  Future<List<Measurement>> getAllMeasurements() async {
    final db = await database;
    final maps = await db.query('measurements', orderBy: 'timestamp DESC');
    return maps.map((map) => Measurement.fromMap(map)).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
