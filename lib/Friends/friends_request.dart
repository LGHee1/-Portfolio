import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsRequestPage extends StatefulWidget {
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

  const FriendsRequestPage({super.key});

  @override
  State<FriendsRequestPage> createState() => _FriendsRequestPageState();
}

class _FriendsRequestPageState extends State<FriendsRequestPage>
    with SingleTickerProviderStateMixin {
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
      backgroundColor: const Color(0xFFE5FBFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5FBFF),
        elevation: 0,
        title: Text(
          '친구 요청',
          style: FriendsRequestPage._kTitleStyle,
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.blue,
          indicatorWeight: 3,
          labelStyle: FriendsRequestPage._kTitleStyle.copyWith(fontSize: 16),
          unselectedLabelStyle:
              FriendsRequestPage._kSubtitleStyle.copyWith(fontSize: 16),
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
          .collection('friend_requests')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 64,
                  color: Colors.black.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  '받은 친구 요청이 없습니다.',
                  style: FriendsRequestPage._kSubtitleStyle.copyWith(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
              vertical: FriendsRequestPage._kDefaultPadding),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final fromUid = data['from'];
            final fromNickname = data['fromNickname'];

            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: FriendsRequestPage._kDefaultPadding,
                vertical: 8,
              ),
              elevation: FriendsRequestPage._kCardElevation,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    FriendsRequestPage._kDefaultBorderRadius),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: FriendsRequestPage._kDefaultPadding,
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
                  fromNickname ?? '알 수 없음',
                  style: FriendsRequestPage._kTitleStyle.copyWith(fontSize: 16),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 24,
                      ),
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
                          final myNickname =
                              myProfile.data()?['nickname'] ?? '';

                          batch.set(theirFriendRef, {
                            'nickname': myNickname,
                            'addedAt': FieldValue.serverTimestamp(),
                          });

                          // 친구 요청 삭제
                          batch.delete(doc.reference);

                          await batch.commit();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '친구 요청을 수락했습니다.',
                                  style: FriendsRequestPage._kSubtitleStyle
                                      .copyWith(color: Colors.white),
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      FriendsRequestPage._kDefaultBorderRadius),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '친구 요청 수락 중 오류가 발생했습니다.',
                                  style: FriendsRequestPage._kSubtitleStyle
                                      .copyWith(color: Colors.white),
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      FriendsRequestPage._kDefaultBorderRadius),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: Colors.red,
                        size: 24,
                      ),
                      onPressed: () async {
                        try {
                          await doc.reference.delete();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '친구 요청을 거절했습니다.',
                                  style: FriendsRequestPage._kSubtitleStyle
                                      .copyWith(color: Colors.white),
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      FriendsRequestPage._kDefaultBorderRadius),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '친구 요청 거절 중 오류가 발생했습니다.',
                                  style: FriendsRequestPage._kSubtitleStyle
                                      .copyWith(color: Colors.white),
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      FriendsRequestPage._kDefaultBorderRadius),
                                ),
                              ),
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
          .collection('sent_requests')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.send_outlined,
                  size: 64,
                  color: Colors.black.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  '보낸 친구 요청이 없습니다.',
                  style: FriendsRequestPage._kSubtitleStyle.copyWith(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
              vertical: FriendsRequestPage._kDefaultPadding),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final toNickname = data['toNickname'] ?? data['to'] ?? '알 수 없음';
            final status = data['status'] ?? 'pending';

            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: FriendsRequestPage._kDefaultPadding,
                vertical: 8,
              ),
              elevation: FriendsRequestPage._kCardElevation,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    FriendsRequestPage._kDefaultBorderRadius),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: FriendsRequestPage._kDefaultPadding,
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
                  toNickname,
                  style: FriendsRequestPage._kTitleStyle.copyWith(fontSize: 16),
                ),
                subtitle: Text(
                  status == 'pending' ? '대기 중' : '수락됨',
                  style: FriendsRequestPage._kSubtitleStyle.copyWith(
                    color: status == 'pending' ? Colors.orange : Colors.green,
                  ),
                ),
                trailing: status == 'pending'
                    ? IconButton(
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: Colors.red,
                          size: 24,
                        ),
                        onPressed: () async {
                          try {
                            await doc.reference.delete();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '친구 요청을 취소했습니다.',
                                    style: FriendsRequestPage._kSubtitleStyle
                                        .copyWith(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.blue,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        FriendsRequestPage
                                            ._kDefaultBorderRadius),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '친구 요청 취소 중 오류가 발생했습니다.',
                                    style: FriendsRequestPage._kSubtitleStyle
                                        .copyWith(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        FriendsRequestPage
                                            ._kDefaultBorderRadius),
                                  ),
                                ),
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