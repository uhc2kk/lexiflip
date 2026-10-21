import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/flashcard.dart';
import 'file_bridge.dart';

class MergeResult {
  const MergeResult(this.toWrite, this.added, this.updated, this.skipped);
  final List<Flashcard> toWrite;
  final int added;
  final int updated;
  final int skipped;

  @override
  String toString() =>
      '$added added · $updated updated · $skipped unchanged';
}

/// Offline sync between devices through a plain JSON file.
///
/// File format:
/// {
///   "format": "lexiflip-deck",
///   "version": 1,
///   "exportedAt": "2026-10-21T12:00:00.000Z",
///   "cards": [ { ...Flashcard.toJson() }, ... ]
/// }
/// A bare JSON array of cards is also accepted on import.
class JsonSyncService {
  JsonSyncService._();

  static const format = 'lexiflip-deck';
  static const version = 1;

  // ---------- Encode / decode ----------

  static String encode(List<Flashcard> cards) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'count': cards.length,
      'cards': cards.map((c) => c.toJson()).toList(),
    });
  }

  static List<Flashcard> decode(String source) {
    // Strip a UTF-8 BOM (files edited in Notepad often have one).
    final cleaned = source.startsWith('﻿') ? source.substring(1) : source;
    final data = jsonDecode(cleaned);

    final List raw;
    if (data is List) {
      raw = data;
    } else if (data is Map && data['cards'] is List) {
      raw = data['cards'] as List;
    } else {
      throw const FormatException('This is not a LexiFlip deck file.');
    }

    return raw
        .whereType<Map>()
        .map((m) => Flashcard.fromJson(Map<String, dynamic>.from(m)))
        .where((c) => c.word.isNotEmpty)
        .toList();
  }

  // ---------- Merge ----------

  static String _norm(String w) => w.trim().toLowerCase();

  /// Matches incoming cards to existing ones by id, then by word
  /// (case-insensitive). The card with the newer `updatedAt` wins.
  /// Nothing local is ever deleted by a merge.
  static MergeResult merge(
    Iterable<Flashcard> existing,
    List<Flashcard> incoming,
  ) {
    final byId = {for (final c in existing) c.id: c};
    final byWord = {for (final c in existing) _norm(c.word): c};
    final toWrite = <Flashcard>[];
    var added = 0, updated = 0, skipped = 0;

    for (final inc in incoming) {
      final match = byId[inc.id] ?? byWord[_norm(inc.word)];

      if (match == null) {
        toWrite.add(inc);
        byId[inc.id] = inc;
        byWord[_norm(inc.word)] = inc;
        added++;
      } else if (inc.updatedAt.isAfter(match.updatedAt)) {
        // Keep the local id so the same card isn't duplicated.
        final merged = inc.copyWith(id: match.id, createdAt: match.createdAt);
        toWrite.add(merged);
        byId[merged.id] = merged;
        byWord[_norm(merged.word)] = merged;
        updated++;
      } else {
        skipped++;
      }
    }
    return MergeResult(toWrite, added, updated, skipped);
  }

  // ---------- File I/O (cross-platform) ----------

  /// Opens a save dialog (Android/Desktop) or triggers a download (Web).
  /// Returns a path / filename, or null if the user cancelled.
  static Future<String?> exportToFile(List<Flashcard> cards) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name = 'lexiflip_${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}.json';
    final bytes = Uint8List.fromList(utf8.encode(encode(cards)));
    return saveBytes(name, bytes);
  }

  /// Lets the user pick a .json file and parses it.
  /// Returns null if the user cancelled.
  static Future<List<Flashcard>?> pickAndDecode() async {
    // Android's picker often greys out .json with a custom filter,
    // so allow any file there and validate the content instead.
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import LexiFlip deck',
      type: isAndroid ? FileType.any : FileType.custom,
      allowedExtensions: isAndroid ? null : const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final bytes = result.files.single.bytes;
    if (bytes == null) {
      throw StateError('Could not read the selected file.');
    }
    return decode(utf8.decode(bytes, allowMalformed: true));
  }
}
