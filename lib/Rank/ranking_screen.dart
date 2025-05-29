import 'package:flutter/material.dart';
import '../../models/ranking_data.dart';
import '../../utils/theme.dart';
import 'user_medals_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../Widgets/bottom_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RankingScreen extends StatefulWidget {
  @override
  _RankingScreenState createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String selectedLevel = '전체';
  List<RankingData> _rankingData = [];
  bool _isLoading = true;
  RankingData? _currentUser;
  int _selectedIndex = 1;
  List<Map<String, dynamic>> _userData = [];

  @override
  void initState() {
    super.initState();
    _loadRankingData();
  }

  Future<void> _loadRankingData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      List<Map<String, dynamic>> userData = [];
      String? currentUserId = _auth.currentUser?.uid;

      for (var userDoc in usersSnapshot.docs) {
        try {
          final workoutSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('Running_Data')
              .get();

          double totalDistance = 0;
          Map<String, double> dailyDistances = {};

          for (var workoutDoc in workoutSnapshot.docs) {
            final workoutData = workoutDoc.data();
            final date = (workoutData['date'] as Timestamp).toDate();
            final dateKey =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final distance = (workoutData['distance'] as num).toDouble();

            totalDistance += distance;
            dailyDistances[dateKey] = (dailyDistances[dateKey] ?? 0) + distance;
          }

          String level = '초급자';
          if (totalDistance >= 60) {
            level = '상급자';
          } else if (totalDistance >= 30) {
            level = '중급자';
          }

          userData.add({
            'userId': userDoc.id,
            'nickname': userDoc.data()['nickname'] ?? '알 수 없음',
            'totalDistance': totalDistance,
            'dailyDistances': dailyDistances,
            'level': level,
          });
        } catch (e) {
          print('사용자 ${userDoc.id}의 데이터 로드 중 오류: $e');
        }
      }

      // 거리순으로 정렬
      userData.sort((a, b) => (b['totalDistance'] as double)
          .compareTo(a['totalDistance'] as double));

      // RankingData 객체로 변환
      List<RankingData> rankingData = userData.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        return RankingData(
          userId: data['userId'],
          name: data['nickname'],
          totalDistance: data['totalDistance'],
          rank: index + 1,
          level: data['level'],
          monthlyMedals: {},
        );
      }).toList();

      setState(() {
        _rankingData = rankingData;
        _currentUser = rankingData.firstWhere(
          (data) => data.userId == currentUserId,
          orElse: () => rankingData.first,
        );
        _isLoading = false;
      });
    } catch (e) {
      print('랭킹 데이터 로드 중 오류 발생: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sortUserData() {
    if (_userData.isEmpty) return;

    // 거리순으로 정렬
    _userData.sort((a, b) =>
        (b['totalDistance'] as double).compareTo(a['totalDistance'] as double));

    // RankingData 객체로 변환
    _rankingData = _userData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      String level = '초급자';
      if (data['totalDistance'] >= 60) {
        level = '상급자';
      } else if (data['totalDistance'] >= 30) {
        level = '중급자';
      }

      return RankingData(
        userId: data['userId'],
        name: data['nickname'],
        totalDistance: data['totalDistance'],
        rank: index + 1,
        level: level,
        monthlyMedals: {},
      );
    }).toList();

    // 현재 사용자 정보 업데이트
    String? currentUserId = _auth.currentUser?.uid;
    _currentUser = _rankingData.firstWhere(
      (data) => data.userId == currentUserId,
      orElse: () => _rankingData.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            '${DateTime.now().month}월 달 랭킹',
            style: TextStyle(
              fontSize: 22.sp,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
            strokeWidth: 2.w,
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('${DateTime.now().month}월 달 랭킹'),
          centerTitle: true,
        ),
        body: Center(
          child: Text(
            '사용자 정보를 불러올 수 없습니다.',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.lightTextColor,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '${DateTime.now().month}월 달 랭킹',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildMyStatus(_currentUser!),
          _buildLevelSelector(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '랭킹',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkTextColor,
                    letterSpacing: -0.3,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        title: Text(
                          '✨ 등급 기준 안내 ✨',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLevelInfoRow('초급자', '0 ~ 30km', Colors.blue),
                            SizedBox(height: 12.h),
                            _buildLevelInfoRow(
                                '중급자', '30 ~ 60km', Colors.green),
                            SizedBox(height: 12.h),
                            _buildLevelInfoRow('상급자', '60km 이상', Colors.purple),
                          ],
                        ),
                        actions: [
                          Center(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24.w,
                                  vertical: 12.h,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Text(
                                '확인',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.info_outline,
                    size: 18.w,
                    color: const Color.fromARGB(255, 143, 234, 255),
                  ),
                  label: Text(
                    '등급 기준 보기',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color.fromARGB(255, 31, 208, 248),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildRankingList(_currentUser!),
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

  Widget _buildLevelInfoRow(String level, String range, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            level,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            range,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: color.withOpacity(0.8),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyStatus(RankingData currentUser) {
    return Container(
      padding: EdgeInsets.all(20.w),
      margin: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color.fromARGB(255, 126, 205, 237).withOpacity(0.1),
            const Color.fromARGB(255, 126, 205, 237).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentUser.name,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkTextColor,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 6.h,
                ),
                decoration: BoxDecoration(
                  color: _getLevelColor(currentUser.level).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  currentUser.level,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: _getLevelColor(currentUser.level),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${currentUser.totalDistance.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0066CC),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'km',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0066CC).withOpacity(0.9),
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '이번 달',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppTheme.lightTextColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSelector() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: ['전체', '초급자', '중급자', '상급자'].map((level) {
            final isSelected = selectedLevel == level;
            return Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedLevel = level;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF0066CC) : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Color(0xFF0066CC)
                          : AppTheme.lightTextColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(25.r),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Color(0xFF0066CC).withOpacity(0.2),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    level,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          isSelected ? Colors.white : AppTheme.lightTextColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRankingList(RankingData currentUser) {
    // 선택된 레벨에 따라 필터링
    var filteredList = _rankingData.where((data) {
      if (selectedLevel == '전체') return true;
      return data.level == selectedLevel;
    }).toList();

    // 레벨별 순위 계산
    if (selectedLevel != '전체') {
      // 같은 레벨 내에서 거리순으로 정렬
      filteredList.sort((a, b) => b.totalDistance.compareTo(a.totalDistance));
      // 레벨 내 순위 재할당
      for (var i = 0; i < filteredList.length; i++) {
        filteredList[i] = filteredList[i].copyWith(levelRank: i + 1);
      }
    }

    // 상위 10명 추출
    var displayList = filteredList.take(10).toList();

    // 현재 사용자가 선택된 레벨에 속하는지 확인
    final isUserInSelectedLevel =
        selectedLevel == '전체' || currentUser.level == selectedLevel;

    if (isUserInSelectedLevel) {
      // 현재 사용자의 순위 정보
      final userRankInfo = filteredList.firstWhere(
        (data) => data.userId == currentUser.userId,
        orElse: () => currentUser,
      );
      final isUserInTop10 =
          displayList.any((data) => data.userId == currentUser.userId);

      // 현재 사용자가 상위 10등 밖이면 구분선과 함께 추가
      if (!isUserInTop10) {
        displayList.add(RankingData(
          userId: 'ellipsis',
          name: '...',
          totalDistance: 0,
          rank: -1,
          monthlyMedals: {},
        ));
        displayList.add(userRankInfo);
      }
    }

    if (displayList.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            '해당 레벨에 러너가 없습니다.',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.lightTextColor,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      physics: AlwaysScrollableScrollPhysics(),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final data = displayList[index];

        if (data.userId == 'ellipsis') {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50.w,
                  height: 1.h,
                  color: AppTheme.lightTextColor.withOpacity(0.2),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Text(
                    '...',
                    style: TextStyle(
                      fontSize: 20.sp,
                      color: AppTheme.lightTextColor,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Container(
                  width: 50.w,
                  height: 1.h,
                  color: AppTheme.lightTextColor.withOpacity(0.2),
                ),
              ],
            ),
          );
        }

        final isCurrentUser = data.userId == currentUser.userId;
        final rank = selectedLevel == '전체' ? data.rank : data.levelRank;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserMedalsScreen(
                  userData: data.copyWith(
                    monthlyMedals: data.monthlyMedals,
                  ),
                ),
              ),
            );
          },
          child: Container(
            margin: EdgeInsets.only(
              bottom: index == displayList.length - 1 ? 16.h : 8.h,
            ),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? const Color.fromARGB(255, 133, 214, 246).withOpacity(0.1)
                  : Colors.white,
              border: Border.all(
                color: isCurrentUser
                    ? const Color.fromARGB(255, 126, 205, 237).withOpacity(0.1)
                    : AppTheme.lightTextColor.withOpacity(0.1),
                width: isCurrentUser ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: isCurrentUser
                  ? [
                      BoxShadow(
                        color: const Color.fromARGB(255, 126, 205, 237)
                            .withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: _getRankColor(rank).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: _getRankColor(rank),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            data.name,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: isCurrentUser
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppTheme.darkTextColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (selectedLevel != '전체' &&
                              data.medal != '도전 중') ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _getMedalColor(data.medal).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                data.medal,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _getMedalColor(data.medal),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (selectedLevel == '전체') ...[
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: _getLevelColor(data.level).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            data.level,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: _getLevelColor(data.level),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${data.totalDistance.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0066CC),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'km',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0066CC).withOpacity(0.9),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case '초급자':
        return Colors.blue;
      case '중급자':
        return Colors.green;
      case '상급자':
        return Colors.purple;
      default:
        return AppTheme.primaryColor;
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Color(0xFFFFD700);
      case 2:
        return Color(0xFFA9A9A9);
      case 3:
        return Color(0xFF8B4513);
      default:
        return AppTheme.darkTextColor;
    }
  }

  Color _getMedalColor(String medal) {
    if (medal.contains('금메달')) return Color(0xFFFFD700);
    if (medal.contains('은메달')) return Color(0xFFA9A9A9);
    if (medal.contains('동메달')) return Color(0xFF8B4513);
    return AppTheme.lightTextColor;
  }
}