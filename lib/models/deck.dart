import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

/// A deck ("to'plam") of cards, inside a folder ([folderId]) or at the top
/// level (folderId == null).
class Deck {
  const Deck({
    required this.id,
    required this.name,
    this.folderId,
    this.order = 0,
    this.legacyFolder = '',
    this.starred = false,
    this.wordLang,
    this.primaryLang,
    this.secondaryLang,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Deck.create({required String name, String? folderId, int order = 0}) {
    final now = DateTime.now().toUtc();
    return Deck(
      id: const Uuid().v4(),
      name: name.trim(),
      folderId: folderId,
      order: order,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String name;
  final String? folderId;
  final int order;

  /// v1.x stored the folder as a plain name; migrated into [Folder]s on start.
  final String legacyFolder;

  /// ⭐ favourite deck — shown at the top of the home page.
  final bool starred;

  /// Languages chosen for this deck (ISO codes). null → app defaults.
  final String? wordLang;
  final String? primaryLang;
  final String? secondaryLang;

  bool get hasLangs => wordLang != null || primaryLang != null || secondaryLang != null;

  final DateTime createdAt;
  final DateTime updatedAt;

  Deck copyWith({
    String? name,
    String? folderId,
    bool clearFolder = false,
    int? order,
    bool clearLegacy = false,
    bool? starred,
    String? wordLang,
    String? primaryLang,
    String? secondaryLang,
  }) =>
      Deck(
        id: id,
        name: name ?? this.name,
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        order: order ?? this.order,
        legacyFolder: clearLegacy ? '' : legacyFolder,
        starred: starred ?? this.starred,
        wordLang: wordLang ?? this.wordLang,
        primaryLang: primaryLang ?? this.primaryLang,
        secondaryLang: secondaryLang ?? this.secondaryLang,
        createdAt: createdAt,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (folderId != null) 'folderId': folderId,
        'order': order,
        if (legacyFolder.isNotEmpty) 'folder': legacyFolder,
        if (starred) 'starred': true,
        if (wordLang != null) 'wordLang': wordLang,
        if (primaryLang != null) 'primaryLang': primaryLang,
        if (secondaryLang != null) 'secondaryLang': secondaryLang,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Deck.fromJson(Map<String, dynamic> json) {
    DateTime date(String k) =>
        DateTime.tryParse((json[k] ?? '').toString())?.toUtc() ?? DateTime.now().toUtc();
    final id = (json['id'] ?? '').toString();
    final fid = (json['folderId'] ?? '').toString();
    String? lang(String k) {
      final v = (json[k] ?? '').toString().trim();
      return v.isEmpty ? null : v;
    }

    return Deck(
      id: id.isEmpty ? const Uuid().v4() : id,
      name: (json['name'] ?? '').toString().trim(),
      folderId: fid.isEmpty ? null : fid,
      order: int.tryParse((json['order'] ?? '0').toString()) ?? 0,
      legacyFolder: (json['folder'] ?? '').toString().trim(),
      starred: json['starred'] == true,
      wordLang: lang('wordLang'),
      primaryLang: lang('primaryLang'),
      secondaryLang: lang('secondaryLang'),
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
    );
  }
}

class DeckAdapter extends TypeAdapter<Deck> {
  @override
  final int typeId = 2;

  @override
  Deck read(BinaryReader reader) =>
      Deck.fromJson(Map<String, dynamic>.from(reader.readMap()));

  @override
  void write(BinaryWriter writer, Deck obj) => writer.writeMap(obj.toJson());
}
