import 'package:flutter/cupertino.dart';
import "package:flutter/material.dart";
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/profile_fields.dart';
import 'package:onetouch/data/profile/current_user_repository_provider.dart'
    as current_user_provider;
import 'package:onetouch/data/profile/profile_avatar_repository.dart';
import 'package:onetouch/data/profile/profile_avatar_repository_provider.dart'
    as avatar_provider;
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/user_name_labels.dart';

typedef AvatarImagePicker = Future<XFile?> Function();

enum _AvatarAction { choosePhoto, removePhoto }

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.profile,
    this.avatarRepository,
    this.pickAvatar,
    this.avatarRequestHeaders,
  });

  final CurrentUserProfile? profile;
  final ProfileAvatarRepository? avatarRepository;
  final AvatarImagePicker? pickAvatar;
  final Map<String, String>? avatarRequestHeaders;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController nameController;
  late final TextEditingController usernameController;
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  bool isPasswordVisible = false;
  bool _isAvatarSaving = false;

  ProfileAvatarRepository get _avatarRepository =>
      widget.avatarRepository ?? avatar_provider.profileAvatarRepository;

  Map<String, String> get _avatarRequestHeaders =>
      widget.avatarRequestHeaders ??
      (widget.avatarRepository == null
          ? current_user_provider.currentUserMediaRequestHeaders
          : const {});

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    nameController = TextEditingController();
    usernameController = TextEditingController(
      text: profile?.username ?? '',
    );
    emailController = TextEditingController(
      text: profile?.email ?? '',
    );
    passwordController = TextEditingController(text: '••••••••');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = widget.profile;
    nameController.text = profile == null
        ? ''
        : userNameLabel(
            locale: Localizations.localeOf(context),
            firstName: profile.firstName,
            lastName: profile.lastName,
          );
  }

  Future<XFile?> _pickAvatar() =>
      widget.pickAvatar?.call() ??
      ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
        requestFullMetadata: false,
      );

  Future<void> _showAvatarActions() async {
    if (_isAvatarSaving) return;
    final action = await _showPlatformAvatarActions();
    if (!mounted || action == null) return;

    switch (action) {
      case _AvatarAction.choosePhoto:
        await _chooseAndUploadAvatar();
        break;
      case _AvatarAction.removePhoto:
        await _removeAvatar();
        break;
    }
  }

  Future<_AvatarAction?> _showPlatformAvatarActions() {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return showCupertinoModalPopup<_AvatarAction>(
        context: context,
        useRootNavigator: true,
        builder: (context) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              key: const ValueKey('profile-avatar-choose-photo'),
              onPressed: () => Navigator.of(context).pop(
                _AvatarAction.choosePhoto,
              ),
              child: Text(tr(context, 'Choose from Photos')),
            ),
            if (widget.profile?.avatarUri != null)
              CupertinoActionSheetAction(
                key: const ValueKey('profile-avatar-remove-photo'),
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop(
                  _AvatarAction.removePhoto,
                ),
                child: Text(tr(context, 'Remove Photo')),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            key: const ValueKey('profile-avatar-cancel'),
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr(context, 'Cancel')),
          ),
        ),
      );
    }

    return showModalBottomSheet<_AvatarAction>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('profile-avatar-choose-photo'),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr(context, 'Choose from Gallery')),
              onTap: () => Navigator.of(context).pop(
                _AvatarAction.choosePhoto,
              ),
            ),
            if (widget.profile?.avatarUri != null)
              ListTile(
                key: const ValueKey('profile-avatar-remove-photo'),
                leading: const Icon(Icons.delete_outline),
                title: Text(tr(context, 'Remove Photo')),
                onTap: () => Navigator.of(context).pop(
                  _AvatarAction.removePhoto,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseAndUploadAvatar() async {
    final file = await _pickAvatar();
    if (!mounted || file == null) return;

    setState(() => _isAvatarSaving = true);
    try {
      final filename = file.name.trim().isEmpty ? 'profile-avatar' : file.name;
      final avatarUri = await _avatarRepository.upload(
        bytes: await file.readAsBytes(),
        filename: filename,
      );
      await _evictAvatar(avatarUri);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object {
      if (!mounted) return;
      setState(() => _isAvatarSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              tr(context, 'Unable to update profile photo. Please try again.')),
        ),
      );
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _isAvatarSaving = true);
    try {
      await _avatarRepository.delete();
      final avatarUri = widget.profile?.avatarUri;
      if (avatarUri != null) await _evictAvatar(avatarUri);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object {
      if (!mounted) return;
      setState(() => _isAvatarSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              tr(context, 'Unable to remove profile photo. Please try again.')),
        ),
      );
    }
  }

  Future<void> _evictAvatar(Uri uri) => NetworkImage(
        uri.toString(),
        headers: _avatarRequestHeaders,
      ).evict();

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: appColors.pageBackground,
      appBar: AppBar(
        backgroundColor: appColors.pageBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: colors.onSurface),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Profile Image Section
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: appColors.subtleBackground,
                      child: ClipOval(
                        child: widget.profile?.avatarUri == null
                            ? Image.asset(
                                'assets/profileAvatar.png',
                                width: 108,
                                height: 108,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                widget.profile!.avatarUri.toString(),
                                headers: _avatarRequestHeaders,
                                width: 108,
                                height: 108,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/profileAvatar.png',
                                  width: 108,
                                  height: 108,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: GestureDetector(
                        key: const ValueKey('profile-avatar-action'),
                        onTap: _isAvatarSaving ? null : _showAvatarActions,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppPalette.lightGrey
                                : AppPalette.lightGreyBox,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: appColors.pageBackground,
                              width: 2,
                            ),
                          ),
                          child: _isAvatarSaving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.onSurface,
                                  ),
                                )
                              : Icon(
                                  Icons.camera_alt,
                                  color: colors.onSurface,
                                  size: 18,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              Text(
                tr(context, "LOGIN"),
                style: Body2_b.style,
              ),

              const SizedBox(height: 16),

              _buildTextField(
                  label: tr(context, 'Name'),
                  controller: nameController,
                  fieldKey: const ValueKey('profile-real-name-field'),
                  readOnly: true),
              const SizedBox(height: 24),
              ProfileFields(
                showNameFields: false,
                username: widget.profile?.username,
                firstName: widget.profile?.firstName,
                lastName: widget.profile?.lastName,
                onSaved: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                label: tr(context, "Email"),
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                readOnly: true,
              ),
              const SizedBox(height: 24),
              _buildTextField(
                label: tr(context, "Password"),
                controller: passwordController,
                isPassword: true,
                isObscure: !isPasswordVisible,
                onSuffixTap: () {
                  setState(() {
                    isPasswordVisible = !isPasswordVisible;
                  });
                },
              ),

              const SizedBox(height: 48),

              // Social Accounts Section
              Text(tr(context, "SOCIAL ACCOUNTS"), style: Body2_b.style),
              const SizedBox(height: 16),

              // Updated to use SVGs
              _buildSocialRow(
                  iconPath: 'assets/google.svg',
                  name: 'Google',
                  status: tr(context, 'Connected')),
              _divider(),
              _buildSocialRow(
                  iconPath: 'assets/apple.svg',
                  name: 'Apple',
                  status: tr(context, 'Not Connected')),
              _divider(),

              const SizedBox(height: 48),

              const SizedBox(height: 24),

              // Delete Account
              Center(
                child: GestureDetector(
                  onTap: () {
                    // Handle delete logic
                  },
                  child: Text(
                    tr(context, "DELETE ACCOUNT"),
                    style: Body2_b.style.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: colors.onSurface,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    Key? fieldKey,
    bool isPassword = false,
    bool isObscure = false,
    bool readOnly = false,
    VoidCallback? onSuffixTap,
    TextInputType? keyboardType,
  }) {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    return TextField(
      key: fieldKey,
      controller: controller,
      obscureText: isPassword && isObscure,
      readOnly: readOnly,
      enableInteractiveSelection: !readOnly,
      showCursor: !readOnly,
      keyboardType: keyboardType,
      style: Body1.style.copyWith(color: colors.onSurface),
      cursorColor: colors.onSurface,
      decoration: InputDecoration(
        filled: false,
        labelText: label,
        labelStyle: Body1.style,
        floatingLabelStyle:
            Body1.style.copyWith(color: appColors.mutedForeground),
        suffixIcon: readOnly
            ? Icon(
                Icons.lock_outline,
                color: appColors.mutedForeground,
                size: 20,
              )
            : isPassword
                ? IconButton(
                    icon: Icon(
                      isObscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: colors.onSurface,
                      size: 20,
                    ),
                    onPressed: onSuffixTap,
                  )
                : IconButton(
                    icon: Icon(Icons.cancel, color: colors.onSurface, size: 20),
                    onPressed: () => controller.clear(),
                  ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: appColors.divider),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colors.onSurface),
        ),
        contentPadding: const EdgeInsets.only(bottom: 8),
      ),
    );
  }

  Widget _buildSocialRow(
      {required String iconPath,
      required String name,
      required String status}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            // Changed to SvgPicture.asset
            child: SvgPicture.asset(
              iconPath,
              width: 24,
              height: 24,
              // Add color filter if icons are monochromatic and need to match theme
              // colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Body1.style),
                const SizedBox(height: 4),
                Text(tr(context, status), style: Eyebrow.style),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: Theme.of(context).colorScheme.onSurface,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      color: AppColors.of(context).divider,
      height: 1,
      thickness: 1,
    );
  }
}
