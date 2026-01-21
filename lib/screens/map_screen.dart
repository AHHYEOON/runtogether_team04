import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart'; // primaryColor 가져오기

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // 구글 맵 컨트롤러
  final Completer<GoogleMapController> _controller = Completer();

  // 초기 위치 (서울 시청 - 로딩 전 임시 위치)
  LatLng _currentPosition = const LatLng(37.5665, 126.9780);
  bool _isLoading = true; // 로딩 상태

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // 화면 켜지자마자 내 위치 찾기
  }

  // [내 위치 가져오기]
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. 위치 서비스 켜져있는지 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 2. 권한 확인 및 요청
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 3. 진짜 위치 가져오기
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });

        // 지도 카메라를 내 위치로 부드럽게 이동
        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition, zoom: 16),
        ));
      }
    } catch (e) {
      print("위치 가져오기 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단 앱바
      appBar: AppBar(
        title: const Text("러닝 맵", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false, // 탭 화면이므로 뒤로가기 버튼 숨김
      ),
      body: Stack(
        children: [
          // 1. 구글 지도
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 16, // 줌 레벨 (클수록 확대됨)
            ),
            myLocationEnabled: true,        // ★ 파란 점(내 위치) 표시
            myLocationButtonEnabled: false,  // 기본 버튼 숨기고 커스텀 버튼 사용
            zoomControlsEnabled: false,     // 줌 버튼 숨김
            mapToolbarEnabled: false,       // 안드로이드 길찾기/지도공유 버튼 숨김
            compassEnabled: false,          // 나침반 숨김 (필요하면 true)
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),

          // 2. 로딩 중일 때 화면 가리기 (흰 배경 + 로딩바)
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(color: primaryColor),
              ),
            ),

          // 3. [현위치] 버튼 (우측 하단)
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation, // 누르면 내 위치로 이동
              backgroundColor: Colors.white,
              foregroundColor: primaryColor,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              child: const Icon(Icons.my_location),
            ),
          ),

          // 4. (옵션) 상단 안내 문구 박스
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Row(
                children: [
                  Icon(Icons.directions_run_rounded, color: primaryColor),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "자유롭게 달리며 주변을 탐색해보세요!",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}