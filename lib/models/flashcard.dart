import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

/// Which of the 3 buckets a card is in.
///  - review  : "Qaytarilishi kerak" (new / not answered yet)
///  - problem : "Muammoli so'zlar"   (last answer: Bilmayman)
///  - learned : "Yodlangan"          (last answer: Bilaman)
enum CardStatus { review, problem, learned }

CardStatus _statusFrom(Object? v) => switch (v?.toString()) {
      'learned' => CardStatus.learned,
      'problem' => CardStatus.problem,
      _ => CardStatus.review,
    };

/// One vocabulary card.
///
/// Front: [word] + [ipa] (pronunciation / transliteration) + TTS button
/// Back:  [primaryTranslation] + [secondaryTranslation] + [example] + [mnemonic]
class Flashcard {
  const Flashcard({
    required this.id,
    required this.deckId,
    required this.word,
    this.ipa = '',
    this.primaryTranslation = '',
    this.secondaryTranslation = '',
    this.mnemonic = '',
    this.example = '',
    this.status = CardStatus.review,
    this.correct = 0,
    this.wrong = 0,
    this.lastReviewedAt,
    this.starred = false,
    this.level = 0,
    this.dueAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Flashcard.create({
    required String deckId,
    required String word,
    String ipa = '',
    String primaryTranslation = '',
    String secondaryTranslation = '',
    String mnemonic = '',
    String example = '',
  }) {
    final now = DateTime.now().toUtc();
    return Flashcard(
      id: const Uuid().v4(),
      deckId: deckId,
      word: word.trim(),
      ipa: ipa.trim(),
      primaryTranslation: primaryTranslation.trim(),
      secondaryTranslation: secondaryTranslation.trim(),
      mnemonic: mnemonic.trim(),
      example: example.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String deckId;
  final String word;
  final String ipa;
  final String primaryTranslation;
  final String secondaryTranslation;
  final String mnemonic;
  final String example;
  final CardStatus status;
  final int correct;
  final int wrong;
  final DateTime? lastReviewedAt;

  /// ⭐ "Saralangan" — collected for review across all decks.
  final bool starred;

  /// Spaced return: how many times in a row the word was known (0–6) and
  /// when a learned word goes back to "Qaytarish".
  final int level;
  final DateTime? dueAt;
  final DateTime createdAt;

  /// "Last write wins" key when merging imported decks.
  final DateTime updatedAt;

  Flashcard copyWith({
    String? id,
    String? deckId,
    String? word,
    String? ipa,
    String? primaryTranslation,
    String? secondaryTranslation,
    String? mnemonic,
    String? example,
    CardStatus? status,
    int? correct,
    int? wrong,
    DateTime? lastReviewedAt,
    bool? starred,
    int? level,
    DateTime? dueAt,
    bool clearDue = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Flashcard(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      word: word ?? this.word,
      ipa: ipa ?? this.ipa,
      primaryTranslation: primaryTranslation ?? this.primaryTranslation,
      secondaryTranslation: secondaryTranslation ?? this.secondaryTranslation,
      mnemonic: mnemonic ?? this.mnemonic,
      example: example ?? this.example,
      status: status ?? this.status,
      correct: correct ?? this.correct,
      wrong: wrong ?? this.wrong,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      starred: starred ?? this.starred,
      level: level ?? this.level,
      dueAt: clearDue ? null : (dueAt ?? this.dueAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns a copy with the edit timestamp bumped to now.
  Flashcard touched() => copyWith(updatedAt: DateTime.now().toUtc());

  Map<String, dynamic> toJson() => {
        'id': id,
        'deckId': deckId,
        'word': word,
        'ipa': ipa,
        'primaryTranslation': primaryTranslation,
        'secondaryTranslation': secondaryTranslation,
        'mnemonic': mnemonic,
        'example': example,
        'status': status.name,
        'correct': correct,
        'wrong': wrong,
        if (starred) 'starred': true,
        if (level > 0) 'level': level,
        if (dueAt != null) 'dueAt': dueAt!.toUtc().toIso8601String(),
        if (lastReviewedAt != null)
          'lastReviewedAt': lastReviewedAt!.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  /// Tolerant parser: missing fields fall back to defaults so older / hand-made
  /// JSON files still import.
  factory Flashcard.fromJson(Map<String, dynamic> json, {String? deckId}) {
    String str(String key) => (json[key] ?? '').toString().trim();
    DateTime? maybeDate(String key) =>
        DateTime.tryParse((json[key] ?? '').toString())?.toUtc();
    int number(String key) => int.tryParse((json[key] ?? '0').toString()) ?? 0;

    final id = str('id');
    final created = maybeDate('createdAt') ?? DateTime.now().toUtc();
    return Flashcard(
      id: id.isEmpty ? const Uuid().v4() : id,
      deckId: deckId ?? str('deckId'),
      word: str('word'),
      ipa: str('ipa'),
      primaryTranslation: str('primaryTranslation'),
      secondaryTranslation: str('secondaryTranslation'),
      mnemonic: str('mnemonic'),
      example: str('example'),
      status: _statusFrom(json['status']),
      correct: number('correct'),
      wrong: number('wrong'),
      lastReviewedAt: maybeDate('lastReviewedAt'),
      starred: json['starred'] == true || json['starred'].toString() == 'true',
      level: number('level'),
      dueAt: maybeDate('dueAt'),
      createdAt: created,
      updatedAt: maybeDate('updatedAt') ?? created,
    );
  }
}

/// Hand-written Hive adapter — no build_runner / code generation needed.
/// Stores the card as a map, so adding fields never breaks existing data.
class FlashcardAdapter extends TypeAdapter<Flashcard> {
  @override
  final int typeId = 1;

  @override
  Flashcard read(BinaryReader reader) =>
      Flashcard.fromJson(Map<String, dynamic>.from(reader.readMap()));

  @override
  void write(BinaryWriter writer, Flashcard obj) =>
      writer.writeMap(obj.toJson());
}
