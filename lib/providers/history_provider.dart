import 'package:flutter/foundation.dart';
import 'package:nikki/models/word_entry.dart';
import 'package:nikki/data/word_repository.dart';

class HistoryProvider extends ChangeNotifier {
  final WordRepository _wordRepository;

  List<WordEntry> entries = [];
  String searchQuery = '';
  bool isLoading = false;

  HistoryProvider(this._wordRepository) {
    _purgeOldEntries();
    loadEntries();
  }

  Future<void> _purgeOldEntries() async {
    try {
      final count = await _wordRepository.deleteOlderThan30Days();
      if (count > 0) {
        debugPrint('HistoryProvider: purged $count entries older than 30 days');
        await loadEntries();
      }
    } catch (e) {
      debugPrint('HistoryProvider._purgeOldEntries error: $e');
    }
  }

  Future<void> loadEntries() async {
    try {
      isLoading = true;
      notifyListeners();

      if (searchQuery.isNotEmpty) {
        entries = await _wordRepository.searchAllEntries(searchQuery);
      } else {
        entries = await _wordRepository.getAllEntries();
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

  Future<void> clearAllHistory() async {
    try {
      await _wordRepository.deleteAll();
      await loadEntries();
    } catch (e) {
      debugPrint('HistoryProvider.clearAllHistory error: $e');
    }
  }
}
