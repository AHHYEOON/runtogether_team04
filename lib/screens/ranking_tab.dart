import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runtogether_team04/constants.dart';

// 랭킹 유저 모델
class RankingUser {
  final int rank;
  final String nickname;
  final String? profileImage;
  final String recordValue;
  final bool isMe;

  RankingUser({
    required this.rank,
    required this.nickname,
    this.profileImage,
    required this.recordValue,
    required this.isMe,
  });

  factory RankingUser.fromJson(Map<String, dynamic> json) {
    return RankingUser(
      rank: json['rank'] ?? 0,
      nickname: json['nickname'] ?? '알 수 없음',
      profileImage: json['profileImage'],
      recordValue: json['recordValue'] ?? '-',
      isMe: json['isMe'] ?? false,
    );
  }
}

class RankingTab extends StatefulWidget {
  final int courseId;

  const RankingTab({super.key, required this.courseId});

  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  // 스크롤 가능한 화면에 두 개의 카드(시간순, 구간순) 배치
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20, bottom: 50),
      child: Column(
        children: [
          // 1. 전체 시간순 랭킹 카드
          RankingCard(
            courseId: widget.courseId,
            title: "시간순",
            type: "TOTAL",
            cardIcon: Icons.timer_outlined,
          ),

          const SizedBox(height: 20),

          // 2. 구간별 랭킹 카드 (기본 1km)
          RankingCard(
            courseId: widget.courseId,
            title: "구간순",
            type: "SECTION",
            isSection: true, // 구간 선택 드롭다운 활성화
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 개별 랭킹 카드 위젯 (시간순 / 구간순 공용)
// ---------------------------------------------------------
class RankingCard extends StatefulWidget {
  final int courseId;
  final String title;
  final String type; // TOTAL or SECTION
  final bool isSection;
  final IconData? cardIcon;

  const RankingCard({
    super.key,
    required this.courseId,
    required this.title,
    required this.type,
    this.isSection = false,
    this.cardIcon,
  });

  @override
  State<RankingCard> createState() => _RankingCardState();
}

class _RankingCardState extends State<RankingCard> {
  List<RankingUser> _users = [];
  bool _isLoading = true;
  Timer? _timer; // 실시간 업데이트용 타이머

  // 구간 선택용 변수
  int _selectedKm = 1;
  final int _maxKm = 10; // (임시) 최대 구간. 실제론 코스 정보 받아와야 함.

  @override
  void initState() {
    super.initState();
    _fetchData(); // 최초 로딩

    // [실시간] 10초마다 데이터 갱신 (누군가 달리면 바뀜)
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchData(isRefresh: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 화면 나가면 타이머 종료
    super.dispose();
  }

  Future<void> _fetchData({bool isRefresh = false}) async {
    if (!isRefresh) setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final email = prefs.getString('email') ?? '';
      final dio = Dio();

      final options = Options(headers: {
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
      });

      // URL 생성
      String query = "?email=$email&type=${widget.type}";
      if (widget.isSection) {
        query += "&km=$_selectedKm";
      }

      // API 호출: /api/v1/courses/{id}/rankings
      final url = '$rankingBaseUrl/${widget.courseId}/rankings$query';

      // print("🚀 랭킹 요청: $url"); // 디버깅용

      final response = await dio.get(url, options: options);

      if (response.statusCode == 200 && mounted) {
        List<dynamic> list = response.data;
        setState(() {
          _users = list.map((e) => RankingUser.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      // 에러가 나거나 데이터가 없어도 빈 리스트로 처리 (틀은 보여주기 위해)
      print("❌ 랭킹 로드 오류 (데이터 없음 등): $e");
      if (mounted) {
        setState(() {
          _users = []; // 빈 리스트 유지
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 상위 3명 (데이터 없으면 null)
    RankingUser? rank1 = _users.length >= 1 ? _users[0] : null;
    RankingUser? rank2 = _users.length >= 2 ? _users[1] : null;
    RankingUser? rank3 = _users.length >= 3 ? _users[2] : null;

    // 4등부터 나머지
    List<RankingUser> rest = _users.length > 3 ? _users.sublist(3) : [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // 그림자 효과
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 헤더 (타이틀 + 옵션)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 뱃지 스타일 타이틀
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),

              // 구간 선택 드롭다운 (구간순일 때만 표시)
              if (widget.isSection)
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedKm,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      style: const TextStyle(fontSize: 13, color: Colors.black),
                      items: List.generate(_maxKm, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text("${index + 1}km"),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedKm = val);
                          _fetchData(); // 변경 시 재요청
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 30),

          // 2. 로딩 상태 or 데이터 표시
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator(color: primaryColor)),
            )
          else
            Column(
              children: [
                // 3. 포디움 (1, 2, 3등) - 데이터 없어도 틀은 보임
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end, // 아래쪽 라인 맞춤
                  children: [
                    _buildPodiumUser(rank2, 2), // 2등 (왼쪽)
                    _buildPodiumUser(rank1, 1), // 1등 (중앙, 큼)
                    _buildPodiumUser(rank3, 3), // 3등 (오른쪽)
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),

                // 4. 나머지 리스트 (4등~)
                if (rest.isEmpty && rank1 != null) // 데이터는 있는데 4등은 없는 경우
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("다음 순위 도전!", style: TextStyle(color: Colors.grey)),
                  )
                else if (rank1 == null) // 데이터가 아예 없는 경우
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("아직 기록이 없습니다.\n첫 번째 주인공이 되어보세요!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  )
                else
                // 리스트 출력
                  ListView.builder(
                    shrinkWrap: true, // ScrollView 안이므로 필수
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rest.length,
                    itemBuilder: (context, index) {
                      return _buildListRow(rest[index]);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // 포디움 개별 유저 (데이터가 null이면 빈 원 표시)
  Widget _buildPodiumUser(RankingUser? user, int rank) {
    // 1등은 좀 더 크게
    final double size = rank == 1 ? 90 : 70;

    // 순위 뱃지 색상
    Color badgeColor;
    if (rank == 1) badgeColor = const Color(0xFFFF7E36); // 1등 (오렌지)
    else if (rank == 2) badgeColor = Colors.grey; // 2등
    else badgeColor = const Color(0xFFCD7F32); // 3등 (브론즈)

    return Column(
      children: [
        Stack(
          children: [
            // 프로필 원 (데이터 없으면 회색)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200], // 기본 배경
                border: user?.isMe == true ? Border.all(color: primaryColor, width: 2) : null,
                image: (user?.profileImage != null)
                    ? DecorationImage(
                  image: NetworkImage(user!.profileImage!),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              // 이미지가 없거나 데이터가 없으면 아이콘 표시
              child: (user?.profileImage == null)
                  ? Icon(Icons.person, color: Colors.white, size: size * 0.5)
                  : null,
            ),

            // 순위 뱃지 (우상단)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  "$rank",
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 닉네임 (데이터 없으면 'xxx')
        Text(
          user?.nickname ?? 'xxx',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),

        // 기록 (데이터 없으면 안보임)
        if (user != null)
          Text(
            user!.recordValue,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }

  // 4등 이하 리스트 아이템
  Widget _buildListRow(RankingUser user) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: user.isMe ? primaryColor.withOpacity(0.05) : Colors.transparent, // 나는 배경 살짝 강조
      child: Row(
        children: [
          // 순위 (이탤릭체 느낌)
          SizedBox(
            width: 30,
            child: Text(
              "${user.rank}",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontStyle: FontStyle.italic
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),

          // 프로필 이미지
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[200],
            backgroundImage: user.profileImage != null ? NetworkImage(user.profileImage!) : null,
            child: user.profileImage == null
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 12),

          // 닉네임
          Expanded(
            child: Text(
              user.nickname,
              style: TextStyle(
                fontSize: 16,
                fontWeight: user.isMe ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),

          // 기록
          Text(
            user.recordValue,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}