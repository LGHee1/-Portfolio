import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Auth/login_screen.dart';
import 'workout_screen.dart';
import 'Calendar/calendar_screen.dart';
import 'Rank/ranking_screen.dart';
import 'friends_screen.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'Widgets/running_card_swiper.dart';
import 'profile_screen.dart';
import 'post/post_list.dart';

class ScreenHome extends StatefulWidget {
  const ScreenHome({super.key});

  @override
  State<ScreenHome> createState() => _ScreenHomeState();
}

class _ScreenHomeState extends State<ScreenHome> {
  int _selectedIndex = 1;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // users 컬렉션에서 직접 데이터 가져오기
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (mounted && userData.exists) {
          final nickname = userData.data()?['nickname'] ?? '';
          setState(() {
            _userName = nickname;
          });
          // Provider에도 저장
          Provider.of<UserProvider>(context, listen: false).setNickname(nickname);
          print('사용자 데이터 로드 성공: $nickname');
        } else {
          print('사용자 데이터가 존재하지 않음');
        }
      } catch (e) {
        print('사용자 데이터 로드 중 오류 발생: $e');
      }
    }
  }

  Future<void> _signOut() async {
    // 로그아웃 확인 대화상자 표시
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                '확인',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    // 사용자가 확인을 선택한 경우에만 로그아웃 실행
    if (shouldLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        print('로그아웃 중 오류 발생: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 앱바 (햄버거 버튼 고정)
      appBar: AppBar(
        backgroundColor: const Color(0xFFD8F9FF).withOpacity(1.0),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),

      // ✅ Drawer 설정
      drawer: Drawer(
        width: 240,
        backgroundColor: const Color(0xFFE5FBFF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // 햄버거 버튼 (닫기용)
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(height: 8),

            // 사용자 박스
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black26),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_circle, size: 36, color: Colors.grey),
                      const SizedBox(height: 4),
                      Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 내정보 버튼
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileScreen()),
                  );
                },
                child: const Text(
                  '내정보',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // 랭킹 버튼
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RankingScreen()),
                  );
                },
                child: const Text(
                  '랭킹',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // 기록 버튼
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CalendarScreen()),
                  );
                },
                child: const Text(
                  '기록',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // 나머지 메뉴 항목들
            ...['친구관리', '문의', '환경 설정'].map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
                child: InkWell(
                  onTap: () {
                    if (item == '친구관리') {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FriendsScreen()),
                      );
                    }
                  },
                  child: Text(item, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              );
            }).toList(),

            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 12),
              child: InkWell(
                onTap: _signOut,
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      '로그아웃',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ✅ 홈 버튼
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber.shade100,
        onPressed: () {
          setState(() {
            _selectedIndex = 1;
          });
        },
        child: Icon(
          Icons.home,
          color: _selectedIndex == 1 ? Colors.black : Colors.grey,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ✅ 하단 네비게이션 바
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.directions_run,
                  color: _selectedIndex == 0 ? Colors.amber : Colors.black,
                ),
                onPressed: () {
                  setState(() => _selectedIndex = 0);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WorkoutScreen()),
                  );
                },
              ),

              IconButton(
                icon: Icon(
                  Icons.star_border,
                  color: _selectedIndex == 2 ? Colors.amber : Colors.black,
                ),
                onPressed: () {
                  setState(() => _selectedIndex = 2);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PostListPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // ✅ 본문
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/img/runner_home.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: const Color(0xFFE5FBFF).withOpacity(0.5)),
          ),
          SafeArea(
            child: Container(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      '안녕하세요, $_userName님 👋',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '오늘도 건강하게 달려봐요!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const RunningCardSwiper(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}