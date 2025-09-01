import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({super.key});

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  final _email     = TextEditingController();
  final _password  = TextEditingController();

  bool _obscure = true;
  bool _agreed  = false;
  bool _submitting = false;

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: Body1.style.copyWith(color: Colors.white),
    filled: true,
    fillColor: const Color(0xFF3C3C3C),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
  );

  bool get _canSubmit =>
      _agreed &&
          !_submitting &&
          _firstName.text.trim().isNotEmpty &&
          _lastName.text.trim().isNotEmpty &&
          _email.text.trim().isNotEmpty &&
          _password.text.length >= 6;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) return;

    setState(() => _submitting = true);

    // TODO: 실제 회원가입 API 호출
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() => _submitting = false);

    // verify screen으로 이동 (email을 query로 전달)
    if (!mounted) return;
    context.go('/auth/verify?email=${Uri.encodeComponent(_email.text.trim())}');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0B) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: isDark ? Colors.white : Colors.black),
        centerTitle: true,
        title: Text('Sign up', style: Body1.style.copyWith(color: Colors.black)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}), // 버튼 활성화 갱신
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 12),
              const Text('First name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _firstName,
                decoration: _dec('John'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter first name' : null,
              ),
              const SizedBox(height: 16),

              const Text('Last name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lastName,
                decoration: _dec('Doe'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter last name' : null,
              ),
              const SizedBox(height: 16),

              const Text('Email'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('johndoe@gmail.com'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter email';
                  final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
                  return ok ? null : 'Enter a valid email';
                },
              ),
              const SizedBox(height: 16),

              const Text('Password'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: _dec('• • • • • • • •').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v != null && v.length >= 6) ? null : 'At least 6 characters',
              ),

              const SizedBox(height: 28),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text:
                        "By clicking sign up, I hereby agree and consent to 1Touch’s Terms & Conditions; I confirm that I have read 1Touch’s Privacy Policy.",
                        children: const [],
                      ),
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _submitting
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('SIGN UP', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
