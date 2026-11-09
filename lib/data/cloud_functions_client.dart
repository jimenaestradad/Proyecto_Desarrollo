import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Shared callable-function failure message for currency actions and remote errors.
/// This layer never retries; screens apply optimistic updates and roll back on failure.
const serverUnreachableMessage = "Couldn't reach the server — try again.";

class CloudFunctionFailure implements Exception {
  const CloudFunctionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls [name] with [data], returning a response map or an empty map.
/// Throws [CloudFunctionFailure] with a user-facing message on failure.
Future<Map<String, dynamic>> callCloudFunction(
  String name,
  Map<String, dynamic> data, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  try {
    final callable = FirebaseFunctions.instance.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: timeout),
    );
    final response = await callable.call(data);
    final result = response.data;
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return <String, dynamic>{};
  } on FirebaseFunctionsException catch (e) {
    // Logged before it's flattened into one friendly sentence below: a
    // blocked CORS preflight or a missing IAM binding otherwise shows up
    // only as "Couldn't reach the server", with nothing in the console.
    debugPrint('$name failed: ${e.code} ${e.message} ${e.details ?? ''}');
    // Surface expected HttpsError rejection messages as-is.
    // Use the generic server message for unexpected or connectivity failures.
    final message = switch (e.code) {
      'failed-precondition' ||
      'invalid-argument' ||
      'not-found' => e.message ?? "Couldn't complete that — try again.",
      // An expired session isn't a network problem; retrying won't help.
      'unauthenticated' => 'Your session expired — please log in again.',
      _ => serverUnreachableMessage,
    };
    throw CloudFunctionFailure(message);
  } catch (e) {
    // Network failure, timeout, or anything else that isn't the
    // function's own expected rejection -- same generic message either
    // way (docs/technical/BACKEND.md, "Online only -- no offline mode": "everything
    // fails the same way").
    debugPrint('$name failed: $e');
    throw const CloudFunctionFailure(serverUnreachableMessage);
  }
}
