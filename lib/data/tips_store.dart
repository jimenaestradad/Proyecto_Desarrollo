import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one-time hint cards a screen can show (see `OneTimeHint`).
enum Tip { habitsGestures, calendarDays, limitHabits, adaptiveXp }

/// Device-local, per-user record of intro cards and [Tip] visibility.
/// Storage failures count as already seen to avoid repeated prompts.
class TipsStore {
  const TipsStore(this.uid);

  /// The signed-in account, or a shared bucket if somehow signed out.
  factory TipsStore.current() {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      // Firebase isn't initialised (a widget test): use the shared bucket.
    }
    return TipsStore(uid ?? 'signed-out');
  }

  final String uid;

  /// Bumped by [reset]. Tabs stay mounted in `NoriShell`'s `IndexedStack`, so
  /// a hint card that's already been dismissed listens to this to come back
  /// without an app restart.
  static final ValueNotifier<int> resets = ValueNotifier(0);

  String get _introKey => 'tips.$uid.intro';
  String _hintKey(Tip tip) => 'tips.$uid.hint.${tip.name}';

  Future<bool> hasSeenIntro() => _read(_introKey);
  Future<void> markIntroSeen() => _write(_introKey, true);

  Future<bool> isHintDismissed(Tip tip) => _read(_hintKey(tip));
  Future<void> dismissHint(Tip tip) => _write(_hintKey(tip), true);

  /// Settings' "Replay intro and tips": forget everything for this account.
  Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_introKey);
      for (final tip in Tip.values) {
        await prefs.remove(_hintKey(tip));
      }
    } catch (_) {
      // Nothing to reset if storage is unavailable.
    }
    resets.value++;
  }

  Future<bool> _read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return true;
    }
  }

  Future<void> _write(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // Best-effort, same reasoning as _read.
    }
  }
}
