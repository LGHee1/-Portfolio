import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Auth/login_screen.dart';
import 'Running/workout_screen.dart';
import 'Calendar/calendar_screen.dart';
import 'Rank/ranking_screen.dart';
import 'Friends/friends_screen.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'Widgets/running_card_swiper.dart';
import 'Profile/profile_screen.dart';
import 'Post/post_list.dart';
import 'Widgets/menu.dart';
import 'Widgets/bottom_bar.dart';

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
          Provider.of<UserProvider>(context, listen: false)
              .setNickname(nickname);
          print('사용자 데이터 로드 성공: $nickname');
        } else {
          print('사용자 데이터가 존재하지 않음');
        }
      } catch (e) {
        print('사용자 데이터 로드 중 오류 발생: $e');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 다시 표시될 때마다 사용자 데이터 새로고침
    _loadUserData();
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
    // 화면 크기 정보 가져오기
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // 동적 크기 계산
    final titleFontSize = screenWidth * 0.06; // 화면 너비의 6%
    final subtitleFontSize = screenWidth * 0.04; // 화면 너비의 4%
    final padding = screenWidth * 0.06; // 화면 너비의 6%
    final spacing = screenHeight * 0.02; // 화면 높이의 2%

    return Scaffold(
      // ✅ 앱바 (햄버거 버튼 고정)
      appBar: AppBar(
        backgroundColor: const Color(0xFFD8F9FF).withOpacity(1.0),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.black, size: titleFontSize * 0.8),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),

      // ✅ Drawer 설정
      drawer: const Menu(),

      // ✅ 하단 네비게이션 바
      bottomNavigationBar: BottomBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() => _selectedIndex = index);
          // 기존 네비게이션 동작 유지
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WorkoutScreen()),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PostListPage()),
            );
          }
        },
      ),

      // ✅ 본문
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/img/runner_home.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Container(
              color: const Color(0xFFE5FBFF).withOpacity(0.5),
              width: double.infinity,
              height: double.infinity,
            ),
            SafeArea(
              child: Container(
                color: Colors.transparent,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: spacing * 0.5),
                      Text(
                        '안녕하세요, $_userName님 👋',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: spacing * 0.5),
                      Text(
                        '오늘도 건강하게 달려봐요!',
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: spacing * 1.5),
                      const RunningCardSwiper(),
                      SizedBox(height: spacing),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}