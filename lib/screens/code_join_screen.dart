import 'package:flutter/material.dart';
import '../constants.dart';

class CodeJoinScreen extends StatelessWidget {
  const CodeJoinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('코드 참여', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 50),
            const Text('비공개 대회 참가 코드', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('주최자에게 받은 참가 코드를 입력하세요.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            // 코드 입력창
            TextField(
              decoration: InputDecoration(
                hintText: 'XXXXXXXXXXXX',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                suffixIcon: IconButton(icon: const Icon(Icons.cancel, color: Colors.grey), onPressed: () {}),
              ),
            ),
            const SizedBox(height: 20),

            // 입력 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // 나중에 API 연결 (코드 확인)
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                child: const Text('입력', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}