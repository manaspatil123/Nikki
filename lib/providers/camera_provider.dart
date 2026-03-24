import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:nikki/models/novel.dart';
import 'package:nikki/models/explanation_category.dart';
import 'package:nikki/data/novel_repository.dart';
import 'package:nikki/data/settings_repository.dart';

class RecognizedBlock {
  final String text;
  final Rect? boundingBox;
  final List<RecognizedElement> elements;

  RecognizedBlock({
    required this.text,
    this.boundingBox,
    required this.elements,
  });
}

class RecognizedElement {
  final String text;
  final Rect? boundingBox;

  RecognizedElement({required this.text, this.boundingBox});
}

class SelectedWord {
  final String text;
  final String surroundingContext;

  SelectedWord({required this.text, required this.surroundingContext});
}

class CameraProvider extends ChangeNotifier {
  final NovelRepository _novelRepository;
  final SettingsRepository _settingsRepository;

  List<Novel> novels = [];
  Novel? selectedNovel;
  String sourceLanguage = 'Japanese';
  String targetLanguage = 'English';
  bool dontSave = false;
  bool isFrozen = false;
  List<RecognizedBlock> recognizedBlocks = [];
  SelectedWord? selectedWord;
  bool showExplanation = false;
  Set<ExplanationCategory> enabledCategories = ExplanationCategory.values.toSet();
  int imageWidth = 0;
  int imageHeight = 0;
  int rotationDegrees = 0;

  CameraProvider(this._novelRepository, this._settingsRepository) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      novels = await _novelRepository.getAllNovels();
      sourceLanguage = await _settingsRepository.getSourceLanguage();
      targetLanguage = await _settingsRepository.getTargetLanguage();
      enabledCategories = await _settingsRepository.getEnabledCategories();
      notifyListeners();
    } catch (e) {
      debugPrint('CameraProvider._loadInitialData error: $e');
    }
  }

  Future<void> loadNovels() async {
    try {
      novels = await _novelRepository.getAllNovels();
      notifyListeners();
    } catch (e) {
      debugPrint('CameraProvider.loadNovels error: $e');
    }
  }

  void selectNovel(Novel novel) {
    selectedNovel = novel;
    notifyListeners();
  }

  Future<void> createNovel(String name) async {
    try {
      final id = await _novelRepository.insert(name, sourceLanguage, targetLanguage);
      await loadNovels();
      final novel = novels.where((n) => n.id == id).firstOrNull;
      if (novel != null) {
        selectedNovel = novel;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('CameraProvider.createNovel error: $e');
    }
  }

  void onTextRecognized(
    List<RecognizedBlock> blocks,
    int width,
    int height,
    int rotation,
  ) {
    if (isFrozen) return;
    recognizedBlocks = blocks;
    imageWidth = width;
    imageHeight = height;
    rotationDegrees = rotation;
    notifyListeners();
  }

  void onWordSelected(RecognizedElement element, String blockText) {
    selectedWord = SelectedWord(
      text: element.text,
      surroundingContext: blockText,
    );
    showExplanation = true;
    notifyListeners();
  }

  void dismissExplanation() {
    selectedWord = null;
    showExplanation = false;
    notifyListeners();
  }

  void toggleDontSave() {
    dontSave = !dontSave;
    notifyListeners();
  }

  void toggleFreeze() {
    isFrozen = !isFrozen;
    notifyListeners();
  }
}
