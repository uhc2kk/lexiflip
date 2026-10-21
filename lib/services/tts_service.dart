import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around flutter_tts (Android, Web, Windows, macOS).
/// On platforms without a TTS engine it fails silently.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('en-US');
      // Android's scale is 0..1 (0.5 = normal); browsers use 1.0 = normal.
      await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
    _ready = true;
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS unavailable on this platform: $e');
    }
  }
}
