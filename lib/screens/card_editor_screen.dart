import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/flashcard.dart';
import '../providers/deck_provider.dart';
import '../providers/settings_provider.dart';
import '../services/autofill_service.dart';
import '../services/tts_service.dart';

/// Add a new card (cardId == null) or edit an existing one.
class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({super.key, this.cardId});
  final String? cardId;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _word = TextEditingController();
  final _ipa = TextEditingController();
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  final _example = TextEditingController();
  final _mnemonic = TextEditingController();

  Flashcard? _original;
  bool _loading = false;

  bool get _isNew => _original == null;

  @override
  void initState() {
    super.initState();
    if (widget.cardId != null) {
      final deck = context.read<DeckProvider>();
      for (final c in deck.cards) {
        if (c.id == widget.cardId) {
          _original = c;
          break;
        }
      }
      final c = _original;
      if (c != null) {
        _word.text = c.word;
        _ipa.text = c.ipa;
        _primary.text = c.primaryTranslation;
        _secondary.text = c.secondaryTranslation;
        _example.text = c.example;
        _mnemonic.text = c.mnemonic;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_word, _ipa, _primary, _secondary, _example, _mnemonic]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------- Auto-fill ----------------

  Future<void> _autofill({bool onlyIfEmpty = false}) async {
    final word = _word.text.trim();
    if (word.isEmpty || _loading) return;
    if (onlyIfEmpty &&
        (_ipa.text.isNotEmpty ||
            _primary.text.isNotEmpty ||
            _example.text.isNotEmpty)) {
      return;
    }

    final settings = context.read<SettingsProvider>();
    final service = context.read<AutofillService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _loading = true);
    try {
      final r = await service.fetch(
        word,
        targetLangCode: settings.targetLang,
        targetLangName: settings.targetLangName,
        geminiKey: settings.geminiKey,
        geminiModel: settings.geminiModel,
      );
      if (!mounted) return;
      // Overwrite with fetched values; never touch the user's mnemonic.
      if (r.ipa != null) _ipa.text = r.ipa!;
      if (r.primary != null) _primary.text = r.primary!;
      if (r.secondary != null) _secondary.text = r.secondary!;
      if (r.example != null) _example.text = r.example!;
      if (!r.isComplete) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Partially filled — complete the empty fields.'),
        ));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Auto-fill: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- Save / delete ----------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final deck = context.read<DeckProvider>();
    final word = _word.text.trim();

    if (deck.wordExists(word, exceptId: _original?.id)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Duplicate word'),
          content: Text('"$word" is already in your deck. Save anyway?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      );
      if (ok != true) return;
    }

    final card = _isNew
        ? Flashcard.create(
            word: word,
            ipa: _ipa.text,
            primaryTranslation: _primary.text,
            secondaryTranslation: _secondary.text,
            example: _example.text,
            mnemonic: _mnemonic.text,
          )
        : _original!
            .copyWith(
              word: word,
              ipa: _ipa.text.trim(),
              primaryTranslation: _primary.text.trim(),
              secondaryTranslation: _secondary.text.trim(),
              example: _example.text.trim(),
              mnemonic: _mnemonic.text.trim(),
            )
            .touched();

    await deck.upsert(card);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text('"${_original!.word}" will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<DeckProvider>().delete(_original!.id);
    if (mounted) Navigator.of(context).pop();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    InputDecoration deco(String label, {String? hint, IconData? icon}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon),
          border: const OutlineInputBorder(),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New card' : 'Edit card'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Word + Auto-fill
                TextFormField(
                  controller: _word,
                  autofocus: _isNew,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _autofill(onlyIfEmpty: true),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a word' : null,
                  decoration: deco('English word', icon: Icons.translate_rounded)
                      .copyWith(
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Pronounce',
                          icon: const Icon(Icons.volume_up_outlined),
                          onPressed: () => context
                              .read<TtsService>()
                              .speak(_word.text),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _loading
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : IconButton.filledTonal(
                                  tooltip: 'Auto-fill',
                                  icon: const Icon(Icons.auto_awesome_rounded),
                                  onPressed: () => _autofill(),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 18),
                  child: Text(
                    settings.hasGemini
                        ? 'Auto-fill: Gemini → ${settings.targetLangName}'
                        : 'Auto-fill: Free Dictionary + MyMemory → ${settings.targetLangName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextFormField(
                  controller: _ipa,
                  decoration: deco('IPA pronunciation',
                      hint: '/rɪˈzɪliənt/', icon: Icons.record_voice_over_outlined),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _primary,
                  decoration: deco('Primary translation',
                      icon: Icons.looks_one_outlined),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _secondary,
                  decoration: deco('Secondary translation / context synonym',
                      icon: Icons.looks_two_outlined),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _example,
                  minLines: 2,
                  maxLines: 4,
                  decoration: deco('Example sentence',
                      icon: Icons.format_quote_rounded),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mnemonic,
                  minLines: 1,
                  maxLines: 3,
                  decoration: deco('Mnemonic / keyword',
                      hint: 'Your own memory hook',
                      icon: Icons.lightbulb_outline_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
