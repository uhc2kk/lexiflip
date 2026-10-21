import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _key;
  late final TextEditingController _model;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _key = TextEditingController(text: s.geminiKey);
    _model = TextEditingController(text: s.geminiModel);
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
          child: Text(t,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              header('Appearance'),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('System')),
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light')),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.setThemeMode(v.first),
              ),

              header('Translation language'),
              DropdownMenu<String>(
                initialSelection: s.targetLang,
                expandedInsets: EdgeInsets.zero,
                label: const Text('Translate English into'),
                onSelected: (v) {
                  if (v != null) s.setTargetLang(v);
                },
                dropdownMenuEntries: [
                  for (final e in kTargetLanguages.entries)
                    DropdownMenuEntry(value: e.key, label: '${e.value} (${e.key})'),
                ],
              ),

              header('Gemini API (optional)'),
              Text(
                'With a key, auto-fill uses Gemini for better translations. '
                'Without one, it uses the free Dictionary + MyMemory APIs. '
                'The key is stored only on this device.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _key,
                obscureText: _obscure,
                onChanged: s.setGeminiKey,
                decoration: InputDecoration(
                  labelText: 'Gemini API key',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _model,
                onChanged: s.setGeminiModel,
                decoration: const InputDecoration(
                  labelText: 'Gemini model',
                  helperText: 'e.g. gemini-2.5-flash',
                  border: OutlineInputBorder(),
                ),
              ),

              header('Keyboard shortcuts'),
              const _Shortcut(keys: 'Space', action: 'Flip card'),
              const _Shortcut(keys: '← / →', action: 'Previous / next card'),
              const _Shortcut(keys: 'P', action: 'Pronounce word'),
              const _Shortcut(keys: 'Esc', action: 'Leave mnemonic field'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.keys, required this.action});
  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(keys,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 16),
          Text(action),
        ],
      ),
    );
  }
}
