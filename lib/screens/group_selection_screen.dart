import 'package:flutter/material.dart';
import 'code_join_screen.dart';
import '../constants.dart';
import 'group_create_screen.dart';

class GroupSelectionScreen extends StatelessWidget {
  const GroupSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('무엇을 하시겠습니까?', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 참가자 버튼
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CodeJoinScreen()));
              },
              child: const Text('참가자입니다 (코드 입력)'),
            ),
            const SizedBox(height: 20),
            // 주최자 버튼
            ElevatedButton(
              onPressed: () {
                // 여기서 그룹 생성 화면으로 넘어갑니다!
                Navigator.push(context, MaterialPageRoute(builder: (context) => const GroupCreateScreen()));
              },
              child: const Text('대회 주최자입니다 (대회 생성)'),
            ),
          ],
        ),
      ),
    );
  }
}