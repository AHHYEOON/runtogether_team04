import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runtogether_team04/constants.dart';
import 'package:runtogether_team04/screens/running_screen.dart';
import 'package:runtogether_team04/screens/my_record_screen.dart';
import 'package:runtogether_team04/screens/ranking_tab.dart';
class GroupDetailScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _groupDetail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchGroupDetail();
  }

  // [API] 그룹 상세 정보 조회
  Future<void> _fetchGroupDetail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final dio = Dio();

      final options = Options(headers: {
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (widget.groupId == 0) {
        setState(() => _isLoading = false);
        return;
      }

      // /main 대신 기본 상세 조회 사용
      final url = '$baseUrl/api/v1/groups/${widget.groupId}';
      final response = await dio.get(url, options: options);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _groupDetail = response.data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("❌ 상세 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    // 2. [추가] 랭킹 탭에 넘겨줄 courseId 추출
    // _groupDetail이 아직 로드 안 됐거나 null이면 0으로 처리 (에러 방지)
    int courseId = 0;
    if (_groupDetail != null && _groupDetail!['courseId'] != null) {
      courseId = _groupDetail!['courseId'];
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.groupName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings, color: Colors.white))
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: "메인"),
            Tab(text: "내 기록"),
            Tab(text: "랭킹"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : TabBarView(
        controller: _tabController,
        children: [
          _buildMainTab(), // 1번 탭 (기존 작성 완료)

          // 2번 탭: [수정] 이제 준비중 텍스트 대신 진짜 화면을 넣습니다!
          // isEmbedded: true를 줘서 헤더를 숨깁니다.
          const MyRecordScreen(isEmbedded: true),
          // 3. [수정] 랭킹 화면 연결!
          RankingTab(courseId: courseId),
        ],
      ),
    );
  }

  Widget _buildMainTab() {
    if (_groupDetail == null) return const Center(child: Text("정보를 불러오지 못했습니다."));

    final courseName = _groupDetail!['courseName'] ?? '코스 미정';
    final startDate = _groupDetail!['startDate'] ?? '날짜 미정';
    final endDate = _groupDetail!['endDate'] ?? '';
    final dDay = _groupDetail!['dDay'] ?? 0;

    final description = _groupDetail!['description'] ?? '';
    String dDayStr = dDay == 0 ? "D-Day" : (dDay > 0 ? "D-$dDay" : "D+${dDay.abs()}");

    return Column(
      children: [
        // 1. 코스 정보 카드
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 10)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(text: "코스  ", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          TextSpan(text: "$courseName", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(text: "기간  ", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          TextSpan(text: "$startDate $endDate", style: const TextStyle(color: Colors.black, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]
                  ],
                ),
              ),
              Text(courseName == '코스 미정' ? '준비중' : dDayStr, style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),

        // 2. 캐릭터 영역
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("열쩡열쩡", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220, height: 220,
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                  ),
                  const Icon(Icons.directions_run_rounded, size: 120, color: primaryColor),
                ],
              ),

              const SizedBox(height: 10),
              const Text("준비되셨나요?", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statItem("0 km", primaryColor),
                    _statItem("00:00", Colors.grey),
                    _statItem("0 kcal", primaryColor),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. START 버튼 (화면 이동 연결!)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      // [수정] 서버 데이터에서 courseId 찾기
                      // 만약 서버가 안 주면 0으로 처리 (에러 방지)
                      int courseId = 0;
                      if (_groupDetail != null && _groupDetail!['courseId'] != null) {
                        courseId = _groupDetail!['courseId'];
                      }

                      print("👉 START! 코스 ID: $courseId, 그룹 ID: ${widget.groupId}");

                      // 러닝 화면으로 이동
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RunningScreen(
                            groupId: widget.groupId,
                            courseId: courseId, // ★ 여기에 넘겨줍니다!
                          ),
                        ),
                      );
                    },
                    // ... 스타일 그대로 ...
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: const Text("start", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: Colors.orange[100], shape: BoxShape.circle),
                child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.chat_bubble_outline, color: primaryColor)
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _statItem(String text, Color color) {
    return Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16));
  }
}