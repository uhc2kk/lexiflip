import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/deck.dart';
import '../models/flashcard.dart';

/// One deck read from an import file.
/// [id] is null when the file didn't say which deck it belongs to (old
/// single-deck files) — the UI then asks the user for a name & folder.
/// [folderPath] is up to 2 folder names, e.g. ["Arabcha", "Kitob 1"].
class ImportedDeck {
  ImportedDeck({
    this.id,
    required this.name,
    List<String>? folderPath,
    required this.cards,
    this.wordLang,
    this.primaryLang,
    this.secondaryLang,
  }) : folderPath = folderPath ?? [];
  final String? id;

  /// Optional deck languages from the file ("wordLang": "ar" …).
  final String? wordLang;
  final String? primaryLang;
  final String? secondaryLang;
  String name;
  List<String> folderPath;

  /// When set, the book goes into this language (chosen in the UI).
  String? targetFolderId;
  final List<Flashcard> cards;
}

String? _lang(Map d, String key) {
  final v = (d[key] ?? '').toString().trim();
  return v.isEmpty ? null : v;
}

List<String> _path(Map d) {
  final p = d['folderPath'];
  if (p is List) {
    return p.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).take(2).toList();
  }
  return (d['folder'] ?? '')
      .toString()
      .split(RegExp(r'\s*[/›>]\s*'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .take(2)
      .toList();
}

class MergeResult {
  MergeResult({this.added = 0, this.updated = 0, this.skipped = 0});
  int added;
  int updated;
  int skipped;

  void addAll(MergeResult o) {
    added += o.added;
    updated += o.updated;
    skipped += o.skipped;
  }

  @override
  String toString() => '$added ta yangi · $updated ta yangilandi · $skipped ta o\'zgarmadi';
}

/// Offline sync between devices through a plain JSON file.
///
/// Format v2 (written by this version):
/// {
///   "format": "lexiflip-deck",
///   "version": 2,
///   "exportedAt": "...",
///   "decks": [
///     { "id": "...", "name": "Mavzu 1", "folder": "Arabcha",
///       "cards": [ { ...Flashcard.toJson() }, ... ] }
///   ]
/// }
///
/// Also accepted on import:
///  - v1: { "deck": "Name", "folder": "...", "cards": [ ... ] }
///  - a bare JSON array of cards
class JsonSyncService {
  JsonSyncService._();

  static const format = 'lexiflip-deck';
  static const version = 2;

  // ---------- Encode ----------

  static String encode(
    Iterable<Deck> decks,
    Iterable<Flashcard> cards,
    List<String> Function(Deck) pathOf,
  ) {
    final byDeck = <String, List<Flashcard>>{};
    for (final c in cards) {
      (byDeck[c.deckId] ??= []).add(c);
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'decks': [
        for (final d in decks)
          {
            'id': d.id,
            'name': d.name,
            'folder': pathOf(d).join(' / '),
            'folderPath': pathOf(d),
            if (d.wordLang != null) 'wordLang': d.wordLang,
            if (d.primaryLang != null) 'primaryLang': d.primaryLang,
            if (d.secondaryLang != null) 'secondaryLang': d.secondaryLang,
            'count': byDeck[d.id]?.length ?? 0,
            'cards': [for (final c in byDeck[d.id] ?? const []) c.toJson()],
          },
      ],
    });
  }

  // ---------- Decode ----------

  static List<Flashcard> _cards(List raw) => raw
      .whereType<Map>()
      .map((m) => Flashcard.fromJson(Map<String, dynamic>.from(m)))
      .where((c) => c.word.isNotEmpty)
      .toList();

  static List<ImportedDeck> decode(String source, {String fallbackName = 'Import'}) {
    final cleaned = source.startsWith('﻿') ? source.substring(1) : source;
    final data = jsonDecode(cleaned);

    if (data is List) {
      return [ImportedDeck(name: fallbackName, cards: _cards(data))];
    }
    if (data is! Map) {
      throw const FormatException('Bu LexiFlip fayli emas.');
    }

    if (data['decks'] is List) {
      return [
        for (final d in (data['decks'] as List).whereType<Map>())
          ImportedDeck(
            id: (d['id'] ?? '').toString().isEmpty ? null : d['id'].toString(),
            name: (d['name'] ?? fallbackName).toString().trim(),
            folderPath: _path(d),
            cards: _cards(d['cards'] is List ? d['cards'] as List : const []),
            wordLang: _lang(d, 'wordLang'),
            primaryLang: _lang(d, 'primaryLang'),
            secondaryLang: _lang(d, 'secondaryLang'),
          ),
      ];
    }

    if (data['cards'] is List) {
      final name = (data['deck'] ?? data['name'] ?? '').toString().trim();
      return [
        ImportedDeck(
          id: (data['deckId'] ?? '').toString().isEmpty
              ? null
              : data['deckId'].toString(),
          name: name.isEmpty ? fallbackName : name,
          folderPath: _path(data),
          cards: _cards(data['cards'] as List),
        ),
      ];
    }
    throw const FormatException('Bu LexiFlip fayli emas.');
  }

  // ---------- Merge (within one deck) ----------

  static String _norm(String w) => w.trim().toLowerCase();

  /// Matches incoming cards to the deck's existing cards by id, then by word.
  /// The card with the newer `updatedAt` wins. Nothing is ever deleted.
  /// Returns the cards to write (already moved into [deckId]).
  static (List<Flashcard>, MergeResult) merge(
    String deckId,
    Iterable<Flashcard> existingInDeck,
    Iterable<Flashcard> allExisting,
    List<Flashcard> incoming,
  ) {
    final byId = {for (final c in existingInDeck) c.id: c};
    final byWord = {for (final c in existingInDeck) _norm(c.word): c};
    final takenIds = {for (final c in allExisting) c.id};
    final toWrite = <Flashcard>[];
    final result = MergeResult();

    for (final raw in incoming) {
      final inc = raw.copyWith(deckId: deckId);
      final match = byId[inc.id] ?? byWord[_norm(inc.word)];

      if (match == null) {
        // Same id used by a card in another deck → give this one a new id.
        final fresh = takenIds.contains(inc.id)
            ? Flashcard.fromJson({...inc.toJson(), 'id': ''}, deckId: deckId)
            : inc;
        toWrite.add(fresh);
        takenIds.add(fresh.id);
        byId[fresh.id] = fresh;
        byWord[_norm(fresh.word)] = fresh;
        result.added++;
      } else if (inc.updatedAt.isAfter(match.updatedAt)) {
        final merged = inc.copyWith(id: match.id, createdAt: match.createdAt);
        toWrite.add(merged);
        byId[merged.id] = merged;
        byWord[_norm(merged.word)] = merged;
        result.updated++;
      } else {
        result.skipped++;
      }
    }
    return (toWrite, result);
  }

  // ---------- File I/O (cross-platform) ----------

  static String _stamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
  }

  static String safeFileName(String s) =>
      s.replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_').replaceAll(RegExp(r'_+'), '_');

  /// Android = "Save as" (SAF), Desktop = native dialog, Web = download.
  static Future<String?> exportToFile(
    Iterable<Deck> decks,
    Iterable<Flashcard> cards,
    List<String> Function(Deck) pathOf, {
    String? baseName,
  }) async {
    final name = 'lexiflip_${safeFileName(baseName ?? 'hammasi')}_${_stamp()}.json';
    final bytes = Uint8List.fromList(utf8.encode(encode(decks, cards, pathOf)));
    final uri = await FilePicker.saveFile(
      dialogTitle: 'LexiFlip eksport',
      fileName: name,
      bytes: bytes,
      mimeType: 'application/json',
    );
    if (uri == null) return kIsWeb ? name : null;
    return uri.isScheme('file') ? uri.toFilePath() : name;
  }

  /// Lets the user pick a .json file and parses it. Null if cancelled.
  static Future<List<ImportedDeck>?> pickAndDecode() async {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final file = await FilePicker.pickFile(
      dialogTitle: 'LexiFlip import',
      type: isAndroid ? FileType.any : FileType.custom,
      allowedExtensions: isAndroid ? null : const ['json'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final base = file.name.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
    return decode(utf8.decode(bytes, allowMalformed: true), fallbackName: base);
  }
}
