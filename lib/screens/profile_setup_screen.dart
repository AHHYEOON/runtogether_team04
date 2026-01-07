import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // image_picker 패키지
import 'package:dio/dio.dart'; // dio 패키지
import '../constants.dart';
import 'main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nicknameController = TextEditingController();

  // 기본값 설정
  String _gender = '남성';
  DateTime _birthDate = DateTime(1995, 5, 5);

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // 갤러리에서 이미지 선택
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _profileImage = File(image.path));
  }

  // [프로필 저장 함수]
  void _updateProfile() async {
    // 1. 닉네임 입력 확인
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. 저장된 토큰 가져오기 (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      print("🔑 저장된 토큰 확인: $token");

      if (token == null) {
        print("❌ 토큰이 없습니다. 로그인 과정에 문제가 있었습니다.");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('인증 정보가 없습니다. 다시 로그인해주세요.')));
        return; // 여기서 멈춤
      }

      final dio = Dio();

      // 3. 헤더 설정 (가장 중요!)
      // Authorization: Bearer 토큰
      // ngrok-skip-browser-warning: true
      final options = Options(
        headers: {
          'Authorization': 'Bearer $token', // 띄어쓰기 주의
          'ngrok-skip-browser-warning': 'true',
          'Content-Type': 'application/json',
        },
      );

      // 4. 데이터 준비 (JSON)
      // 화면엔 '남성'/'여성'이지만 서버엔 'MALE'/'FEMALE'로 보내야 함
      String serverGender = (_gender == '남성') ? 'MALE' : 'FEMALE';
      String birthDateStr = "${_birthDate.year}-${_birthDate.month.toString().padLeft(2,'0')}-${_birthDate.day.toString().padLeft(2,'0')}";

      // 이미지가 없으면 null 보냄 (친구가 null 보내도 된다고 했음)
      // 이미지가 있으면 일단 파일명만 보냄 (나중에 파일 업로드 구현 시 변경 필요)
      String imageFileName = ""; // 기본값 빈 문자열
      if (_profileImage != null) {
        imageFileName = _profileImage!.path.split('/').last;
      }

      final Map<String, dynamic> requestData = {
        "nickname": _nicknameController.text,
        "gender": serverGender,
        "birthDate": birthDateStr,

        // ★ 여기가 수정됨: null 대신 ""(빈 문자열) 전송
        "profileImageUrl": imageFileName
      };

      print("🚀 [프로필 저장 요청] URL: $profileUrl");
      print("📦 [보내는 데이터] $requestData");

      // 5. 서버로 전송 (PATCH)
      final response = await dio.post(
        profileUrl,
        data: requestData,
        options: options, // 위에서 만든 헤더 옵션 적용
      );

      print("✅ [응답 상태코드] ${response.statusCode}");

      if (response.statusCode == 200) {
        print("🎉 프로필 설정 완료! 메인 화면으로 이동합니다.");
        if (!mounted) return;

        // 메인 화면으로 이동 (뒤로가기 못하게 stack 비우기)
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
                (route) => false
        );
      } else {
        print("⚠️ 성공은 아닌 것 같음 (200 아님)");
      }

    } catch (e) {
      print("❌ [프로필 저장 실패] 에러: $e");
      String errorMsg = "프로필 저장 중 오류가 발생했습니다.";

      if(e is DioException) {
        print("❌ 서버 응답 데이터: ${e.response?.data}");
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          errorMsg = "인증에 실패했습니다. (토큰 만료 등)";
        } else if (e.response?.statusCode == 400) {
          errorMsg = "입력 형식이 잘못되었습니다. (생년월일 등)";
        } else {
          errorMsg = "오류: ${e.response?.data}";
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('프로필 설정'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 프로필 사진 (원형) ---
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                        child: _profileImage == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.grey, size: 20),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // --- 닉네임 입력 ---
              const Text('닉네임', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                  controller: _nicknameController,
                  decoration: InputDecoration(
                    hintText: '닉네임 입력',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  )
              ),
              const SizedBox(height: 24),

              // --- 성별 선택 ---
              const Text('성별', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  _buildGenderRadio('남성'),
                  _buildGenderRadio('여성'),
                ],
              ),
              const SizedBox(height: 24),

              // --- 생년월일 ---
              const Text('생년월일', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _birthDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now()
                  );
                  if (date != null) setState(() => _birthDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12)
                  ),
                  child: Text(
                    "${_birthDate.year}-${_birthDate.month.toString().padLeft(2,'0')}-${_birthDate.day.toString().padLeft(2,'0')}",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // --- 완료 버튼 ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: primaryColor))
                    : ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('완료', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderRadio(String label) {
    return Row(
      children: [
        Radio<String>(
          value: label,
          groupValue: _gender,
          activeColor: primaryColor,
          onChanged: (val) {
            setState(() {
              _gender = val!;
            });
          },
        ),
        Text(label),
        const SizedBox(width: 20),
      ],
    );
  }
}