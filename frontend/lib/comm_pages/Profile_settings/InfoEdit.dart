import 'package:onetouch/models/profile_change_limit_exception.dart';
// ignore_for_file: file_names

import 'package:flutter/cupertino.dart';
import "package:flutter/material.dart";
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:cross_file/cross_file.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/identity_name_rules.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/profile/current_user_repository_provider.dart'
    as current_user_provider;
import 'package:onetouch/data/profile/api/api_current_user_repository.dart';
import 'package:onetouch/data/profile/profile_avatar_repository.dart';
import 'package:onetouch/data/profile/profile_avatar_repository_provider.dart'
    as avatar_provider;
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/features/media/asset_media_picker.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/social_identity_service.dart';
import 'package:onetouch/data/profile/social_account_service.dart';
import 'package:onetouch/data/profile/social_account_service_provider.dart'
    as social_account_provider;
import 'package:onetouch/data/profile/account_deletion_service.dart';
import 'package:onetouch/data/profile/account_deletion_service_provider.dart'
    as account_deletion_provider;
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;

typedef AvatarImagePicker = Future<XFile?> Function();

enum _AvatarAction { choosePhoto, removePhoto }

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.profile,
    this.avatarRepository,
    this.pickAvatar,
    this.avatarRequestHeaders,
    this.socialAccountService,
    this.accountDeletionService,
    this.onAccountDeleted,
  });

  final CurrentUserProfile? profile;
  final ProfileAvatarRepository? avatarRepository;
  final AvatarImagePicker? pickAvatar;
  final Map<String, String>? avatarRequestHeaders;
  final SocialAccountService? socialAccountService;
  final AccountDeletionService? accountDeletionService;
  final Future<void> Function()? onAccountDeleted;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController usernameController;
  late final TextEditingController displayNameController;
  late final TextEditingController emailController;
  bool _isAvatarSaving = false;
  bool _isProfileSaving = false;
  bool _isDeletingAccount = false;
  String? _profileSaveError;
  LoginProvider? _connectingProvider;
  late Set<String> _socialAccounts;

  SocialAccountService get _socialAccountService =>
      widget.socialAccountService ??
      social_account_provider.socialAccountService;

  AccountDeletionService get _accountDeletionService =>
      widget.accountDeletionService ??
      account_deletion_provider.accountDeletionService;

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
    _socialAccounts = {...?profile?.socialAccounts};
    usernameController = TextEditingController(
      text: profile?.username ?? '',
    );
    displayNameController = TextEditingController(
      text: profile?.displayName ?? '',
    );
    emailController = TextEditingController(
      text: profile?.email ?? '',
    );
  }

  Future<XFile?> _pickAvatar() async {
    if (widget.pickAvatar != null) return widget.pickAvatar!();
    return pickAvatarImage(context);
  }

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
    try {
      final file = await _pickAvatar();
      if (!mounted || file == null) return;
      setState(() => _isAvatarSaving = true);
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

  Future<void> _saveProfile() async {
    if (_isProfileSaving) return;
    final username =
        widget.profile?.email == null ? null : usernameController.text;
    final displayName = displayNameController.text;
    final message = (username == null || username == widget.profile?.username
            ? null
            : usernameValidationMessage(username)) ??
        displayNameValidationMessage(displayName);
    if (message != null) {
      setState(() => _profileSaveError = tr(context, message));
      return;
    }

    setState(() {
      _isProfileSaving = true;
      _profileSaveError = null;
    });
    try {
      await current_user_provider.currentUserRepository.updateProfile(
        username: username,
        displayName: displayName,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ProfileChangeLimitException catch (error) {
      if (!mounted) return;
      setState(() {
        _isProfileSaving = false;
        _profileSaveError = profileChangeLimitMessage(context,
            item: tr(context, 'Nickname'), limit: error);
      });
    } on ProfileNameConflictException {
      if (!mounted) return;
      setState(() {
        _isProfileSaving = false;
        _profileSaveError =
            tr(context, 'Username or nickname is already in use');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isProfileSaving = false;
        _profileSaveError = tr(
          context,
          'Unable to save profile. Check your username and try again.',
        );
      });
    }
  }

  Future<void> _connectSocialAccount(LoginProvider provider) async {
    // 이미 연결됐거나 인증 창이 열린 동안에는 중복 요청을 보내지 않아요.
    if (_connectingProvider != null ||
        _socialAccounts.contains(provider.name)) {
      return;
    }
    setState(() => _connectingProvider = provider);
    try {
      final accounts = await _socialAccountService.connect(provider);
      if (!mounted) return;
      // 공급자 인증만으로는 연결 완료가 아니에요. 서버가 성공한 뒤에만 상태를 바꿔요.
      setState(() => _socialAccounts = accounts);
    } on SocialLoginCancelled {
      // 공급자 인증 창을 닫았으면 연결 상태를 그대로 둬요.
    } on GoogleIdentityException catch (error) {
      if (error.type != GoogleIdentityFailureType.cancelled && mounted) {
        _showSocialConnectionError(provider);
      }
    } on Object {
      if (mounted) _showSocialConnectionError(provider);
    } finally {
      if (mounted) setState(() => _connectingProvider = null);
    }
  }

  void _showSocialConnectionError(LoginProvider provider) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr(
        context,
        'Unable to connect {provider}. It may already be linked to another account.',
        {'provider': provider.displayName},
      )),
    ));
  }

  Future<void> _confirmDeleteAccount() async {
    if (_isDeletingAccount) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final foreground = isDark ? AppPalette.white : AppPalette.black;
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          backgroundColor:
              isDark ? AppPalette.lightGrey : AppPalette.lightModeDarkGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            key: const ValueKey('profile-delete-confirmation-card'),
            width: 345,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr(dialogContext, 'Leaving the pitch already?'),
                      style: TextStyle(
                        color: foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.10,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr(dialogContext,
                          'Deleting your account will permanently remove your data, predictions, and points.'),
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.30,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      key: const ValueKey('profile-confirm-delete-account'),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: TextButton.styleFrom(
                        backgroundColor: AppPalette.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        trUpper(dialogContext, 'Delete account'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFF5B5B),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: foreground,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        trUpper(dialogContext, 'Cancel'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: foreground,
                          height: 1.30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      await _accountDeletionService.deleteAccount(_socialAccounts);
    } on SocialLoginCancelled {
      if (mounted) setState(() => _isDeletingAccount = false);
      return;
    } on Object {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          tr(context, 'Unable to delete account. Please try again.'),
        ),
      ));
      return;
    }

    if (widget.onAccountDeleted != null) {
      await widget.onAccountDeleted!();
    } else {
      await auth_provider.authService.logout();
      if (mounted) context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    displayNameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: appColors.pageBackground,
      appBar: AppBar(
        backgroundColor: appColors.pageBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                  alignment: Alignment.center,
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
                    Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    GestureDetector(
                      key: const ValueKey('profile-avatar-action'),
                      onTap: _isAvatarSaving ? null : _showAvatarActions,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: _isAvatarSaving
                              ? CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onSurface,
                                )
                              : Icon(
                                  Icons.camera_alt_outlined,
                                  color: colors.onSurface,
                                  size: 26,
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

              if (widget.profile?.email != null) ...[
                _buildTextField(
                  label: tr(context, 'Username'),
                  controller: usernameController,
                  fieldKey: const ValueKey('profile-username-field'),
                  maxLength: 30,
                ),
                const SizedBox(height: 8),
              ],
              _buildTextField(
                label: tr(context, 'Nickname'),
                controller: displayNameController,
                fieldKey: const ValueKey('profile-display-name-field'),
                maxLength: 12,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s'))
                ],
              ),
              const SizedBox(height: 8),
              _buildTextField(
                label: tr(context, "Email"),
                controller: emailController,
                fieldKey: const ValueKey('profile-email-field'),
                keyboardType: TextInputType.emailAddress,
                readOnly: true,
              ),
              const SizedBox(height: 48),

              // 서버가 알려준 연결 상태를 표시하고, 미연결 계정만 탭할 수 있게 해요.
              Text(tr(context, "SOCIAL ACCOUNTS"), style: Body2_b.style),
              const SizedBox(height: 16),

              _buildSocialRow(
                  iconPath: 'assets/google.svg',
                  provider: LoginProvider.google),
              _divider(),
              // Apple 로그인은 현재 iOS에서만 제공해 Android에는 항목을 숨겨요.
              if (Theme.of(context).platform == TargetPlatform.iOS) ...[
                _buildSocialRow(
                    iconPath: 'assets/apple.svg',
                    provider: LoginProvider.apple),
                _divider(),
              ],

              const SizedBox(height: 48),

              if (_profileSaveError != null) ...[
                Text(
                  _profileSaveError!,
                  style: Eyebrow.style.copyWith(color: colors.error),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('profile-update-button'),
                  onPressed: _isProfileSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.onSurface,
                    foregroundColor: appColors.pageBackground,
                    disabledBackgroundColor: appColors.mutedForeground,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isProfileSaving
                        ? tr(context, 'Saving…')
                        : tr(context, 'UPDATE INFO'),
                    style: Body2_b.style.copyWith(
                      color: appColors.pageBackground,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: GestureDetector(
                  key: const ValueKey('profile-delete-account'),
                  onTap: _isDeletingAccount ? null : _confirmDeleteAccount,
                  child: Text(
                    _isDeletingAccount
                        ? tr(context, 'Deleting account…')
                        : tr(context, 'DELETE ACCOUNT'),
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
    bool readOnly = false,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: appColors.divider, width: 2),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: Body1.style.copyWith(color: appColors.mutedForeground),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              key: fieldKey,
              controller: controller,
              readOnly: readOnly,
              enableInteractiveSelection: !readOnly,
              showCursor: !readOnly,
              keyboardType: keyboardType,
              maxLength: maxLength,
              inputFormatters: inputFormatters,
              textAlign: TextAlign.right,
              style: Body1.style.copyWith(color: colors.onSurface),
              cursorColor: colors.onSurface,
              decoration: const InputDecoration(
                isDense: true,
                counterText: '',
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (readOnly)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Align(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.lock_outline,
                      color: appColors.mutedForeground,
                      size: 20,
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: controller.clear,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.close,
                      color: colors.onSurface,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialRow(
      {required String iconPath, required LoginProvider provider}) {
    final connected = _socialAccounts.contains(provider.name);
    return InkWell(
      key: ValueKey('social-account-${provider.name}'),
      onTap: connected || _connectingProvider != null
          ? null
          : () => _connectSocialAccount(provider),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              child: SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.displayName, style: Body1.style),
                  const SizedBox(height: 4),
                  Text(tr(context, connected ? 'Connected' : 'Not Connected'),
                      style: Eyebrow.style),
                ],
              ),
            ),
            if (_connectingProvider == provider)
              const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else if (!connected)
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurface,
                size: 16,
              ),
          ],
        ),
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
