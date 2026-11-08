import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/theme/app_theme.dart';

enum UsernameStatus { idle, checking, available, taken }

/// Debounced advisory username lookup with status, suffix icon and helper text.
/// Screens supply [usernameController] and wire [onUsernameChanged].
/// Failed lookups return to idle; the submit-time atomic claim is the real guard.
mixin UsernameAvailability<T extends StatefulWidget> on State<T> {
  Timer? _usernameDebounce;

  /// Written directly by a screen that learns the name is taken from the
  /// claim itself (inside its own `setState`).
  UsernameStatus usernameStatus = UsernameStatus.idle;

  TextEditingController get usernameController;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    super.dispose();
  }

  void onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final username = value.trim();
    if (username.length < 3) {
      setState(() => usernameStatus = UsernameStatus.idle);
      return;
    }

    setState(() => usernameStatus = UsernameStatus.checking);
    _usernameDebounce = Timer(const Duration(milliseconds: 250), () async {
      bool available;
      try {
        available = await AppData.usernames.isAvailable(username);
      } catch (_) {
        // Can't reach Firestore right now — don't block typing on it, the
        // atomic claim at submit time is the real backstop either way.
        if (!mounted || usernameController.text.trim() != username) return;
        setState(() => usernameStatus = UsernameStatus.idle);
        return;
      }
      // The field has moved on since this lookup started.
      if (!mounted || usernameController.text.trim() != username) return;
      setState(
        () => usernameStatus = available
            ? UsernameStatus.available
            : UsernameStatus.taken,
      );
    });
  }

  Widget? get usernameSuffixIcon {
    switch (usernameStatus) {
      case UsernameStatus.idle:
        return null;
      case UsernameStatus.checking:
        return const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case UsernameStatus.available:
        return const Icon(Icons.check_circle, color: AppColors.moss);
      case UsernameStatus.taken:
        return const Icon(Icons.cancel, color: AppColors.error);
    }
  }

  String? get usernameHelperText {
    switch (usernameStatus) {
      case UsernameStatus.idle:
      case UsernameStatus.checking:
        return null;
      case UsernameStatus.available:
        return 'Username is available';
      case UsernameStatus.taken:
        return 'Username is already taken';
    }
  }

  Color? get usernameHelperColor {
    switch (usernameStatus) {
      case UsernameStatus.taken:
        return AppColors.error;
      case UsernameStatus.available:
        return AppColors.mossDark;
      case UsernameStatus.idle:
      case UsernameStatus.checking:
        return null;
    }
  }
}
