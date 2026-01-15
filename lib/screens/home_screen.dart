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
  int _currentTabIndex = 0; // 0: 오픈 그룹 목록, 1: 새 그룹 생성/참여
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

  // [API] 그룹 목록 조회 (키값 'secret'으로 수정됨)
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

              // ★ [수정됨] 키값을 'secret'으로 변경하여 필터링
              _allGroups = data.where((group) {
                // 1. 'secret' 키값 확인 (없으면 false/공개로 간주)
                bool isSecret = group['secret'] ?? false;

                // 2. 혹시 문자열 'true'로 올 경우 대비
                if (group['secret'].toString().toLowerCase() == 'true') {
                  isSecret = true;
                }

                // 3. 비공개(true)면 리스트에서 제외 (false 반환)
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
      print("❌ 그룹 목록 로드 실패: $e");
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
      final options = Options(
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final url = '$baseUrl/api/v1/groups/$groupId/join';
      final response = await dio.post(url, options: options);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('대회 참여가 완료되었습니다!')));

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailScreen(groupId: groupId, groupName: groupName),
            ),
          ).then((_) {
            _fetchGroups(); // 돌아오면 목록 갱신
          });
        }
      }
    } catch (e) {
      print("참여 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('참여 실패: 이미 참여 중이거나 오류가 발생했습니다.')));
      }
    }
  }

  // [다이얼로그] 참여 확인
  void _showJoinDialog(int groupId, String groupName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("대회 참여"),
        content: Text("'$groupName' 대회에 참여하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _joinGroup(groupId, groupName);
            },
            child: const Text("참여하기", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // [로직] 검색 필터링
  void _runFilter(String keyword) {
    List<dynamic> results = [];
    if (keyword.isEmpty) {
      results = _allGroups;
    } else {
      results = _allGroups
          .where((group) =>
          (group['groupName'] ?? '').toString().toLowerCase().contains(keyword.toLowerCase()))
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
          // 상단 헤더
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
                      width: double.infinity,
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

          // 본문
          Expanded(
            child: _currentTabIndex == 0
                ? _buildGroupList()
                : _buildSelectionView(),
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
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? primaryColor : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
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
          final group = _filteredGroups[i];
          return _buildGroupCard(group);
        },
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

  Widget _buildGroupCard(dynamic group) {
    int groupId = group['id'] ?? 0;
    String groupName = group['groupName'] ?? '제목 없음';
    bool isJoined = group['isJoined'] ?? false;

    return GestureDetector(
      onTap: () {
        if (isJoined) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailScreen(groupId: groupId, groupName: groupName),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("아직 참여 신청되지 않은 대회입니다. 참여 신청 후 참여해주세요."),
              duration: Duration(seconds: 2),
            ),
          );
        }
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
                  child: Text(
                      groupName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (isJoined) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("이미 참여한 대회입니다.")));
                    } else {
                      _showJoinDialog(groupId, groupName);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: isJoined ? Colors.grey : primaryColor,
                        borderRadius: BorderRadius.circular(20)
                    ),
                    child: Text(
                        isJoined ? '참여 완료' : '대회 참여',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(group['tags'] ?? '', style: const TextStyle(color: primaryColor, fontSize: 12)),
            const SizedBox(height: 8),
            Text(group['description'] ?? '설명 없음', style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                    "${group['currentCount'] ?? 0}명 참여 중 (${group['currentCount'] ?? 0}/${group['maxPeople'] ?? '-'})",
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ],
        ),
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
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange[50], shape: BoxShape.circle),
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