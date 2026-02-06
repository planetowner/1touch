import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

class EmailVerifyScreen extends StatefulWidget {
  final String email;

  const EmailVerifyScreen({super.key, required this.email});

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  final _code = TextEditingController();
  bool _submitting = false;

  InputDecoration _dec(String hint) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF3C3C3C),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none),
      );

  Future<void> _continue() async {
    // TODO: 실제 인증 코드 검증 API
    if (_code.text
        .trim()
        .length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the code.')));
      return;
    }
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _submitting = false);

    if (!mounted) return;
    // 인증 성공 가정 → 홈으로
    context.go('/onboarding/welcome');
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isLight ? Colors.white : const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: isLight ? Colors.black :  Colors.white),
        centerTitle: true,
        title: const Text('Verify your email', style: Body1.style),
      ),
      body: SafeArea(
        // 1. Switch ListView to CustomScrollView
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false, // Allows content to fill the screen height
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  // 2. Use Column instead of ListView
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        text: 'Enter the verification code that we sent to ',
                        children: [
                          TextSpan(
                            text: widget.email,
                            style: Body1_b.style,
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      style: Body1.style,
                    ),
                    const SizedBox(height: 24),

                    const Text('Verification code', style: Eyebrow.style),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      decoration: _dec('204182'),
                      style: Body1.style,
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text("Didn't get code? ", style: Body1.style),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code sent again.')));
                          },
                          child: Text(
                            'Send again',
                            style: Body1.style.copyWith(
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 3. This Spacer now works perfectly because of SliverFillRemaining
                    const Spacer(),

                    SizedBox(
                      height: 56,
                      width: double.infinity, // Ensures button takes full width
                      child: FilledButton(
                        onPressed: _submitting ? null : _continue,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                            : Text('CONTINUE',
                            style: Body1_b.style.copyWith(color: Colors.black)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
