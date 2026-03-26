import 'package:flutter/foundation.dart';
import 'package:nikki/models/novel.dart';
import 'package:nikki/models/ocr.dart';
import 'package:nikki/data/novel_repository.dart';
import 'package:nikki/data/settings_repository.dart';

class CameraProvider extends ChangeNotifier {
  final NovelRepository _novelRepository;
  final SettingsRepository _settingsRepository;

  List<Novel> novels = [];
  Novel? selectedNovel;
  String sourceLanguage = 'Japanese';
  String targetLanguage = 'English';
  bool dontSave = false;

  // Capture state
  String? capturedImagePath;
  bool get isCaptured => capturedImagePath != null;

  List<RecognizedBlock> recognizedBlocks = [];
  SelectedWord? selectedWord;
  bool showExplanation = false;
  int imageWidth = 0;
  int imageHeight = 0;

  CameraProvider(this._novelRepository, this._settingsRepository) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      novels = await _novelRepository.getAllNovels();
      sourceLanguage = await _settingsRepository.getSourceLanguage();
      targetLanguage = await _settingsRepository.getTargetLanguage();
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

  Future<void> setSourceLanguage(String language) async {
    sourceLanguage = language;
    await _settingsRepository.setSourceLanguage(language);
    notifyListeners();
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

  /// Called after a picture is taken and OCR completes.
  void onPictureTaken(
    String imagePath,
    List<RecognizedBlock> blocks,
    int width,
    int height,
  ) {
    capturedImagePath = imagePath;
    recognizedBlocks = blocks;
    imageWidth = width;
    imageHeight = height;
    notifyListeners();
  }

  /// Go back to live camera preview.
  void retake() {
    capturedImagePath = null;
    recognizedBlocks = [];
    selectedWord = null;
    showExplanation = false;
    imageWidth = 0;
    imageHeight = 0;
    notifyListeners();
  }

  void onTextSelected(String text, String blockText) {
    selectedWord = SelectedWord(
      text: text,
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
}
