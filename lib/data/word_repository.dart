import 'package:nikki/data/database.dart';
import 'package:nikki/models/word_entry.dart';

class WordRepository {
  Future<List<WordEntry>> getAllEntries() async {
    final db = await NikkiDatabase.database;
    final maps = await db.query(
      'word_entries',
      where: 'hiddenFromHistory = 0',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => WordEntry.fromMap(m)).toList();
  }

  Future<List<WordEntry>> searchAllEntries(String query) async {
    final db = await NikkiDatabase.database;
    final maps = await db.query(
      'word_entries',
      where: 'hiddenFromHistory = 0 AND selectedText LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => WordEntry.fromMap(m)).toList();
  }

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

  Future<void> updateNotes(int id, String notes) async {
    final db = await NikkiDatabase.database;
    await db.update('word_entries', {'notes': notes}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateExplanationJson(int id, String explanationJson) async {
    final db = await NikkiDatabase.database;
    await db.update('word_entries', {'explanationJson': explanationJson}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await NikkiDatabase.database;
    await db.delete('word_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> hideFromHistory(int id) async {
    final db = await NikkiDatabase.database;
    await db.update('word_entries', {'hiddenFromHistory': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> hideMultipleFromHistory(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await NikkiDatabase.database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.update('word_entries', {'hiddenFromHistory': 1}, where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<void> deleteMultiple(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await NikkiDatabase.database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.delete('word_entries', where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<void> removeFromNovel(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await NikkiDatabase.database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.update(
      'word_entries',
      {'novelId': null},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<void> assignToNovel(List<int> ids, int novelId) async {
    if (ids.isEmpty) return;
    final db = await NikkiDatabase.database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.update(
      'word_entries',
      {'novelId': novelId},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<void> deleteAll() async {
    final db = await NikkiDatabase.database;
    await db.delete('word_entries');
  }

  /// Delete entries older than 30 days.
  Future<int> deleteOlderThan30Days() async {
    final db = await NikkiDatabase.database;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    return db.delete(
      'word_entries',
      where: 'createdAt < ?',
      whereArgs: [cutoff],
    );
  }
}
