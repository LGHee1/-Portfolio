class RankingData {
  final String userId;
  final String name;
  final double totalDistance;
  final int rank;
  final String level;
  final String medal;
  final int levelRank;
  final Map<int, double> monthlyMedals;

  RankingData({
    required this.userId,
    required this.name,
    required this.totalDistance,
    required this.rank,
    String? level,
    String? medal,
    int? levelRank,
    Map<int, double>? monthlyMedals,
  })  : level = level ?? calculateLevel(totalDistance),
        medal = medal ?? calculateMedal(totalDistance),
        levelRank = levelRank ?? rank,
        monthlyMedals = monthlyMedals ?? {};

  RankingData copyWith({
    String? userId,
    String? name,
    double? totalDistance,
    int? rank,
    String? level,
    String? medal,
    int? levelRank,
    Map<int, double>? monthlyMedals,
  }) {
    return RankingData(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      totalDistance: totalDistance ?? this.totalDistance,
      rank: rank ?? this.rank,
      level: level ?? this.level,
      medal: medal ?? this.medal,
      levelRank: levelRank ?? this.levelRank,
      monthlyMedals: monthlyMedals ?? Map<int, double>.from(this.monthlyMedals),
    );
  }

  static String calculateLevel(double distance) {
    if (distance >= 60) return '상급자';
    if (distance >= 30) return '중급자';
    return '초급자';
  }

  static String calculateMedal(double distance) {
    // 상급자 메달
    if (distance >= 100) return '최고급 금메달';
    if (distance >= 80) return '최고급 은메달';
    if (distance >= 60) return '최고급 동메달';

    // 중급자 메달
    if (distance >= 50) return '고급 금메달';
    if (distance >= 40) return '고급 은메달';
    if (distance >= 30) return '고급 동메달';

    // 초급자 메달
    if (distance >= 25) return '금메달';
    if (distance >= 15) return '은메달';
    if (distance >= 10) return '동메달';

    return '도전 중';
  }
}

// 임시 데이터 - 나중에 데이터베이스로 대체될 예정
final List<RankingData> dummyRankingData = [
  // 상급자
  RankingData(
    userId: 'user1',
    name: '김철수',
    totalDistance: 107.0,
    rank: 1,
    monthlyMedals: {
      1: 110.0,
      2: 80.0,
      3: 65.0,
      4: 70.0,
      5: 95.0,
      6: 100.0,
    },
  ),
  // ... 나머지 데이터는 동일하게 유지
];

// 현재 사용자 ID (나중에 인증 시스템에서 가져올 예정)
const currentUserId = 'user7'; 