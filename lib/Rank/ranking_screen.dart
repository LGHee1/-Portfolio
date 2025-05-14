import 'package:flutter/material.dart';
import '../Models/ranking_data.dart';
import '../Utils/theme.dart';
import 'user_medals_screen.dart';

class RankingScreen extends StatefulWidget {
  @override
  _RankingScreenState createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  String selectedLevel = '전체'; // '전체', '초급자', '중급자', '상급자'

  @override
  Widget build(BuildContext context) {
    // 현재 사용자의 데이터 가져오기
    final currentUser =
    dummyRankingData.firstWhere((data) => data.userId == currentUserId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${DateTime.now().month}월 달 랭킹'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildMyStatus(currentUser),
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
                            backgroundColor: Color(0xFFCCF6FF), // 배경색
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
                          //decoration: TextDecoration.underline,
                        ),
                      ),
                    ),

                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildRankingList(currentUser),
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
                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
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
                      color: isSelected ? Colors.black : AppTheme.lightTextColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    var filteredList = dummyRankingData.where((data) {
      if (selectedLevel == '전체') return true;
      return data.level == selectedLevel;
    }).toList();

    // 레벨별 순위 계산
    if (selectedLevel != '전체') {
      // 같은 레벨 내에서 거리순으로 정렬
      filteredList.sort((a, b) => b.totalDistance.compareTo(a.totalDistance));
      // 레벨 내 순위 재할당
      for (var i = 0; i < filteredList.length; i++) {
        filteredList[i] = RankingData(
          userId: filteredList[i].userId,
          name: filteredList[i].name,
          totalDistance: filteredList[i].totalDistance,
          rank: filteredList[i].rank,
          levelRank: i + 1,
          monthlyMedals: filteredList[i].monthlyMedals,
        );
      }
    } else {
      // 전체 순위일 경우 기존 rank 사용
      filteredList.sort((a, b) => a.rank.compareTo(b.rank));
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