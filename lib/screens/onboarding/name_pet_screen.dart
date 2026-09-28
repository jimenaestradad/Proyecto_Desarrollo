import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Last onboarding step, shown once right after sign-up (email/password or
/// a brand-new Google account) finishes claiming a username — see
/// login_screen.dart's/sign_up_screen.dart's callers. Lets the person
/// rename their starter pet away from the onUserCreate-provisioned default
/// of 'Nori'; skipping just leaves it as 'Nori'
/// (docs/BACKEND.md: "Onboarding writes the chosen pet name to pet/main
/// ... skipping onboarding leaves it as 'Nori'").
///
/// Always pops back to its caller (never navigates on its own) so the
/// caller can decide what comes after — currently always straight to
/// '/home' — regardless of whether the person typed a name or skipped.
class NamePetScreen extends StatefulWidget {
  const NamePetScreen({super.key});

  @override
  State<NamePetScreen> createState() => _NamePetScreenState();
}

class _NamePetScreenState extends State<NamePetScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      // Nothing typed — same outcome as tapping Skip, no need to make the
      // person hit a second button for it.
      _skip();
      return;
    }
    setState(() => _saving = true);
    try {
      await AppData.pet.renamePet(name);
    } catch (_) {
      // Best-effort: onboarding isn't worth blocking on this failing (no
      // network right at this instant, etc.) — the pet just keeps
      // whatever name it already has, same as skipping.
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _skip() {
    if (_saving) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.containerPaddingMobile,
                vertical: AppSpacing.stackMd,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - (AppSpacing.stackMd * 2))
                      .clamp(0.0, double.infinity),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.stackMd),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: AppColors.ink,
                          width: AppBorder.standard,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.ink,
                                width: AppBorder.thick,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/nori_closeup.png',
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackSm),
                          Text(
                            'Meet your Nori!',
                            style: AppTextStyles.headlineLgMobile,
                          ),
                          const SizedBox(height: AppSpacing.unit),
                          Text(
                            'Give your new companion a name, or keep '
                            '"Nori" — you can always change your mind '
                            'later.',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.inkMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                          NoriTextField(
                            controller: _nameController,
                            label: "Pet's Name",
                            hint: 'Nori',
                            icon: Icons.pets,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _continue(),
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                          TactileButton(
                            label: _saving ? 'Saving...' : "Let's go!",
                            icon: Icons.arrow_forward,
                            onPressed: _saving ? null : _continue,
                          ),
                          const SizedBox(height: AppSpacing.unit),
                          TextButton(
                            onPressed: _saving ? null : _skip,
                            child: const Text('Skip for now'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
