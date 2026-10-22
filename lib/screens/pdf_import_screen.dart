import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/languages.dart';
import '../services/pdf_vocab_service.dart';
import '../services/quick_add.dart';
import '../widgets/word_style.dart';
import 'settings_screen.dart';
import 'ui_helpers.dart';

/// "PDF'dan so'z olish": pick a PDF, Gemini reads it, preview, add to book.
class PdfImportScreen extends StatefulWidget {
  const PdfImportScreen({super.key, required this.deckId});
  final String deckId;

  @override
  State<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends State<PdfImportScreen> {
  final _note = TextEditingController();
  final _service = PdfVocabService();
  String? _fileName;
  Uint8List? _bytes;
  bool _working = false;
  int _seconds = 0;
  Timer? _timer;
  List<QuickRow> _rows = const [];
  bool _truncated = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _note.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final t = S.of(context);
    final file = await FilePicker.pickFile(
      dialogTitle: 'PDF',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > PdfVocabService.maxBytes) {
      setState(() => _error = t.pdfTooBig(PdfVocabService.maxBytes ~/ (1024 * 1024)));
      return;
    }
    setState(() {
      _fileName = file.name;
      _bytes = bytes;
      _rows = const [];
      _error = null;
    });
  }

  Future<void> _run() async {
    final s = context.read<SettingsProvider>();
    final langs = s.langsFor(context.read<LibraryProvider>().deckById(widget.deckId));
    final bytes = _bytes;
    if (bytes == null || _working) return;
    setState(() {
      _working = true;
      _error = null;
      _rows = const [];
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    try {
      final r = await _service.extract(
        pdf: bytes,
        apiKey: s.geminiKey,
        model: s.geminiModel,
        wordLanguage: langEnglishName(langs.word),
        primaryLanguage: langEnglishName(langs.primary),
        secondaryLanguage: langEnglishName(langs.secondary),
        note: _note.text,
      );
      if (!mounted) return;
      setState(() {
        _rows = r.rows;
        _truncated = r.truncated;
        if (r.rows.isEmpty) _error = S.of(context).pdfNone;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      _timer?.cancel();
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _add() async {
    final t = S.of(context);
    final n = await context.read<LibraryProvider>().quickAdd(widget.deckId, _rows);
    if (!mounted) return;
    showSnack(context, t.quickAdded(n, _rows.length - n));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final hasKey = context.watch<SettingsProvider>().hasGemini;
    final deck = context.watch<LibraryProvider>().deckById(widget.deckId);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.pdfImport),
          if (deck != null) Text(deck.name, style: theme.textTheme.bodySmall),
        ]),
      ),
      bottomNavigationBar: _rows.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(t.addN(_rows.length)),
                ),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!hasKey)
                Card(
                  elevation: 0,
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('🔑 ${t.pdfNeedsKeyTitle}', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(t.pdfNeedsKey),
                      const SizedBox(height: 4),
                      const SelectableText('aistudio.google.com/apikey',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                        icon: const Icon(Icons.settings_outlined),
                        label: Text(t.settings),
                      ),
                    ]),
                  ),
                )
              else ...[
                Text(t.pdfIntro, style: theme.textTheme.bodyMedium),
                if (deck != null) ...[
                  const SizedBox(height: 10),
                  Builder(builder: (context) {
                    final l = context.read<SettingsProvider>().langsFor(deck);
                    return ActionChip(
                      avatar: const Icon(Icons.language_rounded, size: 18),
                      label: Text('${t.targetLangName(l.word)} → ${t.targetLangName(l.primary)} · ${t.targetLangName(l.secondary)}'),
                      onPressed: _working ? null : () => editDeckLangs(context, deck),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _working ? null : _pick,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(_fileName ?? t.pdfPick, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  enabled: !_working,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: t.pdfNote,
                    hintText: t.pdfNoteHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _bytes == null || _working ? null : _run,
                  icon: _working
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_working ? t.pdfWorking(_seconds) : t.pdfStart),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text('⚠️ $_error', style: TextStyle(color: theme.colorScheme.error)),
              ],
              if (_rows.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(t.pdfFound(_rows.length), style: theme.textTheme.titleMedium),
                if (_truncated) ...[
                  const SizedBox(height: 6),
                  Text(t.pdfTruncated, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 8),
                for (final r in _rows)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.word, style: wordStyle(context, r.word, const TextStyle(fontSize: 18))),
                    subtitle: Text([r.ipa, r.primary, r.secondary].where((s) => s.isNotEmpty).join('  ·  ')),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
