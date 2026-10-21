import 'package:flutter/widgets.dart';

/// Word language shown in the 'missing voice' message.
enum WordScriptName { arabic, russian, english }

/// App interface languages.
enum AppLang {
  uz('O\'zbekcha'),
  en('English'),
  ru('Русский');

  const AppLang(this.label);
  final String label;

  static AppLang fromCode(String? code) =>
      AppLang.values.firstWhere((l) => l.name == code, orElse: () => AppLang.uz);
}

/// Provides [S] to the widget tree; rebuilds dependents when the language changes.
class L10nScope extends InheritedWidget {
  const L10nScope({super.key, required this.strings, required super.child});
  final S strings;

  @override
  bool updateShouldNotify(L10nScope old) => old.strings.lang != strings.lang;
}

/// All UI texts in O'zbekcha / English / Русский.
/// Usage: `final s = S.of(context);  Text(s.save)`
class S {
  const S(this.lang);
  final AppLang lang;

  static S of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<L10nScope>()?.strings ?? const S(AppLang.uz);

  String _t(String uz, String en, String ru) => switch (lang) {
        AppLang.uz => uz,
        AppLang.en => en,
        AppLang.ru => ru,
      };

  // ---------------- Common ----------------
  String get save => _t('Saqlash', 'Save', 'Сохранить');
  String get cancel => _t('Bekor qilish', 'Cancel', 'Отмена');
  String get yes => _t('Ha', 'Yes', 'Да');
  String get delete => _t('O\'chirish', 'Delete', 'Удалить');
  String get back => _t('Orqaga', 'Back', 'Назад');
  String get edit => _t('Tahrirlash', 'Edit', 'Изменить');
  String get create => _t('Yaratish', 'Create', 'Создать');
  String get search => _t('Qidirish', 'Search', 'Поиск');
  String get nothingFound => _t('Hech narsa topilmadi', 'Nothing found', 'Ничего не найдено');
  String get deleteQ => _t('O\'chirilsinmi?', 'Delete?', 'Удалить?');
  String get name => _t('Nomi', 'Name', 'Название');

  // ---------------- Home ----------------
  String get challengesTooltip =>
      _t('Challenge va yutuqlar', 'Challenges & achievements', 'Челленджи и достижения');
  String get themeTooltip => _t('Mavzu (yorug\'/qorong\'i)', 'Light / dark', 'Светлая / тёмная');
  String get importJson => _t('JSON import', 'Import JSON', 'Импорт JSON');
  String get exportAll => _t('Hammasini eksport', 'Export all', 'Экспорт всего');
  String get settings => _t('Sozlamalar', 'Settings', 'Настройки');
  String get deckFab => _t('To\'plam', 'Deck', 'Набор');
  String get newDeck => _t('Yangi to\'plam', 'New deck', 'Новый набор');
  String get noDecks => _t('Hali to\'plam yo\'q', 'No decks yet', 'Пока нет наборов');
  String get noDecksHint => _t(
      'Yangi to\'plam yarating yoki JSON faylni import qiling.',
      'Create a new deck or import a JSON file.',
      'Создайте новый набор или импортируйте JSON-файл.');
  String get noFolder => _t('Papkasiz', 'No folder', 'Без папки');
  String folderSubtitle(int decks, int learned, int total) => _t(
      '$decks ta to\'plam · $learned/$total yodlangan',
      '$decks decks · $learned/$total learned',
      'Наборов: $decks · выучено $learned/$total');
  String get addDeckToFolder =>
      _t('Bu papkaga to\'plam qo\'shish', 'Add deck to this folder', 'Добавить набор в папку');
  String get renameFolder =>
      _t('Papka nomini o\'zgartirish', 'Rename folder', 'Переименовать папку');
  String get folderName => _t('Papka nomi', 'Folder name', 'Название папки');
  String get nameAndFolder => _t('Nomi / papkasi', 'Name / folder', 'Название / папка');
  String get exportJson => _t('Eksport (JSON)', 'Export (JSON)', 'Экспорт (JSON)');
  String deckCounts(int learned, int problem, int review) => _t(
      '$learned yodlangan · $problem muammoli · $review qaytarish',
      '$learned learned · $problem problem · $review to review',
      'выучено $learned · проблемных $problem · повторить $review');
  String deleteDeckMsg(String name, int n) => _t(
      '"$name" va undagi $n ta so\'z o\'chiriladi.',
      '"$name" and its $n words will be deleted.',
      '«$name» и все слова ($n) будут удалены.');

