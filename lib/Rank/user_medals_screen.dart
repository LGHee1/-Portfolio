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
        title: Text('${widget.userData.name} 랭킹 기록'),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
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
                            widget.userData.name,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkTextColor,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            widget.userData.level,
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
                            '${widget.userData.totalDistance.toStringAsFixed(1)}km',
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
                ),
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
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
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.lightTextColor.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$month월',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkTextColor,
                              ),
                            ),
                            SizedBox(height: 8),
                            if (medal != null) ...[
                              Icon(
                                Icons.emoji_events,
                                color: _getMedalColor(medal),
                                size: 32,
                              ),
                              SizedBox(height: 4),
                              Text(
                                medal,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getMedalColor(medal),
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (distance != null)
                                Text(
                                  '${distance.toStringAsFixed(1)}km',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.lightTextColor),
                                ),
                            ] else
                              Icon(
                                Icons.emoji_events_outlined,
                                color: AppTheme.lightTextColor.withOpacity(0.3),
                                size: 32,
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
    if (medal.contains('금메달')) return Colors.amber;
    if (medal.contains('은메달')) return Colors.grey[400]!;
    if (medal.contains('동메달')) return Colors.brown;
    return AppTheme.lightTextColor;
  }
}