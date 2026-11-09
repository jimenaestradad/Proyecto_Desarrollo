import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/tips_store.dart';
import 'package:nori/screens/onboarding/intro_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/app_log.dart';
import 'package:nori/utils/validators.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Names the starter pet after username setup; skipping keeps 'Nori'.
/// Shows [IntroScreen] if unseen, then pops so the caller can navigate onward.
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
    final problem = validatePetName(name);
    if (problem != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _saving = true);
    try {
      await AppData.pet.renamePet(name);
    } catch (error, stackTrace) {
      logError('renamePet', error, stackTrace);
      // Best-effort: onboarding isn't worth blocking on this failing (no
      // network right at this instant, etc.) — the pet just keeps
      // whatever name it already has, same as skipping.
    }
    await _finish();
  }

  void _skip() {
    if (_saving) return;
    _finish();
  }

  /// Shows the intro cards once per account, then hands back to the caller.
  /// Done here rather than in each caller (login, sign-up, finish-sign-up)
  /// so all three get it, and the caller's "straight to Home" stays as is.
  Future<void> _finish() async {
    final store = TipsStore.current();
    final seen = await store.hasSeenIntro();
    if (!mounted) return;
    if (!seen) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => IntroScreen(store: store)),
      );
      if (!mounted) return;
    }
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
                    child: NoriCard(
                      padding: const EdgeInsets.all(AppSpacing.stackMd),
                      radius: AppRadius.lg,
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
                            label: "Pet's name",
                            hint: 'Nori',
                            icon: Icons.pets,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(
                                petNameMaxLength,
                              ),
                            ],
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
