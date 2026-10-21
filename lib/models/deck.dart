import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

/// A deck ("to'plam") of cards, optionally placed inside a folder
/// ("papka"), e.g. folder "Arabcha" → decks "Mavzu 1", "Mavzu 2".
/// An empty [folder] means the deck sits at the top level.
class Deck {
  const Deck({
    required this.id,
    required this.name,
    this.folder = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Deck.create({required String name, String folder = ''}) {
    final now = DateTime.now().toUtc();
    return Deck(
      id: const Uuid().v4(),
      name: name.trim(),
      folder: folder.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String name;
  final String folder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Deck copyWith({String? name, String? folder}) => Deck(
        id: id,
        name: name ?? this.name,
        folder: folder ?? this.folder,
        createdAt: createdAt,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'folder': folder,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Deck.fromJson(Map<String, dynamic> json) {
    DateTime date(String k) =>
        DateTime.tryParse((json[k] ?? '').toString())?.toUtc() ??
        DateTime.now().toUtc();
    final id = (json['id'] ?? '').toString();
    return Deck(
      id: id.isEmpty ? const Uuid().v4() : id,
      name: (json['name'] ?? '').toString().trim(),
      folder: (json['folder'] ?? '').toString().trim(),
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
