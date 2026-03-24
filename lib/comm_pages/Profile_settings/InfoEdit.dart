import "package:flutter/material.dart";
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final nameController = TextEditingController(text: "John Doe");
  final usernameController = TextEditingController(text: "john_doe");
  final emailController = TextEditingController(text: "jdoe0507@gmail.com");
  final passwordController = TextEditingController(text: "password123");
  bool isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Pure black background
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
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
                  children: [
                    const CircleAvatar(
                      radius: 54,
                      backgroundColor: Color(0xFF2B2B2B), // Dark grey placeholder
                      child: Icon(Icons.person, size: 60, color: Colors.white54),
                      // backgroundImage: ... (Add image provider here if needed)
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3D3D3D), // Badge color
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),
              
              Text("LOGIN", style: Body2_b.style,),

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
              Text(
                "SOCIAL ACCOUNTS",
                style: Body2_b.style
              ),
              const SizedBox(height: 16),

              // Updated to use SVGs
              _buildSocialRow(
                  iconPath: 'assets/google.svg',
                  name: 'Google',
                  status: 'Connected'
              ),
              _divider(),
              _buildSocialRow(
                  iconPath: 'assets/apple.svg',
                  name: 'Apple',
                  status: 'Not Connected'
              ),
              _divider(),
              _buildSocialRow(
                  iconPath: 'assets/facebook.svg',
                  name: 'Facebook',
                  status: 'Not Connected'
              ),
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
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "UPDATE INFO",
                    style: Body2_b.style.copyWith(color: Colors.black),
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
                      decorationColor: Colors.white,
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
    return TextField(
      controller: controller,
      obscureText: isPassword && isObscure,
      keyboardType: keyboardType,
      style: Body1.style.copyWith(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Body1.style,
        floatingLabelStyle: Body1.style.copyWith(color: Colors.white70),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.white,
            size: 20,
          ),
          onPressed: onSuffixTap,
        )
            : IconButton(
          icon: const Icon(Icons.cancel, color: Colors.white, size: 20),
          onPressed: () => controller.clear(),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
        contentPadding: const EdgeInsets.only(bottom: 8),
      ),
    );
  }

  Widget _buildSocialRow({required String iconPath, required String name, required String status}) {
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
          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(color: Color(0xFF3A3A3A), height: 1, thickness: 1);
  }
}