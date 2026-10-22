import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'quick_add.dart';
import 'translit.dart';
import 'tts_service.dart';

class PdfVocabException implements Exception {
  PdfVocabException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Result of reading a PDF: the words, and whether the answer was cut off
/// (very large books — the user should then narrow it down with a note).
class PdfVocabResult {
  const PdfVocabResult(this.rows, {this.truncated = false});
  final List<QuickRow> rows;
  final bool truncated;
}

/// Sends a PDF to Gemini and gets the vocabulary back as flashcards.
///
/// PDF text layers often break Arabic (letters swapped, harakat lost), so the
/// model is told to read the page images.
class PdfVocabService {
  PdfVocabService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// Gemini accepts inline files up to ~20 MB per request.
  static const maxBytes = 19 * 1024 * 1024;

  void dispose() => _client.close();

  Future<PdfVocabResult> extract({
    required Uint8List pdf,
    required String apiKey,
    required String model,
    required String wordLanguage,
    required String primaryLanguage,
    required String secondaryLanguage,
    String note = '',
  }) async {
    if (pdf.length > maxBytes) {
      throw PdfVocabException('PDF > ${maxBytes ~/ (1024 * 1024)} MB');
    }
    final m = model.trim().isEmpty ? 'gemini-2.5-flash' : model.trim();
    final uri = Uri.https('generativelanguage.googleapis.com', '/v1beta/models/$m:generateContent');
    String nice(String l) => l == 'Uzbek' ? 'Uzbek (Latin script)' : l;
    final target = nice(primaryLanguage);
    final second = nice(secondaryLanguage);
    final secondRule = secondaryLanguage == wordLanguage
        ? 'a short $second synonym or explanation of the word'
        : secondaryLanguage == primaryLanguage
            ? 'a second, different $target translation (empty if there is none)'
            : 'the $second translation';

    final prompt = '''
You are building vocabulary flashcards from a textbook PDF.
The words are in $wordLanguage. Extract the vocabulary words this PDF teaches (word lists, glossaries, "new words" boxes, bilingual tables).
${note.trim().isEmpty ? '' : 'User instruction (follow it): ${note.trim()}\n'}
Rules:
- "word": the word exactly as printed, in its original script. For Arabic keep ALL harakat exactly as printed. Read them from the page image — the PDF text layer is often broken.
- "ipa": pronunciation in Latin letters. Arabic: transliteration from the harakat (ā ī ū; ' for ع and ء; kh, sh, th, dh, gh, q; shadda doubles the letter; al- assimilates to sun letters, e.g. ash-shamsu; tanween an/in/un). English: IPA between slashes. Other non-Latin scripts: standard romanization.
- "primaryTranslation": translation into $target. If the book already gives a $target translation, copy it exactly.
- "secondaryTranslation": $secondRule.
- Keep the book's order. Do not skip words. Do not invent words that are not in the PDF. Merge exact duplicates.
- Translations are short: 1–4 words, alternatives separated by " / ".
Return ONLY a JSON array:
[{"word":"...","ipa":"...","primaryTranslation":"...","secondaryTranslation":"..."}]
''';

    final generationConfig = <String, dynamic>{
      'temperature': 0.1,
      'responseMimeType': 'application/json',
      'maxOutputTokens': 65536,
      // Flash models can skip "thinking" — faster and leaves room for output.
      if (m.contains('flash')) 'thinkingConfig': {'thinkingBudget': 0},
    };

    final http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey.trim()},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'inlineData': {'mimeType': 'application/pdf', 'data': base64Encode(pdf)}
                    },
                    {'text': prompt},
                  ]
                }
              ],
              'generationConfig': generationConfig,
            }),
          )
          .timeout(const Duration(minutes: 6));
    } catch (e) {
      throw PdfVocabException('$e');
    }

    final body = _tryJson(utf8.decode(res.bodyBytes, allowMalformed: true));
    if (res.statusCode != 200) {
      final msg = (body is Map ? (body['error'] as Map?)?['message'] : null) ?? 'HTTP ${res.statusCode}';
      throw PdfVocabException(msg.toString());
    }

    final candidates = (body is Map ? body['candidates'] : null) as List? ?? const [];
    if (candidates.isEmpty) throw PdfVocabException('Empty response');
    final first = candidates.first as Map;
    final finish = (first['finishReason'] ?? '').toString();
    final parts = ((first['content'] as Map?)?['parts'] as List?) ?? const [];
    final text = parts.whereType<Map>().map((p) => (p['text'] ?? '').toString()).join();

    final (list, cut) = _parseArray(text);
    final rows = <QuickRow>[];
    for (final item in list.whereType<Map>()) {
      final word = (item['word'] ?? '').toString().trim();
      if (word.isEmpty) continue;
      var ipa = (item['ipa'] ?? '').toString().trim();
      if (ipa.isEmpty && detectScript(word) == WordScript.arabic) ipa = arabicToLatin(word);
      rows.add(QuickRow(
        word,
        ipa,
        (item['primaryTranslation'] ?? '').toString().trim(),
        (item['secondaryTranslation'] ?? '').toString().trim(),
      ));
    }
    return PdfVocabResult(rows, truncated: cut || finish == 'MAX_TOKENS');
  }

  static Object? _tryJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  /// Parses the model's JSON array; salvages a cut-off answer by closing it
  /// after the last complete object.
  static (List, bool) _parseArray(String text) {
    var s = text.trim();
    s = s.replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '').replaceAll('```', '').trim();
    final whole = _tryJson(s);
    if (whole is List) return (whole, false);
    if (whole is Map && whole['cards'] is List) return (whole['cards'] as List, false);
    final start = s.indexOf('[');
    final end = s.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final fixed = _tryJson('${s.substring(start, end + 1)}]');
      if (fixed is List) return (fixed, true);
    }
    throw PdfVocabException('Could not read the answer');
  }
}
