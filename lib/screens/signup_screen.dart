import 'package:flutter/material.dart';
import 'package:runtogether_team04/screens/profile_setup_screen.dart';
import '../constants.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 토큰 저장용


class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isLoading = false;
  bool _isEmailChecked = false;
  String _emailStatusMessage = '';
  Color _emailStatusColor = Colors.transparent;

  // [팁] ngrok용 헤더 옵션 (이걸 요청마다 넣어줘야 함)
  final Options _ngrokOptions = Options(
    headers: {
      'ngrok-skip-browser-warning': 'true', // 이 줄이 핵심! 경고창 무시
      'Content-Type': 'application/json',
    },
  );

  // [1] 이메일 중복 확인 (다시 POST 방식!)
  void _checkEmailDuplicate() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일을 입력해주세요.')));
      return;
    }

    try {
      final dio = Dio();

      // ★ POST 방식으로 변경
      print("🔍 [중복확인 요청] URL: $checkEmailUrl");
      print("🔍 [보내는 데이터] {'email': '${_emailController.text}'}");

      final response = await dio.post(
        checkEmailUrl,
        data: {'email': _emailController.text}, // Body에 담기
      );

      print("✅ [중복확인 응답] 상태코드: ${response.statusCode}");

      if (response.statusCode == 200) {
        setState(() {
          _isEmailChecked = true;
          _emailStatusMessage = '사용 가능한 이메일입니다.';
          _emailStatusColor = Colors.green;
        });
      }
    } catch (e) {
      print("❌ [중복확인 실패] 에러: $e");
      if (e is DioException) {
        print("❌ [서버 메시지]: ${e.response?.data}");
      }
      setState(() {
        _isEmailChecked = false;
        _emailStatusMessage = '이미 사용 중이거나 사용할 수 없는 이메일입니다.';
        _emailStatusColor = Colors.red;
      });
    }
  }

  // [2] 회원가입 + 자동 로그인 (안 넘어가는 문제 해결용 로그 추가)
  void _registerAndLogin() async {
    // 1. 유효성 검사
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요.')));
      return;
    }

    if (!_isEmailChecked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일 중복 확인을 먼저 해주세요.')));
      return;
    }

    if (_passwordController.text != _passwordConfirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
      return;
    }

    setState(() => _isLoading = true);
    final dio = Dio();

    try {
      // -----------------------------------------------------
      // 2. 회원가입 요청
      // -----------------------------------------------------
      print("🚀 [1단계] 회원가입 시도: $registerUrl");
      final registerResponse = await dio.post(registerUrl, data: {
        'email': _emailController.text,
        'password': _passwordController.text,
      });

      print("✅ [1단계] 회원가입 응답 코드: ${registerResponse.statusCode}");

      // -----------------------------------------------------
      // 3. 로그인 요청 (자동)
      // -----------------------------------------------------
      if (registerResponse.statusCode == 200 || registerResponse.statusCode == 201) {
        print("🚀 [2단계] 자동 로그인 시도: $loginUrl");

        final loginResponse = await dio.post(loginUrl, data: {
          'email': _emailController.text,
          'password': _passwordController.text,
        });

        print("✅ [2단계] 로그인 응답 데이터: ${loginResponse.data}");

        if (loginResponse.statusCode == 200) {
          // ★ 친구가 토큰 키를 'accessToken'으로 줬는지 'token'으로 줬는지 몰라서 둘 다 체크
          final token = loginResponse.data['accessToken'] ?? loginResponse.data['token'];

          if (token != null) {
            print("🔑 [토큰 획득 성공]: $token");

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('accessToken', token);

            if (!mounted) return;

            // ★ 화면 이동!
            print("🏃 [화면 이동] 프로필 설정 페이지로 이동합니다.");
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
            );
          } else {
            print("❌ [오류] 로그인은 됐는데 토큰(accessToken)이 없습니다!");
            throw Exception("토큰 미발견");
          }
        }
      } else {
        print("❌ [오류] 회원가입은 요청했으나 성공 코드가 아닙니다. (${registerResponse.statusCode})");
      }
    } catch (e) {
      print("❌ [치명적 에러 발생]: $e");
      String msg = "작업 실패";
      if(e is DioException) {
        print("❌ 서버 에러 상세: ${e.response?.data}");
        msg = "오류: ${e.response?.data}";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('회원가입', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이메일 + 중복확인
              const Text('이메일', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) {
                        if (_isEmailChecked) {
                          setState(() {
                            _isEmailChecked = false;
                            _emailStatusMessage = '';
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'example@email.com',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _checkEmailDuplicate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(80, 50),
                    ),
                    child: const Text('중복\n확인', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(_emailStatusMessage, style: TextStyle(color: _emailStatusColor, fontSize: 13)),
              ),

              const SizedBox(height: 20),

              // 비밀번호
              const Text('비밀번호', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: '비밀번호 입력',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 24),

              // 비밀번호 확인
              const Text('비밀번호 확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordConfirmController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: '비밀번호 재입력',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 40),

              // 다음 버튼
              SizedBox(
                width: double.infinity,
                height: 55,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: primaryColor))
                    : ElevatedButton(
                  onPressed: _registerAndLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEmailChecked ? primaryColor : Colors.grey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('다음 (자동 로그인)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}