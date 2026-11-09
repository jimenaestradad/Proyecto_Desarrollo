import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/session_watch.dart';

void main() {
  late SessionWatch watch;
  late StreamController<bool> signedIn;
  late int lost;

  setUp(() {
    watch = SessionWatch();
    signedIn = StreamController<bool>();
    lost = 0;
    watch.lost(signedIn.stream).listen((_) => lost++);
  });

  tearDown(() => signedIn.close());

  Future<void> emit(bool value) async {
    signedIn.add(value);
    await Future<void>.delayed(Duration.zero);
  }

  test('signed in then signed out on its own is a lost session', () async {
    await emit(true);
    await emit(false);
    expect(lost, 1);
  });

  test('being signed out at launch is not a lost session', () async {
    await emit(false);
    expect(lost, 0);
  });

  test('a sign-out announced with expectEnd is not a lost session', () async {
    await emit(true);
    watch.expectEnd();
    await emit(false);
    expect(lost, 0);
  });

  test('the announcement covers one sign-out only', () async {
    await emit(true);
    watch.expectEnd();
    await emit(false);
    await emit(true);
    await emit(false);
    expect(lost, 1);
  });

  test('a cancelled announcement does not hide a later loss', () async {
    await emit(true);
    watch.expectEnd();
    watch.cancelExpectedEnd();
    await emit(false);
    expect(lost, 1);
  });

  test('an announcement left over from an earlier sign-out is dropped on the '
      'next sign-in', () async {
    await emit(true);
    watch.expectEnd(); // logOut announced, but the account was already out
    await emit(true);
    await emit(false);
    expect(lost, 1);
  });
}
