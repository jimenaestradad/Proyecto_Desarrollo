import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/auth_repository.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/app_log.dart';

/// Non-blocking banner for unverified password accounts in NoriShell.
/// Hidden for Google/mock accounts; dismissal lasts only for this app session.
class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  State<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner>
    with WidgetsBindingObserver {
  bool _needsVerification = false;
  bool _dismissed = false;
  bool _sending = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  /// People verify in their mail app and come back, so the banner re-checks
  /// when the app returns to the foreground. Only while it's showing: a
  /// verified account never needs another check.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _needsVerification) _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final needsVerification = await AppData.auth.needsEmailVerification();
    if (!mounted) return;
    setState(() => _needsVerification = needsVerification);
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds -= 1;
        if (_cooldownSeconds <= 0) timer.cancel();
      });
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resend() async {
    if (_sending || _cooldownSeconds > 0) return;
    setState(() => _sending = true);
    try {
      await AppData.auth.sendEmailVerification();
      if (!mounted) return;
      _showMessage('Verification email sent.');
      _startCooldown();
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (error, stackTrace) {
      logError('sendEmailVerification', error, stackTrace);
      if (!mounted) return;
      _showMessage('Unable to send the verification email.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !_needsVerification) return const SizedBox.shrink();

    return Material(
      color: AppColors.mustardLight,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.unit,
          ),
          child: Row(
            children: [
              const Icon(Icons.mark_email_unread, color: AppColors.mustardDark),
              const SizedBox(width: AppSpacing.unit),
              Expanded(
                child: Text(
                  'Please verify your email address.',
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.ink),
                ),
              ),
              TextButton(
                onPressed: (_sending || _cooldownSeconds > 0) ? null : _resend,
                child: Text(
                  _cooldownSeconds > 0
                      ? 'Resend (${_cooldownSeconds}s)'
                      : 'Resend',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.inkMuted,
                onPressed: () => setState(() => _dismissed = true),
                tooltip: 'Dismiss',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
