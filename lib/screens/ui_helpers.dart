import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deck.dart';
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
  final text = list.map((a) => '${a.emoji} ${a.title}').join('   ');
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      content: Text('Yangi yutuq!  $text'),
    ));
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String ok = 'Ha',
  bool danger = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
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
  String okLabel = 'Saqlash',
  String? subtitle,
}) {
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
                  decoration: const InputDecoration(
                    labelText: 'To\'plam nomi',
                    hintText: 'Masalan: Mavzu 1',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom kiriting' : null,
                  onFieldSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: folderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Papka (ixtiyoriy)',
                    hintText: 'Masalan: Arabcha',
                    prefixIcon: Icon(Icons.folder_outlined),
                    border: OutlineInputBorder(),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
          FilledButton(onPressed: submit, child: Text(okLabel)),
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
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Saqlash')),
      ],
    ),
  );
}

String deckTitle(Deck d) => d.folder.isEmpty ? d.name : '${d.folder} › ${d.name}';
