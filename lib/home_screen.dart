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
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃 중 오류가 발생했습니다.')),
      );
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
              child: IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _signOut,
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