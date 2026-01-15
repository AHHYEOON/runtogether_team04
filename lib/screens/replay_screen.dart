import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// 이전에 보내주신 API 주소 상수 파일이 있다고 가정하고 import 합니다.
// 만약 없다면 아래 변수를 직접 쓰시면 됩니다.
// import 'api_constants.dart';

class ReplayScreen extends StatefulWidget {
  final String groupId; // 예: "1"

  const ReplayScreen({super.key, required this.groupId});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  // --- 상태 변수 ---
  // 모델 클래스 대신 List<dynamic>을 사용합니다.
  List<dynamic> runners = [];
  bool isLoading = true;

  // 재생 관련
  bool isPlaying = false;
  double currentTime = 0.0; // 현재 재생 시간 (초 단위)
  double maxDuration = 100.0; // 전체 길이
  double playbackSpeed = 1.0; // 배속
  Timer? _timer;

  late GoogleMapController _mapController;

  // API 주소 (api_constants.dart 파일 내용을 여기 잠깐 적어둡니다)
  final String baseUrl = 'https://byssal-nondyspeptically-roseann.ngrok-free.dev';

  @override
  void initState() {
    super.initState();
    _fetchReplayData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- 1. API 데이터 가져오기 (Raw JSON 방식) ---
  Future<void> _fetchReplayData() async {
    setState(() => isLoading = true);

    // ★ 실제 연동 시 주석 해제하여 사용하세요 ★
    /*
    try {
      final url = Uri.parse("$baseUrl/api/record/replay/${widget.groupId}");
      final response = await http.get(url, headers: {
        // "Authorization": "Bearer $token", // 필요시 토큰 추가
      });

      if (response.statusCode == 200) {
        // 모델 변환 없이 바로 리스트로 저장
        List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        _initializeData(jsonList);
      }
    } catch (e) {
      print("Error: $e");
    }
    */

    // --- 테스트용 더미 데이터 (백엔드 명세와 동일) ---
    await Future.delayed(const Duration(milliseconds: 500));
    var dummyData = [
      {
        "runRecordId": 101,
        "nickname": "열정열정",
        "isMe": true,
        "path": [
          {"lat": 37.5234, "lng": 126.9231, "time": 0},
          {"lat": 37.5240, "lng": 126.9235, "time": 5},
          {"lat": 37.5250, "lng": 126.9240, "time": 10}
        ]
      },
      {
        "runRecordId": 102,
        "nickname": "마라톤초보",
        "isMe": false,
        "path": [
          {"lat": 37.5234, "lng": 126.9231, "time": 0},
          {"lat": 37.5238, "lng": 126.9233, "time": 5},
          {"lat": 37.5245, "lng": 126.9238, "time": 12}
        ]
      }
    ];

    _initializeData(dummyData);
  }

  void _initializeData(List<dynamic> data) {
    if (data.isEmpty) return;

    double maxTime = 0;
    // 모델이 없으므로 Map['key'] 방식으로 접근
    for (var runner in data) {
      List<dynamic> path = runner['path'];
      if (path.isNotEmpty) {
        int lastTime = path.last['time']; // 마지막 시간
        if (lastTime > maxTime) maxTime = lastTime.toDouble();
      }
    }

    setState(() {
      runners = data;
      maxDuration = maxTime;
      isLoading = false;
    });
  }

  // --- 2. 위치 계산 로직 (Map 데이터 사용) ---
  LatLng _calculatePosition(Map<String, dynamic> runner, double time) {
    List<dynamic> path = runner['path'];
    if (path.isEmpty) return const LatLng(0, 0);

    // 1. 아직 출발 전이면 시작점 반환
    if (time <= path.first['time']) {
      return LatLng(
          (path.first['lat'] as num).toDouble(),
          (path.first['lng'] as num).toDouble()
      );
    }
    // 2. 완주 했으면 도착점 반환
    if (time >= path.last['time']) {
      return LatLng(
          (path.last['lat'] as num).toDouble(),
          (path.last['lng'] as num).toDouble()
      );
    }

    // 3. 현재 시간(time)이 포함된 구간 찾기
    int index = path.indexWhere((p) => p['time'] > time);
    if (index == -1) {
      return LatLng(
          (path.last['lat'] as num).toDouble(),
          (path.last['lng'] as num).toDouble()
      );
    }

    var prev = path[index - 1];
    var next = path[index];

    // 시간차에 따른 비율(progress) 계산
    double prevTime = (prev['time'] as num).toDouble();
    double nextTime = (next['time'] as num).toDouble();
    double progress = (time - prevTime) / (nextTime - prevTime);

    // 위도, 경도 보간 (Interpolation)
    double prevLat = (prev['lat'] as num).toDouble();
    double nextLat = (next['lat'] as num).toDouble();
    double prevLng = (prev['lng'] as num).toDouble();
    double nextLng = (next['lng'] as num).toDouble();

    double lat = prevLat + (nextLat - prevLat) * progress;
    double lng = prevLng + (nextLng - prevLng) * progress;

    return LatLng(lat, lng);
  }

  // --- 3. 재생 타이머 ---
  void _togglePlay() {
    if (isPlaying) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        setState(() {
          currentTime += 0.05 * playbackSpeed;
          if (currentTime >= maxDuration) {
            currentTime = maxDuration;
            isPlaying = false;
            timer.cancel();
          }
        });
      });
    }
    setState(() {
      isPlaying = !isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 화면에 그릴 마커들
    Set<Marker> markers = {};
    LatLng? myPosition;

    // runners 리스트(Map)를 순회하며 마커 생성
    for (var runner in runners) {
      // Map<String, dynamic>으로 형변환하여 사용
      Map<String, dynamic> r = runner as Map<String, dynamic>;

      LatLng pos = _calculatePosition(r, currentTime);
      bool isMe = r['isMe'] == true;

      if (isMe) myPosition = pos;

      markers.add(Marker(
        markerId: MarkerId(r['runRecordId'].toString()),
        position: pos,
        zIndex: isMe ? 2 : 1, // 나를 더 위에
        icon: BitmapDescriptor.defaultMarkerWithHue(
            isMe ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueAzure
        ),
        infoWindow: InfoWindow(title: r['nickname']),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Replay"),
        backgroundColor: const Color(0xFFFF7E36), // 오렌지색 직접 지정
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReplayData,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: myPosition ?? const LatLng(37.5234, 126.9231),
                zoom: 17,
              ),
              markers: markers,
              onMapCreated: (controller) => _mapController = controller,
              // cameraTargetBounds: CameraTargetBounds.unbounded,
            ),
          ),
          // 하단 컨트롤 패널
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${currentTime.toStringAsFixed(1)}s / ${maxDuration.toInt()}s",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    // 배속 버튼
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (playbackSpeed == 1.0) playbackSpeed = 2.0;
                          else if (playbackSpeed == 2.0) playbackSpeed = 4.0;
                          else playbackSpeed = 1.0;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "x${playbackSpeed.toInt()}",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF7E36)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Slider(
                  value: currentTime,
                  min: 0,
                  max: maxDuration,
                  activeColor: const Color(0xFFFF7E36),
                  inactiveColor: Colors.orange.withOpacity(0.3),
                  onChanged: (val) {
                    setState(() {
                      currentTime = val;
                    });
                  },
                ),
                IconButton(
                  iconSize: 50,
                  color: const Color(0xFFFF7E36),
                  icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  onPressed: _togglePlay,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}