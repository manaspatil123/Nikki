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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE novels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            sourceLanguage TEXT NOT NULL,
            targetLanguage TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            sortOrder INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE word_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            novelId INTEGER NOT NULL,
            selectedText TEXT NOT NULL,
            surroundingContext TEXT NOT NULL,
            explanationJson TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (novelId) REFERENCES novels(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_word_entries_novel ON word_entries(novelId)');
      },
    );
  }
}
