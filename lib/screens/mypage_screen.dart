import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart'; // baseUrl, primaryColor 포함
import 'package:runtogether_team04/screens/profile_setup_screen.dart';
import 'package:runtogether_team04/screens/login_screen.dart';
import 'package:runtogether_team04/screens/my_group_list_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _isLoading = true; // 로딩 상태

  // [1] 서버에서 받아올 데이터 변수들
  String _nickname = "";
  String _userCode = "";
  String _profileImage = "";

  // 최근 대회/러닝 기록
  String _competitionTitle = "최근 기록이 없습니다.";
  String _courseName = "-";
  String _period = "-";
  String _totalDistance = "0";
  String _totalTime = "00:00:00";
  int _totalCalories = 0;

  @override
  void initState() {
    super.initState();
    _fetchMyPageData(); // 화면 켜지자마자 데이터 요청
  }

  // [2] API 요청 함수 (마이페이지 정보 로드)
  Future<void> _fetchMyPageData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token == null) {
        setState(() => _isLoading = false);
        return;
      }

      final dio = Dio();
      final options = Options(headers: {
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
        'Content-Type': 'application/json',
      });

      print("🚀 마이페이지 데이터 요청: $baseUrl/api/v1/auth/mypage");
      final response = await dio.get('$baseUrl/api/v1/auth/mypage', options: options);

      if (response.statusCode == 200) {
        final data = response.data;
        if (mounted) {
          setState(() {
            _nickname = data['nickname'] ?? "이름 없음";
            _userCode = data['userCode'] ?? "-";
            _profileImage = data['profileImage'] ?? "";

            _competitionTitle = data['competitionTitle'] ?? "참여한 대회가 없습니다.";
            _courseName = data['courseName'] ?? "-";
            _period = data['period'] ?? "-";
            _totalDistance = data['totalDistance'] ?? "0";
            _totalTime = data['totalTime'] ?? "00:00:00";
            _totalCalories = data['totalCalories'] ?? 0;
          });
        }
      }
    } catch (e) {
      print("❌ 마이페이지 로드 실패: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ★★★ [3] 회원탈퇴 로직 추가 ★★★
  Future<void> _deleteAccount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token == null) return;

      final dio = Dio();
      // 백엔드 API 주소로 DELETE 요청
      final response = await dio.delete(
        '$baseUrl/api/v1/auth/withdraw',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        }),
      );

      // 성공 시 (200 OK)
      if (response.statusCode == 200) {
        // 1. 앱 내부 저장소 비우기 (토큰 삭제)
        await prefs.clear();

        if (!mounted) return;

        // 2. 로그인 화면으로 이동 (뒤로가기 방지)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("회원 탈퇴가 완료되었습니다. 이용해 주셔서 감사합니다.")),
        );
      }
    } catch (e) {
      print("❌ 탈퇴 실패: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("오류가 발생했습니다. 다시 시도해 주세요.")),
      );
    }
  }

  // ★★★ [4] 탈퇴 확인 팝업 (아이콘 위! 제목 아래!) ★★★
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

        // 1. 아이콘 (맨 위) - 빨간색 배경
        icon: Container(
          margin: const EdgeInsets.only(top: 10),
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1), // 연한 빨강 배경
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_amber_rounded, size: 40, color: Colors.redAccent),
        ),

        // 2. 제목 (아이콘 아래)
        title: const Text(
          "회원탈퇴",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),

        // 3. 내용 (맨 아래)
        content: Text(
          "정말로 탈퇴하시겠습니까?\n모든 러닝 기록과 대회 참가 내역이\n영구적으로 삭제됩니다.",
          style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
          textAlign: TextAlign.center,
        ),

        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        actions: [
          Row(
            children: [
              // 취소 버튼
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("취소", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              // 탈퇴하기 버튼 (빨간색)
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteAccount();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("탈퇴", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ★★★ [5] 로그아웃 확인 팝업 (아이콘 위! 제목 아래!) ★★★
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

        // 1. 아이콘 (맨 위) - 주황색 배경
        icon: Container(
          margin: const EdgeInsets.only(top: 10),
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1), // 연한 주황 배경
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.logout_rounded, size: 40, color: primaryColor),
        ),

        // 2. 제목 (아이콘 아래)
        title: const Text(
          "로그아웃",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),

        // 3. 내용 (맨 아래)
        content: const Text(
          "정말 로그아웃 하시겠습니까?",
          style: TextStyle(fontSize: 15),
          textAlign: TextAlign.center,
        ),

        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        actions: [
          Row(
            children: [
              // 취소 버튼
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("취소", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              // 로그아웃 버튼 (주황색)
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("로그아웃", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("마이페이지", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. 프로필 영역
            _buildProfileSection(),

            // 2. 최근 대회 섹션
            _buildRecentRaceSection(),

            const SizedBox(height: 20),

            // 3. 메뉴 리스트
            _buildMenuItem("프로필 수정"),
            _buildDivider(),
            _buildMenuItem("나의 대회 관리"),
            _buildDivider(),
            _buildMenuItem("러닝 기록"),
            _buildDivider(),
            _buildMenuItem("배지"),
            _buildDivider(),
            _buildMenuItem("랭킹"),
            _buildDivider(),
            _buildMenuItem("환경 설정"),
            _buildDivider(),

            const SizedBox(height: 40),

            // ★★★ [여기 추가] 회원탈퇴 버튼 ★★★
            TextButton(
              onPressed: _showDeleteDialog,
              child: const Text(
                "회원탈퇴",
                style: TextStyle(
                  color: Colors.grey, // 연한 회색
                  fontSize: 13,
                  decoration: TextDecoration.underline, // 밑줄
                ),
              ),
            ),

            const SizedBox(height: 50), // 바닥 여백
          ],
        ),
      ),
    );
  }

  // [위젯 1] 프로필 영역 (로그아웃 버튼 포함)
  Widget _buildProfileSection() {
    // 1. 주소 및 슬래시 중복 해결
    String cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    String cleanPath = _profileImage.startsWith('/') ? _profileImage : '/$_profileImage';
    String finalImageUrl = "$cleanBase$cleanPath";

    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!),
              image: DecorationImage(
                image: _profileImage.isNotEmpty
                    ? NetworkImage(
                  finalImageUrl,
                  // ★ ngrok 경고창을 통과하기 위한 헤더 추가
                  headers: {'ngrok-skip-browser-warning': 'true'},
                )
                    : const AssetImage('assets/images/character.png') as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 닉네임 및 유저코드
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nickname,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text("유저 ID  ", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Text(
                      _userCode,
                      style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 로그아웃 버튼
          OutlinedButton(
            onPressed: _showLogoutDialog,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 32),
            ),
            child: const Text("로그아웃", style: TextStyle(color: Colors.grey, fontSize: 12)),
          )
        ],
      ),
    );
  }

  // [위젯] 최근 대회 정보 카드
  Widget _buildRecentRaceSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("최근 대회", style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _competitionTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(_courseName, style: const TextStyle(color: primaryColor, fontSize: 13)),
                Text(_period, style: const TextStyle(color: Colors.grey, fontSize: 12)),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRecordItem("$_totalDistance km"),
                    _buildRecordItem(_totalTime),
                    _buildRecordItem("$_totalCalories kcal"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(String text) {
    return Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF7F50))
    );
  }

  // 메뉴 리스트 아이템
  Widget _buildMenuItem(String title) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: () async {
        if (title == "프로필 수정") {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileSetupScreen(isEditMode: true),
            ),
          );
          _fetchMyPageData();
        }
        else if (title == "나의 대회 관리") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyGroupListScreen(isManagementMode: true),
            ),
          );
        }
        else {
          print("$title 클릭됨 - 나중에 기능 연결 필요");
        }
      },
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 0.5, color: Colors.grey, indent: 24, endIndent: 24);
  }
}