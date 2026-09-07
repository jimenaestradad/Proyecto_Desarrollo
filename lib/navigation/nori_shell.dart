import 'package:flutter/material.dart';
import '../screens/achievements/achievements_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/habits/habits_list_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../widgets/nori_bottom_nav.dart';

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

  void _openHabitsTab() => setState(() => _index = 1);

  List<Widget> get _tabs => [
    HomeScreen(onOpenHabits: _openHabitsTab),
    const HabitsListScreen(),
    const CalendarScreen(),
    const AchievementsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NoriBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