  // ---------------- Daily goal ----------------
  String get goalDone => _t('Bugungi maqsad bajarildi!', 'Today\'s goal done!', 'Цель на сегодня выполнена!');
  String get goalToday => _t('Bugungi maqsad', 'Today\'s goal', 'Цель на сегодня');
  String goalProgress(int n, int goal) =>
      _t('$n / $goal ta so\'z', '$n / $goal words', '$n / $goal слов');
  String days(int n) => _t('$n kun', '$n days', '$n дн.');

  // ---------------- Deck form ----------------
  String get editDeck => _t('To\'plamni tahrirlash', 'Edit deck', 'Изменить набор');
  String get deckName => _t('To\'plam nomi', 'Deck name', 'Название набора');
  String get deckNameHint => _t('Masalan: Mavzu 1', 'e.g. Topic 1', 'Например: Тема 1');
  String get enterName => _t('Nom kiriting', 'Enter a name', 'Введите название');
  String get folderOptional => _t('Papka (ixtiyoriy)', 'Folder (optional)', 'Папка (необязательно)');
  String get folderHint => _t('Masalan: Arabcha', 'e.g. Arabic', 'Например: Арабский');

  // ---------------- Deck screen ----------------
  String get learned => _t('Yodlangan', 'Learned', 'Выучено');
  String get problem => _t('Muammoli', 'Problem', 'Проблемные');
  String get review => _t('Qaytarish', 'To review', 'Повторить');
  String practiceBtn(int n) => _t('Mashq qilish ($n)', 'Practice ($n)', 'Тренировка ($n)');
  String browseAllBtn(int n) => _t('Hammasini ko\'rish ($n)', 'Browse all ($n)', 'Просмотр всех ($n)');
  String get blitzTitle => _t('Tezkor raund', 'Speed round', 'Быстрый раунд');
  String get battleTitle => _t('Muammolilar jangi', 'Problem battle', 'Битва с трудными');
  String record(int n) => _t('Rekord: $n', 'Record: $n', 'Рекорд: $n');
  String get sixtySeconds => _t('60 soniya', '60 seconds', '60 секунд');
  String enemies(int n) => _t('$n ta dushman', '$n enemies', 'Врагов: $n');
  String get addWord => _t('So\'z qo\'shish', 'Add word', 'Добавить слово');
  String get resetProgress => _t('Natijalarni tozalash', 'Reset progress', 'Сбросить прогресс');
  String get resetProgressMsg => _t(
      'Barcha so\'zlar "Qaytarilishi kerak" bo\'limiga qaytadi.',
      'All words go back to "To review".',
      'Все слова вернутся в «Повторить».');
  String get reset => _t('Tozalash', 'Reset', 'Сбросить');
  String get deleteDeck => _t('To\'plamni o\'chirish', 'Delete deck', 'Удалить набор');
  String deleteDeckAllMsg(String name) => _t(
      '"$name" va undagi barcha so\'zlar o\'chiriladi.',
      '"$name" and all its words will be deleted.',
      '«$name» и все его слова будут удалены.');
  String get deckNotFound => _t('To\'plam topilmadi', 'Deck not found', 'Набор не найден');
  String get firstWord => _t('Birinchi so\'zni qo\'shish', 'Add the first word', 'Добавить первое слово');
  String countSuffix(int n) => _t('$n ta', '$n', '$n');
  String get changeBucket => _t('Bo\'limni o\'zgartirish', 'Change bucket', 'Сменить раздел');
  String get noProblemWords =>
      _t('Muammoli so\'z yo\'q — zo\'r!', 'No problem words — great!', 'Нет проблемных слов — отлично!');
  String get allLearned => _t(
      'Hamma so\'zlar yodlangan! "Hammasini ko\'rish"ni sinab ko\'ring.',
      'Everything is learned! Try "Browse all".',
      'Всё выучено! Попробуйте «Просмотр всех».');
  String get deckEmpty => _t('To\'plamda so\'z yo\'q.', 'This deck has no words.', 'В наборе нет слов.');

