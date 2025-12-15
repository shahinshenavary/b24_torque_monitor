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

  /// ✅ Get database file path
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'b24_torque.db');
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7, // ✅ Changed to 7 for editReason column
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration from version 1 to 2
      await db.execute('DROP TABLE IF EXISTS measurements');
      await db.execute('DROP TABLE IF EXISTS pile_sessions');
      await db.execute('DROP TABLE IF EXISTS piles');
      await db.execute('DROP TABLE IF EXISTS projects');
      await _createDB(db, newVersion);
    }
    
    if (oldVersion < 3) {
      // Migration from version 2 to 3: Add finalDepth column
      await db.execute('ALTER TABLE piles ADD COLUMN finalDepth REAL');
    }
    
    if (oldVersion < 4) {
      // Migration from version 3 to 4: Add deviceDataTags column
      await db.execute('ALTER TABLE projects ADD COLUMN deviceDataTags TEXT DEFAULT ""');
    }
    
    if (oldVersion < 5) {
      // Migration from version 4 to 5: Add viewPin column
      await db.execute('ALTER TABLE projects ADD COLUMN viewPin TEXT DEFAULT "0000"');
    }
    
    if (oldVersion < 6) {
      // Migration from version 5 to 6: Add device status columns to measurements
      await db.execute('ALTER TABLE measurements ADD COLUMN statusByte INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE measurements ADD COLUMN statusJson TEXT DEFAULT "{}"');
    }
    
    if (oldVersion < 7) {
      // Migration from version 6 to 7: Add editReason column to piles
      await db.execute('ALTER TABLE piles ADD COLUMN editReason TEXT');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        location TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        deviceDataTags TEXT DEFAULT "",
        viewPin TEXT DEFAULT "0000"
      )
    ''');

    await db.execute('''\n      CREATE TABLE piles (\n        id TEXT PRIMARY KEY,\n        projectId TEXT NOT NULL,\n        pileId TEXT NOT NULL,\n        pileNumber TEXT NOT NULL,\n        pileType TEXT NOT NULL,\n        expectedTorque REAL NOT NULL,\n        expectedDepth REAL NOT NULL,\n        status TEXT NOT NULL,\n        finalDepth REAL,\n        editReason TEXT,\n        FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE\n      )\n    ''');

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

    await db.execute('''\n      CREATE TABLE measurements (\n        id TEXT PRIMARY KEY,\n        projectId TEXT NOT NULL,\n        pileId TEXT NOT NULL,\n        operatorCode TEXT NOT NULL,\n        timestamp INTEGER NOT NULL,\n        torque REAL NOT NULL,\n        force REAL NOT NULL,\n        mass REAL NOT NULL,\n        depth REAL NOT NULL,\n        statusByte INTEGER DEFAULT 0,\n        statusJson TEXT DEFAULT \"{}\",\n        editReason TEXT DEFAULT \"\",\n        FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE,\n        FOREIGN KEY (pileId) REFERENCES piles (id) ON DELETE CASCADE\n      )\n    ''');

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

  Future<Pile?> getPile(String id) async {
    final db = await database;
    final maps = await db.query('piles', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Pile.fromMap(maps.first);
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