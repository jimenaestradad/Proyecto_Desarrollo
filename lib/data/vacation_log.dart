import 'habit_history_store.dart' show dateOnly;

/// Tracks Vacation Mode's on/off history by date, independent of whether the
/// toggle is still on today — so a streak walk over past days can tell which
/// of them were frozen even after the user has since turned it back off.
///
/// Kept as its own small store (same pattern as [HabitHistoryStore]) rather
/// than living on [UserRepository] or [CalendarRepository]: both of those
/// need to read/write this, and [UserRepository] already depends on
/// [CalendarRepository] to compute the live streak, so a direct dependency
/// the other way would be circular.
class VacationLog {
  final List<_FrozenRange> _closed = [];
  DateTime? _openStart;

  /// Starts (or extends, if already open) a frozen period as of [day].
  void startFreeze(DateTime day) {
    _openStart ??= dateOnly(day);
  }

  /// Closes the currently-open frozen period as of [day]. No-op if nothing
  /// is currently open.
  void endFreeze(DateTime day) {
    final start = _openStart;
    if (start == null) return;
    _closed.add(_FrozenRange(start, dateOnly(day)));
    _openStart = null;
  }

  /// Whether Vacation Mode was active on [day] — either inside a closed past
  /// period, or on/after an still-open one.
  bool isFrozen(DateTime day) {
    final d = dateOnly(day);
    final openStart = _openStart;
    if (openStart != null && !d.isBefore(openStart)) return true;
    for (final range in _closed) {
      if (!d.isBefore(range.start) && !d.isAfter(range.end)) return true;
    }
    return false;
  }
}

class _FrozenRange {
  const _FrozenRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}
