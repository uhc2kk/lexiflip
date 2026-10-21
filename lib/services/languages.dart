/// Languages the user can pick for a deck: the word's language and the two
/// translation languages. Order = order shown in every language menu:
/// the 4 main ones first, then the rest alphabetically (by English name).
class Language {
  const Language(this.code, this.en, this.uz, this.ru, this.script);

  /// ISO 639-1 code, also used for MyMemory and TTS ('en', 'ar', 'uz' …).
  final String code;
  final String en;
  final String uz;
  final String ru;

  /// Script a correct translation INTO this language must be written in.
  final LangScript script;
}

enum LangScript { latin, cyrillic, arabic, other }

const List<Language> kLanguages = [
  Language('uz', 'Uzbek', 'O\'zbekcha', 'Узбекский', LangScript.latin),
  Language('en', 'English', 'Inglizcha', 'Английский', LangScript.latin),
  Language('ru', 'Russian', 'Ruscha', 'Русский', LangScript.cyrillic),
  Language('ar', 'Arabic', 'Arabcha', 'Арабский', LangScript.arabic),
  // ---- alphabetical ----
  Language('zh', 'Chinese', 'Xitoycha', 'Китайский', LangScript.other),
  Language('fr', 'French', 'Fransuzcha', 'Французский', LangScript.latin),
  Language('de', 'German', 'Nemischa', 'Немецкий', LangScript.latin),
  Language('hi', 'Hindi', 'Hindcha', 'Хинди', LangScript.other),
  Language('it', 'Italian', 'Italyancha', 'Итальянский', LangScript.latin),
  Language('ja', 'Japanese', 'Yaponcha', 'Японский', LangScript.other),
  Language('kk', 'Kazakh', 'Qozoqcha', 'Казахский', LangScript.cyrillic),
  Language('ko', 'Korean', 'Koreyscha', 'Корейский', LangScript.other),
  Language('ky', 'Kyrgyz', 'Qirg\'izcha', 'Киргизский', LangScript.cyrillic),
  Language('fa', 'Persian', 'Forscha', 'Персидский', LangScript.arabic),
  Language('es', 'Spanish', 'Ispancha', 'Испанский', LangScript.latin),
  Language('tg', 'Tajik', 'Tojikcha', 'Таджикский', LangScript.cyrillic),
  Language('tr', 'Turkish', 'Turkcha', 'Турецкий', LangScript.latin),
  Language('tk', 'Turkmen', 'Turkmancha', 'Туркменский', LangScript.latin),
  Language('ur', 'Urdu', 'Urducha', 'Урду', LangScript.arabic),
];

Language? languageByCode(String? code) {
  for (final l in kLanguages) {
    if (l.code == code) return l;
  }
  return null;
}

/// English name (used inside the Gemini prompt).
String langEnglishName(String code) => languageByCode(code)?.en ?? code;

/// True if [text] looks like it is written in the script expected for [code].
/// Used to throw away wrong-language results (e.g. Russian text returned
/// for an Uzbek translation by the free MyMemory service).
bool matchesScript(String text, String code) {
  final expected = languageByCode(code)?.script ?? LangScript.other;
  if (expected == LangScript.other) return true;
  var latin = 0, cyr = 0, arab = 0;
  for (final r in text.runes) {
    if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A) || (r >= 0xC0 && r <= 0x24F)) {
      latin++;
    } else if (r >= 0x0400 && r <= 0x04FF) {
      cyr++;
    } else if ((r >= 0x0600 && r <= 0x06FF) || (r >= 0x0750 && r <= 0x077F) ||
        (r >= 0xFB50 && r <= 0xFDFF) || (r >= 0xFE70 && r <= 0xFEFF)) {
      arab++;
    }
  }
  return switch (expected) {
    LangScript.latin => latin > 0 && cyr == 0 && arab == 0,
    LangScript.cyrillic => cyr > 0 && arab == 0,
    LangScript.arabic => arab > 0 && cyr == 0,
    LangScript.other => true,
  };
}

/// The three languages of a deck.
class DeckLangs {
  const DeckLangs({required this.word, required this.primary, required this.secondary});

  /// Language the words are written in.
  final String word;

  /// Language of the 1st translation.
  final String primary;

  /// Language of the 2nd translation. Same as [word] → a synonym;
  /// same as [primary] → a second, different translation.
  final String secondary;
}
