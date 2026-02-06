import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // TODO: 로그인 상태 확인 후 분기 (홈/온보딩)
    await Future.delayed(const Duration(seconds: 5)); // 로고 잠깐 보여주기
    if (!mounted) return;
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isLight ? Colors.white : const Color(0xFF0B0B0B),
      body: SafeArea(
        child: Center(
          child: SvgPicture.asset(
            'assets/app_logo.svg',
            width: 120, // 가로 비율 기준
            height: 23, // 세로 맞춤
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(
              isLight ? Colors.black : Colors.white,
              BlendMode.srcIn,
            ), // 라이트/다크 모드 색 반전
          ),
        ),
      ),
    );
  }
}
