import 'package:flutter/material.dart';
import '../../models/ranking_data.dart';
import '../../utils/theme.dart';
import 'user_medals_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _loadRankingData();
  }

  Future<void> _loadRankingData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      // 현재 달의 시작일과 종료일 계산
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      // Timestamp로 변환
      final firstDayTimestamp = Timestamp.fromDate(firstDayOfMonth);
      final lastDayTimestamp = Timestamp.fromDate(lastDayOfMonth);

      // 모든 사용자 데이터 가져오기
      final usersSnapshot = await _firestore.collection('users').get();
      List<RankingData> rankingList = [];

      for (var userDoc in usersSnapshot.docs) {
        try {
          print('사용자 ${userDoc.id}의 데이터 로드 시작'); // 디버깅용 로그

          // 사용자의 이번 달 운동 데이터 가져오기
          final workoutSnapshot = await _firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('Running_Data')
              .where('date', isGreaterThanOrEqualTo: firstDayTimestamp)
              .where('date', isLessThanOrEqualTo: lastDayTimestamp)
              .get();

          print(
              '사용자 ${userDoc.id}의 운동 기록 수: ${workoutSnapshot.docs.length}'); // 디버깅용 로그

          // 날짜별 거리 합산을 위한 Map
          Map<String, double> dailyDistances = {};

          // 총 거리 계산 (운동 기록이 없는 경우 0으로 설정)
          double totalDistance = 0;
          if (workoutSnapshot.docs.isNotEmpty) {
            for (var workout in workoutSnapshot.docs) {
              final workoutData = workout.data();
              print('운동 기록 데이터: $workoutData'); // 디버깅용 로그

              // date가 Timestamp인지 확인하고 적절히 처리
              DateTime workoutDate;
              if (workoutData['date'] is Timestamp) {
                workoutDate = (workoutData['date'] as Timestamp).toDate();
              } else if (workoutData['date'] is String) {
                workoutDate = DateTime.parse(workoutData['date']);
              } else {
                print('알 수 없는 날짜 형식: ${workoutData['date']}');
                continue;
              }

              // 이번 달 데이터인지 확인
              if (workoutDate.year == now.year &&
                  workoutDate.month == now.month) {
                // 날짜를 문자열 키로 변환 (YYYY-MM-DD 형식)
                final dateKey =
                    '${workoutDate.year}-${workoutDate.month.toString().padLeft(2, '0')}-${workoutDate.day.toString().padLeft(2, '0')}';

                // distance 값이 null이 아닌지 확인
                if (workoutData['distance'] != null) {
                  final distance = (workoutData['distance'] as num).toDouble();
                  print('날짜: $dateKey, 거리: $distance'); // 디버깅용 로그

                  // 해당 날짜의 거리를 누적
                  dailyDistances[dateKey] =
                      (dailyDistances[dateKey] ?? 0) + distance;
                }
              }
            }

            // 모든 날짜의 거리를 합산
            totalDistance = dailyDistances.values
                .fold(0.0, (sum, distance) => sum + distance);
            print('사용자 ${userDoc.id}의 총 거리: $totalDistance'); // 디버깅용 로그
          }

          // 레벨 결정 (운동 기록이 없는 경우 '초급자'로 설정)
          String level;
          if (totalDistance >= 60) {
            level = '상급자';
          } else if (totalDistance >= 30) {
            level = '중급자';
          } else {
            level = '초급자';
          }

          final userData = RankingData(
            userId: userDoc.id,
            name: userDoc.data()['nickname'] ?? 'Unknown User',
            totalDistance: totalDistance,
            level: level,
            rank: 0,
            levelRank: 0,
            monthlyMedals: {},
          );

          rankingList.add(userData);
          print(
              '사용자 ${userDoc.id}의 랭킹 데이터 추가 완료: ${userData.name}, 거리: ${userData.totalDistance}'); // 디버깅용 로그

          // 현재 사용자 데이터 저장
          if (userDoc.id == currentUser.uid) {
            _currentUser = userData;
          }
        } catch (e) {
          print('사용자 ${userDoc.id}의 데이터 로드 중 오류: $e');
          // 오류가 발생한 사용자도 기본 데이터로 추가
          final userData = RankingData(
            userId: userDoc.id,
            name: userDoc.data()['nickname'] ?? 'Unknown User',
            totalDistance: 0,
            level: '초급자',
            rank: 0,
            levelRank: 0,
            monthlyMedals: {},
          );
          rankingList.add(userData);

          if (userDoc.id == currentUser.uid) {
            _currentUser = userData;
          }
        }
      }

      // 전체 순위 계산
      rankingList.sort((a, b) => b.totalDistance.compareTo(a.totalDistance));
      for (var i = 0; i < rankingList.length; i++) {
        rankingList[i] = rankingList[i].copyWith(rank: i + 1);
      }

      print(
          '최종 랭킹 데이터: ${rankingList.map((r) => '${r.name}: ${r.totalDistance}km').join(', ')}'); // 디버깅용 로그

      setState(() {
        _rankingData = rankingList;
        _isLoading = false;
      });
    } catch (e) {
      print('랭킹 데이터 로드 중 오류 발생: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('${DateTime.now().month}월 달 랭킹'),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator()),
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
        title: Text('${DateTime.now().month}월 달 랭킹'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildMyStatus(_currentUser!),
          _buildLevelSelector(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '랭킹',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkTextColor,
                  ),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Color(0xFFCCF6FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Text(
                              '✨ 등급 기준 안내 ✨',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            content: Text(
                              '초급자 : 0 ~ 30km\n중급자 : 30 ~ 60km\n상급자 : 60km 이상',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            actions: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text('확인'),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text(
                        '등급 기준 보기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.lightTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildRankingList(_currentUser!),
          ),
        ],
      ),
    );
  }

  Widget _buildMyStatus(RankingData currentUser) {
    return Container(
      padding: EdgeInsets.all(20),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
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
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '${currentUser.level}',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.lightTextColor,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${currentUser.totalDistance.toStringAsFixed(1)}km',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '이번 달',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.lightTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            children: ['전체', '초급자', '중급자', '상급자'].map((level) {
              final isSelected = selectedLevel == level;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedLevel = level;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? AppTheme.primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.lightTextColor.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    level,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.black : AppTheme.lightTextColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
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
      padding: EdgeInsets.symmetric(horizontal: 16),
      physics: AlwaysScrollableScrollPhysics(),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final data = displayList[index];

        if (data.userId == 'ellipsis') {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 1,
                  color: AppTheme.lightTextColor.withOpacity(0.2),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '...',
                    style: TextStyle(
                      fontSize: 20,
                      color: AppTheme.lightTextColor,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Container(
                  width: 50,
                  height: 1,
                  color: AppTheme.lightTextColor.withOpacity(0.2),
                ),
              ],
            ),
          );
        }

        final isCurrentUser = data.userId == currentUser.userId;

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
                bottom: index == displayList.length - 1 ? 16 : 8),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.white,
              border: Border.all(
                color: AppTheme.lightTextColor.withOpacity(0.1),
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isCurrentUser
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  child: Text(
                    selectedLevel == '전체'
                        ? '${data.rank}'
                        : '${data.levelRank}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getRankColor(
                          selectedLevel == '전체' ? data.rank : data.levelRank),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            data.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isCurrentUser
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (selectedLevel != '전체' &&
                              data.medal != '도전 중') ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    _getMedalColor(data.medal).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                data.medal,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getMedalColor(data.medal),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (selectedLevel == '전체') ...[
                        SizedBox(height: 4),
                        Text(
                          data.level,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.lightTextColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${data.totalDistance.toStringAsFixed(1)}km',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.brown;
      default:
        return AppTheme.darkTextColor;
    }
  }

  Color _getMedalColor(String medal) {
    if (medal.contains('금메달')) return Colors.amber;
    if (medal.contains('은메달')) return Colors.grey[400]!;
    if (medal.contains('동메달')) return Colors.brown;
    return AppTheme.lightTextColor;
  }
}