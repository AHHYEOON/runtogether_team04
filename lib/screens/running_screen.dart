import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runtogether_team04/constants.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:health/health.dart';

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class RunningScreen extends StatefulWidget {
  final int groupId;
  final int courseId;

  const RunningScreen({
    super.key,
    required this.groupId,
    required this.courseId,
  });

  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen> {
  // 구글맵 컨트롤러
  final Completer<GoogleMapController> _controller = Completer();

  // 위치 데이터
  Position? _currentPosition;
  final List<LatLng> _myRouteCoords = []; // 내가 뛴 경로 (저장용)

  // 지도 요소
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  // 러닝 데이터
  final StopWatchTimer _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countUp);
  double _totalDistance = 0.0;
  double _calories = 0.0;
  String _pace = "0'00''";
  int _heartRate = 0;
  final Health _health = Health();

  // 상태 관리
  bool _isAiCoachOn = false;
  bool _isNaviOn = false;
  bool _isSaving = false;

  // 러닝 시작 상태 관리 & 코스 시작점 저장
  bool _isRunStarted = false;
  LatLng? _courseStartPoint;

  // 백그라운드 데이터 리스너 구독 변수 (종료 시 해제용)
  StreamSubscription? _serviceSubscription;

  @override
  void initState() {
    super.initState();

    _checkPermission();         // 위치 권한 및 초기 위치 로드
    _health.configure();
    _fetchCoursePath();         // 코스 경로 로딩
    _startBackgroundService();  // 백그라운드 서비스 시작

    _fetchHealthData();         // 심박수 데이터 수집 시작
  }

  @override
  void dispose() {
    _stopWatchTimer.dispose();
    _serviceSubscription?.cancel(); // 화면 꺼질 때 리스너 해제
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // 위치 권한 요청 및 초기 위치 즉시 확보
  // ------------------------------------------------------------------------
  Future<void> _checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      print("위치 권한이 영구적으로 거부되었습니다.");
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        // 내 위치로 카메라 이동
        final c = await _controller.future;
        c.animateCamera(CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude), 16
        ));
      }
    } catch (e) {
      print("초기 위치 로드 실패: $e");
    }
  }

  // ------------------------------------------------------------------------
  // [디자인 수정] 시작 위치 경고 팝업 (MyPage 스타일)
  // ------------------------------------------------------------------------
  void _tryStartRun() {
    // 1. 데이터 로딩 확인
    if (_currentPosition == null || _courseStartPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("위치 정보를 불러오는 중입니다. 잠시만 기다려주세요.")),
      );
      return;
    }

    // 2. 거리 계산
    double dist = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _courseStartPoint!.latitude,
      _courseStartPoint!.longitude,
    );

    // 3. 반경 100m 이내 확인
    if (dist <= 100) {
      _startRealRun(); // 통과
    } else {
      // ❌ 시작 위치 아님 -> 예쁜 디자인 팝업 호출
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                // 1. 아이콘 (연한 빨간 배경)
                Container(
                  width: 70, height: 70,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.warning_rounded, color: Color(0xFFFF5B5B), size: 32),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. 제목
                const Text("시작 위치가 아닙니다", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // 3. 내용
                Text(
                  "코스 시작점과 거리가 너무 멉니다.\n(현재 거리: ${dist.toInt()}m)\n\n시작 위치로 이동해주세요.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF757575), height: 1.5),
                ),
                const SizedBox(height: 30),

                // 4. 버튼 (코랄색 꽉 찬 버튼)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5B5B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("확인", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // ------------------------------------------------------------------------
  // [디자인 추가] 러닝 종료 확인 팝업 (MyPage 스타일)
  // ------------------------------------------------------------------------
  void _showStopDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        elevation: 0,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              // 1. 아이콘 (연한 주황 배경)
              Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.check_circle_outline_rounded, color: primaryColor, size: 32),
                ),
              ),
              const SizedBox(height: 20),

              // 2. 제목
              const Text("러닝 종료", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // 3. 내용
              const Text(
                "러닝을 종료하고\n기록을 저장하시겠습니까?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Color(0xFF757575), height: 1.5),
              ),
              const SizedBox(height: 30),

              // 4. 버튼 2개 (계속 뛰기 / 종료 및 저장)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _stopWatchTimer.onStartTimer(); // 취소하면 다시 타이머 시작
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5F5F5), // 회색 배경
                          foregroundColor: const Color(0xFF757575), // 회색 글씨
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("계속 뛰기", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _saveRecord(); // 저장 로직 실행
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor, // 주황 배경
                          foregroundColor: Colors.white, // 흰색 글씨
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("종료", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startRealRun() {
    setState(() {
      _isRunStarted = true;
    });
    _stopWatchTimer.onStartTimer();
  }

  // ------------------------------------------------------------------------
  // 코스 경로 데이터 가져오기
  // ------------------------------------------------------------------------
  Future<void> _fetchCoursePath() async {
    if (widget.courseId == 0) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final dio = Dio();
      final options = Options(headers: {
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      final url = '$baseUrl/api/v1/courses/${widget.courseId}';
      final response = await dio.get(url, options: options);

      if (response.statusCode == 200) {
        final data = response.data;
        dynamic rawPathData = data['pathData'];
        List<dynamic> pathList = [];

        if (rawPathData is String) {
          try { pathList = jsonDecode(rawPathData); } catch (e) { print(e); }
        } else if (rawPathData is List) {
          pathList = rawPathData;
        }

        if (pathList.isNotEmpty) {
          List<LatLng> coursePoints = [];
          for (var p in pathList) {
            double lat = _toDouble(p['lat'] ?? p['latitude']);
            double lng = _toDouble(p['lng'] ?? p['longitude']);
            if (lat != 0.0 && lng != 0.0) coursePoints.add(LatLng(lat, lng));
          }

          if (mounted && coursePoints.isNotEmpty) {
            _courseStartPoint = coursePoints.first;

            setState(() {
              _polylines.add(Polyline(
                polylineId: const PolylineId("course_guide"),
                points: coursePoints,
                color: Colors.grey.withOpacity(0.5),
                width: 8,
                zIndex: 1,
              ));
              _markers.add(Marker(
                  markerId: const MarkerId("start"),
                  position: coursePoints.first,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
              ));
              _markers.add(Marker(
                  markerId: const MarkerId("end"),
                  position: coursePoints.last,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
              ));
            });

            Future.delayed(const Duration(milliseconds: 500), () async {
              try {
                final c = await _controller.future;
                c.animateCamera(CameraUpdate.newLatLngZoom(coursePoints.first, 16));
              } catch (_) {}
            });
          }
        }
      }
    } catch (e) {
      print("❌ 코스 로드 실패: $e");
    }
  }

  // ------------------------------------------------------------------------
  // 백그라운드 서비스
  // ------------------------------------------------------------------------
  Future<void> _startBackgroundService() async {
    final service = FlutterBackgroundService();
    print("🛠️ 백그라운드 서비스 상태 확인 중...");

    bool isRunning = await service.isRunning();
    if (!isRunning) {
      print("🚀 서비스 시작 시도 중...");
      await service.startService();
    }

    // ★ 이전 구독이 남아있을 수 있으니 취소 후 재설정
    await _serviceSubscription?.cancel();

    // 📡 서비스로부터 'update' 이벤트를 실시간으로 듣는 리스너
    _serviceSubscription = service.on('update').listen((event) {
      if (event != null && mounted) {
        // [디버깅 로그] 이 로그가 찍히는지 꼭 보세요!
        print("📡 서비스 수신 데이터: lat=${event['lat']}, lng=${event['lng']}, speed=${event['speed']}");

        double lat = event['lat'] ?? 0.0;
        double lng = event['lng'] ?? 0.0;
        double speed = (event['speed'] ?? 0.0).toDouble();

        // UI 업데이트 함수 호출
        _updatePosition(lat, lng, speed);
      } else {
        print("⚠️ 수신된 위치 이벤트 데이터가 null입니다.");
      }
    }, onError: (e) {
      print("❌ 서비스 구독 중 에러 발생: $e");
    });
  }

  void _updatePosition(double lat, double lng, double speed) async {
    // [로그 추가] 이 로그가 Debug Console에 찍히는지 꼭 확인해야 합니다!
    print("📍 [위치수신] 위도: $lat, 경도: $lng, 속도: $speed");

    LatLng newPos = LatLng(lat, lng);

    if (_currentPosition != null) {
      double distInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        lat, lng,
      );

      // 시뮬레이터 테스트를 위해 조건을 0보다 크면 다 받도록 수정
      if (distInMeters > 0) {
        setState(() {
          _totalDistance += (distInMeters / 1000);
          _calories = _totalDistance * 60;
          if (speed > 0) {
            double ps = 1000 / speed;
            _pace = "${(ps / 60).floor()}'${(ps % 60).floor().toString().padLeft(2, '0')}''";
          }
        });
        print("🏃 거리 증가! 현재 총 거리: ${_totalDistance.toStringAsFixed(3)} km");
      }
    }

    // 내가 뛴 경로 선 그리기용 리스트에 추가
    _myRouteCoords.add(newPos);

    setState(() {
      _currentPosition = Position(
          latitude: lat, longitude: lng, timestamp: DateTime.now(),
          accuracy: 0, altitude: 0, heading: 0, speed: speed, speedAccuracy: 0,
          altitudeAccuracy: 0, headingAccuracy: 0
      );

      // 지도 위 내 경로 선 업데이트
      _polylines.removeWhere((p) => p.polylineId.value == "my_route");
      _polylines.add(
        Polyline(
          polylineId: const PolylineId("my_route"),
          points: _myRouteCoords,
          color: primaryColor,
          width: 6,
          zIndex: 2,
        ),
      );
    });

    // ★ [중요] 카메라가 내 위치를 따라가게 함
    try {
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLng(newPos));
    } catch (e) {
      print("❌ 카메라 이동 에러: $e");
    }
  }

  // ------------------------------------------------------------------------
  // 기록 저장
  // ------------------------------------------------------------------------
  Future<void> _saveRecord() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final dio = Dio();
      final options = Options(headers: {'ngrok-skip-browser-warning': 'true', 'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});

      List<Map<String, double>> routeJson = _myRouteCoords.map((e) => {"lat": e.latitude, "lng": e.longitude}).toList();

      final data = {
        "courseId": widget.courseId,
        "runTime": StopWatchTimer.getDisplayTime(_stopWatchTimer.rawTime.value, hours: true, milliSecond: false),
        "distance": double.parse(_totalDistance.toStringAsFixed(2)),
        "averagePace": _pace,
        "heartRate": 0,
        "calories": _calories.toInt(),
        "sectionJson": "[]",
        "routeData": jsonEncode(routeJson),
        "status": "COMPLETE"
      };

      final response = await dio.post('$baseUrl/api/v1/records', data: data, options: options);

      if (response.statusCode == 200 || response.statusCode == 201) {
        FlutterBackgroundService().invoke("stopService");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("기록 저장 완료!")));
        Navigator.pop(context);
      }
    } catch (e) {
      print("저장 실패: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("저장 실패")));
        setState(() => _isSaving = false);
      }
    }
  }

  // ------------------------------------------------------------------------
  // 헬스 데이터 가져오기
  // ------------------------------------------------------------------------
  Future<void> _fetchHealthData() async {
    var types = [HealthDataType.HEART_RATE];
    List<HealthDataAccess> permissions = types.map((e) => HealthDataAccess.READ).toList();

    bool requested = await _health.requestAuthorization(types, permissions: permissions);

    if (requested) {
      // print("✅ 건강 데이터 권한 허용됨");
      Timer.periodic(const Duration(seconds: 5), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        DateTime now = DateTime.now();
        DateTime startTime = DateTime(now.year, now.month, now.day);

        try {
          List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
            startTime: startTime,
            endTime: now,
            types: types,
          );

          healthData.sort((a, b) => a.dateTo.compareTo(b.dateTo));

          if (healthData.isNotEmpty) {
            var lastData = healthData.last;
            var value = lastData.value;
            if (value is NumericHealthValue) {
              setState(() {
                _heartRate = value.numericValue.toInt();
              });
            }
          }
        } catch (e) {
          print("❌ 헬스 데이터 에러: $e");
        }
      });
    }
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 구글 맵
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: const CameraPosition(target: LatLng(37.5665, 126.9780), zoom: 15),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            polylines: _polylines,
            markers: _markers,
            onMapCreated: (controller) => _controller.complete(controller),
          ),

          // 2. 상단 토글 버튼
          Positioned(
            top: 50, left: 16, right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildToggleChip("네비게이션", _isNaviOn, (val) => setState(() => _isNaviOn = val)),
                _buildToggleChip("AI 코치", _isAiCoachOn, (val) => setState(() => _isAiCoachOn = val)),
              ],
            ),
          ),

          // 3. 하단 정보창
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${_totalDistance.toStringAsFixed(2)} km", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, fontFamily: "Monospace")),

                  StreamBuilder<int>(
                    stream: _stopWatchTimer.rawTime, initialData: 0,
                    builder: (context, snap) {
                      return Text(StopWatchTimer.getDisplayTime(snap.data!, hours: true, milliSecond: false), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500));
                    },
                  ),

                  const SizedBox(height: 15),

                  // Replay 버튼 + 닉네임 영역
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C3E50),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            elevation: 0,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.play_circle_outline, size: 16),
                          label: const Text("Replay", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            print("Replay 버튼 눌림");
                          },
                        ),
                        const Text("열쩡열쩡", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 80),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildStatItem("페이스", _pace), _buildStatItem("칼로리", "${_calories.toInt()} kcal"), _buildStatItem("심박수", "$_heartRate bpm")]),

                  const SizedBox(height: 30),

                  // START / STOP 버튼 (수정됨: 팝업 로직 연결)
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                        if (!_isRunStarted) {
                          _tryStartRun(); // 시작 시도 (빨간 팝업)
                        } else {
                          // 종료 시도 (주황 팝업)
                          _stopWatchTimer.onStopTimer(); // 우선 일시정지
                          _showStopDialog();             // 예쁜 종료 팝업 호출
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _isRunStarted ? primaryColor : Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                          _isRunStarted ? "STOP" : "START",
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String l, String v) => Column(children: [Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(l, style: const TextStyle(color: Colors.grey, fontSize: 12))]);
  Widget _buildToggleChip(String l, bool isOn, Function(bool) c) => GestureDetector(onTap: () => c(!isOn), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: isOn ? primaryColor : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)]), child: Row(children: [Icon(Icons.directions_run, size: 16, color: isOn ? Colors.white : Colors.black), const SizedBox(width: 8), Text(l, style: TextStyle(color: isOn ? Colors.white : Colors.black, fontWeight: FontWeight.bold))])));
}