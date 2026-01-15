import 'dart:async';
import 'dart:convert';
import 'dart:math'; // ★ 랜덤 생성을 위해 추가
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();

  double _maxPeople = 10;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  bool _isSecret = false;
  bool _isLoading = false;

  final int _fixedCourseId = 6;
  String _fixedCourseName = "로딩 중...";

  final Completer<GoogleMapController> _mapController = Completer();
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  LatLng _initialPosition = const LatLng(37.5665, 126.9780);
  bool _isMapLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFixedCourse();
  }

  // ★ [추가됨] 랜덤 숫자 8자리 생성 함수
  String _generateRandomAccessCode() {
    var rng = Random();
    // 0부터 99999999 사이의 난수 생성 후, 8자리가 안 되면 앞에 0을 채움
    // 예: 123 -> "00000123"
    return rng.nextInt(100000000).toString().padLeft(8, '0');
  }

  // [API] 고정 코스 정보 가져오기
  Future<void> _fetchFixedCourse() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final dio = Dio();
      final options = Options(headers: {
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token'
      });

      final url = '$baseUrl/api/v1/courses/$_fixedCourseId';
      final response = await dio.get(url, options: options);

      if (response.statusCode == 200) {
        final rawData = response.data;
        final data = (rawData is Map && rawData.containsKey('data')) ? rawData['data'] : rawData;

        setState(() {
          _fixedCourseName = data['title'] ?? data['courseName'] ?? "이름 없는 코스";
        });

        final pathData = data['pathData'] ?? data['path'] ?? data['route'];
        _drawRouteOnMap(pathData);
      }
    } catch (e) {
      print("❌ 코스 로드 실패: $e");
      setState(() {
        _fixedCourseName = "코스 정보를 불러올 수 없습니다.";
        _isMapLoading = false;
      });
    }
  }

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
        double lat = double.tryParse(p['lat']?.toString() ?? p['latitude']?.toString() ?? "0") ?? 0.0;
        double lng = double.tryParse(p['lng']?.toString() ?? p['longitude']?.toString() ?? "0") ?? 0.0;
        if (lat != 0 && lng != 0) points.add(LatLng(lat, lng));
      }
    } catch (e) { print("파싱 에러: $e"); }

    if (points.isNotEmpty) {
      setState(() {
        _initialPosition = points.first;
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
        _markers = {
          Marker(markerId: const MarkerId("start"), position: points.first, infoWindow: const InfoWindow(title: "출발"), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
          Marker(markerId: const MarkerId("end"), position: points.last, infoWindow: const InfoWindow(title: "도착"), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
        };
        _isMapLoading = false;
      });
      _mapController.future.then((c) {
        Future.delayed(const Duration(milliseconds: 300), () {
          try { c.animateCamera(CameraUpdate.newLatLngBounds(_createBounds(points), 50.0)); } catch (_) {}
        });
      });
    } else {
      setState(() => _isMapLoading = false);
    }
  }

  // [수정됨] 그룹 생성 요청 (서버 응답 데이터 확인용)
  // [수정됨] 서버 메시지에서 코드를 강제로 꺼내는 버전
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

      // 앱에서 일단 아무거나 생성 (서버가 무시하겠지만 형식상 보냄)
      String myRandomCode = "";
      if (_isSecret) {
        myRandomCode = _generateRandomAccessCode();
      }

      final data = {
        "groupName": _nameController.text,
        "description": _descController.text,
        "tags": _tagController.text,
        "maxPeople": _maxPeople.toInt(),
        "startDate": startStr,
        "endDate": endStr,
        "isSecret": _isSecret,
        "isSearchable": !_isSecret,
        "courseId": _fixedCourseId,
        "accessCode": _isSecret ? myRandomCode : null,
      };

      print("🚀 그룹 생성 요청: $data");

      final response = await dio.post(groupUrl, data: data, options: options);

      print("📥 응답 데이터: ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (_isSecret) {
          if (!mounted) return;

          final resData = response.data;
          String realCode = "";

          // 1. 깔끔하게 accessCode 키로 줬는지 확인
          if (resData['accessCode'] != null) {
            realCode = resData['accessCode'];
          }
          // 2. data 안에 들어있는지 확인
          else if (resData['data'] != null && resData['data']['accessCode'] != null) {
            realCode = resData['data']['accessCode'];
          }
          // ★ [핵심] 3. 메시지 속에 숨겨져 있는지 확인 ("그룹 생성 완료! [입장코드: XXXXX]" 형태)
          else if (resData['message'] != null) {
            String msg = resData['message'].toString();
            // "[입장코드:" 라는 글자가 있으면 그 뒤를 파싱
            if (msg.contains("[입장코드:")) {
              try {
                // ":" 뒤에서부터 "]" 앞까지 자르기
                // 예: "그룹 생성 완료! [입장코드: 2GVF8TMHRD]"
                int start = msg.indexOf(":") + 1;
                int end = msg.indexOf("]");
                if (start > 0 && end > start) {
                  realCode = msg.substring(start, end).trim(); // 공백 제거 후 저장
                  print("🕵️‍♂️ 메시지에서 코드 발견! -> $realCode");
                }
              } catch (e) {
                print("파싱 실패: $e");
              }
            }
          }

          // 여전히 못 찾았으면 어쩔 수 없이 내꺼 사용 (비상용)
          if (realCode.isEmpty) {
            realCode = myRandomCode;
            print("⚠️ 서버 코드를 못 찾음. 임시 코드 사용.");
          }

          _showInviteCodeDialog(realCode);

        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('대회가 생성되었습니다!')));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print("생성 에러: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류가 발생했습니다. 잠시 후 다시 시도해주세요.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInviteCodeDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("비공개 대회 생성 완료", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("아래 입장 코드를 참가자들에게 공유하세요."),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ★ 생성된 숫자 코드 표시
                    Text(code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.copy, color: primaryColor),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("코드가 복사되었습니다!")));
                      },
                    )
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text("※ 이 코드는 대회 상세 페이지에서도\n확인할 수 있습니다.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text("확인", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
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

            _label('공개 설정'),
            Row(children: [
              _buildRadio('공개 (누구나 검색 가능)', false, (v) => setState(() => _isSecret = v)),
              const SizedBox(width: 10),
              _buildRadio('비공개 (코드 필요)', true, (v) => setState(() => _isSecret = v))
            ]),

            const SizedBox(height: 40),

            _label('코스 정보 (고정)'),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Icon(Icons.map, color: primaryColor), const SizedBox(width: 10), Expanded(child: Text(_fixedCourseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))])),
                  SizedBox(
                    height: 500, width: double.infinity,
                    child: _isMapLoading
                        ? const Center(child: CircularProgressIndicator())
                        : GoogleMap(initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 14), mapType: MapType.normal, zoomControlsEnabled: false, scrollGesturesEnabled: false, zoomGesturesEnabled: false, polylines: _polylines, markers: _markers, onMapCreated: (c) => _mapController.complete(c)),
                  ),
                  Padding(padding: const EdgeInsets.all(12), child: Text("※ 이번 대회는 위 코스로 진행됩니다.", style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isLoading ? null : _createGroup, style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('대회 생성 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)));
  InputDecoration _inputDeco(String hint) => InputDecoration(hintText: hint, filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14));
  Widget _buildRadio(String label, bool value, Function(bool) onChanged) => Row(children: [Radio<bool>(value: value, groupValue: _isSecret, activeColor: primaryColor, onChanged: (val) => onChanged(val!)), Text(label)]);

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