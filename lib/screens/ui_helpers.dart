import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/deck.dart';
import '../models/gamification.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import '../services/languages.dart';
import '../services/reminder_service.dart';
import '../services/tts_service.dart';

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Small celebration for level-ups, finished quests, achievements, records.
void showReward(BuildContext context, Reward r) {
  if (!context.mounted || !r.notable) return;
  final t = S.of(context);
  final parts = <String>[
    if (r.leveledUp) '⬆️ ${t.levelUp(r.levelAfter)}',
    if (r.goalReached) '🎯 ${t.goalDone}',
    for (final q in r.quests) '📋 ${t.questTitle(q)} (+${q.xp} XP)',
    for (final (a, tier) in r.tiers) '${kTierEmojis[tier]} ${t.achievementName(a.metric)}',
  ];
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      content: Text(parts.join('\n')),
    ));
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String? ok,
  bool danger = false,
}) async {
  final t = S.of(context);
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok ?? t.yes),
        ),
      ],
    ),
  );
  return res ?? false;
}

Future<String?> showTextInput(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String? okLabel,
}) {
  final t = S.of(context);
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      void submit() {
        final v = ctrl.text.trim();
        if (v.isNotEmpty) Navigator.pop(ctx, v);
      }

      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
            onSubmitted: (_) => submit(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(onPressed: submit, child: Text(okLabel ?? t.save)),
        ],
      );
    },
  );
}

/// Result of the book dialog: name + language (folder) id.
class DeckFormResult {
  DeckFormResult(this.name, this.folderId);
  final String name;
  final String folderId;
}

const _newLang = '__new__';

/// Asks for a book name and its language. A new language can be created
/// right in the dialog.
Future<DeckFormResult?> showDeckForm(
  BuildContext context, {
  required String title,
  String name = '',
  String? folderId,
  String? okLabel,
  String? subtitle,
}) {
  final t = S.of(context);
  final lib = context.read<LibraryProvider>();
  final langs = lib.subfolders(null);
  final nameCtrl = TextEditingController(text: name);
  final langCtrl = TextEditingController();
  var lang = folderId ?? (langs.isNotEmpty ? langs.first.id : null);
  var creating = langs.isEmpty;
  final formKey = GlobalKey<FormState>();

  return showDialog<DeckFormResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      Future<void> submit() async {
        if (!formKey.currentState!.validate()) return;
        var id = lang;
        if (creating) id = await lib.ensureLanguage(langCtrl.text);
        if (id == null || !ctx.mounted) return;
        Navigator.pop(ctx, DeckFormResult(nameCtrl.text.trim(), id));
      }

      return AlertDialog(
        title: Text(title),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) ...[
                  Text(subtitle, style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: t.deckName,
                    hintText: t.deckNameHint,
                    prefixIcon: const Icon(Icons.menu_book_rounded),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? t.enterName : null,
                  onFieldSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 16),
                if (creating) ...[
                  TextFormField(
                    controller: langCtrl,
                    decoration: InputDecoration(
                      labelText: t.languageName,
                      hintText: t.folderHint,
                      prefixIcon: const Icon(Icons.translate_rounded),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? t.enterName : null,
                    onFieldSubmitted: (_) => submit(),
                  ),
                  if (langs.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => setS(() => creating = false),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text(t.chooseExisting),
                    ),
                ] else
                  DropdownMenu<String>(
                    initialSelection: lang,
                    expandedInsets: EdgeInsets.zero,
                    label: Text(t.folder),
                    leadingIcon: const Icon(Icons.translate_rounded),
                    dropdownMenuEntries: [
                      for (final f in langs) DropdownMenuEntry(value: f.id, label: f.name),
                      DropdownMenuEntry(
                        value: _newLang,
                        label: t.newFolder,
                        leadingIcon: const Icon(Icons.add_rounded),
                      ),
                    ],
                    onSelected: (v) {
                      if (v == _newLang) {
                        setS(() => creating = true);
                      } else {
                        lang = v;
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(onPressed: submit, child: Text(okLabel ?? t.save)),
        ],
      );
    }),
  );
}

