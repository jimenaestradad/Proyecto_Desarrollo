import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/utils/provisioning_retry.dart';

FirebaseException firebaseError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  test('returns the first success without retrying', () async {
    var calls = 0;
    final result = await retryWhileProvisioning(() async {
      calls++;
      return 'ok';
    }, delay: Duration.zero);
    expect(result, 'ok');
    expect(calls, 1);
  });

  for (final code in ['not-found', 'permission-denied']) {
    test('retries $code until the doc exists', () async {
      var calls = 0;
      final result = await retryWhileProvisioning(() async {
        calls++;
        if (calls < 3) throw firebaseError(code);
        return calls;
      }, delay: Duration.zero);
      expect(result, 3);
    });
  }

  test('gives up after [attempts] and rethrows the last error', () async {
    var calls = 0;
    await expectLater(
      retryWhileProvisioning(
        () async {
          calls++;
          throw firebaseError('not-found');
        },
        attempts: 4,
        delay: Duration.zero,
      ),
      throwsA(
        isA<FirebaseException>().having((e) => e.code, 'code', 'not-found'),
      ),
    );
    expect(calls, 4);
  });

  test('rethrows other Firebase errors immediately', () async {
    var calls = 0;
    await expectLater(
      retryWhileProvisioning(() async {
        calls++;
        throw firebaseError('unavailable');
      }, delay: Duration.zero),
      throwsA(isA<FirebaseException>()),
    );
    expect(calls, 1);
  });

  test('does not swallow non-Firebase errors', () async {
    var calls = 0;
    await expectLater(
      retryWhileProvisioning(() async {
        calls++;
        throw StateError('bug');
      }, delay: Duration.zero),
      throwsStateError,
    );
    expect(calls, 1);
  });
}
