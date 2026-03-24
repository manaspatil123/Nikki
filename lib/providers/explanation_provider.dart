import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nikki/models/word_entry.dart';
import 'package:nikki/models/explanation.dart';
import 'package:nikki/data/word_repository.dart';
import 'package:nikki/data/settings_repository.dart';
import 'package:nikki/services/openai_service.dart';

class ExplanationProvider extends ChangeNotifier {
  final OpenAiService _openAiService;
  final WordRepository _wordRepository;
  final SettingsRepository _settingsRepository;

  bool isLoading = false;
  String selectedText = '';
  String surroundingContext = '';
  Explanation? explanation;
  String? error;
  bool showComparison = false;
  SimilarWord? comparisonTarget;
  ComparisonResult? comparison;
  bool isComparisonLoading = false;
  String? comparisonError;

  ExplanationProvider(
    this._openAiService,
    this._wordRepository,
    this._settingsRepository,
  );

  Future<void> explain({
    required String selectedText,
    required String surroundingContext,
    required String sourceLanguage,
    required String targetLanguage,
    int? novelId,
    required bool dontSave,
  }) async {
    this.selectedText = selectedText;
    this.surroundingContext = surroundingContext;
    isLoading = true;
    error = null;
    explanation = null;
    showComparison = false;
    comparison = null;
    comparisonTarget = null;
    comparisonError = null;
    notifyListeners();

    try {
      final apiKey = await _settingsRepository.getApiKey();
      final enabledCategories = await _settingsRepository.getEnabledCategories();

      final result = await _openAiService.getExplanation(
        apiKey: apiKey,
        selectedText: selectedText,
        surroundingContext: surroundingContext,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        enabledCategories: enabledCategories,
      );

      explanation = result;
      isLoading = false;
      notifyListeners();

      if (!dontSave && novelId != null) {
        try {
          final entry = WordEntry(
            novelId: novelId,
            selectedText: selectedText,
            surroundingContext: surroundingContext,
            explanationJson: jsonEncode(result.toJson()),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          );
          await _wordRepository.insert(entry);
        } catch (e) {
          debugPrint('ExplanationProvider: failed to save entry: $e');
        }
      }
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> compare({
    required String originalWord,
    required SimilarWord similarWord,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    showComparison = true;
    comparisonTarget = similarWord;
    isComparisonLoading = true;
    comparison = null;
    comparisonError = null;
    notifyListeners();

    try {
      final apiKey = await _settingsRepository.getApiKey();

      final result = await _openAiService.getComparison(
        apiKey: apiKey,
        originalWord: originalWord,
        comparedWord: similarWord.word,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );

      comparison = result;
      isComparisonLoading = false;
      notifyListeners();
    } catch (e) {
      comparisonError = e.toString();
      isComparisonLoading = false;
      notifyListeners();
    }
  }

  void dismissComparison() {
    showComparison = false;
    comparison = null;
    comparisonTarget = null;
    comparisonError = null;
    notifyListeners();
  }

  void showCachedExplanation(String selectedText, String explanationJson) {
    this.selectedText = selectedText;
    explanation = Explanation.fromJson(jsonDecode(explanationJson));
    isLoading = false;
    error = null;
    notifyListeners();
  }

  void reset() {
    isLoading = false;
    selectedText = '';
    surroundingContext = '';
    explanation = null;
    error = null;
    showComparison = false;
    comparisonTarget = null;
    comparison = null;
    isComparisonLoading = false;
    comparisonError = null;
    notifyListeners();
  }
}
