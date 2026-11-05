import 'package:flutter/material.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/habits/habits_list_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/social/social_screen.dart';
import '../widgets/email_verification_banner.dart';
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

  void _openHomeTab() => setState(() => _index = 0);
  void _openHabitsTab() => setState(() => _index = 1);

  List<Widget> get _tabs => [
    HomeScreen(active: _index == 0, onOpenHabits: _openHabitsTab),
    HabitsListScreen(active: _index == 1, onOpenHome: _openHomeTab),
    CalendarScreen(active: _index == 2),
    SocialScreen(active: _index == 3),
    ProfileScreen(active: _index == 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The banner sits above the tabs (not inside any one of them) so it
      // shows regardless of which tab is active, without touching each
      // tab's own — often visually fragile, see docs/KNOWN_ISSUES.md —
      // layout.
      body: Column(
        children: [
          const EmailVerificationBanner(),
          Expanded(
            child: IndexedStack(index: _index, children: _tabs),
          ),
        ],
      ),
      bottomNavigationBar: NoriBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
