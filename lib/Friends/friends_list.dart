import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsListPage extends StatelessWidget {
  // UI Constants
  static const double _kDefaultPadding = 16.0;
  static const double _kDefaultBorderRadius = 12.0;
  static const double _kCardElevation = 2.0;

  // Text Styles
  static const TextStyle _kTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
    letterSpacing: 0.2,
  );

  static const TextStyle _kSubtitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black54,
    letterSpacing: 0.1,
  );

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
      backgroundColor: const Color(0xFFE5FBFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5FBFF),
        elevation: 0,
        title: Text(
          '친구 목록',
          style: _kTitleStyle,
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: friendsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.black.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '등록된 친구가 없습니다.',
                    style: _kSubtitleStyle.copyWith(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }

          final friends = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: _kDefaultPadding),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final doc = friends[index];
              final friend = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: _kDefaultPadding,
                  vertical: 8,
                ),
                elevation: _kCardElevation,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kDefaultBorderRadius),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: _kDefaultPadding,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: const Icon(
                      Icons.person,
                      color: Colors.blue,
                    ),
                  ),
                  title: Text(
                    friend['nickname'] ?? '알 수 없음',
                    style: _kTitleStyle.copyWith(fontSize: 16),
                  ),
                  subtitle: Text(
                    friend['addedAt']?.toDate().toString() ?? '',
                    style: _kSubtitleStyle,
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 24,
                    ),
                    onPressed: () async {
                      final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(_kDefaultBorderRadius),
                            ),
                            title: Text(
                              '친구 삭제',
                              style: _kTitleStyle,
                            ),
                            content: Text(
                              '${friend['nickname']}님을 친구 목록에서 삭제하시겠습니까?',
                              style: _kSubtitleStyle,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _kDefaultPadding,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(
                                  '취소',
                                  style: _kSubtitleStyle.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _kDefaultPadding,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(
                                  '삭제',
                                  style: _kSubtitleStyle.copyWith(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );

                      if (shouldDelete == true) {
                        try {
                          final batch = FirebaseFirestore.instance.batch();
                          batch.delete(doc.reference);
                          batch.delete(FirebaseFirestore.instance
                              .collection('Friends_Data')
                              .doc(doc.id)
                              .collection('friends')
                              .doc(currentUser.uid));
                          await batch.commit();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '친구가 삭제되었습니다.',
                                  style: _kSubtitleStyle.copyWith(
                                      color: Colors.white),
                                ),
                                backgroundColor: Colors.blue,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      _kDefaultBorderRadius),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '친구 삭제 중 오류가 발생했습니다.',
                                  style: _kSubtitleStyle.copyWith(
                                      color: Colors.white),
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      _kDefaultBorderRadius),
                                ),
                              ),
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