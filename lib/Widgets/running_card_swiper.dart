import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RunningCardSwiper extends StatefulWidget {
  const RunningCardSwiper({super.key});

  @override
  State<RunningCardSwiper> createState() => _RunningCardSwiperState();
}

class _RunningCardSwiperState extends State<RunningCardSwiper> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<Map<String, dynamic>> _workoutData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentWorkouts();
  }

  Future<void> _loadRecentWorkouts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Running_Data')
          .orderBy('date', descending: true)
          .limit(3)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> workouts = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          '거리': '${(data['distance'] as num).toDouble().toStringAsFixed(1)}km',
          '시간': '${(data['duration'] as int) ~/ 60}분 ${(data['duration'] as int) % 60}초',
          '칼로리': '${data['calories']} kcal',
          '메시지': _getMotivationalMessage((data['distance'] as num).toDouble()),
          'date': (data['date'] as Timestamp).toDate(),
        };
      }).toList();

      setState(() {
        _workoutData = workouts;
        _isLoading = false;
      });
    } catch (e) {
      print('운동 데이터 로드 중 오류 발생: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getMotivationalMessage(double distance) {
    if (distance >= 10) {
      return '멋진 기록이에요! 👏';
    } else if (distance >= 5) {
      return '꾸준함이 답입니다! 💪';
    } else if (distance >= 3) {
      return '오늘 하루도 파이팅!!! ✨';
    } else {
      return '가볍게 몸을 풀었어요! 🌟';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 화면 크기 정보 가져오기
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // 동적 크기 계산
    final cardHeight = screenHeight * 0.5; // 화면 높이의 50%
    final cardPadding = screenWidth * 0.06; // 화면 너비의 6%
    final cardMargin = screenWidth * 0.05; // 화면 너비의 5%
    final textFontSize = screenWidth * 0.04; // 화면 너비의 4%
    final messageFontSize = screenWidth * 0.045; // 화면 너비의 4.5%
    final spacing = screenHeight * 0.015; // 화면 높이의 1.5%
    final dotSize = screenWidth * 0.015; // 화면 너비의 1.5%
    final activeDotSize = screenWidth * 0.03; // 화면 너비의 3%

    if (_workoutData.isEmpty) {
      return Container(
        height: cardHeight,
        margin: EdgeInsets.symmetric(horizontal: cardMargin, vertical: spacing),
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blueAccent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '최근 운동 기록이 없습니다',
            style: TextStyle(
              fontSize: messageFontSize,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _workoutData.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final item = _workoutData[index];
              return Container(
                margin: EdgeInsets.symmetric(horizontal: cardMargin, vertical: spacing),
                padding: EdgeInsets.all(cardPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _infoText('러닝 거리', item['거리']!, textFontSize),
                    SizedBox(height: spacing),
                    _infoText('러닝 시간', item['시간']!, textFontSize),
                    SizedBox(height: spacing),
                    _infoText('소모 칼로리', item['칼로리']!, textFontSize),
                    SizedBox(height: spacing * 1.5),
                    Text(
                      item['메시지']!,
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: messageFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: spacing),
                    Text(
                      '${item['date'].year}년 ${item['date'].month}월 ${item['date'].day}일',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: textFontSize * 0.9,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_workoutData.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _currentPage == index ? activeDotSize : dotSize,
              height: dotSize,
              margin: EdgeInsets.symmetric(horizontal: dotSize * 0.3),
              decoration: BoxDecoration(
                color: _currentPage == index ? Colors.black : Colors.grey,
                borderRadius: BorderRadius.circular(dotSize * 0.5),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _infoText(String label, String value, double fontSize) {
    return Text(
      '$label : $value',
      style: TextStyle(
        fontSize: fontSize,
        color: Colors.blue,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}