import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/user_repository.dart';
import 'package:nori/data/username_repository.dart';
import 'package:nori/utils/account_setup.dart';

class _Usernames implements UsernameRepository {
  _Usernames(this.claimed, {this.fails = false});
  final String? claimed;
  final bool fails;

  @override
  Future<String?> usernameForUid(String uid) async {
    if (fails) throw StateError('offline');
    return claimed;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Users implements UserRepository {
  _Users({required this.hasProfileValue});
  final bool hasProfileValue;

  @override
  Future<bool> hasProfile() async => hasProfileValue;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('complete: username claimed and profile saved', () async {
    expect(
      await isSignUpComplete(
        'u1',
        usernames: _Usernames('nori_fan'),
        users: _Users(hasProfileValue: true),
      ),
      isTrue,
    );
  });

  test('incomplete: no username claimed yet', () async {
    expect(
      await isSignUpComplete(
        'u1',
        usernames: _Usernames(null),
        users: _Users(hasProfileValue: false),
      ),
      isFalse,
    );
  });

  test('incomplete: claimed but the profile was never saved', () async {
    expect(
      await isSignUpComplete(
        'u1',
        usernames: _Usernames('nori_fan'),
        users: _Users(hasProfileValue: false),
      ),
      isFalse,
    );
  });

  test('a check that cannot be made counts as complete', () async {
    expect(
      await isSignUpComplete(
        'u1',
        usernames: _Usernames(null, fails: true),
        users: _Users(hasProfileValue: false),
      ),
      isTrue,
    );
  });
}
