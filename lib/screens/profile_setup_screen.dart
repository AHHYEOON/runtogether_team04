import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../constants.dart';
import 'main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileSetupScreen extends StatefulWidget {
  // 생성자: 수정 모드인지 확인할 변수와 초기값을 받을 수 있게 함
  final bool isEditMode;

  const ProfileSetupScreen({super.key, this.isEditMode = false});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nicknameController = TextEditingController();

  String _gender = '남성';
  DateTime _birthDate = DateTime(1995, 5, 5);

  File? _profileImage; // 선택된 새 이미지
  String? _serverImageUrl; // 서버에 저장된 기존 이미지 URL (수정 모드용)

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // ★ 만약 수정 모드라면, 기존 내 정보를 불러와서 채워넣어야 함!
    if (widget.isEditMode) {
      print("🛠️ 수정 모드로 진입! 데이터 로딩 시작"); // 로그 추가
      _loadMyProfile();
    }
  }

  // [수정 모드] 기존 내 정보 불러오기
  Future<void> _loadMyProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      if (token == null) return;

      final dio = Dio();
      final options = Options(headers: {
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
        'Content-Type': 'application/json',
      });

      // 마이페이지 조회 API 호출 (정보 가져오기)
      final response = await dio.get('$baseUrl/api/v1/auth/mypage', options: options);

      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          _nicknameController.text = data['nickname'] ?? "";

          // 성별 처리 (서버가 MALE/FEMALE로 준다고 가정)
          String serverGender = data['gender'] ?? "MALE";
          _gender = (serverGender == "FEMALE") ? "여성" : "남성";

          // 생년월일 처리 (YYYY-MM-DD 형식 가정)
          if (data['birthDate'] != null) {
            try {
              _birthDate = DateTime.parse(data['birthDate']);
            } catch (_) {}
          }

          // 프로필 이미지 URL
          _serverImageUrl = data['profileImage'];
        });
      }
    } catch (e) {
      print("❌ 기존 정보 로드 실패: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 갤러리 이미지 선택
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _profileImage = File(image.path));
  }

  // [프로필 저장/수정 함수]
  void _updateProfile() async {
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('인증 정보가 없습니다.')));
        return;
      }

      final dio = Dio();
      final options = Options(headers: {
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
        'Content-Type': 'application/json',
      });

      String serverGender = (_gender == '남성') ? 'MALE' : 'FEMALE';
      String birthDateStr = "${_birthDate.year}-${_birthDate.month.toString().padLeft(2,'0')}-${_birthDate.day.toString().padLeft(2,'0')}";

      String imageFileName = "";
      if (_profileImage != null) {
        imageFileName = _profileImage!.path.split('/').last;
      } else if (_serverImageUrl != null) {
        // 이미지를 새로 안 골랐으면, 기존 이미지를 유지할지 여부는 서버 로직에 따름
        // 여기서는 일단 빈 값 보내거나 처리 필요 (서버 개발자와 상의)
        // 일단은 빈 문자열로 둠
      }

      final Map<String, dynamic> requestData = {
        "nickname": _nicknameController.text,
        "gender": serverGender,
        "birthDate": birthDateStr,
        "profileImageUrl": imageFileName
      };

      print("🚀 [프로필 저장 요청] 데이터: $requestData");

      // ★ 수정 모드면 PATCH, 처음이면 POST (혹은 서버 API가 하나라면 그대로 사용)
      // 여기서는 profileUrl 하나로 통일되어 있다고 가정하고 POST 사용
      // 만약 수정 API가 따로 있다면 분기 처리 필요
      /* String apiUrl = widget.isEditMode ? '$baseUrl/api/v1/users/me' : profileUrl;
      String method = widget.isEditMode ? 'PATCH' : 'POST';
      */

      // 일단 기존 코드대로 POST 사용 (서버가 알아서 처리해주길 기대하거나 API 확인 필요)
      final response = await dio.post(profileUrl, data: requestData, options: options);

      if (response.statusCode == 200) {
        print("🎉 저장 완료!");
        if (!mounted) return;

        // ★ 수정 모드였다면 -> 그냥 뒤로가기 (마이페이지로 복귀)
        if (widget.isEditMode) {
          Navigator.pop(context);
        }
        // ★ 최초 설정이었다면 -> 메인 화면으로 이동 (스택 비우기)
        else {
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()),
                  (route) => false
          );
        }
      }
    } catch (e) {
      print("❌ 저장 실패: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("저장 중 오류가 발생했습니다.")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: Text(widget.isEditMode ? '프로필 수정' : '프로필 설정'), // 제목 변경
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 프로필 사진 ---
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        // 1. 새로 고른 이미지 -> 2. 기존 서버 이미지 -> 3. 기본 아이콘
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : (_serverImageUrl != null && _serverImageUrl!.isNotEmpty
                            ? NetworkImage(_serverImageUrl!)
                            : null) as ImageProvider?,
                        child: (_profileImage == null && (_serverImageUrl == null || _serverImageUrl!.isEmpty))
                            ? const Icon(Icons.person, size: 50, color: Colors.grey)
                            : null,
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

              // --- 닉네임 ---
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

              // --- 성별 ---
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