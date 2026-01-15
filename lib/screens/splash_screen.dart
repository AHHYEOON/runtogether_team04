import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ★ 필수

import '../constants.dart';
import 'login_screen.dart';
import 'main_screen.dart'; // ★ 메인 화면으로 이동해야 하니 import 필요!

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 앱이 켜지면 로그인 상태 확인 시작
    _checkLoginStatus();
  }

  // ★ [핵심] 로그인 상태 확인 함수
  Future<void> _checkLoginStatus() async {
    // 1. 로고를 2초 정도 보여줌 (너무 빨리 넘어가면 어색하니까)
    await Future.delayed(const Duration(seconds: 2));

    // 2. 저장소(SharedPreferences)에서 데이터 가져오기
    final prefs = await SharedPreferences.getInstance();

    // '로그인 상태 유지' 체크 여부 (저장 안 되어있으면 기본값 false)
    bool isAutoLogin = prefs.getBool('isAutoLogin') ?? false;
    // 저장된 토큰 가져오기
    String? token = prefs.getString('accessToken');

    if (!mounted) return; // 화면이 살아있는지 확인

    // 3. 판단 로직
    // 체크박스가 켜져 있고(true) + 토큰도 제대로 있다면 -> 메인 화면으로 직행
    if (isAutoLogin && token != null && token.isNotEmpty) {
      print("✅ 자동 로그인 성공! 메인 화면으로 이동합니다.");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
    // 아니라면 -> 로그인 화면으로 이동
    else {
      print("🔒 로그인 필요. 로그인 화면으로 이동합니다.");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'RUN TOGETHER',
              style: TextStyle(
                color: primaryColor,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            // 로딩 중임을 알려주는 뺑뺑이 (선택 사항)
            CircularProgressIndicator(color: primaryColor),
          ],
        ),
      ),
    );
  }
}