import 'package:nikki/data/database.dart';
import 'package:nikki/models/word_entry.dart';

class WordRepository {
  Future<List<WordEntry>> getEntriesByNovel(int novelId) async {
    final db = await NikkiDatabase.database;
    final maps = await db.query(
      'word_entries',
      where: 'novelId = ?',
      whereArgs: [novelId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => WordEntry.fromMap(m)).toList();
  }

  Future<List<WordEntry>> searchEntries(int novelId, String query) async {
    final db = await NikkiDatabase.database;
    final maps = await db.query(
      'word_entries',
      where: 'novelId = ? AND selectedText LIKE ?',
      whereArgs: [novelId, '%$query%'],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => WordEntry.fromMap(m)).toList();
  }

  Future<int> insert(WordEntry entry) async {
    final db = await NikkiDatabase.database;
    return db.insert('word_entries', entry.toMap());
  }

  Future<void> delete(int id) async {
    final db = await NikkiDatabase.database;
    await db.delete('word_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    final db = await NikkiDatabase.database;
    await db.delete('word_entries');
  }
}
