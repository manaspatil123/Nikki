import 'package:nikki/data/database.dart';
import 'package:nikki/models/novel.dart';

class NovelRepository {
  Future<List<Novel>> getAllNovels() async {
    final db = await NikkiDatabase.database;
    final maps = await db.query('novels', orderBy: 'sortOrder ASC, createdAt DESC');
    return maps.map((m) => Novel.fromMap(m)).toList();
  }

  Future<Novel?> getById(int id) async {
    final db = await NikkiDatabase.database;
    final maps = await db.query('novels', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Novel.fromMap(maps.first);
  }

  Future<int> insert(String name, String sourceLang, String targetLang, {String description = ''}) async {
    final db = await NikkiDatabase.database;
    return db.insert('novels', Novel(
      name: name,
      description: description,
      sourceLanguage: sourceLang,
      targetLanguage: targetLang,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ).toMap());
  }

  Future<void> update(Novel novel) async {
    final db = await NikkiDatabase.database;
    await db.update('novels', novel.toMap(), where: 'id = ?', whereArgs: [novel.id]);
  }

  Future<void> delete(int id) async {
    final db = await NikkiDatabase.database;
    await db.delete('novels', where: 'id = ?', whereArgs: [id]);
  }
}
