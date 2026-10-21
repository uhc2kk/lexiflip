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

/// Result of a [TtsService.speak] call.
enum SpeakResult { ok, missingVoice, unavailable }

/// Thin wrapper around flutter_tts (Android, Web, Windows, macOS).
///
/// Picks a voice that matches the word's script (English / Arabic /
/// Russian). It looks through the installed voices for ANY voice of that
/// language (ar-SA, ar-EG, …), so it works whichever variant is installed.
/// If none is installed it returns [SpeakResult.missingVoice] instead of
/// silently reading Arabic with an English voice.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String? _lang; // language prefix currently set: 'en' | 'ar' | 'ru'
  List<Map<String, String>>? _voices;

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

  Future<List<Map<String, String>>> _installedVoices() async {
    if (_voices != null) return _voices!;
    try {
      final raw = await _tts.getVoices;
      _voices = [
        if (raw is List)
          for (final v in raw)
            if (v is Map)
              {
                'name': (v['name'] ?? '').toString(),
                'locale': (v['locale'] ?? '').toString(),
              },
      ];
    } catch (e) {
      debugPrint('TTS getVoices failed: $e');
      _voices = const [];
    }
    return _voices!;
  }

  /// The deck language wins, unless the text is plainly in another script
  /// (e.g. an Arabic word in a deck marked English).
  static String _prefixForText(String text, String? lang) {
    final script = detectScript(text);
    if (lang == null || lang.isEmpty) return _prefixFor(script);
    if (script == WordScript.arabic && !const {'ar', 'fa', 'ur'}.contains(lang)) return 'ar';
    if (script == WordScript.cyrillic && !const {'ru', 'kk', 'ky', 'tg'}.contains(lang)) return 'ru';
    return lang;
  }

  static String _prefixFor(WordScript s) => switch (s) {
        WordScript.arabic => 'ar',
        WordScript.cyrillic => 'ru',
        WordScript.latin => 'en',
      };

  static String _defaultLocale(String prefix) => switch (prefix) {
        'ar' => 'ar-SA',
        'ru' => 'ru-RU',
        'en' => 'en-US',
        'tr' => 'tr-TR',
        'de' => 'de-DE',
        'fr' => 'fr-FR',
        'es' => 'es-ES',
        'it' => 'it-IT',
        _ => prefix,
      };

  /// Chooses a voice for [prefix]. Returns false if the device has voices
  /// but none in that language.
  Future<bool> _useLanguage(String prefix) async {
    if (_lang == prefix) return true;
    final voices = await _installedVoices();
    final matching = voices
        .where((v) => v['locale']!.toLowerCase().replaceAll('_', '-').startsWith(prefix))
        .toList();

    if (voices.isNotEmpty && matching.isEmpty) return false;

    try {
      if (matching.isNotEmpty) {
        // Prefer the common locale (ar-SA / en-US / ru-RU) if present.
        final want = _defaultLocale(prefix).toLowerCase();
        final pick = matching.firstWhere(
          (v) => v['locale']!.toLowerCase().replaceAll('_', '-') == want,
          orElse: () => matching.first,
        );
        await _tts.setVoice({'name': pick['name']!, 'locale': pick['locale']!});
      } else {
        // Voice list unknown on this platform → fall back to language code.
        final r = await _tts.setLanguage(_defaultLocale(prefix));
        if (r == 0) return false;
      }
    } catch (e) {
      debugPrint('TTS voice for $prefix failed: $e');
    }
    _lang = prefix;
    return true;
  }

  /// Forget cached voices (e.g. after the user installed a new voice).
  void refreshVoices() {
    _voices = null;
    _lang = null;
  }

  /// [lang] = the deck's word language (ISO code). Without it the voice is
  /// chosen from the script (Arabic / Cyrillic / Latin → English).
  Future<SpeakResult> speak(String text, {String? lang}) async {
    if (text.trim().isEmpty) return SpeakResult.ok;
    try {
      await _init();
      final prefix = _prefixForText(text, lang);
      if (!await _useLanguage(prefix)) {
        refreshVoices(); // check again next time — user may install it
        return SpeakResult.missingVoice;
      }
      await _tts.stop();
      await _tts.speak(text);
      return SpeakResult.ok;
    } catch (e) {
      debugPrint('TTS unavailable on this platform: $e');
      return SpeakResult.unavailable;
    }
  }
}
