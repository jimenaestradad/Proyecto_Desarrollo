import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/cloud_functions_client.dart';

/// Shared repository error handling through [RemoteLoadState.guardedLoad]
/// and [RemoteLoadState.guardedAction].

/// Bounds guarded operations so unacknowledged Firestore writes cannot hang the UI.
/// Exceeds callable functions' 15s timeout to allow a subsequent reload.
const remoteTimeout = Duration(seconds: 20);

/// One plain, user-facing sentence for whatever a repository or Cloud
/// Function call threw.
String remoteErrorMessage(Object error) {
  if (error is CloudFunctionFailure) return error.message;
  if (error is FirebaseException && error.code == 'permission-denied') {
    return "You don't have permission to do that.";
  }
  return serverUnreachableMessage;
}

void showRemoteError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(remoteErrorMessage(error))));
}

/// Still logs the real error in debug -- a blanket catch shouldn't turn a
/// genuine bug (a bad cast, a missing field) into a silent "try again".
void _report(Object error, StackTrace stack) {
  FlutterError.reportError(
    FlutterErrorDetails(exception: error, stack: stack, library: 'nori'),
  );
}

mixin RemoteLoadState<T extends StatefulWidget> on State<T> {
  /// Set when the last [guardedLoad] failed; cleared when one succeeds.
  /// A screen with no data yet shows `LoadErrorView` instead of its
  /// spinner while this is non-null.
  Object? loadError;

  /// Runs [load]. On failure: if the screen already has data
  /// ([hasData]), keeps showing it and surfaces a snackbar; otherwise
  /// records [loadError] so the build can swap the spinner for a retry.
  Future<void> guardedLoad(
    Future<void> Function() load, {
    required bool hasData,
  }) async {
    try {
      await load().timeout(remoteTimeout);
      if (mounted && loadError != null) setState(() => loadError = null);
    } catch (error, stack) {
      _report(error, stack);
      if (!mounted) return;
      setState(() => loadError = error);
      if (hasData) showRemoteError(context, error);
    }
  }

  /// Runs a user-triggered [action] (claim, save, buy, ...). On failure
  /// a snackbar explains. A screen that changed itself first re-reads from
  /// the server on failure to undo that change. Returns whether it
  /// succeeded, for callers that only continue (pop, celebrate) on success.
  Future<bool> guardedAction(Future<void> Function() action) async {
    try {
      await action().timeout(remoteTimeout);
      return true;
    } catch (error, stack) {
      _report(error, stack);
      if (mounted) showRemoteError(context, error);
      return false;
    }
  }
}
