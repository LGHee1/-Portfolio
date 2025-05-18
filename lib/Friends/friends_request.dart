import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsRequestPage extends StatefulWidget {
  const FriendsRequestPage({super.key});

  @override
  State<FriendsRequestPage> createState() => _FriendsRequestPageState();
}

class _FriendsRequestPageState extends State<FriendsRequestPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCBF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCBF6FF),
        title: const Text(
          '친구 요청',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: '받은 요청'),
            Tab(text: '보낸 요청'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ReceivedRequestsTab(),
          _SentRequestsTab(),
        ],
      ),
    );
  }
}

class _ReceivedRequestsTab extends StatelessWidget {
  // 임시 받은 요청 데이터
  final List<Map<String, String>> _tempReceivedRequests = [
    {
      'name': '박지민',
      'status': '함께 달리자고요!',
    },
    {
      'name': '최유진',
      'status': '같이 운동해요',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _tempReceivedRequests.length,
      itemBuilder: (context, index) {
        final request = _tempReceivedRequests[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(request['name']!),
            subtitle: Text(request['status']!),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () {
                    // TODO: 친구 요청 수락 기능 구현
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    // TODO: 친구 요청 거절 기능 구현
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SentRequestsTab extends StatelessWidget {
  // 임시 보낸 요청 데이터
  final List<Map<String, String>> _tempSentRequests = [
    {
      'name': '정민수',
      'status': '요청 대기 중',
    },
    {
      'name': '한소희',
      'status': '요청 대기 중',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _tempSentRequests.length,
      itemBuilder: (context, index) {
        final request = _tempSentRequests[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(request['name']!),
            subtitle: Text(request['status']!),
            trailing: IconButton(
              icon: const Icon(Icons.cancel, color: Colors.grey),
              onPressed: () {
                // TODO: 친구 요청 취소 기능 구현
              },
            ),
          ),
        );
      },
    );
  }
} 