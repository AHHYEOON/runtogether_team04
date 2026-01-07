import 'dart:convert'; // jsonDecode를 위해 필요
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class MyRecordScreen extends StatefulWidget {
  final int? recordId; // 특정 기록 ID (없으면 최신 기록 조회)

  const MyRecordScreen({super.key, this.recordId, required bool isEmbedded});

  @override
  State<MyRecordScreen> createState() => _MyRecordScreenState();
}

class _MyRecordScreenState extends State<MyRecordScreen> {
  bool _isLoading = true;

  // [기본값 설정] 서버에서 데이터를 받기 전 보여줄 초기 상태
  Map<String, dynamic> _recordData = {
    "groupName": "기록 불러오는 중...",
    "date": "-",
    "startTime": "-",
    "runTime": "00:00",
    "distance": 0.0,
    "avgPace": "-'--''",
    "calories": 0,
    "heartRate": 0,
    "sectionJson": [], // 빈 리스트
    "myRank": 0,
    "totalRunners": 0,
    "groupAvgPace": "-'--''",
    "paceDifference": "-",
    "analysisResult": "데이터를 분석 중입니다...",
    "badges": [],
  };

  @override
  void initState() {
    super.initState();
    _fetchRecord();
  }

  // ------------------------------------------------------------------------
  // [API] 서버 통신 함수
  // ------------------------------------------------------------------------
  Future<void> _fetchRecord() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      // ID가 있으면 해당 기록, 없으면 최신 기록 (API 주소는 상황에 맞게 조정)
      final endpoint = widget.recordId != null
          ? '$baseUrl/api/v1/records/${widget.recordId}'
          : '$baseUrl/api/v1/records/latest'; // 혹은 records?sort=desc 등

      print("🚀 기록 요청: $endpoint");

