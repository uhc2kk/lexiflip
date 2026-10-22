import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/strings.dart';
import 'providers/library_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/stats_provider.dart';
import 'screens/app_shell.dart';
import 'services/autofill_service.dart';
import 'services/storage_service.dart';
import 'services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
        Provider(create: (_) => TtsService()),
        Provider(
          create: (_) => AutofillService(),
          dispose: (_, s) => s.dispose(),
        ),
      ],
      child: const LexiFlipApp(),
    ),
  );
}

class LexiFlipApp extends StatelessWidget {
  const LexiFlipApp({super.key});

  static const _seed = Color(0xFF4F6D7A); // calm slate blue

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
          letterSpacing: 0.2,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.select<SettingsProvider, ThemeMode>((s) => s.themeMode);
    final lang = context.select<SettingsProvider, AppLang>((s) => s.appLang);
    return L10nScope(
      strings: S(lang),
      child: MaterialApp(
      title: 'LexiFlip',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: mode,
      home: const AppShell(),
      ),
    );
  }
}
