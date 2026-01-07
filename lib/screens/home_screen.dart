import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'code_join_screen.dart';
import 'group_create_screen.dart';
import 'group_selection_screen.dart';




class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // [상태 변수] 0: 오픈 그룹 목록, 1: 새 그룹 생성/참여
  int _currentTabIndex = 0;

  List<dynamic> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  // [API] 그룹 목록 조회
  Future<void> _fetchGroups() async {
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
            _groups = response.data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("❌ 그룹 목록 가져오기 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ============================================================
          // [1] 상단 헤더 (탭 버튼 포함)
          // ============================================================
          Container(
            color: primaryColor,
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: Column(
                  children: [
                    // --- 검색창 ---
                    TextField(
                      decoration: InputDecoration(
                        hintText: '찾고 싶은 대회을 검색하세요',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- [탭 스위치] ---
                    Container(
                      height: 45,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2), // 전체 배경 반투명
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          // 탭 1: 오픈 그룹 목록
                          _buildTabButton(0, '오픈 대회 목록'),

                          // 탭 2: 새 그룹 생성 및 코드 참여
                          _buildTabButton(1, '새 대회 생성 및 코드 참여'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ============================================================
          // [2] 본문 (탭 상태에 따라 내용이 바뀜!)
          // ============================================================
          Expanded(
            child: _currentTabIndex == 0
                ? _buildGroupList()       // 0번이면 리스트 보여주기
                : _buildSelectionView(),  // 1번이면 선택 카드 보여주기
          ),
        ],
      ),
    );
  }

  // [위젯] 탭 버튼 (디자인 로직 분리)
  Widget _buildTabButton(int index, String text) {
    // 현재 선택된 탭인지 확인
    bool isSelected = _currentTabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTabIndex = index; // 탭 변경 -> 화면 갱신
          });
        },
        child: Container(
          decoration: BoxDecoration(
            // 선택되면 흰색, 아니면 투명
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              // 선택되면 오렌지색 글씨, 아니면 연한 흰색 글씨
              color: isSelected ? primaryColor : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13, // 글씨가 길어서 약간 조정
            ),
          ),
        ),
      ),
    );
  }

  // [화면 1] 그룹 리스트 뷰
  Widget _buildGroupList() {
    return RefreshIndicator(
      onRefresh: _fetchGroups,
      color: primaryColor,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _groups.isEmpty
          ? const Center(child: Text('생성된 그룹이 없습니다.'))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _groups.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 16),
        itemBuilder: (ctx, i) {
          final group = _groups[i];
          return _buildGroupCard(group);
        },
      ),
    );
  }

  // [화면 2] 선택 뷰 (참가자 vs 주최자)
  Widget _buildSelectionView() {
    return SingleChildScrollView( // 화면 작을 때 스크롤 가능하게
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'RUN TOGETHER',
            style: TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            '무엇을 하시겠습니까?',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 40),

          // 1. 참가자 버튼
          _buildSelectionCard(
            title: '참가자입니다',
            subtitle: '대회에 참가할 초대 코드를\n가지고 있습니다.',
            icon: Icons.confirmation_number_outlined,
            onTap: () {
              // 코드 입력 화면으로 이동
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CodeJoinScreen()));
            },
          ),

          const SizedBox(height: 20),

          // 2. 주최자 버튼
          _buildSelectionCard(
            title: '대회 주최자입니다',
            subtitle: '대회를 위한 가상 챌린지를\n설정하고 싶습니다.',
            icon: Icons.add_circle_outline,
            onTap: () async {
              // 그룹 생성 화면으로 이동 -> 생성하고 돌아오면 리스트 탭으로 자동 이동시키기
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const GroupCreateScreen()));

              // 돌아왔을 때 목록 새로고침하고 첫 번째 탭으로 이동
              _fetchGroups();
              setState(() {
                _currentTabIndex = 0;
              });
            },
          ),
        ],
      ),
    );
  }

  // 리스트 아이템 카드 디자인
  Widget _buildGroupCard(dynamic group) {
    return Container(
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
                child: Text(
                    group['groupName'] ?? '제목 없음',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(20)),
                child: const Text('대회 참여', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(group['tags'] ?? '', style: const TextStyle(color: primaryColor, fontSize: 12)),
          const SizedBox(height: 8),
          Text(group['description'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                  "${group['currentCount'] ?? 0}명 참여 중 (${group['currentCount'] ?? 0}/${group['maxPeople']})",
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 선택 카드 위젯 (참가자/주최자)
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
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryColor, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}