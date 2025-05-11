import 'package:flutter/material.dart';
import '../../models/workout_record.dart';
import '../../utils/theme.dart';
import 'package:intl/intl.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final WorkoutRecord record;

  const WorkoutDetailScreen({Key? key, required this.record}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('yyyy년 M월 d일').format(record.date),
          style: TextStyle(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildMap(),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '운동 정보',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildStatsGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      height: 250,
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          '지도 영역',
          style: TextStyle(
            color: AppTheme.lightTextColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildStatItem('거리', '${record.distance.toStringAsFixed(2)} km'),
        _buildStatItem('시간', '${record.duration.inMinutes} 분'),
        _buildStatItem('케이던스', '${record.cadence} spm'),
        _buildStatItem('평균 페이스', '${record.pace.toStringAsFixed(2)} /km'),
        _buildStatItem('칼로리', '${record.calories} kcal'),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.lightTextColor,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.darkTextColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}