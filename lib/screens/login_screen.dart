import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:runtogether_team04/screens/signup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _keepLogin = false;
  bool _isLoading = false;

  // [로그인 함수]
  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dio = Dio();

      // ★ [중요] ngrok 헤더 추가 (이거 없으면 에러남)
      final options = Options(
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'Content-Type': 'application/json',
        },
      );

      print("🚀 로그인 요청: $loginUrl");
      print("📦 데이터: $email / $password");

      final response = await dio.post(
        loginUrl,
        data: {
          'email': email,
          'password': password,
        },
        options: options, // 헤더 적용
      );

      print("✅ 응답 코드: ${response.statusCode}");

      if (response.statusCode == 200) {
        // 토큰 가져오기 (null 안전 처리)
        // accessToken이 없으면 token을 찾고, 그것도 없으면 null
        final token = response.data['accessToken'] ?? response.data['token'];

        if (token != null) {
          print("🔑 토큰 획득: $token");

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('accessToken', token.toString());

          if (!mounted) return;
          // 메인 화면으로 이동 (로그인 화면은 뒤로가기 안되게 제거)
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
        } else {
          print("⚠️ 로그인 성공했으나 토큰이 없음: ${response.data}");
          throw Exception("서버 응답에 토큰이 없습니다.");
        }
      }
    } catch (e) {
      print("❌ 로그인 실패: $e");
      String errorMessage = '로그인 실패';

      if (e is DioException) {
        // 서버가 보내준 에러 메시지 확인
        print("❌ 서버 메시지: ${e.response?.data}");

        if (e.response?.data is Map && e.response?.data['message'] != null) {
          // 서버가 { "message": "비번 틀림" } 이렇게 준 경우
          errorMessage = e.response?.data['message'];
        } else if (e.response?.statusCode == 401 || e.response?.statusCode == 400) {
          errorMessage = "이메일 또는 비밀번호를 확인해주세요.";
        } else {
          errorMessage = "서버 연결 오류 (${e.response?.statusCode})";
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              const Center(
                child: Text('RUN TOGETHER', style: TextStyle(color: primaryColor, fontSize: 32, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 50),

              const Text('이메일', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: '이메일 입력', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 20),

              const Text('비밀번호', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '비밀번호 입력', prefixIcon: Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Checkbox(
                      value: _keepLogin,
                      activeColor: primaryColor,
                      onChanged: (val) => setState(() => _keepLogin = val!)
                  ),
                  const Text('로그인 상태 유지'),
                ],
              ),
              const SizedBox(height: 20),

              // 로그인 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: primaryColor))
                    : ElevatedButton(
                  onPressed: _login,
                  child: const Text('로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 10),
              Center(
                  child: TextButton(
                      onPressed: () {
                        // 회원가입 화면으로 이동
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen()));
                      },
                      child: const Text('이메일 회원가입  |  비밀번호 찾기', style: TextStyle(color: Colors.grey))
                  )
              ),
            ],
          ),
        ),
      ),
    );
  }
}