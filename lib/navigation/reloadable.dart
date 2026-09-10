/// A tab hosted by `NoriShell` whose data can go stale while another tab
/// mutates shared state (XP, habits, pet stats). `NoriShell` keeps every
/// tab alive via `IndexedStack` rather than recreating it on each switch,
/// so a screen that only loads in `initState` would otherwise keep
/// showing pre-navigation data for the rest of the session (e.g.
/// completing a habit on Home wouldn't update Profile's XP/streak until
/// the whole app restarted).
///
/// Implement this on a tab's `State` and `NoriShell` calls [reload]
/// every time that tab becomes the active one.
abstract class Reloadable {
  Future<void> reload();
}
