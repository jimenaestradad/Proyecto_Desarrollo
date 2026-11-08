/// Tells a session that ended on its own (expired or revoked token, account
/// disabled or deleted elsewhere) apart from one the person ended with Log
/// out or Delete account, whose screens already navigate away themselves.
///
/// The repository calls [expectEnd] just before it signs out on purpose and
/// [cancelExpectedEnd] if that attempt fails and the session carries on.
class SessionWatch {
  bool _expected = false;

  void expectEnd() => _expected = true;

  void cancelExpectedEnd() => _expected = false;

  /// Emits once for every signed-in -> signed-out change in [signedIn] that
  /// [expectEnd] did not announce. The first value is the state right now,
  /// so someone already signed out at launch emits nothing.
  Stream<void> lost(Stream<bool> signedIn) async* {
    var wasSignedIn = false;
    await for (final isSignedIn in signedIn) {
      if (isSignedIn) {
        // A new sign-in: anything announced earlier no longer applies.
        _expected = false;
      } else {
        if (wasSignedIn && !_expected) yield null;
        _expected = false;
      }
      wasSignedIn = isSignedIn;
    }
  }
}
