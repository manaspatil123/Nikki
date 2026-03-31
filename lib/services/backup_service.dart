import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nikki/data/database.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

/// Exports and imports all app data (novels, word entries) as a JSON file.
class BackupService {
  /// Export all data to a JSON file and open the share sheet.
  static Future<void> export() async {
    final db = await NikkiDatabase.database;

    final novels = await db.query('novels');
    final wordEntries = await db.query('word_entries');

    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'novels': novels,
      'wordEntries': wordEntries,
    };

    final json = const JsonEncoder.withIndent('  ').convert(data);

    // Write to a temp file.
    final dir = await path_provider.getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/nikki_backup_$timestamp.json');
    await file.writeAsString(json);

    // Open share sheet.
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Nikki Backup',
    );
  }

  /// Import data from a JSON backup file. Returns the number of items imported.
  static Future<String> import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) {
      return 'Cancelled';
    }

    final filePath = result.files.single.path;
    if (filePath == null) return 'Failed to read file';

    try {
      final json = await File(filePath).readAsString();
      final data = jsonDecode(json) as Map<String, dynamic>;

      if (!data.containsKey('novels') || !data.containsKey('wordEntries')) {
        return 'Invalid backup file';
      }

      final db = await NikkiDatabase.database;

      final novels = data['novels'] as List<dynamic>;
      final wordEntries = data['wordEntries'] as List<dynamic>;

      int novelsImported = 0;
      int wordsImported = 0;

      // Import novels — skip if a novel with the same name already exists.
      final existingNovels = await db.query('novels');
      final existingNames = existingNovels.map((n) => n['name'] as String).toSet();

      // Map old novel IDs to new IDs for word entry reassignment.
      final novelIdMap = <int, int>{};

      for (final novel in novels) {
        final map = Map<String, dynamic>.from(novel as Map);
        final oldId = map['id'] as int;
        final name = map['name'] as String;

        if (existingNames.contains(name)) {
          // Find the existing novel's ID.
          final existing = existingNovels.firstWhere((n) => n['name'] == name);
          novelIdMap[oldId] = existing['id'] as int;
          continue;
        }

        map.remove('id'); // Let SQLite auto-assign.
        final newId = await db.insert('novels', map);
        novelIdMap[oldId] = newId;
        novelsImported++;
      }

      // Import word entries — skip duplicates (same selectedText + createdAt).
      final existingWords = await db.query('word_entries',
          columns: ['selectedText', 'createdAt']);
      final existingWordKeys = existingWords
          .map((w) => '${w['selectedText']}_${w['createdAt']}')
          .toSet();

      for (final entry in wordEntries) {
        final map = Map<String, dynamic>.from(entry as Map);
        final key = '${map['selectedText']}_${map['createdAt']}';

        if (existingWordKeys.contains(key)) continue;

        map.remove('id');
        // Remap novelId.
        final oldNovelId = map['novelId'] as int?;
        if (oldNovelId != null && novelIdMap.containsKey(oldNovelId)) {
          map['novelId'] = novelIdMap[oldNovelId];
        }

        await db.insert('word_entries', map);
        wordsImported++;
      }

      return 'Imported $novelsImported novels, $wordsImported words';
    } catch (e) {
      debugPrint('BackupService.import error: $e');
      return 'Import failed: $e';
    }
  }
}
