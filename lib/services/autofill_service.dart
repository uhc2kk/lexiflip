import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'languages.dart';

class AutofillResult {
  const AutofillResult({
    this.ipa,
    this.primary,
    this.secondary,
    this.example,
    this.geminiError,
  });

  final String? ipa;
  final String? primary;
  final String? secondary;
  final String? example;

  /// Why Gemini failed, if it was tried and failed.
  final GeminiError? geminiError;

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
        geminiError: geminiError ?? other.geminiError,
      );

  AutofillResult withGeminiError(GeminiError? e) => AutofillResult(
        ipa: ipa,
        primary: primary,
        secondary: secondary,
        example: example,
        geminiError: e,
      );
}

/// Reasons Gemini can fail — shown to the user instead of silently
/// falling back to the free services.
enum GeminiError { badKey, quota, network, badModel, other }

class AutofillException implements Exception {
  AutofillException(this.message, {this.geminiError});
  final String message;
  final GeminiError? geminiError;
  @override
  String toString() => message;
}

class _GeminiFailure implements Exception {
  _GeminiFailure(this.kind, this.detail);
  final GeminiError kind;
  final String detail;
  @override
  String toString() => detail;
}

/// Fills reading, 2 translations and an example for a word in ANY language,
/// using the languages chosen for the deck (nothing is guessed).
///
/// Strategy:
///  1. Gemini API (if a key is set in Settings) — does everything in one call.
///  2. Free Dictionary API (English words only) — IPA, example, synonym.
///  3. MyMemory (free, no key) — translations. Results written in the wrong
///     script (e.g. Cyrillic text for Uzbek) are thrown away.
/// Each step only fills fields the previous ones left empty.
class AutofillService {
  AutofillService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 15);

  void dispose() => _client.close();

  Future<AutofillResult> fetch(
    String word, {
    required DeckLangs langs,
    String? geminiKey,
    String geminiModel = 'gemini-2.5-flash',
  }) async {
    final w = word.trim();
    if (w.isEmpty) throw AutofillException('Type a word first.');

    var result = const AutofillResult();
    final errors = <String>[];
    GeminiError? gError;

    if (geminiKey != null && geminiKey.trim().isNotEmpty) {
      try {
        result = await _fromGemini(w, langs, geminiKey.trim(), geminiModel.trim());
      } on _GeminiFailure catch (e) {
        gError = e.kind;
        errors.add('Gemini: ${e.detail}');
      } catch (e) {
        gError = GeminiError.other;
        errors.add('Gemini: $e');
      }
    }

    String? englishSynonym;
    if (langs.word == 'en' &&
        (result.ipa == null || result.example == null || result.secondary == null)) {
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
        final sameLang = langs.secondary == langs.primary;
        final first = await _fromMyMemory(w, langs.word, langs.primary);
        result = result.fillGapsFrom(AutofillResult(
          primary: first.isNotEmpty ? first[0] : null,
          secondary: sameLang && first.length > 1 ? first[1] : null,
        ));
        if (result.secondary == null && !sameLang && langs.secondary != langs.word) {
          final second = await _fromMyMemory(w, langs.word, langs.secondary);
          result = result.fillGapsFrom(
              AutofillResult(secondary: second.isNotEmpty ? second[0] : null));
        }
      } catch (e) {
        errors.add('Translation: $e');
      }
    }

    // English deck: the 2nd field can be an English synonym.
    if (result.secondary == null &&
        englishSynonym != null &&
        (langs.secondary == 'en' || langs.secondary == langs.primary)) {
      result = result.fillGapsFrom(AutofillResult(
        secondary: langs.secondary == 'en' ? englishSynonym : '≈ $englishSynonym',
      ));
    }

    if (result.isEmpty) {
      throw AutofillException(
        errors.isEmpty ? 'Nothing found for "$w".' : errors.join('\n'),
        geminiError: gError,
      );
    }
    return result.withGeminiError(gError);
  }

  // ---------------- Gemini ----------------

  Future<AutofillResult> _fromGemini(
    String word,
    DeckLangs langs,
    String key,
    String model,
  ) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${model.isEmpty ? 'gemini-2.5-flash' : model}:generateContent',
    );
    final wordName = langEnglishName(langs.word);
    final p1 = langEnglishName(langs.primary);
    final p2 = langEnglishName(langs.secondary);

    final ipaRule = switch (langs.word) {
      'en' => 'General American IPA transcription between slashes, e.g. /ˈwɔːtər/',
      'ar' => 'Latin transliteration that follows the harakat exactly: long vowels ā ī ū, '
          'an apostrophe for ع and ء, h for ح, kh for خ, sh for ش, th for ث, dh for ذ, '
          'gh for غ, q for ق, shadda doubles the letter, al- assimilates to sun letters '
          '(ash-shamsu), tanwin becomes an/in/un',
      _ => 'how to pronounce it: IPA between slashes for Latin-script languages, '
          'otherwise a standard Latin transliteration',
    };
    final secondRule = langs.secondary == langs.word
        ? 'a close synonym in $p2 (a different word)'
        : langs.secondary == langs.primary
            ? 'a second, different $p2 translation or contextual synonym'
            : 'the most common $p2 translation';

    final prompt = 'You are a bilingual lexicographer. The word or phrase "$word" is $wordName.\n'
        'Return ONLY a JSON object with these keys:\n'
        '"ipa": $ipaRule,\n'
        '"primary": the most common $p1 translation (1-4 words),\n'
        '"secondary": $secondRule (1-4 words),\n'
        '"example": one natural $wordName example sentence using "$word" (max 20 words).\n'
        'Write "primary" strictly in $p1 and "secondary" strictly in $p2.';

    final http.Response res;
    try {
      res = await _client
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
    } on TimeoutException {
      throw _GeminiFailure(GeminiError.network, 'timeout');
    } catch (e) {
      throw _GeminiFailure(GeminiError.network, e.toString());
    }

    if (res.statusCode != 200) {
      final err = utf8.decode(res.bodyBytes);
      final GeminiError kind;
      if (res.statusCode == 429) {
        kind = GeminiError.quota;
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        kind = GeminiError.badKey;
      } else if (res.statusCode == 404) {
        kind = GeminiError.badModel;
      } else if (res.statusCode == 400 && err.toLowerCase().contains('api key')) {
        kind = GeminiError.badKey;
      } else {
        kind = GeminiError.other;
      }
      throw _GeminiFailure(kind, 'HTTP ${res.statusCode}');
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
    if (text.trim().isEmpty) throw _GeminiFailure(GeminiError.other, 'empty response');

    final cleaned = text
        .replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '')
        .replaceAll('```', '')
        .trim();
    final json = jsonDecode(cleaned) as Map<String, dynamic>;

    final ipa = _nonEmpty(json['ipa']);
    return AutofillResult(
      ipa: langs.word == 'en' ? _ipa(ipa) : ipa,
      primary: _nonEmpty(json['primary']),
      secondary: _nonEmpty(json['secondary']),
      example: _nonEmpty(json['example']),
    );
  }

  // ---------------- Free Dictionary API (English only) ----------------

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

  /// Distinct translations of [word] from [from] into [to] — only those
  /// written in the right script for [to].
  Future<List<String>> _fromMyMemory(String word, String from, String to) async {
    if (from == to) return const [];
    final uri = Uri.https('api.mymemory.translated.net', '/get', {
      'q': word,
      'langpair': '$from|$to',
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
      if (!matchesScript(s, to)) return; // e.g. Russian text for Uzbek
      if (seen.add(s.toLowerCase())) out.add(s);
    }

    add((json['responseData'] as Map?)?['translatedText']);
    for (final m in (json['matches'] as List? ?? const []).whereType<Map>()) {
      add(m['translation']);
    }
    return out;
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
