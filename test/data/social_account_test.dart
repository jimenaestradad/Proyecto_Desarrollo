import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/mock_social_repository.dart';
import 'package:nori/data/social_account.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/models/social_people.dart';

class _FakeAccount implements SocialAccountSource {
  _FakeAccount({this.failMe = false, this.habits});

  bool failMe;
  List<ProofableHabit>? habits;
  int loads = 0;

  @override
  Future<SocialUser> loadMe(SocialUser fallback) async {
    loads++;
    if (failMe) throw StateError('offline');
    return SocialUser(
      id: 'me',
      name: 'Valeria Vasquez',
      username: 'valevasqc',
      level: 3,
      weeklyXp: 90,
      totalXp: 500,
      currentStreak: 2,
      proofCount: fallback.proofCount,
      petName: 'Biscuit',
      petStage: 0,
    );
  }

  @override
  Future<List<ProofableHabit>?> loadCompletedHabitsToday() async => habits;
}

void main() {
  test('getMe returns the real account and leaderboard ranks it', () async {
    final repo = MockSocialRepository(account: _FakeAccount());
    final me = await repo.getMe();
    expect(me.name, 'Valeria Vasquez');
    expect(me.username, 'valevasqc');

    final board = await repo.getLeaderboard();
    final mine = board.singleWhere((e) => e.user.isMe);
    expect(mine.xp, 90);
    expect(mine.user.name, 'Valeria Vasquez');
    expect(board.length, greaterThan(1), reason: 'friends stay seeded');

    final invite = await repo.getInviteInfo();
    expect(invite.username, 'valevasqc');
    expect(invite.link, contains('valevasqc'));
  });

  test('falls back to the seed profile when the account cannot load', () async {
    final repo = MockSocialRepository(account: _FakeAccount(failMe: true));
    final me = await repo.getMe();
    expect(me.name, 'Hannah Walker');
  });

  test('caches for a moment, and accountChanged drops it', () async {
    final account = _FakeAccount();
    final repo = MockSocialRepository(account: account);
    await repo.getMe();
    await repo.getMe();
    await repo.getUserDirectory();
    expect(account.loads, 1);

    repo.accountChanged();
    await repo.getMe();
    expect(account.loads, 2);
  });

  test(
    'proof composer offers real completed habits, else the samples',
    () async {
      final real = [
        const ProofableHabit(
          id: 'h1',
          name: 'Stretch',
          icon: Icons.accessibility_new,
          color: Colors.white,
        ),
      ];
      final account = _FakeAccount(habits: real);
      final repo = MockSocialRepository(account: account);
      expect((await repo.getProofableHabits()).single.name, 'Stretch');

      account.habits = const [];
      expect((await repo.getProofableHabits()).length, 3);
      account.habits = null;
      expect((await repo.getProofableHabits()).length, 3);
    },
  );

  test('without an account source it behaves exactly like the mock', () async {
    final repo = MockSocialRepository();
    expect((await repo.getMe()).name, 'Hannah Walker');
  });
}
