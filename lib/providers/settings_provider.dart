import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// Target languages offered for translations (ISO 639-1 code -> name).
const Map<String, String> kTargetLanguages = {
  'uz': 'Uzbek',
  'ru': 'Russian',
  'ur': 'Urdu',
  'tr': 'Turkish',
  'ar': 'Arabic',
  'kk': 'Kazakh',
  'tg': 'Tajik',
  'hi': 'Hindi',
  'fa': 'Persian',
  'de': 'German',
  'fr': 'French',
  'es': 'Spanish',
  'zh': 'Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
};

class SettingsProvider extends ChangeNotifier {
  SettingsProvider() {
    final box = StorageService.settings;
    _themeMode = ThemeMode.values[
        (box.get('themeMode', defaultValue: ThemeMode.system.index) as int)
            .clamp(0, ThemeMode.values.length - 1)];
    _targetLang = box.get('targetLang', defaultValue: 'uz') as String;
    _geminiKey = box.get('geminiKey', defaultValue: '') as String;
    _geminiModel =
        box.get('geminiModel', defaultValue: 'gemini-2.5-flash') as String;
  }

  late ThemeMode _themeMode;
  late String _targetLang;
  late String _geminiKey;
  late String _geminiModel;

  ThemeMode get themeMode => _themeMode;
  String get targetLang => _targetLang;
  String get targetLangName => kTargetLanguages[_targetLang] ?? _targetLang;
  String get geminiKey => _geminiKey;
  String get geminiModel => _geminiModel;
  bool get hasGemini => _geminiKey.trim().isNotEmpty;

  Future<void> _put(String key, Object value) =>
      StorageService.settings.put(key, value);

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _put('themeMode', mode.index);
    notifyListeners();
  }

  /// AppBar quick toggle: light <-> dark (resolves "system" first).
  void toggleTheme(Brightness current) =>
      setThemeMode(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);

  void setTargetLang(String code) {
    _targetLang = code;
    _put('targetLang', code);
    notifyListeners();
  }

  void setGeminiKey(String key) {
    _geminiKey = key.trim();
    _put('geminiKey', _geminiKey);
    notifyListeners();
  }

  void setGeminiModel(String model) {
    _geminiModel = model.trim().isEmpty ? 'gemini-2.5-flash' : model.trim();
    _put('geminiModel', _geminiModel);
    notifyListeners();
  }
}
