import 'package:flutter/widgets.dart';

import '../models/gamification.dart';
import '../services/languages.dart';

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
      'Space aylantirish · ← / 1 bilmayman · → / 2 bilaman · P talaffuz · S ⭐',
      'Space flip · ← / 1 don\'t know · → / 2 know · P speak · S ⭐',
      'Space перевернуть · ← / 1 не знаю · → / 2 знаю · P озвучить · S ⭐');
  String get newRecord => _t('Yangi rekord!', 'New record!', 'Новый рекорд!');
  String get timeUp => _t('Vaqt tugadi', 'Time\'s up', 'Время вышло');
  String blitzResult(int n, int sec) => _t(
      '$sec soniyada $n ta so\'z topdingiz', 'You knew $n words in $sec seconds', 'За $sec секунд: $n слов');
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
  String get wordLabel => _t('So\'z', 'Word', 'Слово');
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
  // ---- Deck languages ----
  String get deckLanguages => _t('To\'plam tillari', 'Deck languages', 'Языки набора');
  String get langWord => _t('So\'z tili', 'Word language', 'Язык слов');
  String get langPrimary => _t('1-tarjima tili', '1st translation', '1-й перевод');
  String get langSecondary => _t('2-tarjima tili', '2nd translation', '2-й перевод');
  String get langSecondaryHint => _t(
      'So\'z tili bilan bir xil bo\'lsa — sinonim; 1-tarjima bilan bir xil bo\'lsa — boshqa tarjima.',
      'Same as word language → a synonym; same as 1st → another translation.',
      'Как язык слов → синоним; как 1-й перевод → другой вариант перевода.');
  String applyToFolder(String folder) => _t('"$folder" papkasidagi barcha to\'plamlarga',
      'All decks in "$folder"', 'Все наборы в «$folder»');
  String get changeLangs => _t('Tillarni o\'zgartirish', 'Change languages', 'Изменить языки');
  String get langsSaved => _t('Tillar saqlandi', 'Languages saved', 'Языки сохранены');
  String get defaultLangs => _t('Standart tillar (tili tanlanmagan to\'plamlar uchun)',
      'Default languages (for decks without their own)', 'Языки по умолчанию (для наборов без своих)');
  String get viaGemini => _t('Gemini', 'Gemini', 'Gemini');
  String get viaFree => _t('Bepul lug\'at (Gemini kaliti yo\'q)', 'Free dictionary (no Gemini key)',
      'Бесплатный словарь (нет ключа Gemini)');
  String get freeWeakHint => _t(
      'Gemini kalitisiz faqat tarjima topiladi, o\'qilishi va misol esa faqat inglizcha so\'zlarga. Kalitni Sozlamalarda kiriting.',
      'Without a Gemini key only translations are found; reading and example only for English. Add the key in Settings.',
      'Без ключа Gemini находится только перевод; чтение и пример — только для английского. Добавьте ключ в настройках.');
  String geminiFailed(String reason) => _t('Gemini ishlamadi: $reason.',
      'Gemini failed: $reason.', 'Gemini не сработал: $reason.');
  String get gErrBadKey => _t('API kaliti noto\'g\'ri', 'invalid API key', 'неверный API-ключ');
  String get gErrQuota => _t('bugungi limit tugadi', 'quota exceeded', 'лимит исчерпан');
  String get gErrNetwork => _t('internet yo\'q yoki javob kelmadi', 'no internet / timeout', 'нет интернета / тайм-аут');
  String get gErrModel => _t('model nomi noto\'g\'ri', 'wrong model name', 'неверное имя модели');
  String get gErrOther => _t('noma\'lum xato', 'unknown error', 'неизвестная ошибка');

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
  String get noRecords => _t('Hali rekord yo\'q', 'No records yet', 'Рекордов пока нет');
  String wordsCount(int n) => _t('$n ta', '$n', '$n');
  String achievementsTitle(int a, int b) => _t('Yutuqlar ($a / $b)', 'Achievements ($a / $b)', 'Достижения ($a / $b)');
  List<String> get weekdays => switch (lang) {
        AppLang.uz => const ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'],
        AppLang.en => const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
        AppLang.ru => const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
      };
  String get newAchievement => _t('Yangi yutuq!', 'New achievement!', 'Новое достижение!');

  // ---------------- v2: folders ----------------
  String get add => _t('Qo\'shish', 'Add', 'Добавить');
  String get newFolder => _t('Yangi papka', 'New folder', 'Новая папка');
  String get newSubfolder => _t('Yangi ichki papka', 'New sub-folder', 'Новая подпапка');
  String get rename => _t('Nomini o\'zgartirish', 'Rename', 'Переименовать');
  String get move => _t('Ko\'chirish', 'Move', 'Переместить');
  String get moveFolder => _t('Papkani ko\'chirish', 'Move folder', 'Переместить папку');
  String get cantMoveFolder => _t(
      'Ichida papkalari bor papkani boshqa papkaga ko\'chirib bo\'lmaydi (faqat 2 qavat).',
      'A folder with sub-folders can\'t go inside another folder (2 levels max).',
      'Папку с подпапками нельзя вложить в другую (максимум 2 уровня).');
  String deleteFolderMsg(String name, int decks, int words) => _t(
      '"$name" papkasi, undagi $decks ta to\'plam va $words ta so\'z o\'chiriladi.',
      'Folder "$name" with $decks decks and $words words will be deleted.',
      'Папка «$name», наборов: $decks, слов: $words — всё будет удалено.');
  String get select => _t('Tanlash', 'Select', 'Выбрать');
  String get selectHint => _t(
      'Birga mashq qilish uchun to\'plamlarni belgilang.',
      'Tick the decks you want to practise together.',
      'Отметьте наборы для совместной тренировки.');
  String practiceTogether(int n) => _t('Birga mashq ($n)', 'Practise together ($n)', 'Вместе ($n)');
  String get folders => _t('Papkalar', 'Folders', 'Папки');
  String get decks => _t('To\'plamlar', 'Decks', 'Наборы');
  String folderInfo(int subs, int decks, int learned, int total) => _t(
      '${subs > 0 ? '$subs ta papka · ' : ''}$decks ta to\'plam · $learned/$total yodlangan',
      '${subs > 0 ? '$subs folders · ' : ''}$decks decks · $learned/$total learned',
      '${subs > 0 ? 'папок: $subs · ' : ''}наборов: $decks · выучено $learned/$total');
  String practiceFolder(int n) =>
      _t('Butun papkani mashq qilish ($n)', 'Practise the whole folder ($n)', 'Тренировать всю папку ($n)');
  String get emptyFolder => _t('Papka bo\'sh', 'This folder is empty', 'Папка пуста');
  String get topLevel => _t('Asosiy sahifa (papkasiz)', 'Home (no folder)', 'Главная (без папки)');
  String get folder => _t('Papka', 'Folder', 'Папка');
  String get wholeFolder => _t('Butun papka', 'Whole folder', 'Вся папка');
  String selectedDecks(int n) => _t('Tanlangan $n ta to\'plam', '$n selected decks', 'Выбрано наборов: $n');
  String get importTitle => _t('Import', 'Import', 'Импорт');
  String fileFolderHint(String path) => _t(
      'Fayldagi papka: $path — papka tanlamasangiz, shu nom bilan yaratiladi.',
      'Folder in the file: $path — it will be created unless you pick a folder.',
      'Папка в файле: $path — будет создана, если не выбрать другую.');

  // ---------------- v2: starred ----------------
  String get starred => _t('Saralangan so\'zlar', 'Starred words', 'Избранные слова');
  String starredSub(int n) => n == 0
      ? _t('Kartadagi ⭐ ni bosing — so\'z shu yerga yig\'iladi', 'Tap ⭐ on a card to collect it here', 'Нажмите ⭐ на карточке, чтобы собрать её здесь')
      : _t('$n ta so\'z', '$n words', 'Слов: $n');
  String get starredEmpty => _t(
      'Hali saralangan so\'z yo\'q. Mashq paytida ⭐ (yoki S tugmasi) bilan belgilang.',
      'No starred words yet. Mark them with ⭐ (or the S key) while practising.',
      'Пока нет избранных. Отмечайте ⭐ (или клавишей S) во время тренировки.');
  String get starToggle => _t('Saralash', 'Star', 'В избранное');

  // ---------------- v2: modes ----------------
  String get challenges => _t('Challenge\'lar', 'Challenges', 'Челленджи');
  String secondsN(int n) => _t('$n soniya', '$n seconds', '$n секунд');
  String get lightningTitle => _t('Chaqmoq raund', 'Lightning round', 'Молния');
  String get perfectTitle => _t('Xatosiz seriya', 'No-mistake streak', 'Без ошибок');
  String get perfectSub => _t('Bitta xato — o\'yin tugadi', 'One mistake — game over', 'Одна ошибка — конец');
  String get bossTitle => _t('Boss jang', 'Boss battle', 'Битва с боссом');
  String get bossSub => _t('20 ta eng qiyin so\'z · 3 ❤️', '20 hardest words · 3 ❤️', '20 самых трудных · 3 ❤️');
  String bossNeeds(int n) => _t('Boss jang uchun kamida $n ta so\'z kerak.', 'Boss battle needs at least $n words.', 'Для босса нужно минимум $n слов.');
  String get perfectOver => _t('Seriya tugadi', 'Streak over', 'Серия окончена');
  String perfectResult(int n) => _t('Ketma-ket $n ta so\'zni xatosiz topdingiz', '$n words in a row without a mistake', '$n слов подряд без ошибок');
  String get bossWon => _t('Boss yengildi!', 'Boss defeated!', 'Босс повержен!');
  String bossWonMsg(int lives) => _t('$lives ta ❤️ bilan g\'alaba', 'Won with $lives ❤️ left', 'Победа, осталось ❤️: $lives');
  String get bossLost => _t('Boss yutdi…', 'The boss won…', 'Босс победил…');

  // ---------------- v2: levels & quests ----------------
  String levelN(int n) => _t('$n-daraja', 'Level $n', 'Уровень $n');
  String levelUp(int n) => _t('Yangi daraja: $n!', 'Level up: $n!', 'Новый уровень: $n!');
  String nextRank(String emoji, String name, int level) =>
      _t('Keyingi: $emoji $name ($level)', 'Next: $emoji $name ($level)', 'Далее: $emoji $name ($level)');
  String rankName(String id) => switch (id) {
        'beginner' => _t('Boshlovchi', 'Beginner', 'Новичок'),
        'amateur' => _t('Havaskor', 'Amateur', 'Любитель'),
        'student' => _t('Talaba', 'Student', 'Студент'),
        'expert' => _t('Bilimdon', 'Know-it-all', 'Знаток'),
        'seeker' => _t('Tolib', 'Seeker', 'Искатель'),
        'scholar' => _t('Olim', 'Scholar', 'Учёный'),
        'master' => _t('Ustoz', 'Master', 'Мастер'),
        'sage' => _t('Alloma', 'Sage', 'Мудрец'),
        'wise' => _t('Donishmand', 'Grand sage', 'Великий мудрец'),
        'legend' => _t('Afsona', 'Legend', 'Легенда'),
        'eternal' => _t('Mangu', 'Eternal', 'Вечный'),
        _ => id,
      };
  String get dailyQuests => _t('Kunlik vazifalar', 'Daily quests', 'Задания дня');
  String get weeklyQuests => _t('Haftalik vazifalar', 'Weekly quests', 'Задания недели');
  String questTitle(QuestDef q) {
    final n = q.target;
    return switch (q.type) {
      QuestType.answers => _t('$n ta so\'zga javob ber', 'Answer $n words', 'Ответьте на $n слов'),
      QuestType.known => _t('$n marta "Bilaman"', '"I know" $n times', '«Знаю» $n раз'),
      QuestType.learnedNew => _t('$n ta yangi so\'z yodla', 'Learn $n new words', 'Выучите $n новых слов'),
      QuestType.blitzRounds => _t('$n ta tezkor raund o\'yna', 'Play $n speed rounds', 'Сыграйте $n быстрых раунда'),
      QuestType.battleWins => _t('Muammolilar jangida $n marta yut', 'Win $n problem battles', 'Победите в битве $n раз'),
      QuestType.defeated => _t('$n ta muammoli so\'zni yeng', 'Defeat $n problem words', 'Победите $n трудных слов'),
      QuestType.perfectRun => _t('Xatosiz seriyada $n ga yet', 'Reach $n in a no-mistake streak', 'Наберите $n без ошибок'),
      QuestType.bossWins => _t('Bossni $n marta yeng', 'Defeat the boss $n times', 'Победите босса $n раз'),
      QuestType.goalDays => _t('$n kun kunlik maqsadni bajar', 'Hit your daily goal on $n days', 'Выполните цель дня $n дней'),
    };
  }

  String achievementName(Metric m) => switch (m) {
        Metric.learnedWords => _t('Yodlangan so\'zlar', 'Words learned', 'Выученные слова'),
        Metric.streakDays => _t('Kunlik seriya', 'Daily streak', 'Серия дней'),
        Metric.totalAnswers => _t('Javoblar', 'Answers', 'Ответы'),
        Metric.blitzBest => _t('Tezkor raund rekordi', 'Speed round record', 'Рекорд быстрого раунда'),
        Metric.battleWins => _t('Jang g\'alabalari', 'Battle wins', 'Победы в битвах'),
        Metric.bossWins => _t('Boss g\'alabalari', 'Boss wins', 'Победы над боссом'),
        Metric.perfectBest => _t('Xatosiz seriya rekordi', 'No-mistake record', 'Рекорд без ошибок'),
        Metric.decksMastered => _t('100% to\'plamlar', '100% decks', 'Наборы на 100%'),
        Metric.questsDone => _t('Bajarilgan vazifalar', 'Quests done', 'Выполненные задания'),
        Metric.level => _t('Daraja', 'Level', 'Уровень'),
      };
  String get maxTier => _t('Eng yuqori bosqich! 👑', 'Max tier! 👑', 'Максимум! 👑');
  String get records => _t('Rekordlar', 'Records', 'Рекорды');
  String get statStreak => _t('kun seriya', 'day streak', 'дней подряд');
  String get statBosses => _t('boss g\'alabasi', 'boss wins', 'побед над боссом');
  String get statQuests => _t('vazifa', 'quests', 'заданий');

  // ---------------- v2.1 ----------------
  String get favouriteDecks => _t('Sevimli to\'plamlar', 'Favourite decks', 'Избранные наборы');
  String get favouriteDeck => _t('Sevimlilarga qo\'shish', 'Add to favourites', 'В избранное');
  String get unfavourite => _t('Sevimlilardan olish', 'Remove from favourites', 'Убрать из избранного');
  String get hardest => _t('Eng qiyin so\'zlar', 'Hardest words', 'Самые трудные слова');
  String hardestSub(int n) => _t('Eng ko\'p xato qilingan $n ta so\'z', 'Top $n most-missed words', 'Топ-$n слов с ошибками');
  String get hardestEmptyShort => _t('Hali xato yo\'q', 'No mistakes yet', 'Ошибок пока нет');
  String wordsN(int n) => _t('$n ta so\'z', '$n words', 'Слов: $n');
  String inDays(int n) => n <= 0
      ? _t('bugun', 'today', 'сегодня')
      : _t('$n kunda', 'in $n d', 'через $n дн.');
  String get quickAdd => _t('Tez qo\'shish', 'Quick add', 'Быстрое добавление');
  String get quickAddHelp => _t(
      'Har qatorga bitta so\'z. Ajratuvchi: " - ", "|", ";", "=" yoki Tab.\n'
          '2 qism: so\'z - tarjima · 3 qism: + ikkinchi tarjima · 4 qism: so\'z ; o\'qilishi ; tarjima ; tarjima 2',
      'One word per line. Separator: " - ", "|", ";", "=" or Tab.\n'
          '2 parts: word - translation · 3 parts: + 2nd translation · 4 parts: word ; reading ; translation ; translation 2',
      'Одно слово в строке. Разделитель: " - ", "|", ";", "=" или Tab.\n'
          '2 части: слово - перевод · 3: + второй перевод · 4: слово ; чтение ; перевод ; перевод 2');
  String get quickAddHint => _t('Ro\'yxatni shu yerga yopishtiring…', 'Paste your list here…', 'Вставьте список сюда…');
  String get autoReading => _t('O\'qilishini avtomatik yozish', 'Generate reading automatically', 'Автоматически писать чтение');
  String get autoReadingSub => _t(
      'Arabcha so\'zlar uchun harakatlardan lotincha o\'qilish',
      'Latin reading from harakat for Arabic words',
      'Латинское чтение по огласовкам для арабских слов');
  String preview(int n) => _t('Ko\'rinishi ($n ta)', 'Preview ($n)', 'Предпросмотр ($n)');
  String addN(int n) => _t('Qo\'shish ($n)', 'Add ($n)', 'Добавить ($n)');
  String quickAdded(int n, int skipped) => _t(
      '$n ta so\'z qo\'shildi${skipped > 0 ? ' · $skipped ta takror o\'tkazib yuborildi' : ''}',
      '$n words added${skipped > 0 ? ' · $skipped duplicates skipped' : ''}',
      'Добавлено: $n${skipped > 0 ? ' · пропущено повторов: $skipped' : ''}');
  String get readingFilled => _t(
      'Arabcha so\'z: o\'qilishi harakatlardan yozildi. Tarjimani o\'zingiz kiriting.',
      'Arabic word: reading generated from harakat. Please add the translation.',
      'Арабское слово: чтение создано по огласовкам. Добавьте перевод.');
  String get progress30 => _t('30 kunlik progress', '30-day progress', 'Прогресс за 30 дней');
  String thisWeek(int n) => _t('${n >= 0 ? '+' : ''}$n bu hafta', '${n >= 0 ? '+' : ''}$n this week', '${n >= 0 ? '+' : ''}$n за неделю');
  String daysAgo(int n) => _t('$n kun oldin', '$n days ago', '$n дн. назад');
  String get yearCalendar => _t('Yillik kalendar', 'Year calendar', 'Календарь года');
  String yearSummary(int days, int answers) =>
      _t('$days kun faol · $answers javob', '$days active days · $answers answers', 'Активных дней: $days · ответов: $answers');
  String get less => _t('Kam', 'Less', 'Мало');
  String get more => _t('Ko\'p', 'More', 'Много');
  String get arabicSection => _t('Arabcha yozuv', 'Arabic text', 'Арабский текст');
  String get arabicFont => _t('Kitob shrifti (Amiri)', 'Book font (Amiri)', 'Книжный шрифт (Amiri)');
  String wordSize(int pct) => _t('So\'z o\'lchami: $pct%', 'Word size: $pct%', 'Размер слова: $pct%');
  String get reminder => _t('Kunlik eslatma', 'Daily reminder', 'Ежедневное напоминание');
  String get reminderToggle => _t('Eslatmani yoqish', 'Turn on reminder', 'Включить напоминание');
  String get reminderSub => _t(
      'Kunlik maqsad bajarilmagan bo\'lsa, belgilangan soatda xabar keladi',
      'A notification at the chosen time if today\'s goal isn\'t done yet',
      'Уведомление в выбранное время, если цель дня не выполнена');
  String get reminderUnsupported => _t(
      'Bu qurilmada mavjud emas (faqat Windows va Android)',
      'Not available on this device (Windows and Android only)',
      'Недоступно на этом устройстве (только Windows и Android)');
  String get reminderTime => _t('Eslatma vaqti', 'Reminder time', 'Время напоминания');
  String get reminderDenied => _t(
      'Bildirishnomaga ruxsat berilmadi. Telefon sozlamalaridan LexiFlip\'ga ruxsat bering.',
      'Notification permission denied. Allow it for LexiFlip in system settings.',
      'Нет разрешения на уведомления. Разрешите их для LexiFlip в настройках.');
  String get reminderBody => _t(
      'Bugun hali mashq qilmadingiz — 5 daqiqa ajrating! 📚',
      'You haven\'t practised today — take 5 minutes! 📚',
      'Сегодня ещё не было тренировки — уделите 5 минут! 📚');
  String reminderStreak(int n) => _t(
      '🔥 $n kunlik seriyangizni yo\'qotmang — bugungi maqsadni bajaring!',
      '🔥 Keep your $n-day streak — finish today\'s goal!',
      '🔥 Не потеряйте серию из $n дн. — выполните цель дня!');

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

  /// Languages for menus: the 4 main ones (O'zbekcha, English, Ruscha,
  /// Arabcha) first, then the rest alphabetically in the interface language.
  List<Language> get orderedLanguages {
    final rest = kLanguages.skip(4).toList()
      ..sort((a, b) => targetLangName(a.code).compareTo(targetLangName(b.code)));
    return [...kLanguages.take(4), ...rest];
  }

  String targetLangName(String code) {
    final l = languageByCode(code);
    if (l == null) return code;
    return switch (lang) { AppLang.uz => l.uz, AppLang.en => l.en, AppLang.ru => l.ru };
  }

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
