import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runtogether_team04/constants.dart';
import 'package:runtogether_team04/screens/running_screen.dart';
import 'package:runtogether_team04/screens/my_record_screen.dart';
import 'package:runtogether_team04/screens/ranking_tab.dart';
import 'package:runtogether_team04/screens/replay_screen.dart';

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

      final url = '$baseUrl/api/v1/groups/${widget.groupId}';
      print("🚀 상세 정보 요청: $url");

      final response = await dio.get(url, options: options);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _groupDetail = response.data;
            _isLoading = false;
          });
          print("📥 [디버깅] 서버 응답 데이터: $_groupDetail");
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
          _buildMainTab(), // 메인 탭 (스크롤 수정됨)
          const MyRecordScreen(isEmbedded: true),
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

    // 방장 확인 & 코드 확인
    bool isOwner = _groupDetail!['owner'] == true;
    String? accessCode = _groupDetail!['accessCode'] ?? _groupDetail!['inviteCode'];
    bool isHostAndSecret = (isOwner && accessCode != null && accessCode.toString().isNotEmpty);

    // ★ [수정됨] SingleChildScrollView로 감싸서 오버플로우(노란 줄무늬 에러) 방지
    return SingleChildScrollView(
      child: Column(
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
            child: Column(
              children: [
                Row(
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

                // 방장에게만 보이는 초대 코드
                if (isHostAndSecret) ...[
                  const SizedBox(height: 15),
                  const Divider(),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.key, size: 16, color: primaryColor),
                            const SizedBox(width: 8),
                            const Text("입장 코드: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(accessCode!, style: const TextStyle(color: Colors.black, fontSize: 13)),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: accessCode));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("코드가 복사되었습니다!")));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
                            child: const Text("복사", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    ),
                  )
                ]
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. 캐릭터 영역 (Expanded 제거하고 일반 Column 사용)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3E50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    elevation: 0,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.play_circle_outline, size: 16),
                  label: const Text("Replay", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ReplayScreen(groupId: widget.groupId.toString())));
                  },
                ),
                const Text("열쩡열쩡", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 80),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // ★ [수정됨] 이미지 에러 방지 (Safe Image)
          _buildSafeImage(),

          const SizedBox(height: 20),
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

          const SizedBox(height: 40), // 하단 여백 추가

          // 3. START 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        int courseId = 0;
                        if (_groupDetail != null && _groupDetail!['courseId'] != null) {
                          courseId = _groupDetail!['courseId'];
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RunningScreen(
                              groupId: widget.groupId,
                              courseId: courseId,
                            ),
                          ),
                        );
                      },
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
      ),
    );
  }

  // ★ [추가됨] 이미지가 'default.png'거나 에러가 날 경우 아이콘으로 대체
  Widget _buildSafeImage() {
    // 1. 이미지가 없거나 문자열이 이상하면 바로 아이콘 보여주기
    String? imageUrl = _groupDetail!['imageUrl'];
    if (imageUrl == null || imageUrl.isEmpty || imageUrl.contains("default.png")) {
      return _buildFallbackIcon();
    }

    // 2. 실제 URL이면 네트워크 이미지 로드 (에러 시 아이콘으로 대체)
    return Image.network(
      imageUrl,
      width: 220,
      height: 220,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return _buildFallbackIcon(); // 에러 나면 아이콘 리턴
      },
    );
  }

  // 기본 아이콘 위젯
  Widget _buildFallbackIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 220, height: 220,
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
        ),
        const Icon(Icons.directions_run_rounded, size: 120, color: primaryColor),
      ],
    );
  }

  Widget _statItem(String text, Color color) {
    return Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16));
  }
}