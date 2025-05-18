import 'package:flutter/material.dart';

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({super.key});

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  // 임시 친구 데이터
  final List<Map<String, String>> _tempFriends = [
    {
      'name': '김철수',
      'status': '오늘도 열심히 달려요!',
    },
    {
      'name': '이영희',
      'status': '주말에 등산 가요',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCBF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCBF6FF),
        title: const Text(
          '친구 목록',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: _tempFriends.length,
        itemBuilder: (context, index) {
          final friend = _tempFriends[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(friend['name']!),
              subtitle: Text(friend['status']!),
            ),
          );
        },
      ),
    );
  }
} 