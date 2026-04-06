import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.dark;

    Future<void> proceed() async {
      // TODO: 실제 로그인 처리 후 홈으로
      context.go('/onboarding/welcome');
    }

    // 아이콘을 위젯으로 받아서 PNG/SVG 아무거나 쓸 수 있게
    Widget socialBtn({
      required Widget icon,
      required String label,
      required VoidCallback onTap,
    }) {
      final bgColor =
          isLight ? Colors.black.withOpacity(0.1): Color(0xFF3D3D3D);

      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // 아이콘
              SizedBox(width: 24, height: 24, child: icon),
              const SizedBox(width: 16),
              // 라벨 (가운데 정렬 느낌 유지)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: isLight
                      ? Body1.style.copyWith(color: Colors.black)
                      : Body1.style,
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
      );
    }

    // Divider 색상 테마 대응
    final dividerColor =
        isLight ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.2);

    return Scaffold(
      body: SafeArea(
        child: Container(
            color: isLight ? Colors.white : Colors.black,
            child: Column(
              children: [
                const SizedBox(height: 200),
                // 상단 로고 (SVG)
                SvgPicture.asset(
                  'assets/app_logo.svg',
                  width: 203.4,
                  height: 35,
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(
                    isLight ? Colors.black : Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // ✅ PNG / SVG 아이콘을 그대로 전달
                      socialBtn(
                        icon: SvgPicture.asset('assets/google.svg'),
                        label: 'Continue with Google',
                        onTap: proceed,
                      ),
                      const SizedBox(height: 16),
                      socialBtn(
                        icon: SvgPicture.asset(
                          'assets/apple.svg',
                          color: isLight ? Colors.white : Colors.black,
                        ),
                        label: 'Continue with Apple',
                        onTap: proceed,
                      ),
                      const SizedBox(height: 16),
                      socialBtn(
                        icon: SvgPicture.asset('assets/facebook.svg'),
                        label: 'Continue with Facebook',
                        onTap: proceed,
                      ),
                      const SizedBox(height: 12),
                      Divider(color: dividerColor, thickness: 1),
                      const SizedBox(height: 12),
                      socialBtn(
                        icon: Icon(
                          Icons.mail_outline,
                          size: 24,
                          color: isLight ? Colors.white : Colors.black,
                        ),
                        label: 'Continue with email',
                        onTap: () => context.go('/auth/signup'),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            )),
      ),
    );
  }
}
