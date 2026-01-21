import 'dart:io';
import 'package:flutter/foundation.dart'; // 웹/앱 구분용
import 'package:flutter/services.dart';   // Asset 로딩용
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart'; // ★ 파일 타입 설정용
import '../constants.dart';
import 'main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEditMode;

  const ProfileSetupScreen({super.key, this.isEditMode = false});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nicknameController = TextEditingController();
  String _gender = '남성';
  DateTime _birthDate = DateTime(1995, 5, 5);

  static const String _defaultCharacterPath = 'assets/images/character1.png';
  static const String _serverDefaultString = "DEFAULT_CHARACTER";

  XFile? _pickedImage;
  String? _serverImageUrl;

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) {
      _loadMyProfile();
    }
  }

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
      });

      final response = await dio.get('$baseUrl/api/v1/auth/mypage', options: options);

      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          _nicknameController.text = data['nickname'] ?? "";
          _gender = (data['gender'] == "FEMALE") ? "여성" : "남성";
          if (data['birthDate'] != null) {
            try {
              _birthDate = DateTime.parse(data['birthDate']);
            } catch (_) {}
          }
          _serverImageUrl = data['profileImage'];
        });
      }
    } catch (e) {
      print("❌ 정보 로드 실패: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      // maxWidth, maxHeight, imageQuality를 추가해서 용량을 압축합니다.
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,   // 가로 최대 1000px
        maxHeight: 1000,  // 세로 최대 1000px
        imageQuality: 85, // 화질 85% (용량이 확 줄어듭니다)
      );
      if (image != null) {
        setState(() {
          _pickedImage = image;
        });
      }
    } catch (e) {
      print("갤러리 에러: $e");
    }
  }

  // ★ [수정] 프로필 저장 (500 에러 방지 로직 추가)
  void _updateProfile() async {
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      if (token == null) return;

      final dio = Dio();
      final options = Options(headers: {
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      });

      String serverGender = (_gender == '남성') ? 'MALE' : 'FEMALE';
      String birthDateStr = "${_birthDate.year}-${_birthDate.month.toString().padLeft(2,'0')}-${_birthDate.day.toString().padLeft(2,'0')}";

      final formData = FormData.fromMap({
        "nickname": _nicknameController.text,
        "gender": serverGender,
        "birthDate": birthDateStr,
      });

      if (_pickedImage != null) {
        String fileName = _pickedImage!.name;

        // 🛡️ 서버가 JPG를 못받을 경우를 대비해 image/png로 타입 강제 시도
        MediaType contentType = MediaType('image', 'png');
        if (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg')) {
          contentType = MediaType('image', 'jpeg');
        }

        print("📸 전송할 파일: $fileName (Type: $contentType)");

        MultipartFile multipartFile;
        if (kIsWeb) {
          final bytes = await _pickedImage!.readAsBytes();
          multipartFile = MultipartFile.fromBytes(bytes, filename: fileName, contentType: contentType);
        } else {
          multipartFile = await MultipartFile.fromFile(_pickedImage!.path, filename: fileName, contentType: contentType);
        }

        formData.files.add(MapEntry("image", multipartFile));
      }

      final response = await dio.post('$baseUrl/api/v1/auth/profile', data: formData, options: options);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("🎉 저장 성공!");
        if (!mounted) return;
        if (widget.isEditMode) {
          Navigator.pop(context);
        } else {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainScreen()), (route) => false);
        }
      }
    } catch (e) {
      print("❌ 저장 실패: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("저장 중 오류가 발생했습니다. (이미지 형식을 확인해주세요)")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ★ [수정] 이미지 주소 완성 함수 (슬래시 중복 완벽 제거)
  String _getCorrectImageUrl(String path) {
    if (path.startsWith('http')) return path;

    // baseUrl 끝의 / 제거
    String base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    // path 앞의 / 제거
    String cleanPath = path.startsWith('/') ? path.substring(1) : path;

    return '$base/$cleanPath';
  }

  Widget _buildProfileImageWidget() {
    if (_pickedImage != null) {
      if (kIsWeb) {
        return Image.network(_pickedImage!.path, width: 120, height: 120, fit: BoxFit.cover);
      } else {
        return Image.file(File(_pickedImage!.path), width: 120, height: 120, fit: BoxFit.cover);
      }
    }

    if (_serverImageUrl != null && _serverImageUrl!.isNotEmpty && _serverImageUrl != _serverDefaultString) {
      String fullUrl = _getCorrectImageUrl(_serverImageUrl!);
      print("🧐 이미지 로드 주소: $fullUrl");

      return Image.network(
        fullUrl,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        // ★ ngrok 경고창 우회 헤더 추가
        headers: const {'ngrok-skip-browser-warning': 'true'},
        errorBuilder: (context, error, stackTrace) {
          print("❌ 이미지 로드 실패");
          return Image.asset(_defaultCharacterPath, width: 120, height: 120, fit: BoxFit.cover);
        },
      );
    }

    return Image.asset(_defaultCharacterPath, width: 120, height: 120, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(widget.isEditMode ? '프로필 수정' : '프로필 설정'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
                        child: ClipOval(child: _buildProfileImageWidget()),
                      ),
                      Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: const Icon(Icons.camera_alt, color: primaryColor, size: 20))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text('닉네임', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(controller: _nicknameController, decoration: InputDecoration(hintText: '닉네임 입력', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 24),
              const Text('성별', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(children: [_buildGenderRadio('남성'), _buildGenderRadio('여성')]),
              const SizedBox(height: 24),
              const Text('생년월일', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: _birthDate, firstDate: DateTime(1900), lastDate: DateTime.now());
                  if (date != null) setState(() => _birthDate = date);
                },
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), width: double.infinity, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)), child: Text("${_birthDate.year}-${_birthDate.month.toString().padLeft(2,'0')}-${_birthDate.day.toString().padLeft(2,'0')}", style: const TextStyle(fontSize: 16))),
              ),
              const SizedBox(height: 40),
              SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _updateProfile, style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('완료', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderRadio(String label) {
    return Row(children: [Radio<String>(value: label, groupValue: _gender, activeColor: primaryColor, onChanged: (val) {setState(() {_gender = val!;});}), Text(label), const SizedBox(width: 20)]);
  }
}