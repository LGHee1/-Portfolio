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
        children: const [
          _ReceivedRequestsTab(),
          _SentRequestsTab(),
        ],
      ),
    );
  }
}

class _ReceivedRequestsTab extends StatelessWidget {
  const _ReceivedRequestsTab();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Friends_Data')
          .doc(currentUser!.uid)
          .collection('friend_requests') // ✅ 받은 요청
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              '받은 친구 요청이 없습니다.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final fromUid = data['from'];
            final fromNickname = data['fromNickname'];

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(fromNickname ?? '알 수 없음'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        try {
                          final batch = FirebaseFirestore.instance.batch();
                          final myUid = currentUser.uid;

                          // 내 친구 목록에 추가
                          final myFriendRef = FirebaseFirestore.instance
                              .collection('Friends_Data')
                              .doc(myUid)
                              .collection('friends')
                              .doc(fromUid);

                          batch.set(myFriendRef, {
                            'nickname': fromNickname,
                            'addedAt': FieldValue.serverTimestamp(),
                          });

                          // 상대방 친구 목록에 추가
                          final theirFriendRef = FirebaseFirestore.instance
                              .collection('Friends_Data')
                              .doc(fromUid)
                              .collection('friends')
                              .doc(myUid);

                          final myProfile = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(myUid)
                              .get();
                          final myNickname = myProfile.data()?['nickname'] ?? '';

                          batch.set(theirFriendRef, {
                            'nickname': myNickname,
                            'addedAt': FieldValue.serverTimestamp(),
                          });

                          // 친구 요청 삭제
                          batch.delete(doc.reference);

                          await batch.commit();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('친구 요청을 수락했습니다.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('친구 요청 수락 중 오류가 발생했습니다.')),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        try {
                          await doc.reference.delete();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('친구 요청을 거절했습니다.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('친구 요청 거절 중 오류가 발생했습니다.')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SentRequestsTab extends StatelessWidget {
  const _SentRequestsTab();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Friends_Data')
          .doc(currentUser!.uid)
          .collection('sent_requests') // ✅ 보낸 요청
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              '보낸 친구 요청이 없습니다.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final toNickname = data['toNickname'] ?? data['to'] ?? '알 수 없음';
            final status = data['status'] ?? 'pending';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(toNickname),
                subtitle: Text(status == 'pending' ? '대기 중' : '수락됨'),
                trailing: status == 'pending'
                    ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () async {
                    try {
                      await doc.reference.delete();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('친구 요청을 취소했습니다.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('친구 요청 취소 중 오류가 발생했습니다.')),
                        );
                      }
                    }
                  },
                )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}