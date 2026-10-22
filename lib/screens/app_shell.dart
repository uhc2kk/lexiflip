import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../providers/library_provider.dart';
import 'challenges_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'ui_helpers.dart';

/// Root layout: 📚 Books · 🏆 Challenge · ⚙️ Settings.
/// Phone → bottom navigation bar; wide window (PC) → side rail.
/// Also refreshes due words and the reminder on start / resume.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Switches tab from anywhere below the shell (e.g. tapping the level card).
  static void goTo(BuildContext context, int index) {
    final shell = context.findAncestorStateOfType<AppShellState>();
    if (shell != null) {
      shell.goTo(index);
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChallengesScreen()));
    }
  }

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;

  void goTo(int i) => setState(() => _index = i);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await context.read<LibraryProvider>().refreshDue();
    if (mounted) await syncReminder(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final pages = const [HomeScreen(), ChallengesScreen(), SettingsScreen()];
    final body = IndexedStack(index: _index, children: pages);

    final items = [
      (Icons.menu_book_outlined, Icons.menu_book_rounded, t.tabBooks),
      (Icons.emoji_events_outlined, Icons.emoji_events_rounded, t.tabChallenges),
      (Icons.settings_outlined, Icons.settings_rounded, t.settings),
    ];

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: goTo,
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('🃏', style: TextStyle(fontSize: 28)),
            ),
            destinations: [
              for (final (o, s, l) in items)
                NavigationRailDestination(icon: Icon(o), selectedIcon: Icon(s), label: Text(l)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: goTo,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final (o, s, l) in items) NavigationDestination(icon: Icon(o), selectedIcon: Icon(s), label: l),
        ],
      ),
    );
  }
}
