import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runtogether_team04/constants.dart';
import 'package:runtogether_team04/screens/group_detail_screen.dart';

class MyGroupListScreen extends StatefulWidget {
  final bool isManagementMode;

  const MyGroupListScreen({
    super.key,
    this.isManagementMode = false, // 기본값 false
  });

  @override
  State<MyGroupListScreen> createState() => _MyGroupListScreenState();
}

class _MyGroupListScreenState extends State<MyGroupListScreen> {
  List<dynamic> _myGroups = [];
  bool _isLoading = true;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchMyGroups();
  }

  // [API] 내 그룹 목록 조회
  Future<void> _fetchMyGroups() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final dio = Dio();
      final response = await dio.get(
        myGroupUrl,
        options: Options(headers: {
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            // 데이터 타입 안전하게 체크
            if (response.data is List) {
              _myGroups = response.data;
            } else if (response.data is Map && response.data['result'] is List) {
              _myGroups = response.data['result'];
            } else {
              _myGroups = [];
            }
          });
        }
      }
    } catch (e) {
      print("❌ 데이터 로드 에러: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "데이터를 불러올 수 없습니다.";
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // [API] 그룹 삭제 또는 나가기
  Future<void> _leaveGroup(int groupId, int index, bool isOwner) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final dio = Dio();

      Response response;

      // 1. 방장이면 -> 그룹 삭제 API
      if (isOwner) {
        print("👑 방장이므로 그룹을 삭제합니다. ID: $groupId");
        response = await dio.delete(
          '$baseUrl/api/v1/groups/$groupId',
          options: Options(headers: {
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          }),
        );
      }
      // 2. 일반 멤버면 -> 그룹 나가기 API
      else {
        print("🏃 멤버이므로 그룹에서 나갑니다. ID: $groupId");
        response = await dio.delete(
          '$baseUrl/api/v1/groups/$groupId/leave',
          options: Options(headers: {
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          }),
        );
      }

      if (response.statusCode == 200) {
        setState(() {
          _myGroups.removeAt(index);
        });
        if (mounted) {
          String msg = isOwner ? "대회가 삭제되었습니다." : "대회 참가가 취소되었습니다.";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      // ★ 에러 상세 출력 (서버가 보낸 메시지 확인용)
      if (e is DioException) {
        print("❌ 서버 응답 코드: ${e.response?.statusCode}");
        print("❌ 서버 응답 내용: ${e.response?.data}");

        String userMsg = "오류가 발생했습니다.";
        if (e.response?.data is Map && e.response?.data['message'] != null) {
          userMsg = e.response?.data['message'];
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMsg)));
        }
      } else {
        print("❌ 기타 에러: $e");
      }
    }
  }

  // [UI] 삭제 확인 다이얼로그
  void _showLeaveDialog(int groupId, int index, String groupName, bool isOwner) {
    String title = isOwner ? "대회 삭제 (방장)" : "대회 참가 취소";
    String content = isOwner
        ? "정말로 대회를 삭제하시겠습니까?\n모든 참가자의 기록이 영구적으로 삭제됩니다."
        : "'$groupName' 목록에서 삭제하시겠습니까?";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 선택에 따라 API 호출
              _leaveGroup(groupId, index, isOwner);
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isManager = widget.isManagementMode;
    final bool canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isManager ? '나의 대회 관리' : '내 대회 목록',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage))
          : _myGroups.isEmpty
          ? const Center(child: Text('참여 중인 대회가 없습니다.'))
          : ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _myGroups.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 16),
        itemBuilder: (ctx, i) {
          if (_myGroups[i] == null) return const SizedBox();
          return _buildMyGroupCard(_myGroups[i], i, isManager);
        },
      ),
    );
  }

  Widget _buildMyGroupCard(dynamic group, int index, bool isManager) {
    int finalId = 0;
    if (group['id'] != null) finalId = group['id'];
    else if (group['groupId'] != null) finalId = group['groupId'];
    else if (group['group_id'] != null) finalId = group['group_id'];

    String groupName = group['groupName'] ?? '제목 없음';
    String description = group['description'] ?? '설명이 없습니다.';
    int count = group['currentCount'] ?? 0;

    // ★ [수정됨] 키 값을 'owner' -> 'isOwner'로 변경 (DTO 필드명과 일치시킴)
    bool isOwner = group['isOwner'] == true;

    // (만약 서버가 여전히 'owner'로 보낸다면 group['owner']도 체크)
    if (group['isOwner'] == null && group['owner'] != null) {
      isOwner = group['owner'] == true;
    }

    print("🧐 그룹: ${group['groupName']} / 방장 여부: $isOwner"); // 디버깅용 로그

    List<String> tags = [];
    if (group['tags'] != null) {
      tags = group['tags'].toString().split(' ').where((t) => t.isNotEmpty).toList();
    }

    return GestureDetector(
      onTap: () {
        // 관리 모드가 아닐 때만 상세 화면으로 이동
        if (!isManager && finalId != 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailScreen(groupId: finalId, groupName: groupName),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    groupName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (isManager)
                // 1. 관리 모드 (삭제 버튼)
                  OutlinedButton(
                    onPressed: () => _showLeaveDialog(finalId, index, groupName, isOwner),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(60, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text("삭제", style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  )
                else
                // 2. 일반 모드 (입장 버튼)
                  ElevatedButton(
                    onPressed: () {
                      if (finalId != 0) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupDetailScreen(groupId: finalId, groupName: groupName),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      minimumSize: const Size(60, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text("입장", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (tags.isNotEmpty)
              Wrap(
                spacing: 8,
                children: tags.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                  child: Text(t, style: TextStyle(color: Colors.grey[700], fontSize: 11)),
                )).toList(),
              ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              "$count명 참여 중",
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}