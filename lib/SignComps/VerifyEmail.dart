import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmailVerifyScreen extends StatefulWidget {
  final String email;
  const EmailVerifyScreen({super.key, required this.email});

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  final _code = TextEditingController();
  bool _submitting = false;

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: const Color(0xFF3C3C3C),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
  );

  Future<void> _continue() async {
    // TODO: 실제 인증 코드 검증 API
    if (_code.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the code.')));
      return;
    }
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _submitting = false);

    if (!mounted) return;
    // 인증 성공 가정 → 홈으로
    context.go('/home');
  }

  @override
  void dispose() {
    _code.dispose();
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
        title: const Text('Verify your email', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                text: 'Enter the verification code that we sent to ',
                children: [
                  TextSpan(
                    text: widget.email,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              style: const TextStyle(fontSize: 18, height: 1.5),
            ),
            const SizedBox(height: 24),

            const Text('Verification code'),
            const SizedBox(height: 8),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: _dec('204182'),
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                const Text("Didn't get code? "),
                GestureDetector(
                  onTap: () {
                    // TODO: 코드 재전송 API
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code sent again.')));
                  },
                  child: const Text('Send again', style: TextStyle(decoration: TextDecoration.underline)),
                ),
              ],
            ),

            const SizedBox(height: 32),

            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _submitting ? null : _continue,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: _submitting
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('CONTINUE', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
