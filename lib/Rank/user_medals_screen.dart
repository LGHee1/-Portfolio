import 'package:flutter/material.dart';
import '../Models/ranking_data.dart';
import '../Utils/theme.dart';

class UserMedalsScreen extends StatelessWidget {
  final RankingData userData;

  const UserMedalsScreen({Key? key, required this.userData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${userData.name} 랭킹 기록'),
        centerTitle: true,
      ),
      body: Column(
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
                      userData.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkTextColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      userData.level,
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
                      '${userData.totalDistance.toStringAsFixed(1)}km',
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
                final distance = userData.monthlyMedals[month];
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
                                fontSize: 10, color: AppTheme.lightTextColor),
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