import 'package:flutter/material.dart';
import 'package:runtogether_team04/constants.dart';
import 'package:runtogether_team04/screens/home_screen.dart';
import 'package:runtogether_team04/screens/running_screen.dart';
import 'package:runtogether_team04/screens/mypage_screen.dart';
import 'package:runtogether_team04/screens/map_screen.dart';

import 'my_group_list_screen.dart'; // 홈 화면(리스트) 가져오기

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // 현재 선택된 탭 인덱스 (0번: 홈)

  // 각 탭에 보여줄 화면들
  final List<Widget> _screens = [
    const HomeScreen(),      // [0] 홈 (그룹 리스트 & 상단 버튼 있는 곳)
    const MyGroupListScreen(), // [1] 내그룹
    const MapScreen(), // [2] 지도
    const MyPageScreen(), // [3] 마이페이지
  ];

  // 탭 클릭 시 실행되는 함수
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 현재 선택된 인덱스의 화면을 보여줌
      body: _screens[_selectedIndex],

      // 하단 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: primaryColor, // 선택된 아이콘 색상 (오렌지)
        unselectedItemColor: Colors.grey, // 선택 안 된 아이콘 색상
        type: BottomNavigationBarType.fixed, // 탭이 4개 이상일 때 필수
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: '내 대회'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: '지도'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '마이'),
        ],
      ),
    );
  }
}