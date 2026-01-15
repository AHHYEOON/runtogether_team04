import 'package:flutter/material.dart';
import 'package:runtogether_team04/screens/profile_setup_screen.dart';
import '../constants.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // ★ [추가] 비밀번호 관련 상태 변수
  String _passwordErrorMsg = ''; // 비밀번호 안내/에러 메시지
  String _confirmErrorMsg = '';  // 비밀번호 확인 에러 메시지
  bool _isPasswordValid = false; // 비밀번호 유효성 여부

  // ngrok용 헤더
  final Options _ngrokOptions = Options(
    headers: {
      'ngrok-skip-browser-warning': 'true',
      'Content-Type': 'application/json',
    },
  );

  // ------------------------------------------------------------------------
  // [로직 1] 실시간 비밀번호 유효성 검사 (정규식)
  // ------------------------------------------------------------------------
  void _validatePassword(String value) {
    // 영문, 숫자, 특수문자 포함 8자 이상 정규식
    String pattern = r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$';
    RegExp regExp = RegExp(pattern);

    if (value.isEmpty) {
      setState(() {
        _passwordErrorMsg = '';
        _isPasswordValid = false;
      });
    } else if (!regExp.hasMatch(value)) {
      setState(() {
        _passwordErrorMsg = '영문, 숫자, 특수문자를 섞어서 8자 이상 입력해주세요.';
        _isPasswordValid = false;
      });
    } else {
      setState(() {
        _passwordErrorMsg = ''; // 조건 만족하면 메시지 지움
        _isPasswordValid = true;
      });
    }

    // 비밀번호가 바뀌면 '비밀번호 확인' 쪽도 다시 검사해야 함
    if (_passwordConfirmController.text.isNotEmpty) {
      _validateConfirm(_passwordConfirmController.text);
    }
  }

  // ------------------------------------------------------------------------
  // [로직 2] 실시간 비밀번호 일치 검사
  // ------------------------------------------------------------------------
  void _validateConfirm(String value) {
    if (value.isEmpty) {
      setState(() => _confirmErrorMsg = '');
    } else if (value != _passwordController.text) {
      setState(() => _confirmErrorMsg = '비밀번호가 올바르지 않습니다.');
    } else {
      setState(() => _confirmErrorMsg = ''); // 일치하면 메시지 지움
    }
  }

  // [로직 3] 이메일 중복 확인
  void _checkEmailDuplicate() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일을 입력해주세요.')));
      return;
    }

    try {
      final dio = Dio();
      final response = await dio.post(
        checkEmailUrl,
        data: {'email': _emailController.text},
      );

      if (response.statusCode == 200) {
        setState(() {
          _isEmailChecked = true;
          _emailStatusMessage = '사용 가능한 이메일입니다.';
          _emailStatusColor = Colors.green;
        });
      }
    } catch (e) {
      setState(() {
        _isEmailChecked = false;
        _emailStatusMessage = '이미 사용 중이거나 사용할 수 없는 이메일입니다.';
        _emailStatusColor = const Color(0xFFFF7F50);
      });
    }
  }

  // [로직 4] 회원가입 + 로그인
  void _registerAndLogin() async {
    // 최종 유효성 검사
    if (!_isEmailChecked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일 중복 확인을 해주세요.')));
      return;
    }
    if (!_isPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호 조건을 확인해주세요.')));
      return;
    }
    if (_passwordController.text != _passwordConfirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
      return;
    }

    setState(() => _isLoading = true);
    final dio = Dio();

    try {
      // 1. 회원가입
      final registerResponse = await dio.post(registerUrl, data: {
        'email': _emailController.text,
        'password': _passwordController.text,
      });

      // 2. 로그인 (토큰 발급)
      if (registerResponse.statusCode == 200 || registerResponse.statusCode == 201) {
        final loginResponse = await dio.post(loginUrl, data: {
          'email': _emailController.text,
          'password': _passwordController.text,
        });

        if (loginResponse.statusCode == 200) {
          final token = loginResponse.data['accessToken'] ?? loginResponse.data['token'];
          if (token != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('accessToken', token);

            if (!mounted) return;
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileSetupScreen()));
          }
        }
      }
    } catch (e) {
      String msg = "작업 실패";
      if(e is DioException) {
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
              // ---------------------------------------------------
              // 이메일 영역
              // ---------------------------------------------------
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

              // ---------------------------------------------------
              // 비밀번호 영역 (수정됨)
              // ---------------------------------------------------
              const Text('비밀번호', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                onChanged: _validatePassword, // ★ 입력할 때마다 검사
                decoration: InputDecoration(
                  hintText: '비밀번호 입력',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              // ★ 비밀번호 조건 불만족 시 에러 메시지 노출
              if (_passwordErrorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    _passwordErrorMsg,
                    style: const TextStyle(color: Color(0xFFFF7F50), fontSize: 13), // 오렌지색
                  ),
                ),

              const SizedBox(height: 24),

              // ---------------------------------------------------
              // 비밀번호 확인 영역 (수정됨)
              // ---------------------------------------------------
              const Text('비밀번호 확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordConfirmController,
                obscureText: true,
                onChanged: _validateConfirm, // ★ 입력할 때마다 검사
                decoration: InputDecoration(
                  hintText: '비밀번호 재입력',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              // ★ 비밀번호 불일치 시 에러 메시지 노출
              if (_confirmErrorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    _confirmErrorMsg,
                    style: const TextStyle(color: Color(0xFFFF7F50), fontSize: 13), // 오렌지색 (또는 빨간색 Colors.red)
                  ),
                ),

              const SizedBox(height: 40),

              // ---------------------------------------------------
              // 다음 버튼
              // ---------------------------------------------------
              SizedBox(
                width: double.infinity,
                height: 55,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: primaryColor))
                    : ElevatedButton(
                  onPressed: _registerAndLogin,
                  style: ElevatedButton.styleFrom(
                    // 이메일 확인 OK && 비밀번호 조건 OK 여야 활성화된 색상
                    backgroundColor: (_isEmailChecked && _isPasswordValid) ? primaryColor : Colors.grey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('다음', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}