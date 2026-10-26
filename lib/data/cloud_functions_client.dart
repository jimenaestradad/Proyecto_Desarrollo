import 'package:cloud_functions/cloud_functions.dart';

/// Thin, shared "call a callable Cloud Function, catch, surface a plain
/// error" helper -- see docs/BACKEND.md, "Online only -- no offline mode":
/// "One shared helper for 'call, catch, show error' is enough -- this
/// shouldn't become a per-screen pattern." Every Jimena-owned currency-
/// affecting action (shop purchases, bucket-list completion) goes through
/// this instead of each screen writing its own try/catch.
///
/// Kept deliberately dumb: no retry queue, no optimistic update to roll
/// back (per the same doc section, offline support is out of scope) --
/// just "call it, and turn whatever comes back into one plain message."
class CloudFunctionFailure implements Exception {
  const CloudFunctionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Invokes the callable Cloud Function [name] with [data] and returns its
/// response payload as a map (empty if the function returned nothing/
/// something else). Throws [CloudFunctionFailure] with a plain, user-
/// facing message on any failure -- network, timeout, or a rejection the
/// function itself raised (e.g. "Not enough coins.") via `HttpsError`.
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
    // `e.message` is whatever the function passed to `HttpsError` for an
    // expected, user-facing rejection (e.g. "Not enough coins.",
    // "You already own this accessory.") -- surface that as-is. Anything
    // else (deadline-exceeded, unavailable, internal, ...) gets the
    // generic offline-friendly message from docs/BACKEND.md.
    final message = switch (e.code) {
      'failed-precondition' ||
      'invalid-argument' ||
      'not-found' => e.message ?? "Couldn't complete that -- try again.",
      _ => "Couldn't reach the server -- try again.",
    };
    throw CloudFunctionFailure(message);
  } catch (_) {
    // Network failure, timeout, or anything else that isn't the
    // function's own expected rejection -- same generic message either
    // way (docs/BACKEND.md, "Online only -- no offline mode": "everything
    // fails the same way").
    throw const CloudFunctionFailure("Couldn't reach the server -- try again.");
  }
}
