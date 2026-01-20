import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'group_detail_screen.dart'; // 가입 성공 시 이동할 상세 화면

class CodeJoinScreen extends StatefulWidget {
  const CodeJoinScreen({super.key});

  @override
  State<CodeJoinScreen> createState() => _CodeJoinScreenState();
}

class _CodeJoinScreenState extends State<CodeJoinScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // [API] 코드로 그룹 가입 요청
  Future<void> _joinByCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('참가 코드를 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final dio = Dio();

      final options = Options(
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // ★ [수정됨] constants.dart에 추가한 URL 사용
      // POST /api/v1/groups/join/code

      final data = {
        "accessCode": code // ★ [중요] 친구가 말한대로 키값 변경 (inviteCode -> accessCode)
      };

      print("🚀 코드 참여 요청: $groupJoinCodeUrl, data: $data");

      final response = await dio.post(groupJoinCodeUrl, data: data, options: options);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('대회 참여 성공!')));

        // 성공 시 목록 화면으로 돌아가기 (자동 새로고침 됨)
        Navigator.pop(context);
      }
    } catch (e) {
      print("❌ 코드 참여 실패: $e");

      String message = '참여에 실패했습니다. 코드를 확인해주세요.';
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          message = '존재하지 않는 코드입니다.';
        } else if (e.response?.statusCode == 409) {
          message = '이미 가입된 대회입니다.';
        } else if (e.response?.statusCode == 400) {
          message = '잘못된 요청입니다.';
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('코드 참여', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 50),
            const Text('비공개 대회 참가 코드', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('주최자에게 받은 참가 코드를 입력하세요.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            // 코드 입력창
            TextField(
              controller: _codeController, // ★ 컨트롤러 연결
              decoration: InputDecoration(
                hintText: '코드를 입력하세요',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.grey),
                    onPressed: () => _codeController.clear() // X버튼 누르면 지우기
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 입력 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _joinByCode, // ★ 함수 연결
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('입력', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}