/// Re-schedules the daily reminder (skips today once the goal is done).
Future<void> syncReminder(BuildContext context) async {
  if (!ReminderService.supported) return;
  final s = context.read<SettingsProvider>();
  final stats = context.read<StatsProvider>();
  final t = S.of(context);
  final streak = stats.streak(s.dailyGoal);
  await ReminderService.instance.schedule(
    enabled: s.reminderOn,
    hour: s.reminderHour,
    minute: s.reminderMinute,
    skipToday: stats.todayCount >= s.dailyGoal,
    title: 'LexiFlip',
    body: streak > 0 ? t.reminderStreak(streak) : t.reminderBody,
  );
}

/// Word language of the deck [deckId] (its own choice or the default).
String wordLangOf(BuildContext context, String deckId) {
  final deck = context.read<LibraryProvider>().deckById(deckId);
  return context.read<SettingsProvider>().langsFor(deck).word;
}

/// Speaks [text] in [lang] (deck word language); if the device has no voice
/// for it, explains how to install one (unless [quiet], for auto-pronounce).
Future<void> speakWord(BuildContext context, String text,
    {bool quiet = false, String? lang}) async {
  final result = await context.read<TtsService>().speak(text, lang: lang);
  if (result != SpeakResult.missingVoice || quiet || !context.mounted) return;
  final t = S.of(context);
  final name = lang != null && languageByCode(lang) != null
      ? t.targetLangName(lang)
      : t.voiceLangName(switch (detectScript(text)) {
          WordScript.arabic => WordScriptName.arabic,
          WordScript.cyrillic => WordScriptName.russian,
          WordScript.latin => WordScriptName.english,
        });
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.record_voice_over_outlined),
      title: Text(t.missingVoiceTitle(name)),
      content: Text(android ? t.missingVoiceAndroid : t.missingVoiceWindows),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(t.ok))],
    ),
  );
}

/// Dialog to choose a deck's word / translation languages.
/// Optionally applies the choice to every deck in the deck's folder.
Future<bool> editDeckLangs(BuildContext context, Deck deck) async {
  final t = S.of(context);
  final lib = context.read<LibraryProvider>();
  final settings = context.read<SettingsProvider>();
  final cur = settings.langsFor(deck);
  var word = cur.word, primary = cur.primary, secondary = cur.secondary;
  var toFolder = false;
  final folder = lib.folderById(deck.folderId);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        Widget pick(String label, String value, ValueChanged<String> onChanged) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownMenu<String>(
                initialSelection: value,
                expandedInsets: EdgeInsets.zero,
                menuHeight: 360,
                label: Text(label),
                onSelected: (v) {
                  if (v != null) setLocal(() => onChanged(v));
                },
                dropdownMenuEntries: [
                  for (final l in t.orderedLanguages)
                    DropdownMenuEntry(value: l.code, label: t.targetLangName(l.code)),
                ],
              ),
            );
        return AlertDialog(
          icon: const Icon(Icons.language_rounded),
          title: Text(t.deckLanguages),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lib.deckTitle(deck), style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 16),
                  pick(t.langWord, word, (v) => word = v),
                  pick(t.langPrimary, primary, (v) => primary = v),
                  pick(t.langSecondary, secondary, (v) => secondary = v),
                  Text(t.langSecondaryHint, style: Theme.of(ctx).textTheme.bodySmall),
                  if (folder != null)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: toFolder,
                      onChanged: (v) => setLocal(() => toFolder = v ?? false),
                      title: Text(t.applyToFolder(folder.name)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.save)),
          ],
        );
      },
    ),
  );
  if (ok != true || !context.mounted) return false;
  final Iterable<String> ids =
      toFolder && folder != null ? lib.decksInTree(folder.id).map((d) => d.id) : [deck.id];
  await lib.setDeckLangs(ids, word: word, primary: primary, secondary: secondary);
  if (context.mounted) showSnack(context, t.langsSaved);
  return true;
}