      final dio = Dio();
      final response = await dio.get(
        endpoint,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true'
        }),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        // ★ [핵심] sectionJson이 문자열(String)로 오면 -> 리스트(List)로 변환
        dynamic sections = data['sectionJson'];
        if (sections is String) {
          try {
            sections = jsonDecode(sections);
          } catch (e) {
            sections = [];
            print("⚠️ JSON 파싱 에러: $e");
          }
        }

        // 데이터 덮어쓰기
        setState(() {
          _recordData = data;
          _recordData['sectionJson'] = sections ?? []; // 변환된 리스트 저장
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ 기록 불러오기 실패: $e");
      // 실패해도 로딩은 끔 (기본값 표시)
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------------------------------------
  // [Helper] "6:41" 같은 문자열을 6.68 (Double)로 변환 (그래프용)
  // ------------------------------------------------------------------------
  double _parsePaceToDouble(String? paceStr) {
    if (paceStr == null || !paceStr.contains(":")) return 0.0;
    try {
      final parts = paceStr.split(":"); // ["6", "41"]
      double min = double.parse(parts[0]);
      double sec = double.parse(parts[1]);
      return min + (sec / 60); // 6분 + 0.68분 = 6.68
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI 편의를 위해 변수 추출
    final sections = _recordData['sectionJson'] as List<dynamic>;
    final badges = _recordData['badges'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_recordData['groupName'] ?? "내 기록", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. 러닝 요약
            _buildSummaryCard(),
            const SizedBox(height: 16),

            // 2. 구간별 기록 (데이터 있을 때만 표시)
            if (sections.isNotEmpty) ...[
              _buildLapTableCard(sections),
              const SizedBox(height: 16),
              _buildPaceGraphCard(sections),
              const SizedBox(height: 16),
            ],

            // 3. 그룹 비교
            _buildComparisonCard(),
            const SizedBox(height: 16),

            // 4. 분석 결과
            _buildAnalysisCard(),
            const SizedBox(height: 16),

            // 5. 배지
            _buildBadgeCard(badges),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // [1] 러닝 요약 카드
  Widget _buildSummaryCard() {
    return _buildCardLayout(
      title: "러닝 요약",
      headerAction: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF2C3E50), borderRadius: BorderRadius.circular(20)),
        child: const Row(
          children: [
            Icon(Icons.play_circle_outline, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text("Replay", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      child: Column(
        children: [
          Text(_recordData['runTime'] ?? "00:00", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black87)),
          const Text("총 소요 시간", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(_recordData['date'] ?? "-", "날짜"),
              _buildSummaryItem(_recordData['startTime'] ?? "-", "시작 시간"),
              _buildSummaryItem("${_recordData['distance']} km", "총 거리"),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(_recordData['avgPace'] ?? "-", "평균 페이스"),
              _buildSummaryItem("${_recordData['heartRate']} bpm", "평균 심박수"),
              _buildSummaryItem("${_recordData['calories']} kcal", "칼로리"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  // [2] 구간별 기록 테이블
  Widget _buildLapTableCard(List<dynamic> sections) {
    return _buildCardLayout(
      title: "구간별 기록",
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1.5)},
        children: [
          const TableRow(children: [
            Padding(padding: EdgeInsets.only(bottom: 8), child: Text("구간 (km)", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center)),
            Padding(padding: EdgeInsets.only(bottom: 8), child: Text("페이스", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center)),
          ]),
          ...sections.map((sec) {
            return TableRow(children: [
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text("${sec['km']}km", textAlign: TextAlign.center)),
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(sec['pace'] ?? "-", textAlign: TextAlign.center)),
            ]);
          }),
        ],
      ),
    );
  }

  // [3] 페이스 그래프
  Widget _buildPaceGraphCard(List<dynamic> sections) {
    // 데이터 변환: "6:41" -> 6.68 (Double)
    List<FlSpot> spots = [];
    double minY = 100.0;
    double maxY = 0.0;

    for (var sec in sections) {
      double x = double.tryParse(sec['km'].toString()) ?? 0;
      double y = _parsePaceToDouble(sec['pace']);
      if (y > 0) {
        spots.add(FlSpot(x, y));
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }

    // 그래프 상하 여백
    minY = (minY - 1).clamp(0, 100);
    maxY = maxY + 1;

    return _buildCardLayout(
      title: "페이스 그래프",
      child: Column(
        children: [
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text("${v.toInt()}분", style: const TextStyle(fontSize: 10)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text("${v.toInt()}km", style: const TextStyle(fontSize: 10)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.lightGreen,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                ],
                minY: minY,
                maxY: maxY,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [4] 비교 카드
  Widget _buildComparisonCard() {
    return _buildCardLayout(
      title: "그룹 비교 기록",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text("오늘 내 순위: ${_recordData['myRank']}위 / ${_recordData['totalRunners']}명", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const SizedBox(height: 20),
          _buildBarChartRow("참가자 평균", 0.6, Colors.grey[300]!, _recordData['groupAvgPace'] ?? "-"),
          const SizedBox(height: 10),
          _buildBarChartRow("내 페이스", 0.8, primaryColor, _recordData['avgPace'] ?? "-"),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text("→ ${_recordData['paceDifference'] ?? '-'}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartRow(String label, double ratio, Color color, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(flex: 4, child: Container(height: 30, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  // [5] 분석 카드
  Widget _buildAnalysisCard() {
    return _buildCardLayout(
      title: "러닝 분석 요약",
      child: Text(_recordData['analysisResult'] ?? "분석 데이터 없음", style: TextStyle(color: Colors.grey[700], height: 1.5)),
    );
  }

  // [6] 배지 카드
  Widget _buildBadgeCard(List<dynamic> badges) {
    return _buildCardLayout(
      title: "획득한 배지",
      child: badges.isEmpty
          ? const Text("획득한 배지가 없습니다.", style: TextStyle(color: Colors.grey))
          : Column(
        children: badges.map((badgeName) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(30)),
            child: Row(
              children: [
                const Icon(Icons.verified, color: Colors.orangeAccent),
                const SizedBox(width: 12),
                Text(badgeName.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 공통 카드 레이아웃
  Widget _buildCardLayout({required String title, required Widget child, Widget? headerAction}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(20)), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))), if (headerAction != null) headerAction]),
        const SizedBox(height: 20),
        child,
      ]),
    );
  }
}