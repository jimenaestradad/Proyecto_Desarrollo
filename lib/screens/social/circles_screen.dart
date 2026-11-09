import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/circle_detail_screen.dart';
import 'package:nori/screens/social/circle_editor_screen.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/circular_icon_button.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/tactile_button.dart';

class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key});

  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen>
    with RemoteLoadState<CirclesScreen>, SocialLoadState<CirclesScreen> {
  List<SocialCircle> _circles = [];
  Map<String, SocialUser> _people = {};
  final Set<String> _nudging = {};

  @override
  Future<void> loadSocial() async {
    final circles = await AppData.social.getCircles();
    final people = await AppData.social.getUserDirectory();
    if (!mounted) return;
    setState(() {
      _circles = circles;
      _people = people;
    });
  }

  void _create() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => const CircleEditorScreen()),
  );

  Future<void> _nudge(SocialCircle circle) async {
    if (_nudging.contains(circle.id)) return;
    setState(() => _nudging.add(circle.id));
    var count = 0;
    final success = await guardedAction(() async {
      count = await AppData.social.nudgeCircle(circle.id);
    });
    if (!mounted) return;
    setState(() => _nudging.remove(circle.id));
    if (success) showSocialToast(context, 'Nudged $count friends');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded(
        (context) => NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Circles',
              titleStyle: AppTextStyles.headlineLgMobile,
              trailing: CircularIconButton(
                icon: Icons.add,
                tooltip: 'Create a circle',
                onPressed: _create,
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (_circles.isEmpty)
              NoriEmptyState(
                icon: Icons.groups,
                title: 'No circles yet',
                message: 'Bring a few friends together to build habits.',
                actionLabel: 'Create a circle',
                onAction: _create,
              )
            else
              for (final circle in _circles) ...[
                _CircleCard(
                  circle: circle,
                  members: [for (final id in circle.memberIds) ?_people[id]],
                  nudging: _nudging.contains(circle.id),
                  onNudge: () => _nudge(circle),
                  onOpen: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CircleDetailScreen(circleId: circle.id),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.stackSm),
              ],
          ],
        ),
      ),
    ),
  );
}

class _CircleCard extends StatelessWidget {
  const _CircleCard({
    required this.circle,
    required this.members,
    required this.nudging,
    required this.onNudge,
    required this.onOpen,
  });

  final SocialCircle circle;
  final List<SocialUser> members;
  final bool nudging;
  final VoidCallback onNudge;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => NoriCard(
    color: circle.color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CoverBadge(
              icon: circle.icon,
              background: AppColors.white,
              size: 48,
              iconSize: 24,
              asset: circle.coverAsset,
            ),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(circle.name, style: AppTextStyles.headlineLgMobile),
                  Text(
                    '${circle.friendCount} friends · ${(circle.completionRate * 100).round()}% completion',
                    style: AppTextStyles.labelSm,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.gutter),
        Row(
          children: [
            if (members.isNotEmpty)
              SizedBox(
                height: 40,
                width: 40 + (members.take(4).length - 1) * AppSpacing.stackMd,
                child: Stack(
                  children: [
                    for (var i = 0; i < members.take(4).length; i++)
                      Positioned(
                        left: i * AppSpacing.stackMd,
                        child: Semantics(
                          label: members[i].isMe ? 'You' : members[i].name,
                          button: !members[i].isMe,
                          child: GestureDetector(
                            onTap: members[i].isMe
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => FriendProfileScreen(
                                        userId: members[i].id,
                                      ),
                                    ),
                                  ),
                            child: SocialAvatar(user: members[i]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (members.length > 4) ...[
              const SizedBox(width: AppSpacing.unit),
              Text('+${members.length - 4}', style: AppTextStyles.labelLg),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.gutter),
        Row(
          children: [
            Expanded(
              child: TactileButton(label: 'Open', onPressed: onOpen),
            ),
            const SizedBox(width: AppSpacing.stackSm),
            TextButton.icon(
              onPressed: nudging || circle.friendCount == 0 ? null : onNudge,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(
                nudging ? 'Nudging...' : 'Nudge all',
                style: AppTextStyles.labelLg,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
