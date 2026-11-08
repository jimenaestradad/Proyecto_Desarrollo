import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_date.dart';
import 'habit_history_store.dart' show dateOnly;
import 'signed_in_uid.dart';

/// Tracks frozen dates even after Vacation Mode is disabled.
/// Separate from user/calendar repositories to avoid a circular dependency;
/// Future-based operations follow the repository convention.
abstract class VacationLog {
  /// Starts (or extends, if already open) a frozen period as of [day].
  Future<void> startFreeze(DateTime day);

  /// Closes the currently-open frozen period as of [day]. No-op if nothing
  /// is currently open.
  Future<void> endFreeze(DateTime day);

  /// Whether Vacation Mode was active on [day] — either inside a closed past
  /// period, or on/after a still-open one.
  Future<bool> isFrozen(DateTime day);
}

class MockVacationLog implements VacationLog {
  final List<_FrozenRange> _closed = [];
  DateTime? _openStart;

  @override
  Future<void> startFreeze(DateTime day) async {
    _openStart ??= dateOnly(day);
  }

  @override
  Future<void> endFreeze(DateTime day) async {
    final start = _openStart;
    if (start == null) return;
    _closed.add(_FrozenRange(start, dateOnly(day)));
    _openStart = null;
  }

  @override
  Future<bool> isFrozen(DateTime day) async =>
      _isFrozenAt(_closed, _openStart, day);
}

/// Stores vacationRanges and vacationModeEnabled on `/users/{uid}`.
/// An open range has `end: null`; cached ranges avoid per-day Firestore reads.
class FirestoreVacationLog implements VacationLog {
  List<_FrozenRange> _closed = [];
  DateTime? _openStart;

  /// Memoizes the *loading operation*, not just its result — so two calls
  /// racing before the first fetch completes share one Firestore read
  /// instead of each starting their own.
  Future<void>? _loadFuture;

  /// Tracks which account owns the cached ranges.
  /// [_ensureLoaded] refetches on uid changes to prevent cross-account reads or writes.
  String? _loadedUid;

  String get _uid => requireSignedInUid('FirestoreVacationLog');

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(_uid);

  Future<void> _ensureLoaded() async {
    final uid = _uid;
    if (_loadedUid != uid) {
      _loadedUid = uid;
      _loadFuture = _load();
    }
    try {
      await _loadFuture;
    } catch (_) {
      // Don't let a failed fetch (e.g. the user doc not existing yet — see
      // docs/BACKEND.md) poison the cache forever; the next call retries.
      _loadFuture = null;
      _loadedUid = null;
      rethrow;
    }
  }

  Future<void> _load() async {
    final snapshot = await _userDoc.get();
    final raw = (snapshot.data()?['vacationRanges'] as List<dynamic>?) ?? [];
    final closed = <_FrozenRange>[];
    DateTime? open;
    for (final entry in raw) {
      final range = entry as Map<String, dynamic>;
      final start = dateFromFirestoreValue(range['start'])!;
      final end = range['end'];
      if (end == null) {
        open = start;
      } else {
        closed.add(_FrozenRange(start, dateFromFirestoreValue(end)!));
      }
    }
    _closed = closed;
    _openStart = open;
  }

  List<Map<String, dynamic>> _rangesJson(
    List<_FrozenRange> closed,
    DateTime? open,
  ) => [
    for (final range in closed) {'start': range.start, 'end': range.end},
    if (open != null) {'start': open, 'end': null},
  ];

  // The cache changes only after the write succeeds, so a rejected write
  // can't leave the calendar frozen (or a retry skipped) until a restart.
  @override
  Future<void> startFreeze(DateTime day) async {
    await _ensureLoaded();
    if (_openStart != null) return;
    final start = dateOnly(day);
    await _userDoc.update({
      'vacationModeEnabled': true,
      'vacationRanges': _rangesJson(_closed, start),
    });
    _openStart = start;
  }

  @override
  Future<void> endFreeze(DateTime day) async {
    await _ensureLoaded();
    final start = _openStart;
    if (start == null) return;
    final closed = [..._closed, _FrozenRange(start, dateOnly(day))];
    await _userDoc.update({
      'vacationModeEnabled': false,
      'vacationRanges': _rangesJson(closed, null),
    });
    _closed = closed;
    _openStart = null;
  }

  @override
  Future<bool> isFrozen(DateTime day) async {
    await _ensureLoaded();
    return _isFrozenAt(_closed, _openStart, day);
  }
}

class _FrozenRange {
  const _FrozenRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

/// Shared by [MockVacationLog] and [FirestoreVacationLog] — both track the
/// same two pieces of state (closed ranges + an optional still-open one),
/// they just get that state from different places (an in-memory list vs.
/// a cached Firestore fetch).
bool _isFrozenAt(List<_FrozenRange> closed, DateTime? openStart, DateTime day) {
  final d = dateOnly(day);
  if (openStart != null && !d.isBefore(openStart)) return true;
  for (final range in closed) {
    if (!d.isBefore(range.start) && !d.isAfter(range.end)) return true;
  }
  return false;
}
