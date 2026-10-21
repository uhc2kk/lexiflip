import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/flashcard.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/autofill_service.dart';
import '../services/translit.dart';
import '../services/tts_service.dart';
import 'ui_helpers.dart';

/// Add a new card (cardId == null) or edit an existing one.
class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({super.key, required this.deckId, this.cardId});
  final String deckId;
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
  late String _deckId = widget.deckId;
  bool _loading = false;

  bool get _isNew => _original == null;

  @override
  void initState() {
    super.initState();
    if (widget.cardId != null) {
      _original = context.read<LibraryProvider>().cardById(widget.cardId!);
      final c = _original;
      if (c != null) {
        _deckId = c.deckId;
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

  // ---------------- Auto-fill (any language, deck languages) ----------------

  String _gErr(S t, GeminiError e) => switch (e) {
        GeminiError.badKey => t.gErrBadKey,
        GeminiError.quota => t.gErrQuota,
        GeminiError.network => t.gErrNetwork,
        GeminiError.badModel => t.gErrModel,
        GeminiError.other => t.gErrOther,
      };

  Future<void> _autofill({bool onlyIfEmpty = false}) async {
    final word = _word.text.trim();
    if (word.isEmpty || _loading) return;
    final t = S.of(context);
    final settings = context.read<SettingsProvider>();
    final langs = settings.langsFor(context.read<LibraryProvider>().deckById(_deckId));

    if (onlyIfEmpty &&
        (_ipa.text.isNotEmpty || _primary.text.isNotEmpty || _example.text.isNotEmpty)) {
      return;
    }

    // Arabic: the reading is generated offline, exactly from the harakat.
    final arabic = langs.word == 'ar' || detectScript(word) == WordScript.arabic;
    if (arabic && _ipa.text.isEmpty) _ipa.text = arabicToLatin(word);

    final service = context.read<AutofillService>();
    setState(() => _loading = true);
    try {
      final r = await service.fetch(
        word,
        langs: langs,
        geminiKey: settings.geminiKey,
        geminiModel: settings.geminiModel,
      );
      if (!mounted) return;
      if (r.ipa != null && !(arabic && _ipa.text.isNotEmpty)) _ipa.text = r.ipa!;
      if (r.primary != null) _primary.text = r.primary!;
      if (r.secondary != null) _secondary.text = r.secondary!;
      if (r.example != null) _example.text = r.example!;
      final complete = [_ipa, _primary, _secondary, _example].every((c) => c.text.isNotEmpty);
      if (r.geminiError != null) {
        showSnack(context, t.geminiFailed(_gErr(t, r.geminiError!)));
      } else if (!complete) {
        showSnack(context, settings.hasGemini ? t.autofillPartial : t.freeWeakHint);
      }
    } on AutofillException catch (e) {
      if (!mounted) return;
      if (e.geminiError != null) {
        showSnack(context, t.geminiFailed(_gErr(t, e.geminiError!)));
      } else if (arabic && _ipa.text.isNotEmpty) {
        showSnack(context, t.readingFilled);
      } else {
        showSnack(context, '${t.autofill}: $e');
      }
    } catch (e) {
      if (mounted) showSnack(context, '${t.autofill}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editLangs() async {
    final deck = context.read<LibraryProvider>().deckById(_deckId);
    if (deck == null) return;
    await editDeckLangs(context, deck);
  }

  // ---------------- Save / delete ----------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final lib = context.read<LibraryProvider>();
    final t = S.of(context);
    final word = _word.text.trim();

    if (lib.wordExists(_deckId, word, exceptId: _original?.id)) {
      final ok = await confirm(context,
          title: t.duplicateWord,
          message: t.duplicateWordMsg(word),
          ok: t.save);
      if (!ok) return;
    }

    final card = _isNew
        ? Flashcard.create(
            deckId: _deckId,
            word: word,
            ipa: _ipa.text,
            primaryTranslation: _primary.text,
            secondaryTranslation: _secondary.text,
            example: _example.text,
            mnemonic: _mnemonic.text,
          )
        : _original!
            .copyWith(
              deckId: _deckId,
              word: word,
              ipa: _ipa.text.trim(),
              primaryTranslation: _primary.text.trim(),
              secondaryTranslation: _secondary.text.trim(),
              example: _example.text.trim(),
              mnemonic: _mnemonic.text.trim(),
            )
            .touched();

    await lib.upsertCard(card);
    if (!mounted) return;
    if (_isNew) {
      // Keep adding: clear the form for the next word.
      showSnack(context, t.wordAdded(word));
      for (final c in [_word, _ipa, _primary, _secondary, _example, _mnemonic]) {
        c.clear();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final t = S.of(context);
    final ok = await confirm(context,
        title: t.deleteQ,
        message: t.wordDeleteMsg(_original!.word),
        ok: t.delete,
        danger: true);
    if (!ok || !mounted) return;
    await context.read<LibraryProvider>().deleteCard(_original!.id);
    if (mounted) Navigator.of(context).pop();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final settings = context.watch<SettingsProvider>();
    final t = S.of(context);
    final langs = settings.langsFor(lib.deckById(_deckId));
    String ln(String code) => t.targetLangName(code);

    InputDecoration deco(String label, {String? hint, IconData? icon}) => InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon),
          border: const OutlineInputBorder(),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? t.newWord : t.edit),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: t.delete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: _save, child: Text(t.save)),
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
                DropdownMenu<String>(
                  initialSelection: _deckId,
                  expandedInsets: EdgeInsets.zero,
                  label: Text(t.deck),
                  leadingIcon: const Icon(Icons.folder_outlined),
                  onSelected: (v) {
                    if (v != null) setState(() => _deckId = v);
                  },
                  dropdownMenuEntries: [
                    for (final d in lib.decks)
                      DropdownMenuEntry(value: d.id, label: lib.deckTitle(d)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _word,
                  autofocus: _isNew,
                  style: const TextStyle(fontSize: 20),
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _autofill(onlyIfEmpty: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? t.enterWord : null,
                  decoration: deco('${t.wordLabel} · ${ln(langs.word)}', icon: Icons.translate_rounded)
                      .copyWith(
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: t.kPronounce,
                          icon: const Icon(Icons.volume_up_outlined),
                          onPressed: () => speakWord(context, _word.text, lang: langs.word),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _loading
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : IconButton.filledTonal(
                                  tooltip: t.autofill,
                                  icon: const Icon(Icons.auto_awesome_rounded),
                                  onPressed: () => _autofill(),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.language_rounded, size: 18),
                        tooltip: t.changeLangs,
                        onPressed: _editLangs,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${ln(langs.word)}  →  ${ln(langs.primary)} · ${ln(langs.secondary)}'),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit_outlined, size: 16),
                          ],
                        ),
                      ),
                      Text(
                        '${t.autofill}: ${settings.hasGemini ? t.viaGemini : t.viaFree}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextFormField(
                  controller: _ipa,
                  decoration: deco(t.ipaLabel,
                      hint: '/rɪˈzɪliənt/  yoki  bismi', icon: Icons.record_voice_over_outlined),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _primary,
                  decoration: deco('${t.primaryLabel} · ${ln(langs.primary)}', icon: Icons.looks_one_outlined),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _secondary,
                  decoration: deco('${t.secondaryLabel} · ${ln(langs.secondary)}', icon: Icons.looks_two_outlined),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _example,
                  minLines: 2,
                  maxLines: 4,
                  decoration: deco(t.exampleLabel, icon: Icons.format_quote_rounded),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mnemonic,
                  minLines: 1,
                  maxLines: 3,
                  decoration: deco(t.mnemonicLabel,
                      hint: t.mnemonicFieldHint,
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
