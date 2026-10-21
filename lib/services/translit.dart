/// Arabic (with harakat) → Latin transliteration, e.g.
///   بِسْمِ → bismi, ٱللَّهِ → allāhi, الشَّمْسُ → ash-shamsu, كَانُوا → kānū
///
/// Works best on fully vowelled text; letters without harakat are still
/// transliterated, just without vowels.
library;

const _fatha = 'َ', _kasra = 'ِ', _damma = 'ُ', _sukun = 'ْ', _shadda = 'ّ';
const _fathatan = 'ً', _kasratan = 'ٍ', _dammatan = 'ٌ', _dagger = 'ٰ';
const _marks = {_fatha, _kasra, _damma, _sukun, _shadda, _fathatan, _kasratan, _dammatan, _dagger, 'ـ'};

const _cons = {
  'ب': 'b', 'ت': 't', 'ث': 'th', 'ج': 'j', 'ح': 'h', 'خ': 'kh', 'د': 'd', 'ذ': 'dh', 'ر': 'r',
  'ز': 'z', 'س': 's', 'ش': 'sh', 'ص': 's', 'ض': 'd', 'ط': 't', 'ظ': 'z', 'ع': "'", 'غ': 'gh',
  'ف': 'f', 'ق': 'q', 'ك': 'k', 'ل': 'l', 'م': 'm', 'ن': 'n', 'ه': 'h', 'و': 'w', 'ي': 'y',
  'ء': "'", 'أ': "'", 'إ': "'", 'ؤ': "'", 'ئ': "'",
};
const _sun = 'تثدذرزسشصضطظلن';

class _L {
  _L(this.ch);
  String ch;
  final List<String> marks = [];
}

String _vowel(List<String> m) {
  if (m.contains(_fatha)) return 'a';
  if (m.contains(_kasra)) return 'i';
  if (m.contains(_damma)) return 'u';
  if (m.contains(_fathatan)) return 'an';
  if (m.contains(_kasratan)) return 'in';
  if (m.contains(_dammatan)) return 'un';
  if (m.contains(_dagger)) return 'ā';
  return '';
}

bool _endsWithVowel(String s) => s.isNotEmpty && 'aiuāīū'.contains(s[s.length - 1]);

String _translitWord(String word) {
  final t = <_L>[];
  for (final ch in word.split('')) {
    if (_marks.contains(ch)) {
      if (t.isNotEmpty) t.last.marks.add(ch);
    } else {
      t.add(_L(ch));
    }
  }
  var res = '';
  var i = 0;
  while (i < t.length) {
    final ch = t[i].ch;
    final m = t[i].marks;
    final nxt = i + 1 < t.length ? t[i + 1] : null;

    // Definite article (ا / ٱ) + ل
    if ((ch == 'ا' || ch == 'ٱ') && _vowel(m).isEmpty && nxt != null && nxt.ch == 'ل' && i + 2 < t.length) {
      final after = t[i + 2];
      final prefix = _endsWithVowel(res) ? '' : 'a';
      if (nxt.marks.contains(_shadda)) {
        // alladhī, allatī, allāh
        res += '${prefix}ll${_vowel(nxt.marks)}';
        i += 2;
        continue;
      }
      if (after.marks.contains(_shadda) && _sun.contains(after.ch) && _vowel(nxt.marks).isEmpty) {
        res += '$prefix${_cons[after.ch]}-';
        after.marks.remove(_shadda);
      } else {
        res += '${prefix}l-${_vowel(nxt.marks)}';
      }
      i += 2;
      continue;
    }
    // Wasla alif before a sukun letter: silent ("i" at word start)
    if ((ch == 'ا' || ch == 'ٱ') && _vowel(m).isEmpty && nxt != null && nxt.marks.contains(_sukun)) {
      if (i == 0) res += 'i';
      i++;
      continue;
    }
    if (ch == 'ا' || ch == 'ٱ') {
      final prevTanween = i > 0 && t[i - 1].marks.contains(_fathatan);
      if (prevTanween || res.endsWith('ū')) {
        // silent alif after -an or plural wāw
      } else if (res.endsWith('a')) {
        res = '${res.substring(0, res.length - 1)}ā';
      } else if (i == 0) {
        res += _vowel(m).isEmpty ? 'a' : _vowel(m);
      } else {
        res += _vowel(m);
      }
      i++;
      continue;
    }
    if (ch == 'آ') {
      res += i == 0 ? 'ā' : "'ā";
      i++;
      continue;
    }
    if (ch == 'ى') {
      if (i > 0 && t[i - 1].marks.contains(_fathatan)) {
        i++;
        continue;
      }
      res = res.endsWith('a') ? '${res.substring(0, res.length - 1)}ā' : '$resā';
      i++;
      continue;
    }
    if (ch == 'ة') {
      final v = _vowel(m);
      res += v.isEmpty ? 'h' : 't$v';
      i++;
      continue;
    }
    if (ch == 'ي' && _vowel(m).isEmpty && !m.contains(_shadda) && res.endsWith('i')) {
      res = '${res.substring(0, res.length - 1)}ī';
      i++;
      continue;
    }
    if (ch == 'و' && _vowel(m).isEmpty && !m.contains(_shadda) && res.endsWith('u')) {
      res = '${res.substring(0, res.length - 1)}ū';
      i++;
      continue;
    }
    var c = _cons[ch];
    if (c == null) {
      i++;
      continue;
    }
    if ((ch == 'أ' || ch == 'إ') && i == 0) c = '';
    if (m.contains(_shadda) && c.isNotEmpty) c = c + c;
    res += c + _vowel(m);
    if (m.contains(_dagger) && !_vowel(m).endsWith('ā')) {
      res = res.endsWith('a') ? '${res.substring(0, res.length - 1)}ā' : '$resā';
    }
    i++;
  }
  res = res.replaceAll("''", "'").replaceAll('al-lah', 'allāh').replaceAll('l-lah', 'llāh');
  return res;
}

/// Transliterates every Arabic word in [text]; other characters are kept.
String arabicToLatin(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map(_translitWord).join(' ');
