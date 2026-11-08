/// Runs async calls one after another, in the order they were queued.
///
/// Screens that show a change before the server confirms it use this so
/// that two quick taps reach the server in the order they were made (an
/// edit never overtakes the create it depends on). A call that fails does
/// not stop the ones queued behind it.
class OrderedQueue {
  Future<void> _tail = Future.value();

  Future<void> run(Future<void> Function() call) {
    final next = _tail.catchError((_) {}).then((_) => call());
    _tail = next;
    return next;
  }
}
