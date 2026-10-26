import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/relative_time.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/section_header.dart';
import 'package:nori/widgets/tactile_button.dart';

class VisitPetScreen extends StatefulWidget {
  const VisitPetScreen({super.key, required this.userId});
  final String userId;
  @override
  State<VisitPetScreen> createState() => _VisitPetScreenState();
}

class _VisitPetScreenState extends State<VisitPetScreen>
    with RemoteLoadState<VisitPetScreen>, SocialLoadState<VisitPetScreen> {
  SocialUser? _owner;
  Map<String, SocialUser> _directory = {};
  List<CheerEntry> _log = [];
  bool _busy = false;

  @override
  Future<void> loadSocial() async {
    final owner = await AppData.social.getUser(widget.userId);
    final directory = await AppData.social.getUserDirectory();
    final log = await AppData.social.getCheerLog(widget.userId);
    if (!mounted) return;
    setState(() {
      _owner = owner;
      _directory = directory;
      _log = log;
    });
  }

  IconData _icon(CheerKind kind) => switch (kind) {
    CheerKind.hug => Icons.favorite_outline,
    CheerKind.treat => Icons.cookie_outlined,
    CheerKind.wave => Icons.waving_hand_outlined,
  };

  String _label(CheerKind kind) => switch (kind) {
    CheerKind.hug => 'Hug',
    CheerKind.treat => 'Treat',
    CheerKind.wave => 'Wave',
  };

  Future<void> _cheer(CheerKind kind) async {
    if (_busy) return;
    setState(() => _busy = true);
    final success = await guardedAction(
      () => AppData.social.cheerPet(widget.userId, kind),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (success) {
      showSocialToast(context, '${_label(kind)} sent to ${_owner!.petName}');
    }
  }

  Widget _pill(String label, IconData icon) => NoriCard(
    color: AppColors.white,
    radius: AppRadius.full,
    borderWidth: AppBorder.thin,
    padding: const EdgeInsets.all(AppSpacing.unit),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.ink),
        const SizedBox(width: AppSpacing.unit),
        Text(label, style: AppTextStyles.labelSm),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded((context) {
        final owner = _owner!;
        return NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: "${owner.petName}'s room",
              titleStyle: AppTextStyles.headlineLgMobile,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            NoriCard(
              radius: AppRadius.lg,
              color: AppColors.mossLight,
              borderWidth: AppBorder.thick,
              child: Column(
                children: [
                  Wrap(
                    spacing: AppSpacing.unit,
                    runSpacing: AppSpacing.unit,
                    children: [
                      // Mock-only: other pets currently share a joyful mood.
                      _pill('Joyful', Icons.sentiment_very_satisfied),
                      _pill('Stage ${owner.petStage}', Icons.eco_outlined),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.stackLg),
                  const NoriIconBadge(
                    icon: Icons.pets,
                    background: AppColors.linenAlt,
                    size: AppSpacing.stackLg * 4,
                    iconSize: AppSpacing.stackLg * 2,
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  Text(owner.petName, style: AppTextStyles.headlineLg),
                  Text("${owner.firstName}'s pet", style: AppTextStyles.bodyMd),
                  const SizedBox(height: AppSpacing.stackMd),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Row(
              children: [
                for (final kind in CheerKind.values) ...[
                  if (kind != CheerKind.values.first)
                    const SizedBox(width: AppSpacing.unit),
                  Expanded(
                    child: TactileButton(
                      label: _label(kind),
                      icon: _icon(kind),
                      onPressed: _busy ? null : () => _cheer(kind),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.stackLg),
            const SectionHeader(
              title: 'Recent visitors',
              trailing: SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            if (_log.isEmpty)
              const NoriEmptyState(
                icon: Icons.waving_hand_outlined,
                title: 'Be the first to say hello',
                message: 'Send a hug, treat, or wave to leave a little cheer.',
              )
            else
              for (final entry in _log) ...[
                _visitor(entry),
                const SizedBox(height: AppSpacing.stackSm),
              ],
          ],
        );
      }),
    ),
  );

  Widget _visitor(CheerEntry entry) {
    final visitor = _directory[entry.fromId];
    final name = visitor?.isMe == true
        ? 'You'
        : visitor?.firstName ?? 'A friend';
    final action = switch (entry.kind) {
      CheerKind.hug => 'gave a warm hug',
      CheerKind.treat => 'tossed a treat',
      CheerKind.wave => 'waved hello',
    };
    return GestureDetector(
      onTap: visitor == null || visitor.isMe
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FriendProfileScreen(userId: visitor.id),
              ),
            ),
      child: NoriCard(
        padding: const EdgeInsets.all(AppSpacing.stackSm),
        borderWidth: AppBorder.thin,
        child: Row(
          children: [
            if (visitor != null)
              SocialAvatar(user: visitor)
            else
              NoriIconBadge(
                icon: _icon(entry.kind),
                background: AppColors.blush,
                size: 40,
                iconSize: 20,
                circle: true,
              ),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name $action', style: AppTextStyles.bodyMd),
                  Text(
                    relativeTimeLabel(entry.createdAt),
                    style: AppTextStyles.labelSm,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.unit),
            Icon(_icon(entry.kind), color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}
