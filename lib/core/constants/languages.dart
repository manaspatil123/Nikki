class Languages {
  Languages._();

  /// Canonical list of source languages for the camera dropdown.
  static const cameraSourceLanguages = [
    'Japanese',
    'Chinese',
    'Korean',
    'English',
    'French',
    'German',
    'Spanish',
  ];

  /// Extended list of source languages for the settings screen.
  static const settingsSourceLanguages = [
    'Japanese',
    'Korean',
    'Chinese (Simplified)',
    'Chinese (Traditional)',
    'French',
    'German',
    'Spanish',
    'Italian',
    'Portuguese',
    'Russian',
    'Arabic',
  ];

  /// Canonical list of target languages.
  static const targetLanguages = [
    'English',
    'Japanese',
    'Korean',
    'Chinese',
    'Spanish',
    'French',
    'German',
  ];

  /// English name -> native script display name.
  static const nativeNames = {
    'Japanese': '日本語',
    'Chinese': '中文',
    'Chinese (Simplified)': '中文(简)',
    'Chinese (Traditional)': '中文(繁)',
    'Korean': '한국어',
    'English': 'English',
    'French': 'Français',
    'German': 'Deutsch',
    'Spanish': 'Español',
    'Italian': 'Italiano',
    'Portuguese': 'Português',
    'Russian': 'Русский',
    'Arabic': 'العربية',
  };

  /// English name -> native display name, with fallback.
  static String nativeName(String language) {
    return nativeNames[language] ?? language;
  }

  /// English name -> ISO 639 code for Apple Vision OCR.
  static String appleOcrLanguageCode(String language) {
    switch (language.toLowerCase()) {
      case 'japanese':
        return 'ja';
      case 'chinese':
      case 'chinese (simplified)':
        return 'zh-Hans';
      case 'chinese (traditional)':
        return 'zh-Hant';
      case 'korean':
        return 'ko';
      case 'english':
        return 'en';
      case 'french':
        return 'fr';
      case 'german':
        return 'de';
      case 'spanish':
        return 'es';
      case 'italian':
        return 'it';
      case 'portuguese':
        return 'pt';
      case 'russian':
        return 'ru';
      case 'arabic':
        return 'ar';
      default:
        return 'en';
    }
  }

  /// English name -> ISO 639 code for Google Cloud Vision OCR.
  static String googleOcrLanguageHint(String language) {
    switch (language.toLowerCase()) {
      case 'japanese':
        return 'ja';
      case 'chinese':
      case 'chinese (simplified)':
      case 'chinese (traditional)':
        return 'zh';
      case 'korean':
        return 'ko';
      case 'english':
        return 'en';
      case 'french':
        return 'fr';
      case 'german':
        return 'de';
      case 'spanish':
        return 'es';
      case 'italian':
        return 'it';
      case 'portuguese':
        return 'pt';
      case 'russian':
        return 'ru';
      case 'arabic':
        return 'ar';
      default:
        return 'en';
    }
  }
}
