import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/nori_bottom_sheet.dart';

Future<void> showPostActionsSheet(
  BuildContext context, {
  required SocialPost post,
  required SocialUser author,
}) async {
  final report = await showNoriSheet<bool>(
    context,
    title: 'Post options',
    builder: (_) => _PostActions(author: author),
  );
  if (!context.mounted || report != true) return;
  await showNoriSheet<void>(
    context,
    title: 'Report post',
    builder: (_) => _ReportActions(postId: post.id),
  );
}

class _PostActions extends StatefulWidget {
  const _PostActions({required this.author});
  final SocialUser author;
  @override
  State<_PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<_PostActions>
    with RemoteLoadState<_PostActions> {
  bool _busy = false;

  Future<void> _block() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
        ),
        title: Text(
          'Block ${widget.author.firstName}?',
          style: AppTextStyles.headlineLgMobile,
        ),
        content: Text(
          'Their posts will be hidden and they will be removed from your friends.',
          style: AppTextStyles.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: AppTextStyles.labelLg),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Block', style: AppTextStyles.labelLg),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    final success = await guardedAction(() async {
      await AppData.social.blockUser(widget.author.id);
    });
    if (!mounted) return;
    if (success) {
      showSocialToast(context, '${widget.author.firstName} blocked');
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    absorbing: _busy,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (widget.author.isMe)
          NoriSheetAction(
            icon: Icons.link,
            label: 'Copy link',
            onTap: () {
              // Mock-only: shareable post URLs are not available yet.
              showSocialToast(context, 'Link copied');
              Navigator.pop(context);
            },
          )
        else ...[
          NoriSheetAction(
            icon: Icons.flag_outlined,
            label: 'Report post',
            onTap: () => Navigator.pop(context, true),
          ),
          NoriSheetAction(
            icon: Icons.block,
            label: 'Block ${widget.author.firstName}',
            destructive: true,
            onTap: _block,
          ),
        ],
      ],
    ),
  );
}

class _ReportActions extends StatefulWidget {
  const _ReportActions({required this.postId});
  final String postId;
  @override
  State<_ReportActions> createState() => _ReportActionsState();
}

class _ReportActionsState extends State<_ReportActions>
    with RemoteLoadState<_ReportActions> {
  bool _busy = false;

  Future<void> _report(ReportReason reason) async {
    if (_busy) return;
    setState(() => _busy = true);
    final success = await guardedAction(() async {
      await AppData.social.reportPost(widget.postId, reason);
    });
    if (!mounted) return;
    if (success) {
      showSocialToast(context, "Thanks — we'll take a look");
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    absorbing: _busy,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_busy) const LinearProgressIndicator(),
        for (final reason in ReportReason.values)
          NoriSheetAction(
            icon: Icons.flag_outlined,
            label: reason.label,
            onTap: () => _report(reason),
          ),
      ],
    ),
  );
}
