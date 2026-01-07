import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';


import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // 지도 패키지 추가
import '../constants.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  // 입력 컨트롤러들
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();

  double _maxPeople = 10;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isSecret = false;
  bool _isSearchable = true;
  bool _isLoading = false;

  // ★ [변경] 고정 코스 관련 변수
  final int _fixedCourseId = 4; // 친구 DB에 있는 코스 ID (1번이 아니면 수정하세요!)
  String _fixedCourseName = "로딩 중...";
  String _fixedCourseInfo = "";

  // 지도 관련 변수
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  LatLng _initialPosition = const LatLng(37.5665, 126.9780); // 기본 서울시청
  bool _isMapLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFixedCourse(); // 화면 켜지자마자 코스 정보 로드
  }

  // [API] 고정 코스 정보 가져오기
  // [API] 고정 코스 정보 가져오기 (수정됨)
  Future<void> _fetchFixedCourse() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final dio = Dio();
      final options = Options(headers: {
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token'
      });

      // 친구 API: 코스 상세 정보 조회
      final url = '$baseUrl/api/v1/courses/$_fixedCourseId';
      print("🚀 요청 URL: $url");

      final response = await dio.get(url, options: options);

      // ★ [중요] 서버가 보내준 데이터가 정확히 무엇인지 콘솔에 찍어봅니다.
      print("📥 서버 응답 데이터: ${response.data}");

      if (response.statusCode == 200) {
        // 데이터가 바로 { } 형태인지, 아니면 { "data": { } } 형태인지 체크
        final rawData = response.data;
        final data = (rawData is Map && rawData.containsKey('data'))
            ? rawData['data']
            : rawData;

        setState(() {
          // 변수명이 title일 수도 있고, courseName일 수도 있어서 둘 다 시도해봅니다.
          _fixedCourseName = data['title'] ?? data['courseName'] ?? "이름 없는 코스";

          // 추가 정보도 있으면 가져오기 (예: expectedTime, distance)
          String time = "${data['expectedTime'] ?? '??'}분";
          String dist = "${data['distance'] ?? '??'}km";
          _fixedCourseInfo = "거리: $dist  |  소요시간: $time";
        });

        // 경로 데이터 파싱 (pathData 또는 path 또는 route)
        final pathData = data['pathData'] ?? data['path'] ?? data['route'];
        _drawRouteOnMap(pathData);
      }
    } catch (e) {
      print("❌ 코스 로드 실패: $e");
      setState(() {
        _fixedCourseName = "코스 정보를 불러올 수 없습니다.";
        _fixedCourseInfo = "네트워크 상태를 확인해주세요.";
        _isMapLoading = false;
      });
    }
  }

  // [지도] 경로 그리기
  // [1] 지도 도우미: 경로의 남서쪽/북동쪽 끝을 계산해서 화면 꽉 차게 만드는 함수
  LatLngBounds _createBounds(List<LatLng> positions) {
    final southwestLat = positions.map((p) => p.latitude).reduce((curr, next) => curr < next ? curr : next);
    final southwestLon = positions.map((p) => p.longitude).reduce((curr, next) => curr < next ? curr : next);
    final northeastLat = positions.map((p) => p.latitude).reduce((curr, next) => curr > next ? curr : next);
    final northeastLon = positions.map((p) => p.longitude).reduce((curr, next) => curr > next ? curr : next);
    return LatLngBounds(
      southwest: LatLng(southwestLat, southwestLon),
      northeast: LatLng(northeastLat, northeastLon),
    );
  }

  // [2] 지도 그리기 함수 (카메라 자동 이동 기능 추가됨)
  void _drawRouteOnMap(dynamic rawPathData) {
    if (rawPathData == null) {
      setState(() => _isMapLoading = false);
      return;
    }

    List<LatLng> points = [];
    try {
      List<dynamic> list = [];
      if (rawPathData is String) {
        list = jsonDecode(rawPathData);
      } else if (rawPathData is List) {
        list = rawPathData;
      }

      for (var p in list) {
        // 서버 데이터 키값 확인 (lat, lng 혹은 latitude, longitude)
        double lat = double.tryParse(p['lat']?.toString() ?? p['latitude']?.toString() ?? "0") ?? 0.0;
        double lng = double.tryParse(p['lng']?.toString() ?? p['longitude']?.toString() ?? "0") ?? 0.0;

        if (lat != 0 && lng != 0) {
          points.add(LatLng(lat, lng));
        }
      }
    } catch (e) {
      print("파싱 에러: $e");
    }

    if (points.isNotEmpty) {
      setState(() {
        _initialPosition = points.first;

        // 경로선(Polyline) 설정
        _polylines = {
          Polyline(
            polylineId: const PolylineId("fixed_course"),
            points: points,
            color: Colors.blueAccent,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          )
        };

        // 출발/도착 마커 설정
        _markers = {
          Marker(
            markerId: const MarkerId("start"),
            position: points.first,
            infoWindow: const InfoWindow(title: "출발"),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
          Marker(
            markerId: const MarkerId("end"),
            position: points.last,
            infoWindow: const InfoWindow(title: "도착"),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        };

        _isMapLoading = false;
      });

      // ★ 지도가 다 그려진 뒤 카메라를 경로 전체가 보이게 이동
      _mapController.future.then((c) {
        try {
          // 0.3초 뒤에 카메라 이동 (지도 로딩 시간 벌어주기)
          Future.delayed(const Duration(milliseconds: 300), () {
            c.animateCamera(CameraUpdate.newLatLngBounds(_createBounds(points), 50.0));
          });
        } catch (e) {
          print("카메라 이동 에러: $e");
        }
      });

    } else {
      setState(() => _isMapLoading = false);
    }
  }

  // [API] 그룹 생성 요청
  void _createGroup() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('그룹 이름을 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final dio = Dio();
      final options = Options(headers: {
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      });

      String startStr = "${_startDate.year}-${_startDate.month.toString().padLeft(2,'0')}-${_startDate.day.toString().padLeft(2,'0')}";
      String endStr = "${_endDate.year}-${_endDate.month.toString().padLeft(2,'0')}-${_endDate.day.toString().padLeft(2,'0')}";

      final data = {
        "groupName": _nameController.text,
        "description": _descController.text,
        "tags": _tagController.text,
        "maxPeople": _maxPeople.toInt(),
        "startDate": startStr,
        "endDate": endStr,
        "isSecret": _isSecret,
        "isSearchable": _isSearchable,
        "courseId": _fixedCourseId, // ★ 여기서 1번으로 고정 전송!
      };

      print("🚀 그룹 생성 요청 데이터: $data");

      final response = await dio.post(groupUrl, data: data, options: options); // groupUrl은 constants.dart에 있다고 가정

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        Navigator.pop(context); // 목록으로 복귀
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('대회가 생성되었습니다!')));
      }
    } catch (e) {
      print("생성 에러: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('대회 생성', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, leading: const BackButton(color: Colors.black)),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('대회명 *'), TextField(controller: _nameController, decoration: _inputDeco('대회명을 입력해주세요.')), const SizedBox(height: 20),
            _label('대회 소개'), TextField(controller: _descController, decoration: _inputDeco('대회 소개를 입력해주세요.')), const SizedBox(height: 10), TextField(controller: _tagController, decoration: _inputDeco('#태그 추가')), const SizedBox(height: 20),
            _label('대회 인원'), Row(children: [Expanded(child: Slider(value: _maxPeople, min: 2, max: 50, divisions: 48, activeColor: primaryColor, onChanged: (val) => setState(() => _maxPeople = val))), Text("${_maxPeople.toInt()}명", style: const TextStyle(fontWeight: FontWeight.bold))]), const SizedBox(height: 20),
            _label('기간 설정'), Row(children: [Expanded(child: _dateSelector(true)), const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("~")), Expanded(child: _dateSelector(false))]), const SizedBox(height: 20),
            _label('공개 설정'), Row(children: [_buildRadio('공개', false, (v) => setState(() => _isSecret = v)), const SizedBox(width: 20), _buildRadio('비공개', true, (v) => setState(() => _isSecret = v))]), const SizedBox(height: 10),
            _label('검색 허용'), Row(children: [_buildRadio2('허용', true, (v) => setState(() => _isSearchable = v)), const SizedBox(width: 20), _buildRadio2('허용 안 함', false, (v) => setState(() => _isSearchable = v))]),

            const SizedBox(height: 40),

            // ============================================================
            // [★ 수정됨] 코스 정보 및 지도 표시 (선택 아님, 보여주기용)
            // ============================================================
            _label('코스 정보 (고정)'),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 코스 이름 헤더
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.map, color: primaryColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_fixedCourseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),

                  // 지도 영역
                  SizedBox(
                    height: 500,
                    width: double.infinity,
                    child: _isMapLoading
                        ? const Center(child: CircularProgressIndicator())
                        : GoogleMap(
                      initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 14),
                      mapType: MapType.normal,
                      zoomControlsEnabled: false,
                      scrollGesturesEnabled: false, // 지도 스크롤 막기 (옵션)
                      zoomGesturesEnabled: false,   // 줌 막기 (옵션)
                      polylines: _polylines,
                      markers: _markers,
                      onMapCreated: (c) => _mapController.complete(c),
                    ),
                  ),

                  // 안내 문구
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text("※ 이번 대회는 위 코스로 진행됩니다.", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ),
                ],
              ),
            ),
            // ============================================================

            const SizedBox(height: 40),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isLoading ? null : _createGroup, style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('대회 생성 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // [Helper Widgets] - 기존 유지
  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)));
  InputDecoration _inputDeco(String hint) => InputDecoration(hintText: hint, filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14));
  Widget _buildRadio(String label, bool value, Function(bool) onChanged) => Row(children: [Radio<bool>(value: value, groupValue: _isSecret, activeColor: primaryColor, onChanged: (val) => onChanged(val!)), Text(label)]);
  Widget _buildRadio2(String label, bool value, Function(bool) onChanged) => Row(children: [Radio<bool>(value: value, groupValue: _isSearchable, activeColor: primaryColor, onChanged: (val) => onChanged(val!)), Text(label)]);

  Widget _dateSelector(bool isStart) {
    final date = isStart ? _startDate : _endDate;
    return GestureDetector(
      onTap: () => _selectDate(context, isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${date.year}-${date.month}-${date.day}", style: const TextStyle(fontSize: 14)), const Icon(Icons.calendar_today, size: 16, color: Colors.grey)]),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: isStart ? _startDate : _endDate, firstDate: DateTime(2020), lastDate: DateTime(2030), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: primaryColor)), child: child!));
    if (picked != null) setState(() { if (isStart) { _startDate = picked; if (_startDate.isAfter(_endDate)) _endDate = _startDate; } else { _endDate = picked; } });
  }
}