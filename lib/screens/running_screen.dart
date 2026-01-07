import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // 구글맵 패키지
import 'package:geolocator/geolocator.dart';
import 'package:runtogether_team04/constants.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

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

  // 상태 관리
  bool _isAiCoachOn = false;
  bool _isNaviOn = false;
  bool _isSaving = false;

  // 백그라운드 데이터 리스너 구독 변수 (종료 시 해제용)
  StreamSubscription? _serviceSubscription;

  @override
  void initState() {
    super.initState();
    _fetchCoursePath();         // 1. 코스 경로 로딩 (회색 선)
    _startBackgroundService();  // 2. [변경됨] 백그라운드 서비스 시작
    _stopWatchTimer.onStartTimer();
  }

  @override
  void dispose() {
    _stopWatchTimer.dispose();
    _serviceSubscription?.cancel(); // 화면 꺼질 때 리스너 해제
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // [1] 코스 경로 데이터 가져오기
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

          if (mounted) {
            setState(() {
              _polylines.add(Polyline(
                polylineId: const PolylineId("course_guide"),
                points: coursePoints,
                color: Colors.grey.withOpacity(0.5),
                width: 8,
                zIndex: 1,
              ));
              _markers.add(Marker(markerId: const MarkerId("start"), position: coursePoints.first, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)));
              _markers.add(Marker(markerId: const MarkerId("end"), position: coursePoints.last, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)));
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
  // [2] (핵심 변경) 백그라운드 서비스 시작 및 데이터 수신
  // ------------------------------------------------------------------------
  Future<void> _startBackgroundService() async {
    final service = FlutterBackgroundService();

    // 서비스가 안 켜져 있다면 시작
    if (!(await service.isRunning())) {
      await service.startService();
    }

    // 서비스로부터 'update' 이벤트를 받아서 UI 갱신
    _serviceSubscription = service.on('update').listen((event) {
      if (event != null && mounted) {
        double lat = event['lat'];
        double lng = event['lng'];
        double speed = event['speed'] ?? 0.0;

        _updatePosition(lat, lng, speed);
      }
    });
  }

  // ------------------------------------------------------------------------
  // [3] (핵심 변경) 위치 업데이트 로직
  // ------------------------------------------------------------------------
  void _updatePosition(double lat, double lng, double speed) async {
    LatLng newPos = LatLng(lat, lng);

    // 거리 및 데이터 계산
    if (_currentPosition != null) {
      double dist = Geolocator.distanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude,
        lat, lng,
      );

      setState(() {
        _totalDistance += (dist / 1000);
        _calories = _totalDistance * 60; // (예시 공식)

        // 속도(m/s) -> 페이스(분/km) 변환
        if (speed > 0) {
          double ps = 1000 / speed;
          _pace = "${(ps / 60).floor()}'${(ps % 60).floor().toString().padLeft(2, '0')}''";
        }
      });
    }

    _myRouteCoords.add(newPos);

    setState(() {
      // Geolocator 호환성을 위해 Position 객체 생성
      _currentPosition = Position(
          latitude: lat, longitude: lng, timestamp: DateTime.now(),
          accuracy: 0, altitude: 0, heading: 0, speed: speed, speedAccuracy: 0,
          altitudeAccuracy: 0, headingAccuracy: 0
      );

      // 내 경로(오렌지색) 그리기
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

    // 지도 카메라 이동
    try {
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLng(newPos));
    } catch (_) {}
  }

  // ------------------------------------------------------------------------
  // [4] 기록 저장
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
        // [중요] 저장 성공 시 서비스 종료
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
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)]),
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
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildStatItem("페이스", _pace), _buildStatItem("칼로리", "${_calories.toInt()} kcal"), _buildStatItem("심박수", "-- bpm")]),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () {
                        _stopWatchTimer.onStopTimer();
                        showDialog(context: context, builder: (ctx) => AlertDialog(
                          title: const Text("러닝 종료"), content: const Text("기록을 저장하고 종료하시겠습니까?"),
                          actions: [
                            TextButton(onPressed: () { Navigator.pop(ctx); _stopWatchTimer.onStartTimer(); }, child: const Text("계속 뛰기")),
                            TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  // 종료 버튼 누르면 저장 로직 실행
                                  _saveRecord();
                                },
                                child: const Text("종료 및 저장", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))
                            ),
                          ],
                        ));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                      child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("STOP", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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