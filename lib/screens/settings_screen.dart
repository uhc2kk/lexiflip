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
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text(t, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Sozlamalar')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              header('Karta ko\'rinishi'),
              SwitchListTile(
                value: s.showPronunciation,
                onChanged: s.setShowPronunciation,
                secondary: const Icon(Icons.record_voice_over_outlined),
                title: const Text('O\'qilishini ko\'rsatish'),
                subtitle: const Text('So\'z ostidagi lotincha o\'qilish / IPA'),
              ),
              SwitchListTile(
                value: s.showSecondary,
                onChanged: s.setShowSecondary,
                secondary: const Icon(Icons.looks_two_outlined),
                title: const Text('Ikkinchi tarjima'),
                subtitle: const Text('Orqa tomondagi qo\'shimcha / inglizcha tarjima'),
              ),
              SwitchListTile(
                value: s.showMnemonic,
                onChanged: s.setShowMnemonic,
                secondary: const Icon(Icons.lightbulb_outline_rounded),
                title: const Text('Eslatma maydoni'),
                subtitle: const Text('Orqa tomonda mnemonic yozish joyi'),
              ),
              SwitchListTile(
                value: s.autoSpeak,
                onChanged: s.setAutoSpeak,
                secondary: const Icon(Icons.campaign_outlined),
                title: const Text('Avto-talaffuz'),
                subtitle: const Text('Yangi karta chiqqanda so\'zni o\'qib beradi'),
              ),

              header('Kunlik maqsad'),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text('Kuniga ${s.dailyGoal} ta so\'z'),
                subtitle: Slider(
                  value: s.dailyGoal.toDouble(),
                  min: 5,
                  max: 100,
                  divisions: 19,
                  label: '${s.dailyGoal}',
                  onChanged: (v) => s.setDailyGoal(v.round()),
                ),
              ),

              header('Ko\'rinish'),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Tizim')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Yorug\'')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Qorong\'i')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.setThemeMode(v.first),
              ),

              header('Avto-to\'ldirish (inglizcha so\'zlar)'),
              DropdownMenu<String>(
                initialSelection: s.targetLang,
                expandedInsets: EdgeInsets.zero,
                label: const Text('Tarjima tili'),
                onSelected: (v) {
                  if (v != null) s.setTargetLang(v);
                },
                dropdownMenuEntries: [
                  for (final e in kTargetLanguagesUz.entries)
                    DropdownMenuEntry(value: e.key, label: e.value),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Gemini kaliti bo\'lsa, tarjimalar sifatliroq bo\'ladi. Bo\'lmasa bepul '
                'Dictionary + MyMemory ishlatiladi. Kalit faqat shu qurilmada saqlanadi.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _key,
                obscureText: _obscure,
                onChanged: s.setGeminiKey,
                decoration: InputDecoration(
                  labelText: 'Gemini API kaliti (ixtiyoriy)',
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
                decoration: const InputDecoration(
                  labelText: 'Gemini modeli',
                  helperText: 'masalan: gemini-2.5-flash',
                  border: OutlineInputBorder(),
                ),
              ),

              header('Klaviatura (kompyuter)'),
              const _Shortcut(keys: 'Space', action: 'Kartani aylantirish'),
              const _Shortcut(keys: '→ / 2', action: 'Bilaman'),
              const _Shortcut(keys: '← / 1', action: 'Bilmayman'),
              const _Shortcut(keys: 'P', action: 'Talaffuz'),
              const _Shortcut(keys: 'Esc', action: 'Eslatma maydonidan chiqish'),
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
