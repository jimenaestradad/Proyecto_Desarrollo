import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/widgets/nori_choice_chip.dart';
import 'package:nori/widgets/nori_segmented_control.dart';
import '../../widgets/scroll_edge_fade.dart';
import 'package:nori/screens/social/add_friend_screen.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.initialCircleId});
  final String? initialCircleId;
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with
        RemoteLoadState<LeaderboardScreen>,
        SocialLoadState<LeaderboardScreen> {
  List<LeaderboardEntry> _entries = [];
  List<SocialCircle> _circles = [];
  late String? _circleId = widget.initialCircleId;
  LeaderboardPeriod _period = LeaderboardPeriod.week;
  final _meKey = GlobalKey();
  final _viewportKey = GlobalKey();
  bool _pinMe = false;
  bool _filtering = false;
  int _loadVersion = 0;

  @override
  Future<void> loadSocial() async {
    final version = ++_loadVersion;
    final circles = await AppData.social.getCircles();
    final circleId = circles.any((c) => c.id == _circleId) ? _circleId : null;
    final entries = await AppData.social.getLeaderboard(
      circleId: circleId,
      period: _period,
    );
    if (!mounted || version != _loadVersion) return;
    setState(() {
      _circles = circles;
      _circleId = circleId;
      _entries = entries;
    });
    _checkVisibility();
  }

  void _checkVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final me = _meKey.currentContext?.findRenderObject() as RenderBox?;
      final viewport =
          _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (me == null || viewport == null || !me.hasSize || !viewport.hasSize) {
        return;
      }
      final top = me.localToGlobal(Offset.zero).dy;
      final viewportTop = viewport.localToGlobal(Offset.zero).dy;
      final visible =
          top + me.size.height > viewportTop &&
          top < viewportTop + viewport.size.height;
      if (_pinMe == visible) setState(() => _pinMe = !visible);
    });
  }

  Future<void> _filter({String? circleId, LeaderboardPeriod? period}) async {
    setState(() {
      if (period != null) {
        _period = period;
      } else {
        _circleId = circleId;
      }
      _filtering = true;
    });
    await reload();
    if (mounted) setState(() => _filtering = false);
  }

  void _profile(SocialUser user) {
    if (user.isMe) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FriendProfileScreen(userId: user.id)),
    );
  }

  Widget _row(LeaderboardEntry entry, {bool pinned = false}) => PersonRow(
    key: !pinned && entry.user.isMe ? _meKey : null,
    user: entry.user,
    avatarSize: 32,
    highlighted: entry.user.isMe,
    subtitle: '#${entry.rank}${entry.user.isMe ? ' · You' : ''}',
    onTap: entry.user.isMe ? null : () => _profile(entry.user),
    trailing: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${entry.xp} XP', style: AppTextStyles.labelLg),
        if (entry.rankChange != 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                entry.rankChange > 0
                    ? Icons.arrow_drop_up
                    : Icons.arrow_drop_down,
                color: entry.rankChange > 0
                    ? AppColors.mossDark
                    : AppColors.error,
              ),
              Text('${entry.rankChange.abs()}', style: AppTextStyles.labelSm),
            ],
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mine = _entries.where((e) => e.user.isMe).firstOrNull;
    return Scaffold(
      bottomNavigationBar:
          hasLoaded && _entries.length >= 2 && _pinMe && mine != null
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: _row(mine, pinned: true),
              ),
            )
          : null,
      body: SafeArea(
        child: SizedBox.expand(
          key: _viewportKey,
          child: buildLoaded(
            (context) => NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _checkVisibility();
                return false;
              },
              child: NoriScrollScaffold(
                maxWidth: 800,
                children: [
                  NoriScreenHeader(
                    leading: NoriScreenHeader.backButton(context),
                    title: 'Leaderboard',
                    titleStyle: AppTextStyles.headlineLgMobile,
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  ScrollEdgeFade(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          NoriChoiceChip(
                            label: 'All friends',
                            selected: _circleId == null,
                            onTap: () => _filter(),
                          ),
                          for (final circle in _circles) ...[
                            const SizedBox(width: AppSpacing.unit),
                            NoriChoiceChip(
                              label: circle.name,
                              icon: circle.icon,
                              selected: _circleId == circle.id,
                              onTap: () => _filter(circleId: circle.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackSm),
                  NoriSegmentedControl(
                    labels: const ['This week', 'This month', 'All time'],
                    selectedIndex: _period.index,
                    onChanged: (i) =>
                        _filter(period: LeaderboardPeriod.values[i]),
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  if (_filtering) const LinearProgressIndicator(),
                  if (_entries.length < 2)
                    NoriEmptyState(
                      icon: Icons.people_outline,
                      title: 'No one to compete with yet',
                      message: 'Add a friend to cheer each other on.',
                      actionLabel: 'Add friends',
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddFriendScreen(),
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final index in [1, 0, 2])
                          Expanded(
                            child: index < _entries.length
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.unit / 2,
                                    ),
                                    child: _PodiumEntry(
                                      key: _entries[index].user.isMe
                                          ? _meKey
                                          : null,
                                      entry: _entries[index],
                                      onTap: () =>
                                          _profile(_entries[index].user),
                                    ),
                                  )
                                : const SizedBox(),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    for (final entry in _entries.skip(3)) ...[
                      _row(entry),
                      const SizedBox(height: AppSpacing.stackSm),
                    ],
                    Text(
                      'Ranked by XP earned in the period (mock rule)',
                      style: AppTextStyles.labelSm,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PodiumEntry extends StatelessWidget {
  const _PodiumEntry({super.key, required this.entry, required this.onTap});
  final LeaderboardEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: !entry.user.isMe,
    label: 'Rank ${entry.rank}',
    child: GestureDetector(
      onTap: entry.user.isMe ? null : onTap,
      child: Column(
        children: [
          if (entry.rank == 1)
            const Icon(
              Icons.workspace_premium,
              color: AppColors.mustardDark,
              size: 32,
            ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              SocialAvatar(user: entry.user, size: 56),
              Positioned(
                right: -AppSpacing.unit / 2,
                bottom: -AppSpacing.unit / 2,
                child: NoriCard(
                  radius: AppRadius.full,
                  color: entry.user.isMe
                      ? AppColors.mossLight
                      : AppColors.white,
                  padding: const EdgeInsets.all(AppSpacing.unit / 2),
                  borderWidth: AppBorder.thin,
                  child: Text('#${entry.rank}', style: AppTextStyles.labelSm),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            entry.user.isMe ? 'You' : entry.user.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelLg,
          ),
          Text('${entry.xp} XP', style: AppTextStyles.labelSm),
          const SizedBox(height: AppSpacing.unit),
          NoriCard(
            color: switch (entry.rank) {
              1 => AppColors.mustard,
              2 => AppColors.mossLight,
              _ => AppColors.blushPink,
            },
            borderWidth: entry.user.isMe ? AppBorder.thick : AppBorder.standard,
            padding: EdgeInsets.symmetric(
              vertical: entry.rank == 1
                  ? AppSpacing.stackLg
                  : entry.rank == 2
                  ? AppSpacing.stackMd
                  : AppSpacing.gutter,
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: AppTextStyles.headlineLgMobile,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
