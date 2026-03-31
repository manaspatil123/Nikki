import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class NikkiDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'nikki.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE novels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            author TEXT NOT NULL DEFAULT '',
            description TEXT NOT NULL DEFAULT '',
            sourceLanguage TEXT NOT NULL,
            targetLanguage TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE word_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            novelId INTEGER,
            selectedText TEXT NOT NULL,
            surroundingContext TEXT NOT NULL,
            explanationJson TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            hiddenFromHistory INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_word_entries_novel ON word_entries(novelId)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE word_entries_v2 (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              novelId INTEGER,
              selectedText TEXT NOT NULL,
              surroundingContext TEXT NOT NULL,
              explanationJson TEXT NOT NULL,
              createdAt INTEGER NOT NULL
            )
          ''');
          await db.execute('INSERT INTO word_entries_v2 SELECT * FROM word_entries');
          await db.execute('DROP TABLE word_entries');
          await db.execute('ALTER TABLE word_entries_v2 RENAME TO word_entries');
          await db.execute('CREATE INDEX idx_word_entries_novel ON word_entries(novelId)');
        }
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE novels ADD COLUMN author TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE novels ADD COLUMN description TEXT NOT NULL DEFAULT ''");
        }
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE word_entries ADD COLUMN notes TEXT NOT NULL DEFAULT ''");
        }
        if (oldVersion < 5) {
          await db.execute("ALTER TABLE word_entries ADD COLUMN hiddenFromHistory INTEGER NOT NULL DEFAULT 0");
        }
      },
    );
  }
}
