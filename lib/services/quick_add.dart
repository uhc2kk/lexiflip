import 'tts_service.dart';
import 'translit.dart';

/// One parsed line of the quick-add box.
class QuickRow {
  const QuickRow(this.word, this.ipa, this.primary, this.secondary);
  final String word;
  final String ipa;
  final String primary;
  final String secondary;
}

final _separators = [
  RegExp(r'\t'),
  RegExp(r'\s*\|\s*'),
  RegExp(r'\s+[—–-]\s+'),
  RegExp(r'\s*;\s*'),
  RegExp(r'\s*=\s*'),
];

/// Parses lines like:
///   كِتَابٌ - kitob - book
///   book | kitob
///   قَلَمٌ ; qalamun ; qalam ; pen        (4 parts: word ; reading ; tr1 ; tr2)
/// 2 parts: word, translation · 3 parts: word, translation, 2nd translation
/// 4+ parts: word, reading, translation, 2nd translation.
/// Arabic words without a reading get one generated automatically.
List<QuickRow> parseQuickList(String text, {bool autoReading = true}) {
  final rows = <QuickRow>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim().replaceFirst(RegExp(r'^\d+[.)]\s*'), '');
    if (line.isEmpty) continue;
    List<String> parts = [line];
    for (final sep in _separators) {
      final p = line.split(sep).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (p.length >= 2) {
        parts = p;
        break;
      }
    }
    String word = parts[0], ipa = '', primary = '', secondary = '';
    if (parts.length == 2) {
      primary = parts[1];
    } else if (parts.length == 3) {
      primary = parts[1];
      secondary = parts[2];
    } else if (parts.length >= 4) {
      ipa = parts[1];
      primary = parts[2];
      secondary = parts.sublist(3).join(' / ');
    }
    if (ipa.isEmpty && autoReading && detectScript(word) == WordScript.arabic) {
      ipa = arabicToLatin(word);
    }
    rows.add(QuickRow(word, ipa, primary, secondary));
  }
  return rows;
}
