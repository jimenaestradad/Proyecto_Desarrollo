// Dev-only harness: renders the Social tab with no sign-in so it can be
// previewed/screenshotted (`flutter run -d chrome -t tool/social_preview.dart`).
// Firebase is initialised (AppData's static fields construct Firebase-backed
// repositories) but never called — Social reads only AppData.social (in-memory)
// and the stubbed AppData.user below. Not part of the shipped app.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/user_repository.dart';
import 'package:nori/firebase_options.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/screens/social/add_friend_screen.dart';
import 'package:nori/screens/social/circle_detail_screen.dart';
import 'package:nori/screens/social/circle_editor_screen.dart';
import 'package:nori/screens/social/circles_screen.dart';
import 'package:nori/screens/social/competition_detail_screen.dart';
import 'package:nori/screens/social/competition_invite_screen.dart';
import 'package:nori/screens/social/competition_results_screen.dart';
import 'package:nori/screens/social/competitions_screen.dart';
import 'package:nori/screens/social/create_competition_screen.dart';
import 'package:nori/screens/social/feed_screen.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';
import 'package:nori/screens/social/friend_streak_detail_screen.dart';
import 'package:nori/screens/social/friend_streaks_screen.dart';
import 'package:nori/screens/social/friends_screen.dart';
import 'package:nori/screens/social/invite_friends_screen.dart';
import 'package:nori/screens/social/leaderboard_screen.dart';
import 'package:nori/screens/social/post_detail_screen.dart';
import 'package:nori/screens/social/post_proof_screen.dart';
import 'package:nori/screens/social/social_intro_view.dart';
import 'package:nori/screens/social/social_privacy_screen.dart';
import 'package:nori/screens/social/visit_pet_screen.dart';
import 'package:nori/screens/social/social_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/nori_bottom_nav.dart';

class _StubUserRepository implements UserRepository {
  @override
  NoriUser? get lastKnownUser => kDemoUser;
  @override
  Future<NoriUser> getCurrentUser() async => kDemoUser;
  @override
  Future<void> setVacationMode(bool enabled) async {}
  @override
  Future<void> updateProfile({
    String? name,
    String? username,
    String? email,
  }) async {}
  @override
  Future<bool> hasProfile() async => true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppData.user = _StubUserRepository();
  if (Uri.base.queryParameters['empty'] == '1') {
    await AppData.social.resetDemo(empty: true);
  }
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: AppScrollBehavior(),
      home: Scaffold(
        body: _screenFor(Uri.base.queryParameters['screen']),
        bottomNavigationBar: NoriBottomNav(currentIndex: 3, onTap: (_) {}),
      ),
    ),
  );
}

/// `?uid=alexh` picks the friend for the profile and pet screens.
String get _uid => Uri.base.queryParameters['uid'] ?? 'jimena';

/// `?screen=name` opens a screen directly (default: the hub) so each one can
/// be screenshotted without click-navigating to it.
Widget _screenFor(String? name) => switch (name) {
  'friends' => const FriendsScreen(),
  'requests' => const FriendsScreen(initialTab: 1),
  'add' => const AddFriendScreen(),
  'invite' => const InviteFriendsScreen(),
  'profile' => FriendProfileScreen(userId: _uid),
  'pet' => VisitPetScreen(userId: _uid),
  'privacy' => const SocialPrivacyScreen(),
  'feed' => const FeedScreen(),
  'post' => const PostDetailScreen(postId: 'p1'),
  'proof' => const PostProofScreen(),
  'compproof' => const PostProofScreen(competitionId: 'hydration'),
  'leaderboard' => const LeaderboardScreen(),
  'comps' => const CompetitionsScreen(),
  'invites' => const CompetitionsScreen(initialTab: 1),
  'past' => const CompetitionsScreen(initialTab: 2),
  'create' => const CreateCompetitionScreen(),
  'compdetail' => const CompetitionDetailScreen(competitionId: 'hydration'),
  'compinvite' => const CompetitionInviteScreen(competitionId: 'no-social'),
  'results' => const CompetitionResultsScreen(competitionId: 'morning-run'),
  'circles' => const CirclesScreen(),
  'circleeditor' => const CircleEditorScreen(),
  'circle' => const CircleDetailScreen(circleId: 'gym'),
  'streaks' => const FriendStreaksScreen(),
  'streak' => const FriendStreakDetailScreen(friendId: 'alexh'),
  'intro' => Scaffold(
    body: SafeArea(
      child: SocialIntroView(onFindFriends: () {}, onInvite: () {}),
    ),
  ),
  _ => SocialScreen(active: true, onOpenHome: () {}),
};
