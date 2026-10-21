import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/gamification.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
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

/// Dropdown value meaning "top level, no folder".
const kRootFolder = '__root__';

/// Folder picker entries: top level + every folder ("Arabcha › Kitob 1").
/// [onlyRoots] limits the list to top-level folders (for moving a folder).
List<DropdownMenuEntry<String>> folderEntries(BuildContext context, {bool onlyRoots = false, String? exclude}) {
  final lib = context.read<LibraryProvider>();
  final t = S.of(context);
  return [
    DropdownMenuEntry(value: kRootFolder, label: t.topLevel, leadingIcon: const Icon(Icons.home_outlined)),
    for (final f in lib.foldersFlat)
      if ((!onlyRoots || f.isRoot) && f.id != exclude)
        DropdownMenuEntry(
          value: f.id,
          label: lib.folderPathNames(f.id).join(' › '),
          leadingIcon: Icon(f.isRoot ? Icons.folder_rounded : Icons.subdirectory_arrow_right_rounded),
        ),
  ];
}

/// Asks the user to pick a folder. Returns kRootFolder for top level.
Future<String?> pickFolder(BuildContext context, {required String title, String? current, bool onlyRoots = false, String? exclude}) {
  final t = S.of(context);
  final entries = folderEntries(context, onlyRoots: onlyRoots, exclude: exclude);
  var value = current ?? kRootFolder;
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: DropdownMenu<String>(
          initialSelection: value,
          expandedInsets: EdgeInsets.zero,
          label: Text(t.folder),
          dropdownMenuEntries: entries,
          onSelected: (v) => value = v ?? kRootFolder,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, value), child: Text(t.move)),
      ],
    ),
  );
}

/// Result of the deck dialog. [folderId] null = top level.
class DeckFormResult {
  DeckFormResult(this.name, this.folderId);
  final String name;
  final String? folderId;
}

/// Asks for a deck name and the folder to put it in.
Future<DeckFormResult?> showDeckForm(
  BuildContext context, {
  required String title,
  String name = '',
  String? folderId,
  String? okLabel,
  String? subtitle,
}) {
  final t = S.of(context);
  final entries = folderEntries(context);
  final nameCtrl = TextEditingController(text: name);
  var folder = folderId ?? kRootFolder;
  final formKey = GlobalKey<FormState>();

  return showDialog<DeckFormResult>(
    context: context,
    builder: (ctx) {
      void submit() {
        if (!formKey.currentState!.validate()) return;
        Navigator.pop(ctx, DeckFormResult(nameCtrl.text.trim(), folder == kRootFolder ? null : folder));
      }

      return AlertDialog(
        title: Text(title),
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
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? t.enterName : null,
                  onFieldSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 16),
                DropdownMenu<String>(
                  initialSelection: folder,
                  expandedInsets: EdgeInsets.zero,
                  label: Text(t.folder),
                  leadingIcon: const Icon(Icons.folder_outlined),
                  dropdownMenuEntries: entries,
                  onSelected: (v) => folder = v ?? kRootFolder,
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
    },
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

/// Speaks [text]; if the device has no voice for its language, explains how
/// to install one (unless [quiet], used for auto-pronounce).
Future<void> speakWord(BuildContext context, String text, {bool quiet = false}) async {
  final result = await context.read<TtsService>().speak(text);
  if (result != SpeakResult.missingVoice || quiet || !context.mounted) return;
  final t = S.of(context);
  final name = t.voiceLangName(switch (detectScript(text)) {
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
