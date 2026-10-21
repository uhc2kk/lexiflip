import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/storage_service.dart';

/// Target languages offered for auto-fill translations (code -> name).
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
    T get<T>(String k, T d) {
      final v = box.get(k, defaultValue: d);
      return v is T ? v : d;
    }

    _themeMode = ThemeMode.values[
        get<int>('themeMode', ThemeMode.system.index).clamp(0, ThemeMode.values.length - 1)];
    _targetLang = get<String>('targetLang', 'uz');
    _geminiKey = get<String>('geminiKey', '');
    _geminiModel = get<String>('geminiModel', 'gemini-2.5-flash');
    _showPronunciation = get<bool>('showPronunciation', true);
    _showSecondary = get<bool>('showSecondary', true);
    _showMnemonic = get<bool>('showMnemonic', true);
    _autoSpeak = get<bool>('autoSpeak', false);
    _dailyGoal = get<int>('dailyGoal', 20);
    _appLang = AppLang.fromCode(get<String>('appLang', 'uz'));
  }

  late AppLang _appLang;
  AppLang get appLang => _appLang;
  S get strings => S(_appLang);

  void setAppLang(AppLang l) {
    _appLang = l;
    _put('appLang', l.name);
    notifyListeners();
  }

  late ThemeMode _themeMode;
  late String _targetLang;
  late String _geminiKey;
  late String _geminiModel;
  late bool _showPronunciation;
  late bool _showSecondary;
  late bool _showMnemonic;
  late bool _autoSpeak;
  late int _dailyGoal;

  ThemeMode get themeMode => _themeMode;
  String get targetLang => _targetLang;
  String get targetLangName => kTargetLanguages[_targetLang] ?? _targetLang;
  String get geminiKey => _geminiKey;
  String get geminiModel => _geminiModel;
  bool get hasGemini => _geminiKey.trim().isNotEmpty;

  /// Card display toggles.
  bool get showPronunciation => _showPronunciation;
  bool get showSecondary => _showSecondary;
  bool get showMnemonic => _showMnemonic;
  bool get autoSpeak => _autoSpeak;

  /// Answers per day needed to keep the streak.
  int get dailyGoal => _dailyGoal;

  Future<void> _put(String key, Object value) =>
      StorageService.settings.put(key, value);

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _put('themeMode', mode.index);
    notifyListeners();
  }

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

  void setShowPronunciation(bool v) {
    _showPronunciation = v;
    _put('showPronunciation', v);
    notifyListeners();
  }

  void setShowSecondary(bool v) {
    _showSecondary = v;
    _put('showSecondary', v);
    notifyListeners();
  }

  void setShowMnemonic(bool v) {
    _showMnemonic = v;
    _put('showMnemonic', v);
    notifyListeners();
  }

  void setAutoSpeak(bool v) {
    _autoSpeak = v;
    _put('autoSpeak', v);
    notifyListeners();
  }

  void setDailyGoal(int v) {
    _dailyGoal = v.clamp(5, 200);
    _put('dailyGoal', _dailyGoal);
    notifyListeners();
  }
}
