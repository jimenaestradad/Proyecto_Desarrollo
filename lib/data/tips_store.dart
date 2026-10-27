import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one-time hint cards a screen can show (see `OneTimeHint`).
enum Tip { habitsGestures, calendarDays }

/// Remembers which first-run help this account has already seen: the intro
/// cards and each [Tip]. Device-local (`shared_preferences`: Android's own
/// settings storage, the browser's localStorage on web), keyed by user id so
/// a second account on the same phone still gets its own intro. A reinstall
/// shows everything again, which is harmless; nothing here is worth a
/// Firestore field or a rules deploy.
///
/// Storage can fail (private browser windows, cleared site data), and help
/// text isn't worth an error, so every read falls back to "already seen" —
/// better to miss a tip than to nag on every launch.
class TipsStore {
  const TipsStore(this.uid);

  /// The signed-in account, or a shared bucket if somehow signed out.
  factory TipsStore.current() =>
      TipsStore(FirebaseAuth.instance.currentUser?.uid ?? 'signed-out');

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
