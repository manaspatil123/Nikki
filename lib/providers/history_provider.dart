import 'package:flutter/foundation.dart';
import 'package:nikki/models/novel.dart';
import 'package:nikki/models/word_entry.dart';
import 'package:nikki/data/novel_repository.dart';
import 'package:nikki/data/word_repository.dart';

class HistoryProvider extends ChangeNotifier {
  final NovelRepository _novelRepository;
  final WordRepository _wordRepository;

  List<Novel> novels = [];
  int? selectedNovelId;
  List<WordEntry> entries = [];
  String searchQuery = '';
  bool isLoading = false;

  HistoryProvider(this._novelRepository, this._wordRepository) {
    loadNovels();
  }

  Future<void> loadNovels() async {
    try {
      novels = await _novelRepository.getAllNovels();
      if (selectedNovelId == null && novels.isNotEmpty) {
        selectedNovelId = novels.first.id;
      }
      await loadEntries();
      notifyListeners();
    } catch (e) {
      debugPrint('HistoryProvider.loadNovels error: $e');
    }
  }

  Future<void> selectNovel(int id) async {
    selectedNovelId = id;
    searchQuery = '';
    await loadEntries();
    notifyListeners();
  }

  Future<void> loadEntries() async {
    if (selectedNovelId == null) {
      entries = [];
      notifyListeners();
      return;
    }

    try {
      isLoading = true;
      notifyListeners();

      if (searchQuery.isNotEmpty) {
        entries = await _wordRepository.searchEntries(selectedNovelId!, searchQuery);
      } else {
        entries = await _wordRepository.getEntriesByNovel(selectedNovelId!);
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      debugPrint('HistoryProvider.loadEntries error: $e');
      notifyListeners();
    }
  }

  Future<void> updateSearchQuery(String query) async {
    searchQuery = query;
    await loadEntries();
  }

  Future<void> deleteWord(int id) async {
    try {
      await _wordRepository.delete(id);
      await loadEntries();
    } catch (e) {
      debugPrint('HistoryProvider.deleteWord error: $e');
    }
  }

  Future<void> deleteNovel(int id) async {
    try {
      await _novelRepository.delete(id);
      if (selectedNovelId == id) {
        selectedNovelId = null;
      }
      await loadNovels();
    } catch (e) {
      debugPrint('HistoryProvider.deleteNovel error: $e');
    }
  }

  Future<void> renameNovel(int id, String newName) async {
    try {
      final novel = novels.where((n) => n.id == id).firstOrNull;
      if (novel != null) {
        await _novelRepository.update(novel.copyWith(name: newName));
        await loadNovels();
      }
    } catch (e) {
      debugPrint('HistoryProvider.renameNovel error: $e');
    }
  }

  Future<void> createNovel(String name, String sourceLang, String targetLang) async {
    try {
      final id = await _novelRepository.insert(name, sourceLang, targetLang);
      await loadNovels();
      selectedNovelId = id;
      await loadEntries();
      notifyListeners();
    } catch (e) {
      debugPrint('HistoryProvider.createNovel error: $e');
    }
  }

  Future<void> clearAllHistory() async {
    try {
      await _wordRepository.deleteAll();
      await loadEntries();
    } catch (e) {
      debugPrint('HistoryProvider.clearAllHistory error: $e');
    }
  }
}
