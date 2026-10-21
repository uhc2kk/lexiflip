import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

/// One vocabulary card.
///
/// Front: [word] + [ipa] (+ TTS button in the UI)
/// Back:  [primaryTranslation] + [secondaryTranslation] + [mnemonic] + [example]
class Flashcard {
  const Flashcard({
    required this.id,
    required this.word,
    this.ipa = '',
    this.primaryTranslation = '',
    this.secondaryTranslation = '',
    this.mnemonic = '',
    this.example = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Flashcard.create({
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
  final String word;
  final String ipa;
  final String primaryTranslation;
  final String secondaryTranslation;
  final String mnemonic;
  final String example;
  final DateTime createdAt;

  /// Used as the "last write wins" key when merging imported decks.
  final DateTime updatedAt;

  Flashcard copyWith({
    String? id,
    String? word,
    String? ipa,
    String? primaryTranslation,
    String? secondaryTranslation,
    String? mnemonic,
    String? example,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Flashcard(
      id: id ?? this.id,
      word: word ?? this.word,
      ipa: ipa ?? this.ipa,
      primaryTranslation: primaryTranslation ?? this.primaryTranslation,
      secondaryTranslation: secondaryTranslation ?? this.secondaryTranslation,
      mnemonic: mnemonic ?? this.mnemonic,
      example: example ?? this.example,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns a copy with the edit timestamp bumped to now.
  Flashcard touched() => copyWith(updatedAt: DateTime.now().toUtc());

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'ipa': ipa,
        'primaryTranslation': primaryTranslation,
        'secondaryTranslation': secondaryTranslation,
        'mnemonic': mnemonic,
        'example': example,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  /// Tolerant parser: missing fields fall back to defaults so older / hand-made
  /// JSON files still import.
  factory Flashcard.fromJson(Map<String, dynamic> json) {
    String str(String key) => (json[key] ?? '').toString().trim();
    DateTime date(String key) =>
        DateTime.tryParse((json[key] ?? '').toString())?.toUtc() ??
        DateTime.now().toUtc();

    final id = str('id');
    final created = date('createdAt');
    return Flashcard(
      id: id.isEmpty ? const Uuid().v4() : id,
      word: str('word'),
      ipa: str('ipa'),
      primaryTranslation: str('primaryTranslation'),
      secondaryTranslation: str('secondaryTranslation'),
      mnemonic: str('mnemonic'),
      example: str('example'),
      createdAt: created,
      updatedAt: json['updatedAt'] == null ? created : date('updatedAt'),
    );
  }
}

/// Hand-written Hive adapter — no build_runner / code generation needed.
///
/// Stores the card as a map, so adding new fields later never breaks
/// existing databases (unknown keys are ignored, missing keys get defaults).
class FlashcardAdapter extends TypeAdapter<Flashcard> {
  @override
  final int typeId = 1;

  @override
  Flashcard read(BinaryReader reader) {
    final map = Map<String, dynamic>.from(reader.readMap());
    return Flashcard.fromJson(map);
  }

  @override
  void write(BinaryWriter writer, Flashcard obj) {
    writer.writeMap(obj.toJson());
  }
}