  // ---------------- Study ----------------
  String get modePractice => _t('Mashq', 'Practice', 'Тренировка');
  String get modeBattle => _t('⚔️ Muammolilar jangi', '⚔️ Problem battle', '⚔️ Битва с трудными');
  String get modeBlitz => _t('⏱️ Tezkor raund', '⏱️ Speed round', '⏱️ Быстрый раунд');
  String get modeBrowse => _t('Ko\'rib chiqish', 'Browse', 'Просмотр');
  String get finish => _t('Tugatish', 'Finish', 'Завершить');
  String get know => _t('Bilaman', 'I know', 'Знаю');
  String get dontKnow => _t('Bilmayman', 'Don\'t know', 'Не знаю');
  String get showMeaning => _t('Tarjimani ko\'rish', 'Show meaning', 'Показать перевод');
  String get showWord => _t('So\'zni ko\'rish', 'Show word', 'Показать слово');
  String get prev => _t('Oldingi (←)', 'Previous (←)', 'Назад (←)');
  String get next => _t('Keyingi (→)', 'Next (→)', 'Далее (→)');
  String get tapToStart => _t('Boshlash uchun kartani bosing', 'Tap the card to start', 'Нажмите на карточку');
  String enemiesLeft(int n) => _t('Dushmanlar: $n', 'Enemies: $n', 'Врагов: $n');
  String get keyHintBrowse => _t(
      'Space aylantirish · ← → o\'tish · P talaffuz',
      'Space flip · ← → move · P speak',
      'Space перевернуть · ← → листать · P озвучить');
  String get keyHintScored => _t(
      'Space aylantirish · ← / 1 bilmayman · → / 2 bilaman · P talaffuz',
      'Space flip · ← / 1 don\'t know · → / 2 know · P speak',
      'Space перевернуть · ← / 1 не знаю · → / 2 знаю · P озвучить');
  String get newRecord => _t('Yangi rekord!', 'New record!', 'Новый рекорд!');
  String get timeUp => _t('Vaqt tugadi', 'Time\'s up', 'Время вышло');
  String blitzResult(int n) => _t(
      '60 soniyada $n ta so\'z topdingiz', 'You knew $n words in 60 seconds', 'За 60 секунд: $n слов');
  String get victory => _t('G\'alaba!', 'Victory!', 'Победа!');
  String victoryMsg(int n) => _t(
      'Barcha $n ta muammoli so\'z yengildi', 'All $n problem words defeated', 'Все трудные слова ($n) побеждены');
  String get battleStopped => _t('Jang to\'xtatildi', 'Battle stopped', 'Битва остановлена');
  String battleProgress(int d, int n) =>
      _t('$d / $n ta dushman yengildi', '$d / $n enemies defeated', 'Побеждено $d / $n');
  String get practiceDone => _t('Mashq tugadi', 'Practice finished', 'Тренировка завершена');
  String practiceResult(int k, int u) => _t(
      '$k ta bildingiz · $u ta muammoli', '$k known · $u problem', 'Знаю: $k · проблемных: $u');
  String get repeatMissed =>
      _t('Bilmaganlarimni takrorlash', 'Repeat the ones I missed', 'Повторить невыученные');
  String get again => _t('Yana bir bor', 'Again', 'Ещё раз');
  String get noProblemLeft => _t('Muammoli so\'z qolmadi — zo\'r!', 'No problem words left — great!', 'Трудных слов не осталось!');
  String get allLearnedShort => _t('Hamma so\'zlar yodlangan!', 'All words learned!', 'Все слова выучены!');

  // ---------------- Card faces ----------------
  String get labelEnglish => _t('INGLIZCHA', 'ENGLISH', 'АНГЛИЙСКИЙ');
  String get labelArabic => _t('ARABCHA', 'ARABIC', 'АРАБСКИЙ');
  String get labelRussian => _t('RUSCHA', 'RUSSIAN', 'РУССКИЙ');
  String get labelMeaning => _t('TARJIMA', 'MEANING', 'ПЕРЕВОД');
  String get pronounce => _t('Talaffuz (P)', 'Pronounce (P)', 'Озвучить (P)');
  String get mnemonicHint =>
      _t('Eslatma / kalit so\'z…', 'Mnemonic / keyword…', 'Подсказка / ассоциация…');

