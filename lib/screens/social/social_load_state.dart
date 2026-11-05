import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/load_error_view.dart';

/// Load-and-stay-fresh plumbing every Social screen shares.
///
/// A screen mixes this in *after* [RemoteLoadState], implements [loadSocial]
/// (read from `AppData.social`, then `setState` its fields), and renders its
/// body through [buildLoaded]. The mixin runs [loadSocial] on first build and
/// again whenever `AppData.social.changes` fires, so a screen that stays
/// mounted underneath a pushed route (the hub, a list) refreshes when you
/// come back from a change made elsewhere.
///
/// ```dart
/// class _FooState extends State<Foo>
///     with RemoteLoadState<Foo>, SocialLoadState<Foo> {
///   List<SocialUser>? _friends;
///
///   @override
///   Future<void> loadSocial() async {
///     final friends = await AppData.social.getFriends();
///     if (!mounted) return;
///     setState(() => _friends = friends);
///   }
///
///   @override
///   Widget build(BuildContext context) => Scaffold(
///     body: SafeArea(child: buildLoaded((context) => ...)),
///   );
/// }
/// ```
mixin SocialLoadState<T extends StatefulWidget>
    on State<T>, RemoteLoadState<T> {
  bool _hasLoaded = false;

  /// True once the first [loadSocial] has succeeded.
  bool get hasLoaded => _hasLoaded;

  /// Read from `AppData.social` and `setState` the results. Throwing is fine —
  /// it's wrapped in [guardedLoad].
  Future<void> loadSocial();

  @override
  void initState() {
    super.initState();
    AppData.social.changes.addListener(_onSocialChanged);
    reload();
  }

  @override
  void dispose() {
    AppData.social.changes.removeListener(_onSocialChanged);
    super.dispose();
  }

  void _onSocialChanged() {
    // Signing out fires this too (AppData.unbindUser) while the tab is still
    // mounted; with nobody signed in the reload would hit Firestore and
    // surface "Couldn't reach the server" on the welcome screen.
    if (mounted && AppData.auth.currentUserId != null) reload();
  }

  Future<void> reload() => guardedLoad(hasData: _hasLoaded, () async {
    await loadSocial();
    _hasLoaded = true;
  });

  /// Spinner until the first load, [LoadErrorView] if it failed, else
  /// [builder]'s content.
  Widget buildLoaded(WidgetBuilder builder) {
    if (_hasLoaded) return builder(context);
    final error = loadError;
    if (error != null) return LoadErrorView(error: error, onRetry: reload);
    return const Center(child: CircularProgressIndicator());
  }
}

/// Plain confirmation toast ("Nudge sent", "Request sent", …).
void showSocialToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
