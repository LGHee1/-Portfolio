import 'package:flutter/material.dart';
import '../../models/ranking_data.dart';
import '../../utils/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class UserMedalsScreen extends StatefulWidget {
  final RankingData userData;

  const UserMedalsScreen({Key? key, required this.userData}) : super(key: key);

  @override
  _UserMedalsScreenState createState() => _UserMedalsScreenState();
}

class _UserMedalsScreenState extends State<UserMedalsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<int, double> _monthlyDistances = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserWorkoutHistory();
  }

  Future<void> _loadUserWorkoutHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 연도의 시작일과 종료일 계산
      final now = DateTime.now();
      final firstDayOfYear = DateTime(now.year, 1, 1);
      final lastDayOfYear = DateTime(now.year, 12, 31);

      // 사용자의 올해 운동 데이터 가져오기
      final snapshot = await _firestore
          .collection('users')
          .doc(widget.userData.userId)
          .collection('Running_Data')
          .where('date', isGreaterThanOrEqualTo: firstDayOfYear)
          .where('date', isLessThanOrEqualTo: lastDayOfYear)
          .get();

      // 월별 거리 계산
      Map<int, double> monthlyDistances = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final month = date.month;
        final distance = (data['distance'] as num).toDouble();

        monthlyDistances[month] = (monthlyDistances[month] ?? 0) + distance;
      }

      setState(() {
        _monthlyDistances = monthlyDistances;
        _isLoading = false;
      });
    } catch (e) {
      print('운동 기록 로드 중 오류 발생: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '${widget.userData.name} 랭킹 기록',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
          strokeWidth: 2.w,
        ),
      )
          : Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            margin: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.primaryColor.withOpacity(0.05),
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
                      widget.userData.name,
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
                        color: _getLevelColor(widget.userData.level)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        widget.userData.level,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: _getLevelColor(widget.userData.level),
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
                      '${widget.userData.totalDistance.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0066CC), // 더 진한 파란색
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'km',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0066CC)
                            .withOpacity(0.9), // 더 진한 파란색
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
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(16.w),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16.w,
                mainAxisSpacing: 16.h,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final distance = _monthlyDistances[month];
                final medal = distance != null
                    ? RankingData.calculateMedal(distance)
                    : null;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppTheme.lightTextColor.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$month월',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkTextColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      if (medal != null) ...[
                        Icon(
                          Icons.emoji_events,
                          color: _getMedalColor(medal),
                          size: 32.w,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          medal,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: _getMedalColor(medal),
                            letterSpacing: -0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (distance != null)
                          Text(
                            '${distance.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0066CC), // 더 진한 파란색
                              letterSpacing: -0.3,
                            ),
                          ),
                        Text(
                          'km',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0066CC)
                                .withOpacity(0.9), // 더 진한 파란색
                            letterSpacing: -0.2,
                          ),
                        ),
                      ] else
                        Icon(
                          Icons.emoji_events_outlined,
                          color: AppTheme.lightTextColor.withOpacity(0.3),
                          size: 32.w,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getMedalColor(String medal) {
    if (medal.contains('금메달')) return Color(0xFFFFD700); // 더 진한 금색
    if (medal.contains('은메달')) return Color(0xFFA9A9A9); // 더 진한 은색
    if (medal.contains('동메달')) return Color(0xFF8B4513); // 더 진한 동색
    return AppTheme.lightTextColor;
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
}