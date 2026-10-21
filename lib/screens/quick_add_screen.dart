import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../providers/library_provider.dart';
import '../services/quick_add.dart';
import '../widgets/word_style.dart';
import 'ui_helpers.dart';

/// Paste many "word - translation" lines at once.
class QuickAddScreen extends StatefulWidget {
  const QuickAddScreen({super.key, required this.deckId});
  final String deckId;

  @override
  State<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends State<QuickAddScreen> {
  final _ctrl = TextEditingController();
  bool _autoReading = true;
  List<QuickRow> _rows = const [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _parse() => setState(() => _rows = parseQuickList(_ctrl.text, autoReading: _autoReading));

  Future<void> _add() async {
    final lib = context.read<LibraryProvider>();
    final t = S.of(context);
    final n = await lib.quickAdd(widget.deckId, _rows);
    if (!mounted) return;
    final skipped = _rows.length - n;
    showSnack(context, t.quickAdded(n, skipped));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final deck = context.watch<LibraryProvider>().deckById(widget.deckId);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.quickAdd),
          if (deck != null) Text(deck.name, style: theme.textTheme.bodySmall),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _rows.isEmpty ? null : _add,
              icon: const Icon(Icons.add_rounded),
              label: Text(t.addN(_rows.length)),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.quickAddHelp, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    SelectableText(
                      'كِتَابٌ - kitob - book\n'
                      'قَلَمٌ | qalam | pen\n'
                      'resilient - chidamli\n'
                      'بَيْتٌ ; baytun ; uy ; house',
                      style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Amiri', height: 1.6),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                minLines: 8,
                maxLines: 18,
                onChanged: (_) => _parse(),
                decoration: InputDecoration(
                  hintText: t.quickAddHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _autoReading,
                onChanged: (v) {
                  _autoReading = v;
                  _parse();
                },
                title: Text(t.autoReading),
                subtitle: Text(t.autoReadingSub),
              ),
              if (_rows.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(t.preview(_rows.length), style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final r in _rows.take(200))
                  ListTile(
                    dense: true,
                    title: Text(r.word, style: wordStyle(context, r.word, const TextStyle(fontSize: 18))),
                    subtitle: Text(
                      [r.ipa, r.primary, r.secondary].where((s) => s.isNotEmpty).join('  ·  '),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
