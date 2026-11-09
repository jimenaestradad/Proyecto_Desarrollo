import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/section_header.dart';
import 'package:nori/widgets/tactile_button.dart';

class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({super.key});
  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen>
    with
        RemoteLoadState<InviteFriendsScreen>,
        SocialLoadState<InviteFriendsScreen> {
  ({String username, String code, String link})? _info;

  @override
  Future<void> loadSocial() async {
    final info = await AppData.social.getInviteInfo();
    if (mounted) setState(() => _info = info);
  }

  Future<void> _copy(String value, String label) async {
    final success = await guardedAction(
      () => Clipboard.setData(ClipboardData(text: value)),
    );
    if (success && mounted) showSocialToast(context, '$label copied');
  }

  Widget _copyRow(String label, String value) => NoriCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTextStyles.labelSm),
        const SizedBox(height: AppSpacing.unit),
        SelectableText(value, style: AppTextStyles.bodyMd),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _copy(value, label),
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded((context) {
        final info = _info!;
        return NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Invite friends',
              titleStyle: AppTextStyles.headlineLgMobile,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            NoriCard(
              color: AppColors.mossLight,
              child: Column(
                children: [
                  const NoriIconBadge(
                    icon: Icons.person_add,
                    background: AppColors.white,
                    size: 64,
                    iconSize: 32,
                    circle: true,
                  ),
                  const SizedBox(height: AppSpacing.stackSm),
                  SelectableText(
                    '@${info.username}',
                    style: AppTextStyles.headlineLgMobile,
                  ),
                  const SizedBox(height: AppSpacing.unit),
                  Text('Better habits, together.', style: AppTextStyles.bodyMd),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            _copyRow('Invite code', info.code),
            const SizedBox(height: AppSpacing.stackSm),
            _copyRow('Invite link', info.link),
            const SizedBox(height: AppSpacing.stackMd),
            TactileButton(
              label: 'Share',
              icon: Icons.share,
              onPressed: () =>
                  showSocialToast(context, "Sharing isn't wired up yet"),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Center(
              child: SizedBox(
                width: AppSpacing.stackLg * 4,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: NoriCard(
                    color: AppColors.linenAlt,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_2,
                          size: AppSpacing.stackLg * 2,
                          color: AppColors.ink,
                        ),
                        const SizedBox(height: AppSpacing.unit),
                        Text('QR preview', style: AppTextStyles.labelSm),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.stackLg),
            const SectionHeader(
              title: 'How it works',
              trailing: SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            for (final step in const [
              '1. Copy your code or invite link.',
              '2. Send it to a friend you know.',
              '3. Accept their request and grow together.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
                child: Text(step, style: AppTextStyles.bodyMd),
              ),
            NoriCard(
              color: AppColors.sky,
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.ink),
                  const SizedBox(width: AppSpacing.unit),
                  Expanded(
                    child: Text(
                      'Friends only. Sharing a link lets someone send a request; you choose who to accept.',
                      style: AppTextStyles.bodyMd,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    ),
  );
}
