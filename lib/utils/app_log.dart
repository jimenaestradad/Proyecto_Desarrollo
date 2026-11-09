import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart' show debugPrint;

/// Logs a tagged `[Nori]` failure through [debugPrint], including release web builds.
/// [where] names the failed action; pass [stack] only for non-[FirebaseException] errors.
void logError(String where, Object error, [StackTrace? stack]) {
  if (error is FirebaseException) {
    debugPrint(
      '[Nori] $where failed: ${error.plugin}/${error.code}'
      '${error.message == null ? '' : ' -- ${error.message}'}',
    );
    return;
  }
  debugPrint('[Nori] $where failed: ${error.runtimeType}: $error');
  if (stack != null) debugPrint('$stack');
}
