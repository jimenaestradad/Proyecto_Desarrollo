import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/app_notification.dart';
import 'package:nori/screens/notifications/notifications_screen.dart';
import 'package:nori/widgets/circular_icon_button.dart';

/// The one notification bell. Every tab that shows it opens the same inbox
/// (pet and app events plus social activity), and its dot means "anything
/// unread in either".
class NotificationsBell extends StatefulWidget {
  const NotificationsBell({
    super.key,
    required this.onCarePet,
    this.initialFilter = NotificationFilter.all,
    this.largeTapTarget = false,
  });

  /// A "Take care" button in the inbox was tapped: go to Home.
  final VoidCallback onCarePet;

  /// Which filter the inbox opens on; Social's bell opens on Social.
  final NotificationFilter initialFilter;
  final bool largeTapTarget;

  @override
  State<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends State<NotificationsBell> {
  // Created once: a new stream per build would resubscribe every rebuild.
  late final Stream<bool> _appUnread = AppData.notifications.watchHasUnread();
  int _socialUnread = 0;

  @override
  void initState() {
    super.initState();
    _refreshSocialUnread();
  }

  Future<void> _refreshSocialUnread() async {
    try {
      final count = await AppData.social.getUnreadNotificationCount();
      if (mounted) setState(() => _socialUnread = count);
    } catch (_) {
      // Best effort: the dot corrects itself the next time this loads.
    }
  }

  Future<void> _open() async {
    final action = await Navigator.of(context).push<NotificationAction>(
      MaterialPageRoute(
        builder: (_) =>
            NotificationsScreen(initialFilter: widget.initialFilter),
      ),
    );
    if (!mounted) return;
    _refreshSocialUnread();
    if (action == NotificationAction.carePet) widget.onCarePet();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _appUnread,
      builder: (context, snapshot) {
        final hasUnread = (snapshot.data ?? false) || _socialUnread > 0;
        return CircularIconButton(
          icon: Icons.notifications,
          tooltip: hasUnread ? 'Notifications (unread)' : 'Notifications',
          onPressed: _open,
          showDot: hasUnread,
          largeTapTarget: widget.largeTapTarget,
        );
      },
    );
  }
}
