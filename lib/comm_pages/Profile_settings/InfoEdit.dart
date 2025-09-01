import "package:flutter/material.dart";
// import 'package:go_router/go_router.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:onetouch/core/stylesheet_dark.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final nameController = TextEditingController(text: "John Doe");
  final emailController = TextEditingController(text: "jdoe0507@gmail.com");
  final passwordController = TextEditingController(text: "password123");
  bool isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient Top Bar with back and search
              Container(
                padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFB10030), Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    BackButton(color: Colors.white),
                    Icon(Icons.search, color: Colors.white),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Profile avatar with camera icon
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: const [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: Colors.black54,
                    ),
                    Icon(Icons.camera_alt, color: Colors.white),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // TextFields
              _buildTextField("Name", nameController),
              _buildTextField("Email", emailController),
              _buildTextField("Password", passwordController,
                  isPassword: true,
                  isObscure: !isPasswordVisible,
                  onSuffixTap: () {
                    setState(() {
                      isPasswordVisible = !isPasswordVisible;
                    });
                  }),

              /// 🆕 Social Accounts Section
              _buildSocialAccountsSection(),

              const SizedBox(height: 48),

              // Update Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Center(
                    child: Text("UPDATE INFO", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () {},
                  child: const Text(
                    "DELETE ACCOUNT",
                    style: TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isPassword = false, bool isObscure = false, VoidCallback? onSuffixTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: isPassword && isObscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              isObscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.white54,
            ),
            onPressed: onSuffixTap,
          )
              : IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => controller.clear(),
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

Widget _buildSocialAccountsSection() {
  final List<Map<String, dynamic>> socialAccounts = [
    {
      'icon': Image.asset('assets/google.png', height: 24),
      'name': 'Google',
      'status': 'Connected',
    },
    {
      'icon': Image.asset('assets/apple.png', height: 24),
      'name': 'Apple',
      'status': 'Not Connected',
    },
    {
      'icon': Image.asset('assets/facebook.png', height: 24),
      'name': 'Facebook',
      'status': 'Not Connected',
    },
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(24, 32, 24, 12),
        child: Text(
          "SOCIAL ACCOUNTS",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      ...socialAccounts.map((account) => Column(
        children: [
          ListTile(
            leading: account['icon'],
            title: Text(account['name'],
                style: const TextStyle(color: Colors.white)),
            subtitle: Text(account['status'],
                style: const TextStyle(color: Colors.white54)),
            trailing:
            const Icon(Icons.chevron_right, color: Colors.white),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            onTap: () {
              // TODO: Handle connection logic
            },
          ),
          const Divider(color: Color(0xFF3A3A3A), height: 1, thickness: 1),
        ],
      )),
    ],
  );
}