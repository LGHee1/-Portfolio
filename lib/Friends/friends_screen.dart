import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../user_provider.dart';
import '../Widgets/bottom_bar.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  int _selectedIndex = 1;
  String _selectedTab = 'friends'; // 'friends' 또는 'requests'

  @override
  Widget build(BuildContext context) {
    final nickname = Provider.of<UserProvider>(context).nickname;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFD8F9FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          nickname.isNotEmpty ? '$nickname님의 친구 목록' : '친구 목록',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, color: Colors.black),
            ),
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/img/runner_home.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: const Color(0xFFE5FBFF).withOpacity(0.5)),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 28,
                              width: MediaQuery.of(context).size.width * 0.25,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedTab = 'friends';
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedTab == 'friends'
                                      ? const Color(0xFFB6F5E8)
                                      : Colors.white,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 0),
                                ),
                                child: const Text('친구',
                                    style: TextStyle(fontSize: 14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 28,
                              width: MediaQuery.of(context).size.width * 0.25,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedTab = 'requests';
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedTab == 'requests'
                                      ? const Color(0xFFB6F5E8)
                                      : Colors.white,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 0),
                                ),
                                child: const Text('신청',
                                    style: TextStyle(fontSize: 14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => const _FriendSearchDialog(),
                        );
                      },
                      child: const Icon(Icons.person_add,
                          size: 32, color: Colors.black54),
                    ),
                    const SizedBox(width: 18),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _selectedTab == 'friends'
                      ? const _FriendsListTab()
                      : const _RequestsTab(),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class _FriendsListTab extends StatelessWidget {
  const _FriendsListTab();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('로그인이 필요합니다'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('Friends_Data')
          .orderBy('addedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final friends = snapshot.data?.docs ?? [];

        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '등록된 호닥 친구가 없습니다.',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 8),
                const Text(
                  '닉네임으로 친구를 추가해보세요!',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const _FriendSearchDialog(),
                        );
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('친구 추가하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

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
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('친구 삭제'),
                          content:
                          Text('${friend['nickname']}님을 친구 목록에서 삭제하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('삭제',
                                  style: TextStyle(color: Colors.red)),
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
                            .collection('users')
                            .doc(doc.id)
                            .collection('Friends_Data')
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
    );
  }
}

class _RequestsTab extends StatefulWidget {
  const _RequestsTab();

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab>
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
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: '받은 요청'),
            Tab(text: '보낸 요청'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _ReceivedRequestsTab(),
              _SentRequestsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReceivedRequestsTab extends StatelessWidget {
  const _ReceivedRequestsTab();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('로그인이 필요합니다'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('Received_Requests')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return const Center(
            child: Text(
              '받은 친구 요청이 없습니다.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
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
                              .collection('users')
                              .doc(myUid)
                              .collection('Friends_Data')
                              .doc(fromUid);

                          batch.set(myFriendRef, {
                            'nickname': fromNickname,
                            'addedAt': FieldValue.serverTimestamp(),
                          });

                          // 상대방 친구 목록에 추가
                          final theirFriendRef = FirebaseFirestore.instance
                              .collection('users')
                              .doc(fromUid)
                              .collection('Friends_Data')
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

                          // 보낸 요청도 삭제
                          final sentRequestRef = FirebaseFirestore.instance
                              .collection('users')
                              .doc(fromUid)
                              .collection('Sent_Requests')
                              .doc(myUid);
                          batch.delete(sentRequestRef);

                          await batch.commit();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('친구 요청을 수락했습니다.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('친구 요청 수락 중 오류가 발생했습니다.')),
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
                              const SnackBar(
                                  content: Text('친구 요청 거절 중 오류가 발생했습니다.')),
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
    if (currentUser == null) return const Center(child: Text('로그인이 필요합니다'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('Sent_Requests')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return const Center(
            child: Text(
              '보낸 친구 요청이 없습니다.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
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
                          const SnackBar(
                              content: Text('친구 요청 취소 중 오류가 발생했습니다.')),
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

class _FriendSearchDialog extends StatefulWidget {
  const _FriendSearchDialog();

  @override
  State<_FriendSearchDialog> createState() => _FriendSearchDialogState();
}

class _FriendSearchDialogState extends State<_FriendSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  QueryDocumentSnapshot? _searchResult;
  bool _isSearching = false;
  String _error = '';

  Future<void> _searchNickname() async {
    setState(() {
      _isSearching = true;
      _searchResult = null;
      _error = '';
    });
    final nickname = _controller.text.trim();
    if (nickname.isEmpty) {
      setState(() {
        _isSearching = false;
        _error = '닉네임을 입력하세요.';
      });
      return;
    }
    try {
      final result = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: nickname)
          .limit(1)
          .get();
      if (result.docs.isNotEmpty) {
        setState(() {
          _searchResult = result.docs.first;
        });
      } else {
        setState(() {
          _error = '해당 닉네임의 사용자가 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _error = '검색 중 오류가 발생했습니다.';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_searchResult == null) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final targetUid = _searchResult!.id;
    final myUid = currentUser.uid;
    if (targetUid == myUid) {
      setState(() {
        _error = '본인에게 친구신청할 수 없습니다.';
      });
      return;
    }

    try {
      // 이미 친구인지 확인
      final friendCheck = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('Friends_Data')
          .doc(targetUid)
          .get();

      if (friendCheck.exists) {
        setState(() {
          _error = '이미 친구입니다.';
        });
        return;
      }

      // 이미 신청한 적이 있는지 확인 (보낸 요청에서 확인)
      final sentRequestCheck = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('Sent_Requests')
          .doc(targetUid)
          .get();

      if (sentRequestCheck.exists) {
        setState(() {
          _error = '이미 친구신청을 보냈습니다.';
        });
        return;
      }

      // 상대방의 받은 요청 컬렉션에 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('Received_Requests')
          .doc(myUid)
          .set({
        'from': myUid,
        'fromNickname': (await FirebaseFirestore.instance
            .collection('users')
            .doc(myUid)
            .get())
            .data()?['nickname'],
        'to': targetUid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending'
      });

      // 내 보낸 요청 컬렉션에도 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('Sent_Requests')
          .doc(targetUid)
          .set({
        'to': targetUid,
        'toNickname':
        (_searchResult!.data() as Map<String, dynamic>)['nickname'],
        'from': myUid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending'
      });

      setState(() {
        _error = '친구신청이 전송되었습니다!';
      });
    } catch (e) {
      setState(() {
        _error = '친구신청 중 오류가 발생했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF7F3FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 4),
                child: Text('친구 추가',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade300)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '닉네임 입력',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _searchNickname(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _isSearching ? null : _searchNickname,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isSearching) const CircularProgressIndicator(),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),
            if (_searchResult != null)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundImage: AssetImage(
                        'assets/img/runner_home.png'), // 프로필 이미지 없으면 기본 이미지
                  ),
                  title: Text(((_searchResult?.data()
                  as Map<String, dynamic>?)?['nickname'] ??
                      '')),
                  trailing: IconButton(
                    icon:
                    const Icon(Icons.add_circle, color: Colors.deepPurple),
                    onPressed: _sendFriendRequest,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}