import "package:flutter/material.dart";
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/community/mock/community_catalog.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _currentUserId = 1001;

  late final TextEditingController nameController;
  late final TextEditingController usernameController;
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  bool isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    final user = mockUserById(_currentUserId);
    nameController = TextEditingController(text: user.displayName);
    usernameController = TextEditingController(text: user.username);
    emailController = TextEditingController(text: user.email);
    passwordController = TextEditingController(text: '••••••••');
  }

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
                      backgroundImage:
                          const AssetImage('assets/profileAvatar.png'),
                    ),
                    Positioned(
                      bottom: -4,
                      right: -4,
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
                        child: Icon(
                          Icons.camera_alt,
                          color: colors.onSurface,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              Text(
                "LOGIN",
                style: Body2_b.style,
              ),

              const SizedBox(height: 16),

              // Form Fields
              _buildTextField(
                label: "Name",
                controller: nameController,
              ),
              const SizedBox(height: 24),
              _buildTextField(
                label: "Username",
                controller: usernameController,
              ),
              const SizedBox(height: 24),
              _buildTextField(
                label: "Email",
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              _buildTextField(
                label: "Password",
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
              Text("SOCIAL ACCOUNTS", style: Body2_b.style),
              const SizedBox(height: 16),

              // Updated to use SVGs
              _buildSocialRow(
                  iconPath: 'assets/google.svg',
                  name: 'Google',
                  status: 'Connected'),
              _divider(),
              _buildSocialRow(
                  iconPath: 'assets/apple.svg',
                  name: 'Apple',
                  status: 'Not Connected'),
              _divider(),
              _buildSocialRow(
                  iconPath: 'assets/facebook.svg',
                  name: 'Facebook',
                  status: 'Not Connected'),
              _divider(),

              const SizedBox(height: 48),

              // Update Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Handle update logic
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.onSurface,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "UPDATE INFO",
                    style: Body2_b.style.copyWith(color: colors.onPrimary),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Delete Account
              Center(
                child: GestureDetector(
                  onTap: () {
                    // Handle delete logic
                  },
                  child: Text(
                    "DELETE ACCOUNT",
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
    bool isPassword = false,
    bool isObscure = false,
    VoidCallback? onSuffixTap,
    TextInputType? keyboardType,
  }) {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: isPassword && isObscure,
      keyboardType: keyboardType,
      style: Body1.style.copyWith(color: colors.onSurface),
      cursorColor: colors.onSurface,
      decoration: InputDecoration(
        filled: false,
        labelText: label,
        labelStyle: Body1.style,
        floatingLabelStyle:
            Body1.style.copyWith(color: appColors.mutedForeground),
        suffixIcon: isPassword
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
                Text(status, style: Eyebrow.style),
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
