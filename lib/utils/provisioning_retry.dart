import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;

import 'app_log.dart';

/// Retries [action] on not-found/permission-denied while `onUserCreate` provisions docs.
/// Auth may return first; rethrows after [attempts] or immediately for other errors.
Future<T> retryWhileProvisioning<T>(
  Future<T> Function() action, {
  int attempts = 8,
  Duration delay = const Duration(milliseconds: 600),
}) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await action();
    } on FirebaseException catch (e) {
      final isMissingDocRace =
          e.code == 'not-found' || e.code == 'permission-denied';
      if (!isMissingDocRace || attempt >= attempts) {
        // Giving up on a missing doc is the tell-tale of an account that
        // onUserCreate never provisioned (e.g. one made by hand in the
        // Firebase console) -- say so, since the UI only shows a generic error.
        if (isMissingDocRace) {
          logError('write to users/pet doc (gave up after $attempts tries)', e);
        }
        rethrow;
      }
      await Future.delayed(delay);
    }
  }
}
