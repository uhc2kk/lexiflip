import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import 'package:flutter/foundation.dart';

import '../models/deck.dart';
import '../services/tts_service.dart';
import '../providers/library_provider.dart';
import '../providers/stats_provider.dart';

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Pops a small celebration for newly unlocked badges.
void showAchievements(BuildContext context, List<Achievement> list) {
  if (list.isEmpty || !context.mounted) return;
  final t = S.of(context);
  final text = list.map((a) => '${a.emoji} ${t.achievementTitle(a.id)}').join('   ');
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      content: Text('${t.newAchievement}  $text'),
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

/// Result of the deck name / folder dialog.
class DeckFormResult {
  DeckFormResult(this.name, this.folder);
  final String name;
  final String folder;
}

/// Asks for a deck name and folder. Folder field suggests existing folders.
Future<DeckFormResult?> showDeckForm(
  BuildContext context, {
  required String title,
  String name = '',
  String folder = '',
  String? okLabel,
  String? subtitle,
}) {
  final t = S.of(context);
  final folders = context.read<LibraryProvider>().namedFolders;
  final nameCtrl = TextEditingController(text: name);
  final folderCtrl = TextEditingController(text: folder);
  final formKey = GlobalKey<FormState>();

  return showDialog<DeckFormResult>(
    context: context,
    builder: (ctx) {
      void submit() {
        if (!formKey.currentState!.validate()) return;
        Navigator.pop(ctx, DeckFormResult(nameCtrl.text.trim(), folderCtrl.text.trim()));
      }

      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 400,
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
                const SizedBox(height: 14),
                TextFormField(
                  controller: folderCtrl,
                  decoration: InputDecoration(
                    labelText: t.folderOptional,
                    hintText: t.folderHint,
                    prefixIcon: const Icon(Icons.folder_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (_) => submit(),
                ),
                if (folders.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final f in folders)
                        ActionChip(
                          avatar: const Icon(Icons.folder_outlined, size: 18),
                          label: Text(f),
                          onPressed: () => folderCtrl.text = f,
                        ),
                    ],
                  ),
                ],
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

Future<String?> showTextInput(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) {
  final t = S.of(context);
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(t.save)),
      ],
    ),
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

String deckTitle(Deck d) => d.folder.isEmpty ? d.name : '${d.folder} › ${d.name}';
