import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // ★ 날짜 포맷을 위해 추가
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
  Map<String, dynamic>? _courseDetail;
  String _myNickname = "러너";

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchGroupDetail();
    _fetchUserInfo();
  }

  // [API] 내 정보(닉네임) 조회
  Future<void> _fetchUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      if (token == null) return;

      final dio = Dio();
      // 1. /users/info 시도
      try {
        final response = await dio.get(
          '$baseUrl/api/v1/users/info',
          options: Options(headers: {'Authorization': 'Bearer $token', 'ngrok-skip-browser-warning': 'true'}),
        );
        if (response.statusCode == 200) {
          setState(() {
            _myNickname = response.data['nickname'] ?? "러너";
          });
          return;
        }
      } catch (_) {}

      // 2. 실패시 /users/me 시도
      try {
        final response = await dio.get(
          '$baseUrl/api/v1/users/me',
          options: Options(headers: {'Authorization': 'Bearer $token', 'ngrok-skip-browser-warning': 'true'}),
        );
        if (response.statusCode == 200) {
          setState(() {
            _myNickname = response.data['nickname'] ?? "러너";
          });
        }
      } catch (_) {}

    } catch (e) {
      // 닉네임 로드 실패 시 조용히 넘김 (기본값 '러너' 유지)
    }
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

      final url = '$baseUrl/api/v1/groups/${widget.groupId}';
      print("🚀 상세 정보 요청: $url");
      final response = await dio.get(url, options: options);

      if (response.statusCode == 200) {
        if (mounted) {
          final data = response.data;
          // data가 Map 형태가 아니라면 data['data'] 확인
          final realData = (data is Map && data.containsKey('data')) ? data['data'] : data;

          setState(() {
            _groupDetail = realData;
          });

          print("📥 그룹 데이터 수신: $realData");

          // ★ 코스 ID 찾기 (여러 변수명 대응)
          var cId = realData['courseId'] ?? realData['course_id'];
          if (cId != null) {
            int courseId = int.parse(cId.toString());
            _fetchCourseDetail(courseId); // 코스 정보 가져오기
          } else {
            setState(() => _isLoading = false);
          }
        }
      }
    } catch (e) {
      print("❌ 상세 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // [API] 코스 상세 조회
  Future<void> _fetchCourseDetail(int courseId) async {
    if (courseId == 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final dio = Dio();
      final response = await dio.get(
        '$baseUrl/api/v1/courses/$courseId',
        options: Options(headers: {'Authorization': 'Bearer $token', 'ngrok-skip-browser-warning': 'true'}),
      );
      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        final realData = (data is Map && data.containsKey('data')) ? data['data'] : data;

        setState(() {
          _courseDetail = realData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("코스 상세 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // D-Day 계산 함수
  String _calculateDDay(String? startDateStr) {
    if (startDateStr == null || startDateStr.isEmpty) return "준비중";
    try {
      DateTime start = DateTime.parse(startDateStr);
      DateTime now = DateTime.now();
      // 시간 제거하고 날짜만 비교
      DateTime dateStart = DateTime(start.year, start.month, start.day);
      DateTime dateNow = DateTime(now.year, now.month, now.day);

      int diff = dateStart.difference(dateNow).inDays;

      if (diff == 0) return "D-Day";
      if (diff > 0) return "D-$diff";
      return "D+${diff.abs()}";
    } catch (e) {
      return "준비중";
    }
  }

  @override
  Widget build(BuildContext context) {
    int courseId = 0;
    if (_groupDetail != null) {
      var cId = _groupDetail!['courseId'] ?? _groupDetail!['course_id'];
      if (cId != null) courseId = int.tryParse(cId.toString()) ?? 0;
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
          _buildMainTab(),
          const MyRecordScreen(isEmbedded: true),
          RankingTab(courseId: courseId),
        ],
      ),
    );
  }

  Widget _buildMainTab() {
    if (_groupDetail == null && _courseDetail == null) return const Center(child: Text("정보를 불러오지 못했습니다."));

    // 1. 코스 이름 결정
    String courseName = "코스 미정";
    if (_courseDetail != null) {
      courseName = _courseDetail!['title'] ?? _courseDetail!['courseName'] ?? "코스 미정";
    } else if (_groupDetail != null) {
      courseName = _groupDetail!['courseName'] ?? "코스 미정";
    }

    // 2. 날짜 정보 결정
    String startDate = "날짜 미정";
    String endDate = "";

    // ★ [수정됨] 그룹(_groupDetail)에 날짜가 있으면 그걸 먼저 씁니다!
    if (_groupDetail != null && _groupDetail!['startDate'] != null) {
      startDate = _groupDetail!['startDate'];
      endDate = _groupDetail!['endDate'] ?? "";
    }
    // 그룹에 날짜가 없으면 그때 코스 정보를 봅니다.
    else if (_courseDetail != null) {
      startDate = _courseDetail!['startDate'] ?? "날짜 미정";
      endDate = _courseDetail!['endDate'] ?? "";
    }

    // 3. D-Day 직접 계산
    String dDayStr = _calculateDDay(startDate == "날짜 미정" ? null : startDate);

    // 설명
    String description = "";
    if (_groupDetail != null) description = _groupDetail!['description'] ?? "";

    // 방장 확인 & 코드 확인
    bool isOwner = false;
    String? accessCode;
    if (_groupDetail != null) {
      isOwner = _groupDetail!['owner'] == true;
      accessCode = _groupDetail!['accessCode'] ?? _groupDetail!['inviteCode'];
    }
    // 코드가 있고 비어있지 않아야 비밀방 로직 수행
    bool isHostAndSecret = (isOwner && accessCode != null && accessCode.toString().isNotEmpty);

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
                          // 코스 이름
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(text: "코스  ", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                TextSpan(text: courseName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          // 기간
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(text: "기간  ", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                TextSpan(text: "$startDate ~ $endDate", style: const TextStyle(color: Colors.black, fontSize: 13)),
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
                    Text(dDayStr, style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
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
                            // ★ [수정됨] accessCode 뒤에 ?? "" 추가하여 에러 해결!
                            Clipboard.setData(ClipboardData(text: accessCode ?? ""));
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

          // 2. 캐릭터 영역 (닉네임 표시)
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

                // 닉네임
                Text(_myNickname, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                const SizedBox(width: 80),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // 이미지 표시
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

          const SizedBox(height: 40),

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
                        if (_groupDetail != null) {
                          var cId = _groupDetail!['courseId'] ?? _groupDetail!['course_id'];
                          if (cId != null) courseId = int.tryParse(cId.toString()) ?? 0;
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

  Widget _buildSafeImage() {
    if (_groupDetail == null) return _buildFallbackIcon();
    String? imageUrl = _groupDetail!['imageUrl'];
    if (imageUrl == null || imageUrl.isEmpty || imageUrl.contains("default.png")) {
      return _buildFallbackIcon();
    }
    return Image.network(
      imageUrl,
      width: 220,
      height: 220,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return _buildFallbackIcon();
      },
    );
  }

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