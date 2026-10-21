import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AutofillResult {
  const AutofillResult({
    this.ipa,
    this.primary,
    this.secondary,
    this.example,
  });

  final String? ipa;
  final String? primary;
  final String? secondary;
  final String? example;

  bool get isEmpty =>
      ipa == null && primary == null && secondary == null && example == null;
  bool get isComplete =>
      ipa != null && primary != null && secondary != null && example != null;

  /// Keeps current values, fills only what is still missing from [other].
  AutofillResult fillGapsFrom(AutofillResult other) => AutofillResult(
        ipa: ipa ?? other.ipa,
        primary: primary ?? other.primary,
        secondary: secondary ?? other.secondary,
        example: example ?? other.example,
      );
}

class AutofillException implements Exception {
  AutofillException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Fetches IPA, 2 translations and 1 example sentence for an English word.
///
/// Strategy:
///  1. Gemini API (if a key is set in Settings) — does everything in one call.
///  2. Free Dictionary API (dictionaryapi.dev) — IPA, example, English synonym.
///  3. MyMemory (free, no key) — translations into the target language.
/// Each step only fills fields the previous ones left empty.
class AutofillService {
  AutofillService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  void dispose() => _client.close();

  Future<AutofillResult> fetch(
    String word, {
    required String targetLangCode,
    required String targetLangName,
    String? geminiKey,
    String geminiModel = 'gemini-2.5-flash',
  }) async {
    final w = word.trim();
    if (w.isEmpty) throw AutofillException('Type a word first.');

    var result = const AutofillResult();
    final errors = <String>[];

    if (geminiKey != null && geminiKey.trim().isNotEmpty) {
      try {
        result = await _fromGemini(
            w, targetLangName, geminiKey.trim(), geminiModel.trim());
      } catch (e) {
        errors.add('Gemini: $e');
      }
    }

    String? englishSynonym;
    if (result.ipa == null || result.example == null || result.secondary == null) {
      try {
        final dict = await _fromDictionary(w);
        englishSynonym = dict.secondary;
        result = result.fillGapsFrom(
          AutofillResult(ipa: dict.ipa, example: dict.example),
        );
      } catch (e) {
        errors.add('Dictionary: $e');
      }
    }

    if (result.primary == null || result.secondary == null) {
      try {
        result = result.fillGapsFrom(await _fromMyMemory(w, targetLangCode));
      } catch (e) {
        errors.add('Translation: $e');
      }
    }

    // Still no second translation? Use an English context synonym.
    if (result.secondary == null && englishSynonym != null) {
      result = result.fillGapsFrom(
        AutofillResult(secondary: '≈ $englishSynonym'),
      );
    }

    if (result.isEmpty) {
      throw AutofillException(
        errors.isEmpty ? 'Nothing found for "$w".' : errors.join('\n'),
      );
    }
    return result;
  }

  // ---------------- Gemini ----------------

  Future<AutofillResult> _fromGemini(
    String word,
    String langName,
    String key,
    String model,
  ) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${model.isEmpty ? 'gemini-2.5-flash' : model}:generateContent',
    );
    final prompt = '''
You are a bilingual lexicographer. For the English word or phrase "$word" return ONLY a JSON object with these keys:
"ipa": General American IPA transcription between slashes,
"primary": the most common $langName translation,
"secondary": a second, different $langName translation or a contextual synonym in $langName,
"example": one natural English example sentence using "$word" (max 20 words).
''';

    final res = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': key,
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.2,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw AutofillException('HTTP ${res.statusCode}');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final candidates = body['candidates'] as List? ?? const [];
    final parts = candidates.isEmpty
        ? const []
        : (((candidates.first as Map)['content'] as Map?)?['parts'] as List? ??
            const []);
    final text = parts
        .whereType<Map>()
        .map((p) => (p['text'] ?? '').toString())
        .join();
    if (text.trim().isEmpty) throw AutofillException('empty response');

    final cleaned = text
        .replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '')
        .replaceAll('```', '')
        .trim();
    final json = jsonDecode(cleaned) as Map<String, dynamic>;

    return AutofillResult(
      ipa: _ipa(_nonEmpty(json['ipa'])),
      primary: _nonEmpty(json['primary']),
      secondary: _nonEmpty(json['secondary']),
      example: _nonEmpty(json['example']),
    );
  }

  // ---------------- Free Dictionary API ----------------

  /// Returns ipa, example, and an English synonym in `secondary`.
  Future<AutofillResult> _fromDictionary(String word) async {
    final uri = Uri.parse(
      'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word.toLowerCase())}',
    );
    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode == 404) return const AutofillResult();
    if (res.statusCode != 200) throw AutofillException('HTTP ${res.statusCode}');

    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! List) return const AutofillResult();

    String? ipa, example, synonym;
    for (final entry in data.whereType<Map>()) {
      ipa ??= _nonEmpty(entry['phonetic']);
      for (final p in (entry['phonetics'] as List? ?? const []).whereType<Map>()) {
        ipa ??= _nonEmpty(p['text']);
      }
      for (final m in (entry['meanings'] as List? ?? const []).whereType<Map>()) {
        for (final d in (m['definitions'] as List? ?? const []).whereType<Map>()) {
          example ??= _nonEmpty(d['example']);
          final syns = d['synonyms'] as List?;
          if (synonym == null && syns != null && syns.isNotEmpty) {
            synonym = syns.first.toString();
          }
        }
        final syns = m['synonyms'] as List?;
        if (synonym == null && syns != null && syns.isNotEmpty) {
          synonym = syns.first.toString();
        }
      }
    }
    return AutofillResult(ipa: _ipa(ipa), example: example, secondary: synonym);
  }

  // ---------------- MyMemory translation ----------------

  Future<AutofillResult> _fromMyMemory(String word, String lang) async {
    final uri = Uri.https('api.mymemory.translated.net', '/get', {
      'q': word,
      'langpair': 'en|$lang',
    });
    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode != 200) throw AutofillException('HTTP ${res.statusCode}');

    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final seen = <String>{};
    final out = <String>[];

    void add(Object? t) {
      final s = (t ?? '').toString().trim();
      if (s.isEmpty || s.length > 60) return;
      if (s.toLowerCase() == word.toLowerCase()) return;
      if (s.toUpperCase().contains('MYMEMORY')) return; // quota warnings
      if (seen.add(s.toLowerCase())) out.add(s);
    }

    add((json['responseData'] as Map?)?['translatedText']);
    for (final m in (json['matches'] as List? ?? const []).whereType<Map>()) {
      add(m['translation']);
    }

    return AutofillResult(
      primary: out.isNotEmpty ? out[0] : null,
      secondary: out.length > 1 ? out[1] : null,
    );
  }

  // ---------------- helpers ----------------

  static String? _nonEmpty(Object? v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _ipa(String? v) {
    if (v == null) return null;
    if (v.startsWith('/') || v.startsWith('[')) return v;
    return '/$v/';
  }
}
