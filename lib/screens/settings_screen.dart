import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../providers/settings_provider.dart';
import '../services/reminder_service.dart';
import 'ui_helpers.dart';

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

              header(t.arabicSection),
              SwitchListTile(
                value: s.arabicFont,
                onChanged: s.setArabicFont,
                secondary: const Text('ع', style: TextStyle(fontFamily: 'Amiri', fontSize: 26)),
                title: Text(t.arabicFont),
                subtitle: Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
                    style: TextStyle(fontFamily: s.arabicFont ? 'Amiri' : null, fontSize: 18)),
              ),
              ListTile(
                leading: const Icon(Icons.format_size_rounded),
                title: Text(t.wordSize((s.wordScale * 100).round())),
                subtitle: Slider(
                  value: s.wordScale,
                  min: 0.8,
                  max: 2.0,
                  divisions: 12,
                  label: '${(s.wordScale * 100).round()}%',
                  onChanged: s.setWordScale,
                ),
              ),

              header('🔔 ${t.reminder}'),
              SwitchListTile(
                value: s.reminderOn && ReminderService.supported,
                onChanged: ReminderService.supported
                    ? (v) async {
                        if (v && !await ReminderService.instance.requestPermission()) {
                          if (context.mounted) showSnack(context, t.reminderDenied);
                          return;
                        }
                        s.setReminder(on: v);
                        if (context.mounted) await syncReminder(context);
                      }
                    : null,
                secondary: const Icon(Icons.notifications_active_outlined),
                title: Text(t.reminderToggle),
                subtitle: Text(ReminderService.supported ? t.reminderSub : t.reminderUnsupported),
              ),
              ListTile(
                enabled: s.reminderOn && ReminderService.supported,
                leading: const Icon(Icons.schedule_rounded),
                title: Text(t.reminderTime),
                trailing: Text(
                  '${s.reminderHour.toString().padLeft(2, '0')}:${s.reminderMinute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.titleMedium,
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
                  );
                  if (picked == null) return;
                  s.setReminder(hour: picked.hour, minute: picked.minute);
                  if (context.mounted) await syncReminder(context);
                },
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
              Text(t.defaultLangs, style: theme.textTheme.bodySmall),
              const SizedBox(height: 10),
              for (final (label, value, apply) in <(String, String, void Function(String))>[
                (t.langWord, s.wordLang, (v) => s.setDefaultLangs(word: v)),
                (t.langPrimary, s.targetLang, (v) => s.setDefaultLangs(primary: v)),
                (t.langSecondary, s.secondaryLang, (v) => s.setDefaultLangs(secondary: v)),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownMenu<String>(
                    key: ValueKey('$label-$value'),
                    initialSelection: value,
                    expandedInsets: EdgeInsets.zero,
                    menuHeight: 360,
                    label: Text(label),
                    onSelected: (v) {
                      if (v != null) apply(v);
                    },
                    dropdownMenuEntries: [
                      for (final l in t.orderedLanguages)
                        DropdownMenuEntry(value: l.code, label: t.targetLangName(l.code)),
                    ],
                  ),
                ),
              Text(t.langSecondaryHint, style: theme.textTheme.bodySmall),
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