  // ---------------- Editor ----------------
  String get newWord => _t('Yangi so\'z', 'New word', 'Новое слово');
  String get deck => _t('To\'plam', 'Deck', 'Набор');
  String get wordLabel => _t('So\'z (inglizcha / arabcha …)', 'Word (English / Arabic …)', 'Слово (англ. / араб. …)');
  String get enterWord => _t('So\'z kiriting', 'Enter a word', 'Введите слово');
  String get autofill => _t('Avto-to\'ldirish', 'Auto-fill', 'Автозаполнение');
  String autofillVia(String source, String lang) =>
      _t('Avto-to\'ldirish: $source → $lang', 'Auto-fill: $source → $lang', 'Автозаполнение: $source → $lang');
  String get autofillEnglishOnly => _t(
      'Avto-to\'ldirish faqat inglizcha so\'zlar uchun ishlaydi.',
      'Auto-fill works for English words only.',
      'Автозаполнение работает только для английских слов.');
  String get autofillPartial => _t(
      'Qisman to\'ldirildi — bo\'sh joylarni o\'zingiz yozing.',
      'Partially filled — complete the empty fields.',
      'Заполнено частично — допишите пустые поля.');
  String get ipaLabel => _t('O\'qilishi / IPA', 'Pronunciation / IPA', 'Произношение / IPA');
  String get primaryLabel => _t('Asosiy tarjima', 'Main translation', 'Основной перевод');
  String get secondaryLabel =>
      _t('Ikkinchi tarjima / sinonim', 'Second translation / synonym', 'Второй перевод / синоним');
  String get exampleLabel => _t('Misol gap', 'Example sentence', 'Пример');
  String get mnemonicLabel => _t('Eslatma / kalit so\'z', 'Mnemonic / keyword', 'Подсказка / ассоциация');
  String get mnemonicFieldHint =>
      _t('O\'zingizning eslab qolish usulingiz', 'Your own memory hook', 'Ваш способ запомнить');
  String get duplicateWord => _t('Takroriy so\'z', 'Duplicate word', 'Повтор слова');
  String duplicateWordMsg(String w) => _t(
      '"$w" bu to\'plamda allaqachon bor. Baribir saqlansinmi?',
      '"$w" is already in this deck. Save anyway?',
      '«$w» уже есть в наборе. Всё равно сохранить?');
  String wordAdded(String w) => _t('"$w" qo\'shildi', '"$w" added', '«$w» добавлено');
  String wordDeleteMsg(String w) => _t('"$w" o\'chiriladi.', '"$w" will be deleted.', '«$w» будет удалено.');

  // ---------------- Sync ----------------
  String get nothingToExport => _t('Eksport qilish uchun so\'z yo\'q.', 'Nothing to export.', 'Нечего экспортировать.');
  String exported(int n, String where) =>
      _t('$n ta so\'z saqlandi → $where', '$n words saved → $where', 'Сохранено слов: $n → $where');
  String exportError(Object e) => _t('Eksport xatosi: $e', 'Export failed: $e', 'Ошибка экспорта: $e');
  String get noWordsInFile => _t('Faylda so\'z topilmadi.', 'No words in this file.', 'В файле нет слов.');
  String importWords(int n) =>
      _t('$n ta so\'z import qilinadi', '$n words will be imported', 'Будет импортировано слов: $n');
  String get importBtn => _t('Import', 'Import', 'Импорт');
  String importDone(int a, int u, int s) => _t(
      'Import tayyor: $a ta yangi · $u ta yangilandi · $s ta o\'zgarmadi',
      'Imported: $a new · $u updated · $s unchanged',
      'Импорт: новых $a · обновлено $u · без изменений $s');
  String get invalidFile => _t('Noto\'g\'ri fayl — bu LexiFlip fayli emas.', 'Invalid file — not a LexiFlip deck.', 'Неверный файл — это не набор LexiFlip.');
  String importError(Object e) => _t('Import xatosi: $e', 'Import failed: $e', 'Ошибка импорта: $e');

