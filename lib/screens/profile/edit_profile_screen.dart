import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Pushed from [ProfileScreen]'s avatar edit pencil. Editing is scoped to the
/// three user-owned text fields [NoriUser] has ([NoriUser.name],
/// [NoriUser.username], [NoriUser.email]) — changing the avatar photo itself
/// needs an image picker that doesn't exist anywhere in the app yet, so that
/// button stays a "coming soon" stub (separate backlog item: mock profile
/// picture).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final NoriUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _nameController = TextEditingController(text: widget.user.name);
  late final _usernameController = TextEditingController(
    text: widget.user.username,
  );
  late final _emailController = TextEditingController(
    text: widget.user.email,
  );

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _editPhoto() => _showMessage('Coming soon');

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || username.isEmpty || email.isEmpty) {
      _showMessage('Please complete all fields.');
      return;
    }

    setState(() => _saving = true);
    await AppData.user.updateProfile(
      name: name,
      username: username,
      email: email,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: NoriScrollScaffold(
          maxWidth: 600,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Edit Profile',
              titleStyle: AppTextStyles.headlineLgMobile,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  NoriAvatar(
                    imageUrl: widget.user.avatarUrl,
                    size: 120,
                    borderWidth: AppBorder.thick,
                  ),
                  Positioned(
                    right: -4,
                    bottom: 2,
                    child: IconButton.filled(
                      onPressed: _editPhoto,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.moss,
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size.square(38),
                        side: const BorderSide(
                          color: AppColors.ink,
                          width: AppBorder.standard,
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            NoriCard(
              radius: AppRadius.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NoriTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Alex Human',
                    icon: Icons.person,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                  ),
                  NoriTextField(
                    controller: _usernameController,
                    label: 'Username',
                    hint: 'alex_habits',
                    icon: Icons.alternate_email,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                  ),
                  NoriTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'alex@example.com',
                    icon: Icons.mail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => _save(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            TactileButton(
              label: _saving ? 'Saving...' : 'Save Changes',
              icon: Icons.check,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
