import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'code_join_screen.dart';
import 'group_create_screen.dart';
import 'group_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allGroups = [];
  List<dynamic> _filteredGroups = [];

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // [API] 그룹 목록 조회
  Future<void> _fetchGroups() async {
    if (mounted) setState(() => _isLoading = true);

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

      final response = await dio.get(groupUrl, options: options);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            final data = response.data;
            if (data != null && data is List) {
              _allGroups = data.where((group) {
                bool isSecret = group['secret'] ?? false;
                if (group['secret'].toString().toLowerCase() == 'true') isSecret = true;
                return !isSecret;
              }).toList();
            } else {
              _allGroups = [];
            }
            _filteredGroups = List.from(_allGroups);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("❌ 대회 목록 로드 실패: $e");
      if (mounted) {
        setState(() {
          _allGroups = [];
          _filteredGroups = [];
          _isLoading = false;
        });
      }
    }
  }

  // [API] 그룹 참여
  Future<void> _joinGroup(int groupId, String groupName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final dio = Dio();
      final response = await dio.post(
        '$baseUrl/api/v1/groups/$groupId/join',
        options: Options(headers: {
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('참여 완료!')));
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GroupDetailScreen(groupId: groupId, groupName: groupName)),
          ).then((_) => _fetchGroups());
        }
      }
    } catch (e) {
      print("참여 실패: $e");
      if (mounted) {
        // ★ [수정됨] 스낵바 대신 팝업창 띄우기
        String message = "오류가 발생했습니다.";

        // 400 에러(Bad Request)면 보통 '이미 가입됨' 또는 '인원 초과'
        if (e is DioException) {
          if (e.response?.statusCode == 400) {
            message = "이미 참여 중인 대회입니다."; // 사용자가 원하는 문구로 고정
          } else if (e.response?.data is Map && e.response?.data['message'] != null) {
            message = e.response?.data['message']; // 서버 메시지 사용
          }
        }

        _showErrorDialog(message);
      }
    }
  }

  // [디자인 통일] 에러/알림 팝업 (아이콘 위! 제목 아래!)
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),

        // 1. 아이콘 (주황색 배경)
        icon: Container(
          margin: const EdgeInsets.only(top: 10),
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.info_outline_rounded, size: 40, color: Colors.orangeAccent),
        ),

        // 2. 제목
        title: const Text(
          "알림",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),

        // 3. 내용
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),

        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text("확인", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // [디자인 통일] 참여 확인 팝업 (아이콘 위! 제목 아래!)
  void _showJoinDialog(int groupId, String groupName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

        // 1. 아이콘 (달리기 아이콘)
        icon: Container(
          margin: const EdgeInsets.only(top: 10),
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.directions_run_rounded, size: 40, color: primaryColor),
        ),

        // 2. 제목
        title: const Text(
          "대회 참여",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),

        // 3. 내용
        content: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(text: "'$groupName'", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              const TextSpan(text: " 대회에\n참여하시겠습니까?", style: TextStyle(color: Colors.black87, fontSize: 16, height: 1.4)),
            ],
          ),
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
              // 참여하기 버튼
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _joinGroup(groupId, groupName);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("참여", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _runFilter(String keyword) {
    List<dynamic> results = [];
    if (keyword.isEmpty) {
      results = _allGroups;
    } else {
      results = _allGroups
          .where((group) => (group['groupName'] ?? '').toString().toLowerCase().contains(keyword.toLowerCase()))
          .toList();
    }
    setState(() => _filteredGroups = results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            color: primaryColor,
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: _runFilter,
                      decoration: InputDecoration(
                        hintText: '찾고 싶은 대회를 검색하세요',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          _buildTabButton(0, '오픈 대회 목록'),
                          _buildTabButton(1, '새 대회 생성 및 코드 참여'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _currentTabIndex == 0 ? _buildGroupList() : _buildSelectionView(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String text) {
    bool isSelected = _currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTabIndex = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          alignment: Alignment.center,
          child: Text(text, style: TextStyle(color: isSelected ? primaryColor : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildGroupList() {
    return RefreshIndicator(
      onRefresh: _fetchGroups,
      color: primaryColor,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _filteredGroups.isEmpty
          ? const Center(child: Text('검색 결과가 없거나 생성된 대회가 없습니다.'))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredGroups.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 16),
        itemBuilder: (ctx, i) {
          return _buildGroupCard(_filteredGroups[i]);
        },
      ),
    );
  }

  Widget _buildGroupCard(dynamic group) {
    int groupId = group['id'] ?? 0;
    String groupName = group['groupName'] ?? '제목 없음';
    bool isJoined = group['isJoined'] ?? false;

    // 인원수 파싱
    int currentCount = 0;
    if (group['currentPeople'] != null) {
      currentCount = int.tryParse(group['currentPeople'].toString()) ?? 0;
    }

    int maxPeople = 0;
    if (group['maxPeople'] != null) {
      maxPeople = int.tryParse(group['maxPeople'].toString()) ?? 0;
    }

    return GestureDetector(
      onTap: () {
        // 이미 참여한 경우에만 상세 화면으로 이동
        if (isJoined) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => GroupDetailScreen(groupId: groupId, groupName: groupName)
              )
          );
        }
        // 참여하지 않은 경우 아무 동작 안 함 (메시지 삭제됨)
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                  child: const Text("모집중", style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                ),
                GestureDetector(
                  onTap: () {
                    if (isJoined) {
                      // 이미 참여했으면 여기도 팝업으로 안내
                      _showErrorDialog("이미 참여 중인 대회입니다.");
                    } else {
                      _showJoinDialog(groupId, groupName);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: isJoined ? Colors.grey : primaryColor, borderRadius: BorderRadius.circular(20)),
                    child: Text(isJoined ? '참여 완료' : '대회 참여', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(group['tags'] ?? '', style: const TextStyle(color: primaryColor, fontSize: 12)),
            const SizedBox(height: 8),
            Text(group['description'] ?? '설명 없음', style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "$currentCount명 참여 중 ($currentCount/${maxPeople > 0 ? maxPeople : '-'})",
                style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text('RUN TOGETHER', style: TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('무엇을 하시겠습니까?', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 40),
          _buildSelectionCard(
            title: '참가자입니다',
            subtitle: '대회에 참가할 초대 코드를\n가지고 있습니다.',
            icon: Icons.confirmation_number_outlined,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CodeJoinScreen())),
          ),
          const SizedBox(height: 20),
          _buildSelectionCard(
            title: '대회 주최자입니다',
            subtitle: '대회를 위한 가상 챌린지를\n설정하고 싶습니다.',
            icon: Icons.add_circle_outline,
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const GroupCreateScreen()));
              await _fetchGroups();
              if (mounted) setState(() => _currentTabIndex = 0);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange[50], shape: BoxShape.circle), child: Icon(icon, color: primaryColor, size: 30)),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13))])),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}