import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_date.dart';
import 'habit_history_store.dart' show dateOnly;
import 'signed_in_uid.dart';

/// Tracks Vacation Mode's on/off history by date, independent of whether the
/// toggle is still on today — so a streak walk over past days can tell which
/// of them were frozen even after the user has since turned it back off.
///
/// Kept as its own small store (same pattern as [HabitHistoryStore]) rather
/// than living on [UserRepository] or [CalendarRepository]: both of those
/// need to read/write this, and [UserRepository] already depends on
/// [CalendarRepository] to compute the live streak, so a direct dependency
/// the other way would be circular.
///
/// `Future`-returning even for [MockVacationLog] (which has no real I/O) to
/// match every other repository interface's convention — see
/// docs/BACKEND.md "Conventions locked".
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

/// Real Firestore-backed [VacationLog]. `vacationModeEnabled`/
/// `vacationRanges` live directly on the `/users/{uid}` doc (see
/// docs/BACKEND.md "Firestore schema") — a currently-open freeze is the
/// last entry in `vacationRanges` with `end: null`; `vacationModeEnabled`
/// mirrors that as a quick boolean so a settings toggle doesn't need to
/// parse the array just to render itself. (This exact encoding wasn't
/// pinned down in the schema doc before now — logged as resolved there.)
///
/// [isFrozen] gets called once per day in [FirestoreCalendarRepository]'s
/// month grid and up-to-400-day streak walk — turning that into up to 400
/// Firestore reads would reintroduce exactly the N+1 problem [logsInRange]
/// exists to avoid on the habit side. So this fetches the ranges **once**
/// (cached for as long as this object lives — in practice, the lifetime of
/// the app, since `AppData.vacationLog` is a single long-lived instance)
/// and answers every later call from that in-memory copy.
class FirestoreVacationLog implements VacationLog {
  List<_FrozenRange> _closed = [];
  DateTime? _openStart;

  /// Memoizes the *loading operation*, not just its result — so two calls
  /// racing before the first fetch completes share one Firestore read
  /// instead of each starting their own.
  Future<void>? _loadFuture;

  /// Which uid [_loadFuture] was fetched for — [_ensureLoaded] compares this
  /// against the currently signed-in uid on every call and refetches if
  /// they differ, so a sign-out/sign-in during the same app session can't
  /// leave one user reading (or, via [startFreeze]/[endFreeze], overwriting)
  /// another user's vacation ranges.
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

  List<Map<String, dynamic>> _toRangesJson() => [
    for (final range in _closed) {'start': range.start, 'end': range.end},
    if (_openStart != null) {'start': _openStart, 'end': null},
  ];

  @override
  Future<void> startFreeze(DateTime day) async {
    await _ensureLoaded();
    if (_openStart != null) return;
    _openStart = dateOnly(day);
    await _userDoc.update({
      'vacationModeEnabled': true,
      'vacationRanges': _toRangesJson(),
    });
  }

  @override
  Future<void> endFreeze(DateTime day) async {
    await _ensureLoaded();
    final start = _openStart;
    if (start == null) return;
    _closed = [..._closed, _FrozenRange(start, dateOnly(day))];
    _openStart = null;
    await _userDoc.update({
      'vacationModeEnabled': false,
      'vacationRanges': _toRangesJson(),
    });
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
