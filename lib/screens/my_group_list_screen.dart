import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runtogether_team04/constants.dart';
import 'package:runtogether_team04/screens/group_detail_screen.dart'; // 상세 화면 임포트

class MyGroupListScreen extends StatefulWidget {
  const MyGroupListScreen({super.key});

  @override
  State<MyGroupListScreen> createState() => _MyGroupListScreenState();
}

class _MyGroupListScreenState extends State<MyGroupListScreen> {
  List<dynamic> _myGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyGroups();
  }

  // [API] 내 그룹 목록 조회
  Future<void> _fetchMyGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final dio = Dio();

      final options = Options(headers: {
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      print("🚀 내 그룹 조회 요청: $myGroupUrl");
      final response = await dio.get(myGroupUrl, options: options);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _myGroups = response.data;
            _isLoading = false;
          });
          print("📦 내 그룹 데이터 수신 완료: ${_myGroups.length}개");
        }
      }
    } catch (e) {
      print("❌ 내 그룹 목록 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 지금 뒤로 갈 수 있는 상황인지 확인 (마이페이지에서 왔으면 true, 탭이면 false)
    bool canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '내 대회 목록',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),

        // ★ [핵심] 뒤로 갈 수 있을 때만 버튼 보여주기!
        automaticallyImplyLeading: false, // 기본 자동 생성 끄고 우리가 직접 제어
        leading: canPop
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        )
            : null, // 뒤로 갈 곳 없으면(탭) 아무것도 안 보여줌
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _myGroups.isEmpty
          ? const Center(child: Text('참여 중인 대회가 없습니다.'))
          : ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _myGroups.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 16),
        itemBuilder: (ctx, i) {
          final group = _myGroups[i];
          return _buildMyGroupCard(group);
        },
      ),
    );
  }

  Widget _buildMyGroupCard(dynamic group) {
    // 태그 파싱
    List<String> tags = [];
    if (group['tags'] != null) {
      tags = group['tags'].toString().split(' ').where((t) => t.isNotEmpty).toList();
    }

    return GestureDetector(
      onTap: () {
        // ---------------------------------------------------------
        // [ID 찾기 로직] 서버가 주는 키값이 뭔지 몰라서 다 뒤져봅니다.
        // ---------------------------------------------------------
        print("👉 클릭한 데이터: $group");

        int finalId = 0;
        if (group['id'] != null) finalId = group['id'];
        else if (group['groupId'] != null) finalId = group['groupId'];
        else if (group['group_id'] != null) finalId = group['group_id'];

        print("👉 추출한 ID: $finalId");

        if (finalId == 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류: 그룹 ID를 찾을 수 없습니다.')));
          return;
        }

        // 상세 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupDetailScreen(
              groupId: finalId,
              groupName: group['groupName'] ?? '이름 없음',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(
                        group['groupName'] ?? '제목 없음',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        overflow: TextOverflow.ellipsis
                    )
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(20)),
                  child: const Text("대회 예선", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (tags.isNotEmpty)
              Wrap(
                spacing: 8,
                children: tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                  child: Text(tag, style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.bold)),
                )).toList(),
              ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey[200], thickness: 1),
            const SizedBox(height: 12),
            Text(
                group['description'] ?? '설명이 없습니다.',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis
            ),
            const SizedBox(height: 12),
            Text(
                "${group['currentCount'] ?? 0}명 참여 중",
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)
            ),
          ],
        ),
      ),
    );
  }
}