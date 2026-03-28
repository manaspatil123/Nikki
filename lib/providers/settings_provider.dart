import 'package:flutter/foundation.dart';
import 'package:nikki/models/explanation_category.dart';
import 'package:nikki/data/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;

  String sourceLanguage = 'Japanese';
  String targetLanguage = 'English';
  Set<ExplanationCategory> enabledCategories = ExplanationCategory.values.toSet();
  String apiKey = '';
  bool showApiKey = false;
  String googleCloudApiKey = '';
  bool showGoogleCloudApiKey = false;
  bool useGoogleOcr = false;
  bool isLoaded = false;

  SettingsProvider(this._settingsRepository) {
    _load();
  }

  Future<void> _load() async {
    try {
      sourceLanguage = await _settingsRepository.getSourceLanguage();
      targetLanguage = await _settingsRepository.getTargetLanguage();
      enabledCategories = await _settingsRepository.getEnabledCategories();
      apiKey = await _settingsRepository.getApiKey();
      googleCloudApiKey = await _settingsRepository.getGoogleCloudApiKey();
      useGoogleOcr = await _settingsRepository.getUseGoogleOcr();
      isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('SettingsProvider._load error: $e');
    }
  }

  Future<void> setSourceLanguage(String lang) async {
    sourceLanguage = lang;
    notifyListeners();
    try {
      await _settingsRepository.setSourceLanguage(lang);
    } catch (e) {
      debugPrint('SettingsProvider.setSourceLanguage error: $e');
    }
  }

  Future<void> setTargetLanguage(String lang) async {
    targetLanguage = lang;
    notifyListeners();
    try {
      await _settingsRepository.setTargetLanguage(lang);
    } catch (e) {
      debugPrint('SettingsProvider.setTargetLanguage error: $e');
    }
  }

  Future<void> toggleCategory(ExplanationCategory category) async {
    if (enabledCategories.contains(category)) {
      enabledCategories.remove(category);
    } else {
      enabledCategories.add(category);
    }
    notifyListeners();
    try {
      await _settingsRepository.setEnabledCategories(enabledCategories);
    } catch (e) {
      debugPrint('SettingsProvider.toggleCategory error: $e');
    }
  }

  Future<void> setApiKey(String key) async {
    apiKey = key;
    notifyListeners();
    try {
      await _settingsRepository.setApiKey(key);
    } catch (e) {
      debugPrint('SettingsProvider.setApiKey error: $e');
    }
  }

  void toggleShowApiKey() {
    showApiKey = !showApiKey;
    notifyListeners();
  }

  Future<void> setGoogleCloudApiKey(String key) async {
    googleCloudApiKey = key;
    notifyListeners();
    try {
      await _settingsRepository.setGoogleCloudApiKey(key);
    } catch (e) {
      debugPrint('SettingsProvider.setGoogleCloudApiKey error: $e');
    }
  }

  void toggleShowGoogleCloudApiKey() {
    showGoogleCloudApiKey = !showGoogleCloudApiKey;
    notifyListeners();
  }

  /// Fetch the Google Cloud API key directly from storage.
  /// Used when the provider hasn't finished loading yet.
  Future<String> ensureGoogleCloudApiKey() async {
    if (googleCloudApiKey.isNotEmpty) return googleCloudApiKey;
    googleCloudApiKey = await _settingsRepository.getGoogleCloudApiKey();
    return googleCloudApiKey;
  }

  Future<void> toggleUseGoogleOcr() async {
    useGoogleOcr = !useGoogleOcr;
    notifyListeners();
    try {
      await _settingsRepository.setUseGoogleOcr(useGoogleOcr);
    } catch (e) {
      debugPrint('SettingsProvider.toggleUseGoogleOcr error: $e');
    }
  }
}
