/// A tab state that [reload] refreshes whenever NoriShell activates it.
/// IndexedStack keeps tabs alive, so initState alone leaves shared data stale.
abstract class Reloadable {
  Future<void> reload();
}
