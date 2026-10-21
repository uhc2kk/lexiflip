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

  final DateTime createdAt;
  final DateTime updatedAt;

  Deck copyWith({
    String? name,
    String? folderId,
    bool clearFolder = false,
    int? order,
    bool clearLegacy = false,
  }) =>
      Deck(
        id: id,
        name: name ?? this.name,
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        order: order ?? this.order,
        legacyFolder: clearLegacy ? '' : legacyFolder,
        createdAt: createdAt,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (folderId != null) 'folderId': folderId,
        'order': order,
        if (legacyFolder.isNotEmpty) 'folder': legacyFolder,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Deck.fromJson(Map<String, dynamic> json) {
    DateTime date(String k) =>
        DateTime.tryParse((json[k] ?? '').toString())?.toUtc() ?? DateTime.now().toUtc();
    final id = (json['id'] ?? '').toString();
    final fid = (json['folderId'] ?? '').toString();
    return Deck(
      id: id.isEmpty ? const Uuid().v4() : id,
      name: (json['name'] ?? '').toString().trim(),
      folderId: fid.isEmpty ? null : fid,
      order: int.tryParse((json['order'] ?? '0').toString()) ?? 0,
      legacyFolder: (json['folder'] ?? '').toString().trim(),
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
