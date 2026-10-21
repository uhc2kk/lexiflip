import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Detects the script of a word so the card label and TTS voice match it.
enum WordScript { latin, arabic, cyrillic }

WordScript detectScript(String text) {
  for (final r in text.runes) {
    if ((r >= 0x0600 && r <= 0x06FF) ||
        (r >= 0x0750 && r <= 0x077F) ||
        (r >= 0x08A0 && r <= 0x08FF) ||
        (r >= 0xFB50 && r <= 0xFDFF) ||
        (r >= 0xFE70 && r <= 0xFEFF)) {
      return WordScript.arabic;
    }
    if (r >= 0x0400 && r <= 0x04FF) return WordScript.cyrillic;
  }
  return WordScript.latin;
}

String scriptLabel(String text) => switch (detectScript(text)) {
      WordScript.arabic => 'ARABCHA',
      WordScript.cyrillic => 'РУССКИЙ',
      WordScript.latin => 'ENGLISH',
    };

/// Thin wrapper around flutter_tts (Android, Web, Windows, macOS).
/// Picks the voice language from the word's script (English / Arabic /
/// Russian). On platforms without a TTS engine it fails silently.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String? _lang;

  Future<void> _init() async {
    if (_ready) return;
    try {
      // Android's scale is 0..1 (0.5 = normal); browsers use 1.0 = normal.
      await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
    _ready = true;
  }

  Future<void> _setLanguageFor(String text) async {
    final lang = switch (detectScript(text)) {
      WordScript.arabic => 'ar-SA',
      WordScript.cyrillic => 'ru-RU',
      WordScript.latin => 'en-US',
    };
    if (lang == _lang) return;
    try {
      await _tts.setLanguage(lang);
      _lang = lang;
    } catch (e) {
      debugPrint('TTS language $lang unavailable: $e');
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _init();
      await _setLanguageFor(text);
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS unavailable on this platform: $e');
    }
  }
}
