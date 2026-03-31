import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nikki/models/explanation_category.dart';

class SettingsRepository {
  static const _keySourceLang = 'source_language';
  static const _keyTargetLang = 'target_language';
  static const _keyEnabledCategories = 'enabled_categories';
  static const _keyApiKey = 'openai_api_key';
  static const _keyGoogleCloudApiKey = 'google_cloud_api_key';
  static const _keyUseGoogleOcr = 'use_google_ocr';
  static const _keyDarkMode = 'dark_mode';
  static const _defaultGoogleCloudApiKey = 'AIzaSyA6L_yCAPQt0RWmHwWZF2CbCJRSDjFs65w';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<String> getSourceLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySourceLang) ?? 'Japanese';
  }

  Future<void> setSourceLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySourceLang, lang);
  }

  Future<String> getTargetLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTargetLang) ?? 'English';
  }

  Future<void> setTargetLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTargetLang, lang);
  }

  Future<Set<ExplanationCategory>> getEnabledCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_keyEnabledCategories);
    if (stored == null) return ExplanationCategory.values.toSet();
    return stored
        .map((name) {
          try {
            return ExplanationCategory.values.firstWhere((c) => c.name == name);
          } catch (_) {
            return null;
          }
        })
        .whereType<ExplanationCategory>()
        .toSet();
  }

  Future<void> setEnabledCategories(Set<ExplanationCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyEnabledCategories,
      categories.map((c) => c.name).toList(),
    );
  }

  Future<String> getApiKey() async {
    return await _secureStorage.read(key: _keyApiKey) ?? '';
  }

  Future<void> setApiKey(String key) async {
    await _secureStorage.write(key: _keyApiKey, value: key);
  }

  Future<String> getGoogleCloudApiKey() async {
    return await _secureStorage.read(key: _keyGoogleCloudApiKey) ?? _defaultGoogleCloudApiKey;
  }

  Future<void> setGoogleCloudApiKey(String key) async {
    await _secureStorage.write(key: _keyGoogleCloudApiKey, value: key);
  }

  Future<bool> getUseGoogleOcr() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseGoogleOcr) ?? false;
  }

  Future<void> setUseGoogleOcr(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseGoogleOcr, value);
  }

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }
}
