import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    final socialButtonBackground =
        isLightMode ? AppPalette.black : AppPalette.lightGrey;
    const socialButtonForeground = AppPalette.white;
    final emailButtonBackground =
        isLightMode ? AppPalette.lightGreyBox : AppPalette.darkGrey;
    final emailButtonForeground =
        isLightMode ? AppPalette.black : AppPalette.white;

    Future<void> proceed() async {
      // TODO: 실제 로그인 처리 후 홈으로
      context.go('/onboarding/welcome');
    }

    // 아이콘을 위젯으로 받아서 PNG/SVG 아무거나 쓸 수 있게
    Widget socialBtn({
      Widget? icon,
      required String label,
      required VoidCallback onTap,
      Color? backgroundColor,
      Color? foregroundColor,
    }) {
      final buttonForeground = foregroundColor ?? colors.onSurface;

      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? appColors.cardBackground,
            foregroundColor: buttonForeground,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: icon == null
              ? Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Body1.style.copyWith(color: buttonForeground),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(width: 24, height: 24, child: icon),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Body1.style.copyWith(color: buttonForeground),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
        ),
      );
    }

    // Divider 색상 테마 대응
    return Scaffold(
      body: SafeArea(
        child: Container(
            color: appColors.pageBackground,
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
                    colors.onSurface,
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
                        backgroundColor: socialButtonBackground,
                        foregroundColor: socialButtonForeground,
                        onTap: proceed,
                      ),
                      const SizedBox(height: 16),
                      socialBtn(
                        icon: SvgPicture.asset(
                          'assets/apple.svg',
                          colorFilter: const ColorFilter.mode(
                            socialButtonForeground,
                            BlendMode.srcIn,
                          ),
                        ),
                        label: 'Continue with Apple',
                        backgroundColor: socialButtonBackground,
                        foregroundColor: socialButtonForeground,
                        onTap: proceed,
                      ),
                      const SizedBox(height: 16),
                      socialBtn(
                        icon: SvgPicture.asset('assets/facebook.svg'),
                        label: 'Continue with Facebook',
                        backgroundColor: socialButtonBackground,
                        foregroundColor: socialButtonForeground,
                        onTap: proceed,
                      ),
                      const SizedBox(height: 12),
                      const Divider(
                        color: AppPalette.lightGrey,
                        thickness: 1,
                      ),
                      const SizedBox(height: 12),
                      socialBtn(
                        label: 'Continue with email',
                        backgroundColor: emailButtonBackground,
                        foregroundColor: emailButtonForeground,
                        onTap: () => context.push('/auth/signup'),
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
