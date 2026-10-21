import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

/// A folder ("papka"). Two levels only:
///  - root folder:  parentId == null   (e.g. "Arabcha")
///  - sub-folder:   parentId == root id (e.g. "Lug'otul arobiyya bayna yadayk")
class Folder {
  const Folder({
    required this.id,
    required this.name,
    this.parentId,
    this.order = 0,
    required this.createdAt,
  });

  factory Folder.create({required String name, String? parentId, int order = 0}) => Folder(
        id: const Uuid().v4(),
        name: name.trim(),
        parentId: parentId,
        order: order,
        createdAt: DateTime.now().toUtc(),
      );

  final String id;
  final String name;
  final String? parentId;
  final int order;
  final DateTime createdAt;

  bool get isRoot => parentId == null;

  Folder copyWith({String? name, String? parentId, bool clearParent = false, int? order}) => Folder(
        id: id,
        name: name ?? this.name,
        parentId: clearParent ? null : (parentId ?? this.parentId),
        order: order ?? this.order,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (parentId != null) 'parentId': parentId,
        'order': order,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory Folder.fromJson(Map<String, dynamic> j) {
    final pid = (j['parentId'] ?? '').toString();
    return Folder(
      id: (j['id'] ?? '').toString().isEmpty ? const Uuid().v4() : j['id'].toString(),
      name: (j['name'] ?? '').toString(),
      parentId: pid.isEmpty ? null : pid,
      order: int.tryParse((j['order'] ?? '0').toString()) ?? 0,
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}

class FolderAdapter extends TypeAdapter<Folder> {
  @override
  final int typeId = 3;

  @override
  Folder read(BinaryReader reader) =>
      Folder.fromJson(Map<String, dynamic>.from(reader.readMap()));

  @override
  void write(BinaryWriter writer, Folder obj) => writer.writeMap(obj.toJson());
}