  // ---------------- Challenges ----------------
  String get challengesTitle => _t('Challenge va yutuqlar', 'Challenges & achievements', 'Челленджи и достижения');
  String get last7Days => _t('Oxirgi 7 kun', 'Last 7 days', 'Последние 7 дней');
  String get overall => _t('Umumiy', 'Overall', 'Всего');
  String get statLearned => _t('yodlangan', 'learned', 'выучено');
  String get statProblem => _t('muammoli', 'problem', 'проблемных');
  String get statTotal => _t('jami so\'z', 'words', 'всего слов');
  String get statAnswers => _t('javob', 'answers', 'ответов');
  String get statBattles => _t('jang g\'alabasi', 'battle wins', 'побед в битвах');
  String get blitzRecords => _t('Tezkor raund rekordlari', 'Speed round records', 'Рекорды быстрого раунда');
  String get noRecords => _t(
      'Hali rekord yo\'q. To\'plamni ochib "Tezkor raund"ni boshlang!',
      'No records yet. Open a deck and start a "Speed round"!',
      'Рекордов пока нет. Откройте набор и начните «Быстрый раунд»!');
  String wordsCount(int n) => _t('$n ta', '$n', '$n');
  String achievementsTitle(int a, int b) => _t('Yutuqlar ($a / $b)', 'Achievements ($a / $b)', 'Достижения ($a / $b)');
  List<String> get weekdays => switch (lang) {
        AppLang.uz => const ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'],
        AppLang.en => const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
        AppLang.ru => const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
      };
  String get newAchievement => _t('Yangi yutuq!', 'New achievement!', 'Новое достижение!');

  String achievementTitle(String id) => switch (id) {
        'first_answer' => _t('Birinchi qadam', 'First step', 'Первый шаг'),
        'learned_10' => _t('10 ta so\'z', '10 words', '10 слов'),
        'learned_50' => _t('50 ta so\'z', '50 words', '50 слов'),
        'learned_100' => _t('100 ta so\'z', '100 words', '100 слов'),
        'learned_500' => _t('500 ta so\'z', '500 words', '500 слов'),
        'daily_goal' => _t('Maqsadga erishdim', 'Goal reached', 'Цель достигнута'),
        'streak_3' => _t('3 kun ketma-ket', '3-day streak', '3 дня подряд'),
        'streak_7' => _t('Bir hafta', 'One week', 'Неделя'),
        'streak_30' => _t('Bir oy', 'One month', 'Месяц'),
        'blitz_20' => _t('Tezkor', 'Quick', 'Быстрый'),
        'blitz_40' => _t('Chaqmoq', 'Lightning', 'Молния'),
        'battle_win' => _t('G\'olib', 'Winner', 'Победитель'),
        'battle_5' => _t('Jangchi', 'Warrior', 'Воин'),
        'deck_master' => _t('Mavzu ustasi', 'Deck master', 'Мастер набора'),
        _ => id,
      };

  String achievementDesc(String id) => switch (id) {
        'first_answer' => _t('Birinchi so\'zga javob berdingiz', 'Answered your first word', 'Первый ответ'),
        'learned_10' => _t('10 ta so\'z yodlandi', '10 words learned', 'Выучено 10 слов'),
        'learned_50' => _t('50 ta so\'z yodlandi', '50 words learned', 'Выучено 50 слов'),
        'learned_100' => _t('100 ta so\'z yodlandi', '100 words learned', 'Выучено 100 слов'),
        'learned_500' => _t('500 ta so\'z yodlandi', '500 words learned', 'Выучено 500 слов'),
        'daily_goal' => _t('Kunlik maqsad birinchi marta bajarildi', 'Daily goal reached for the first time', 'Дневная цель выполнена впервые'),
        'streak_3' => _t('Kunlik maqsad 3 kun ketma-ket bajarildi', 'Daily goal 3 days in a row', 'Цель 3 дня подряд'),
        'streak_7' => _t('Kunlik maqsad 7 kun ketma-ket bajarildi', 'Daily goal 7 days in a row', 'Цель 7 дней подряд'),
        'streak_30' => _t('Kunlik maqsad 30 kun ketma-ket bajarildi', 'Daily goal 30 days in a row', 'Цель 30 дней подряд'),
        'blitz_20' => _t('Tezkor raundda 20+ so\'z topildi', '20+ words in a speed round', '20+ слов в быстром раунде'),
        'blitz_40' => _t('Tezkor raundda 40+ so\'z topildi', '40+ words in a speed round', '40+ слов в быстром раунде'),
        'battle_win' => _t('Muammolilar jangida g\'alaba qozonildi', 'Won a problem battle', 'Победа в битве с трудными'),
        'battle_5' => _t('Muammolilar jangida 5 marta g\'alaba', '5 problem battle wins', '5 побед в битвах'),
        'deck_master' => _t('Bitta to\'plam 100% yodlandi', 'A deck is 100% learned', 'Набор выучен на 100%'),
        _ => '',
      };

