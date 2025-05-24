import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsListPage extends StatelessWidget {
  const FriendsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final friendsStream = FirebaseFirestore.instance
        .collection('Friends_Data')
        .doc(currentUser!.uid)
        .collection('friends')
        .orderBy('addedAt', descending: true)
        .snapshots();

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
      body: StreamBuilder<QuerySnapshot>(
        stream: friendsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                '등록된 친구가 없습니다.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          final friends = snapshot.data!.docs;
          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final doc = friends[index];
              final friend = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(friend['nickname'] ?? '알 수 없음'),
                  subtitle: Text(friend['addedAt']?.toDate().toString() ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      // 삭제 확인 대화상자 표시
                      final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('친구 삭제'),
                            content: Text(
                                '${friend['nickname']}님을 친구 목록에서 삭제하시겠습니까?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text(
                                  '삭제',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          );
                        },
                      );

                      // 사용자가 확인을 선택한 경우에만 삭제 진행
                      if (shouldDelete == true) {
                        try {
                          final batch = FirebaseFirestore.instance.batch();

                          // 내 친구 목록에서 삭제
                          batch.delete(doc.reference);

                          // 상대방 친구 목록에서 삭제
                          batch.delete(FirebaseFirestore.instance
                              .collection('Friends_Data')
                              .doc(doc.id)
                              .collection('friends')
                              .doc(currentUser.uid));

                          await batch.commit();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('친구가 삭제되었습니다.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('친구 삭제 중 오류가 발생했습니다.')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}