import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDB {
  static final LocalDB instance = LocalDB._init();
  static Database? _database;
  LocalDB._init();

  static const String schema = '''
    CREATE TABLE plagas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_cientifico TEXT,
        nombre_comun TEXT,
        descripcion TEXT
    );

    CREATE TABLE usuarios (
        id TEXT PRIMARY KEY,
        nombre TEXT,
        email TEXT UNIQUE,
        telefono TEXT,
        password_hash TEXT,
        rol TEXT
    );

    CREATE TABLE cultivos (
        id TEXT PRIMARY KEY,
        usuario_id TEXT,
        nombre_parcela TEXT,
        coordenadas_sector TEXT,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id)
    );

    CREATE TABLE detecciones (
        id TEXT PRIMARY KEY,
        cultivo_id TEXT,
        plaga_id INTEGER,
        plaga_real_manual_id INTEGER,
        confianza REAL,
        fecha_hora TEXT,
        latitud REAL,
        longitud REAL,
        ubicacion_origen TEXT,
        box_left REAL,
        box_top REAL,
        box_right REAL,
        box_bottom REAL,
        ruta_imagen TEXT,
        dispositivo_id TEXT,
        sincronizado INTEGER DEFAULT 0,
        cloud_id TEXT,
        sync_status TEXT DEFAULT 'pendiente',
        last_sync_at TEXT,
        sync_error TEXT,
        retry_count INTEGER DEFAULT 0,
        nivel_afectacion TEXT,
        metodo_evaluacion TEXT,
        rango_afectacion TEXT,
        recomendacion_version TEXT,
        FOREIGN KEY(cultivo_id) REFERENCES cultivos(id),
        FOREIGN KEY(plaga_id) REFERENCES plagas(id)
    );
  ''';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('plagas_arroz.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 6,
      onConfigure: _onConfigure,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
    final statements = schema.split(';');
    final batch = db.batch();

    for (final statement in statements) {
      final trimmed = statement.trim();
      if (trimmed.isNotEmpty) {
        batch.execute(trimmed);
      }
    }

    await batch.commit(noResult: true);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE usuarios ADD COLUMN telefono TEXT');
    }

    if (oldVersion < 3) {
      await db.execute('ALTER TABLE detecciones ADD COLUMN box_left REAL');
      await db.execute('ALTER TABLE detecciones ADD COLUMN box_top REAL');
      await db.execute('ALTER TABLE detecciones ADD COLUMN box_right REAL');
      await db.execute('ALTER TABLE detecciones ADD COLUMN box_bottom REAL');
    }

    if (oldVersion < 4) {
      await db
          .execute('ALTER TABLE detecciones ADD COLUMN ubicacion_origen TEXT');
    }

    if (oldVersion < 5) {
      await db.execute('ALTER TABLE detecciones ADD COLUMN cloud_id TEXT');
      await db.execute(
        "ALTER TABLE detecciones ADD COLUMN sync_status TEXT DEFAULT 'pendiente'",
      );
      await db.execute('ALTER TABLE detecciones ADD COLUMN last_sync_at TEXT');
      await db.execute('ALTER TABLE detecciones ADD COLUMN sync_error TEXT');
      await db.execute(
        'ALTER TABLE detecciones ADD COLUMN retry_count INTEGER DEFAULT 0',
      );
    }

    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE detecciones ADD COLUMN nivel_afectacion TEXT',
      );
      await db.execute(
        'ALTER TABLE detecciones ADD COLUMN metodo_evaluacion TEXT',
      );
      await db.execute(
        'ALTER TABLE detecciones ADD COLUMN rango_afectacion TEXT',
      );
      await db.execute(
        'ALTER TABLE detecciones ADD COLUMN recomendacion_version TEXT',
      );
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