  // ---------------- Settings ----------------
  String get appLanguage => _t('Ilova tili', 'App language', 'Язык приложения');
  String get cardDisplay => _t('Karta ko\'rinishi', 'Card display', 'Вид карточки');
  String get showPronunciation => _t('O\'qilishini ko\'rsatish', 'Show pronunciation', 'Показывать произношение');
  String get showPronunciationSub => _t('So\'z ostidagi lotincha o\'qilish / IPA', 'Transliteration / IPA under the word', 'Транслитерация / IPA под словом');
  String get showSecondary => _t('Ikkinchi tarjima', 'Second translation', 'Второй перевод');
  String get showSecondarySub => _t('Orqa tomondagi qo\'shimcha tarjima', 'Extra translation on the back', 'Дополнительный перевод на обороте');
  String get showMnemonic => _t('Eslatma maydoni', 'Mnemonic field', 'Поле подсказки');
  String get showMnemonicSub => _t('Orqa tomonda eslatma yozish joyi', 'Note field on the back', 'Поле для заметки на обороте');
  String get autoSpeak => _t('Avto-talaffuz', 'Auto-pronounce', 'Автоозвучка');
  String get autoSpeakSub => _t('Yangi karta chiqqanda so\'zni o\'qib beradi', 'Speaks the word when a new card appears', 'Озвучивает слово на новой карточке');
  String get dailyGoal => _t('Kunlik maqsad', 'Daily goal', 'Дневная цель');
  String perDay(int n) => _t('Kuniga $n ta so\'z', '$n words per day', '$n слов в день');
  String get appearance => _t('Ko\'rinish', 'Appearance', 'Оформление');
  String get themeSystem => _t('Tizim', 'System', 'Система');
  String get themeLight => _t('Yorug\'', 'Light', 'Светлая');
  String get themeDark => _t('Qorong\'i', 'Dark', 'Тёмная');
  String get autofillSection =>
      _t('Avto-to\'ldirish (inglizcha so\'zlar)', 'Auto-fill (English words)', 'Автозаполнение (англ. слова)');
  String get translateInto => _t('Tarjima tili', 'Translate into', 'Язык перевода');
  String get geminiInfo => _t(
      'Gemini kaliti bo\'lsa, tarjimalar sifatliroq bo\'ladi. Bo\'lmasa bepul Dictionary + MyMemory ishlatiladi. Kalit faqat shu qurilmada saqlanadi.',
      'With a Gemini key translations are better. Without it, the free Dictionary + MyMemory APIs are used. The key is stored only on this device.',
      'С ключом Gemini переводы точнее. Без него используются бесплатные Dictionary + MyMemory. Ключ хранится только на этом устройстве.');
  String get geminiKey => _t('Gemini API kaliti (ixtiyoriy)', 'Gemini API key (optional)', 'Ключ Gemini API (необязательно)');
  String get geminiModel => _t('Gemini modeli', 'Gemini model', 'Модель Gemini');
  String get geminiModelHelp => _t('masalan: gemini-2.5-flash', 'e.g. gemini-2.5-flash', 'например: gemini-2.5-flash');
  String get keyboard => _t('Klaviatura (kompyuter)', 'Keyboard (PC)', 'Клавиатура (ПК)');
  String get kFlip => _t('Kartani aylantirish', 'Flip card', 'Перевернуть карточку');
  String get kPronounce => _t('Talaffuz', 'Pronounce', 'Озвучить');
  String get kEsc => _t('Eslatma maydonidan chiqish', 'Leave the mnemonic field', 'Выйти из поля подсказки');

