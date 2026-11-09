import '../data/app_data.dart';
import '../data/user_repository.dart';
import '../data/username_repository.dart';
import 'app_log.dart';

/// Whether a signed-in account finished sign-up: it claimed a username AND
/// its profile (name, username) was saved. One that didn't was interrupted
/// mid-sign-up (see FinishSignUpScreen). The username claim and the profile
/// save are separate writes, so an app closed between them leaves a claimed
/// name on an empty profile; checking only the claim would open Home with a
/// blank identity.
///
/// If the check can't be made, say yes: failing to read shouldn't lock anyone
/// out of an account that is fine, and every screen has its own error handling.
///
/// [usernames] and [users] default to the app's repositories; tests pass fakes.
Future<bool> isSignUpComplete(
  String uid, {
  UsernameRepository? usernames,
  UserRepository? users,
}) async {
  try {
    final username = await (usernames ?? AppData.usernames)
        .usernameForUid(uid)
        .timeout(const Duration(seconds: 5));
    if (username == null) return false;
    return await (users ?? AppData.user).hasProfile().timeout(
      const Duration(seconds: 5),
    );
  } catch (error, stackTrace) {
    logError('sign-up check', error, stackTrace);
    return true;
  }
}
