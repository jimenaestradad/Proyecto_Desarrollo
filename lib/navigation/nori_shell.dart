import 'package:flutter/material.dart';
import '../screens/achievements/achievements_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/habits/habits_list_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../widgets/nori_bottom_nav.dart';
import 'reloadable.dart';

/// Hosts the five main tabs behind a shared bottom nav. Each tab is a full
/// [Scaffold] with its own app bar, so nesting them here just swaps bodies
/// — no shared app-bar logic to keep in sync across very different headers.
class NoriShell extends StatefulWidget {
  const NoriShell({super.key});

  @override
  State<NoriShell> createState() => _NoriShellState();
}

class _NoriShellState extends State<NoriShell> {
  int _index = 0;

  // One GlobalKey per tab so we can reach its State and call [Reloadable.
  // reload] on it — see reload comment in [_selectTab].
  final _tabKeys = List.generate(5, (_) => GlobalKey());

  void _openHabitsTab() => _selectTab(1);

  void _selectTab(int index) {
    setState(() => _index = index);
    // IndexedStack below keeps all five tabs alive rather than recreating
    // them, so each one's initState-only data load would otherwise go
    // stale the moment another tab changes shared state (XP, habits, pet
    // stats) — e.g. completing a habit on Home wouldn't show up on
    // Profile until the app restarted. Refresh whichever tab we just
    // switched to instead.
    (_tabKeys[index].currentState as Reloadable?)?.reload();
  }

  List<Widget> get _tabs => [
    HomeScreen(key: _tabKeys[0], onOpenHabits: _openHabitsTab),
    HabitsListScreen(key: _tabKeys[1]),
    CalendarScreen(key: _tabKeys[2]),
    AchievementsScreen(key: _tabKeys[3]),
    ProfileScreen(key: _tabKeys[4]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NoriBottomNav(
        currentIndex: _index,
        onTap: _selectTab,
      ),
    );
  }
}