  String targetLangName(String code) => switch (lang) {
        AppLang.uz => const {
            'uz': 'O\'zbekcha', 'ru': 'Ruscha', 'ur': 'Urducha', 'tr': 'Turkcha', 'ar': 'Arabcha',
            'kk': 'Qozoqcha', 'tg': 'Tojikcha', 'hi': 'Hindcha', 'fa': 'Forscha', 'de': 'Nemischa',
            'fr': 'Fransuzcha', 'es': 'Ispancha', 'zh': 'Xitoycha', 'ja': 'Yaponcha', 'ko': 'Koreyscha',
          }[code],
        AppLang.en => const {
            'uz': 'Uzbek', 'ru': 'Russian', 'ur': 'Urdu', 'tr': 'Turkish', 'ar': 'Arabic',
            'kk': 'Kazakh', 'tg': 'Tajik', 'hi': 'Hindi', 'fa': 'Persian', 'de': 'German',
            'fr': 'French', 'es': 'Spanish', 'zh': 'Chinese', 'ja': 'Japanese', 'ko': 'Korean',
          }[code],
        AppLang.ru => const {
            'uz': 'Узбекский', 'ru': 'Русский', 'ur': 'Урду', 'tr': 'Турецкий', 'ar': 'Арабский',
            'kk': 'Казахский', 'tg': 'Таджикский', 'hi': 'Хинди', 'fa': 'Персидский', 'de': 'Немецкий',
            'fr': 'Французский', 'es': 'Испанский', 'zh': 'Китайский', 'ja': 'Японский', 'ko': 'Корейский',
          }[code],
      } ??
      code;

  // ---------------- TTS ----------------
  String missingVoiceTitle(String lang) => _t(
      '$lang ovoz o\'rnatilmagan', '$lang voice not installed', 'Голос ($lang) не установлен');
  String voiceLangName(WordScriptName s) => switch (s) {
        WordScriptName.arabic => _t('Arabcha', 'Arabic', 'Арабский'),
        WordScriptName.russian => _t('Ruscha', 'Russian', 'Русский'),
        WordScriptName.english => _t('Inglizcha', 'English', 'Английский'),
      };
  String get missingVoiceWindows => _t(
      'Windows\'da shu tildagi ovoz yo\'q.\n\n'
          '1. Settings (Win + I) → Time & language → Speech\n'
          '2. "Add voices" → tilni qidiring → Add\n'
          '3. LexiFlip\'ni yopib, qayta oching.\n\n'
          'Agar "Add voices" bo\'lmasa: Language & region → Add a language → '
          'o\'rnatishda "Text-to-speech" belgilang.',
      'Windows has no voice for this language.\n\n'
          '1. Settings (Win + I) → Time & language → Speech\n'
          '2. "Add voices" → search the language → Add\n'
          '3. Close and reopen LexiFlip.\n\n'
          'No "Add voices"? Language & region → Add a language → tick "Text-to-speech".',
      'В Windows нет голоса для этого языка.\n\n'
          '1. Параметры (Win + I) → Время и язык → Речь\n'
          '2. «Добавить голоса» → найдите язык → Добавить\n'
          '3. Закройте и снова откройте LexiFlip.\n\n'
          'Нет «Добавить голоса»? Язык и регион → Добавить язык → отметьте «Преобразование текста в речь».');
  String get missingVoiceAndroid => _t(
      'Telefonda shu tildagi ovoz yo\'q.\n\n'
          '1. Sozlamalar → "Matnni nutqqa aylantirish" (Text-to-speech) ni qidiring\n'
          '2. Afzal tizim: Google\n'
          '3. ⚙️ → Ovoz ma\'lumotlarini o\'rnatish → tilni yuklab oling.',
      'Your phone has no voice for this language.\n\n'
          '1. Settings → search "Text-to-speech"\n'
          '2. Preferred engine: Google\n'
          '3. ⚙️ → Install voice data → download the language.',
      'На телефоне нет голоса для этого языка.\n\n'
          '1. Настройки → найдите «Синтез речи»\n'
          '2. Система по умолчанию: Google\n'
          '3. ⚙️ → Установка голосовых данных → скачайте язык.');
  String get ok => _t('Tushunarli', 'Got it', 'Понятно');

  /// Default name for the deck old cards are moved into.
  String get generalDeck => _t('Umumiy', 'General', 'Общее');
}
