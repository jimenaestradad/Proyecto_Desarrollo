import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;

/// Runs [action] (a write to a doc `onUserCreate` provisions: `/users/{uid}`,
/// `pet/main`), retrying while that doc might not exist yet. Firebase Auth
/// account creation returns before the trigger is guaranteed to have run, so
/// a write right after sign-up/login can land first. A handful of short
/// retries covers the normal sub-second gap without leaving the caller stuck
/// if the doc genuinely never shows up: after [attempts] tries the last
/// error is rethrown, and any other error is rethrown immediately.
///
/// A write to a not-yet-provisioned doc can surface as either `not-found`
/// (the backend rejects the update outright) or `permission-denied` (the
/// update rule's `resource.data.diff(...)` check can only be evaluated once
/// `resource` exists; before that it's cleanly denied, per
/// firestore.rules). Both mean the doc isn't there yet, so both are retried.
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
      if (!isMissingDocRace || attempt >= attempts) rethrow;
      await Future.delayed(delay);
    }
  }
}
