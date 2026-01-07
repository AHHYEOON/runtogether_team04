import 'package:flutter/material.dart';

// 러닝 상태를 전역에서 관리하는 클래스
class RunningService extends ChangeNotifier {
  static final RunningService _instance = RunningService._internal();
  factory RunningService() => _instance;
  RunningService._internal();

  bool isRunning = false; // 현재 달리는 중인가?
  int? currentGroupId;    // 어떤 그룹(대회)의 러닝인가?

  // 시작
  void startRun(int groupId) {
    isRunning = true;
    currentGroupId = groupId;
    notifyListeners();
  }

  // 종료
  void stopRun() {
    isRunning = false;
    currentGroupId = null;
    notifyListeners();
  }
}