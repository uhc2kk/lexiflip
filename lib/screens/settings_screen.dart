import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
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
    final t = S.of(context);
    final theme = Theme.of(context);

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text(t, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              header(t.appLanguage),
              SegmentedButton<AppLang>(
                segments: [
                  for (final l in AppLang.values)
                    ButtonSegment(value: l, label: Text(l.label)),
                ],
                selected: {s.appLang},
                onSelectionChanged: (v) => s.setAppLang(v.first),
              ),
              header(t.cardDisplay),
              SwitchListTile(
                value: s.showPronunciation,
                onChanged: s.setShowPronunciation,
                secondary: const Icon(Icons.record_voice_over_outlined),
                title: Text(t.showPronunciation),
                subtitle: Text(t.showPronunciationSub),
              ),
              SwitchListTile(
                value: s.showSecondary,
                onChanged: s.setShowSecondary,
                secondary: const Icon(Icons.looks_two_outlined),
                title: Text(t.showSecondary),
                subtitle: Text(t.showSecondarySub),
              ),
              SwitchListTile(
                value: s.showMnemonic,
                onChanged: s.setShowMnemonic,
                secondary: const Icon(Icons.lightbulb_outline_rounded),
                title: Text(t.showMnemonic),
                subtitle: Text(t.showMnemonicSub),
              ),
              SwitchListTile(
                value: s.autoSpeak,
                onChanged: s.setAutoSpeak,
                secondary: const Icon(Icons.campaign_outlined),
                title: Text(t.autoSpeak),
                subtitle: Text(t.autoSpeakSub),
              ),

              header(t.dailyGoal),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(t.perDay(s.dailyGoal)),
                subtitle: Slider(
                  value: s.dailyGoal.toDouble(),
                  min: 5,
                  max: 100,
                  divisions: 19,
                  label: '${s.dailyGoal}',
                  onChanged: (v) => s.setDailyGoal(v.round()),
                ),
              ),

              header(t.appearance),
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_outlined), label: Text(t.themeSystem)),
                  ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined), label: Text(t.themeLight)),
                  ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined), label: Text(t.themeDark)),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.setThemeMode(v.first),
              ),

              header(t.autofillSection),
              DropdownMenu<String>(
                initialSelection: s.targetLang,
                expandedInsets: EdgeInsets.zero,
                label: Text(t.translateInto),
                onSelected: (v) {
                  if (v != null) s.setTargetLang(v);
                },
                dropdownMenuEntries: [
                  for (final code in kTargetLanguages.keys)
                    DropdownMenuEntry(value: code, label: t.targetLangName(code)),
                ],
              ),
              const SizedBox(height: 16),
              Text(t.geminiInfo, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: _key,
                obscureText: _obscure,
                onChanged: s.setGeminiKey,
                decoration: InputDecoration(
                  labelText: t.geminiKey,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _model,
                onChanged: s.setGeminiModel,
                decoration: InputDecoration(
                  labelText: t.geminiModel,
                  helperText: t.geminiModelHelp,
                  border: const OutlineInputBorder(),
                ),
              ),

              header(t.keyboard),
              _Shortcut(keys: 'Space', action: t.kFlip),
              _Shortcut(keys: '→ / 2', action: t.know),
              _Shortcut(keys: '← / 1', action: t.dontKnow),
              _Shortcut(keys: 'P', action: t.kPronounce),
              _Shortcut(keys: 'Esc', action: t.kEsc),
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
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
            child: Text(keys, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 16),
          Text(action),
        ],
      ),
    );
  }
}
