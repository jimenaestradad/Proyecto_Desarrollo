import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/nori_bottom_sheet.dart';

enum _FriendAction { remove, block, report }

Future<void> showFriendActionsSheet(
  BuildContext context, {
  required SocialUser user,
}) async {
  if (user.isMe) return;
  final route = ModalRoute.of(context);
  final action = await showNoriSheet<_FriendAction>(
    context,
    title: user.shortName,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NoriSheetAction(
          icon: Icons.person_remove_outlined,
          label: 'Remove friend',
          destructive: true,
          onTap: () => Navigator.pop(sheetContext, _FriendAction.remove),
        ),
        NoriSheetAction(
          icon: Icons.block,
          label: 'Block ${user.firstName}',
          destructive: true,
          onTap: () => Navigator.pop(sheetContext, _FriendAction.block),
        ),
        NoriSheetAction(
          icon: Icons.flag_outlined,
          label: 'Report',
          onTap: () => Navigator.pop(sheetContext, _FriendAction.report),
        ),
      ],
    ),
  );
  if (!context.mounted || action == null) return;
  if (action == _FriendAction.report) {
    final reason = await showNoriSheet<ReportReason>(
      context,
      title: 'Report ${user.firstName}',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final reason in ReportReason.values)
            NoriSheetAction(
              icon: Icons.flag_outlined,
              label: reason.label,
              onTap: () => Navigator.pop(sheetContext, reason),
            ),
        ],
      ),
    );
    // Mock-only: user reports have no repository endpoint yet.
    if (reason != null && context.mounted) {
      showSocialToast(context, "Thanks — we'll take a look");
    }
    return;
  }
  final success = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConfirmFriendAction(user: user, action: action),
  );
  if (success != true || !context.mounted) return;
  showSocialToast(
    context,
    action == _FriendAction.remove
        ? '${user.firstName} removed from friends'
        : '${user.firstName} blocked',
  );
  if (route?.isCurrent == true && Navigator.canPop(context)) {
    Navigator.pop(context);
  }
}

class _ConfirmFriendAction extends StatefulWidget {
  const _ConfirmFriendAction({required this.user, required this.action});
  final SocialUser user;
  final _FriendAction action;
  @override
  State<_ConfirmFriendAction> createState() => _ConfirmFriendActionState();
}

class _ConfirmFriendActionState extends State<_ConfirmFriendAction>
    with RemoteLoadState<_ConfirmFriendAction> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final success = await guardedAction(() async {
      if (widget.action == _FriendAction.remove) {
        await AppData.social.removeFriend(widget.user.id);
      } else {
        await AppData.social.blockUser(widget.user.id);
      }
    });
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remove = widget.action == _FriendAction.remove;
    final verb = remove ? 'Remove' : 'Block';
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
        ),
        title: Text(
          '$verb ${widget.user.firstName}?',
          style: AppTextStyles.headlineLgMobile,
        ),
        content: Text(
          remove
              ? 'You can send another friend request later.'
              : 'They will be removed from your friends and hidden from your social activity.',
          style: AppTextStyles.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTextStyles.labelLg),
          ),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            child: Text(
              _busy ? 'Saving...' : verb,
              style: AppTextStyles.labelLg,
            ),
          ),
        ],
      ),
    );
  }
}
