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
  RankingData(
    userId: 'user2',
    name: '이영희',
    totalDistance: 95.5,
    rank: 2,
    monthlyMedals: {
      1: 60.0,
      2: 95.0,
      3: 80.0,
      4: 85.0,
      7: 90.0,
      8: 70.0,
    },
  ),
  RankingData(
    userId: 'user3',
    name: '박지민',
    totalDistance: 85.2,
    rank: 3,
    monthlyMedals: {
      2: 80.0,
      4: 65.0,
      6: 100.0,
    },
  ),
  RankingData(
    userId: 'user4',
    name: '최동욱',
    totalDistance: 75.8,
    rank: 4,
    monthlyMedals: {
      1: 60.0,
      3: 100.0,
      5: 95.0,
    },
  ),
  RankingData(
    userId: 'user5',
    name: '정수진',
    totalDistance: 65.0,
    rank: 5,
    monthlyMedals: {
      2: 100.0,
      4: 85.0,
      6: 90.0,
    },
  ),

  // 중급자
  RankingData(
    userId: 'user6',
    name: '강민서',
    totalDistance: 55.3,
    rank: 6,
    monthlyMedals: {
      1: 100.0,
      3: 85.0,
      5: 90.0,
    },
  ),
  RankingData(
    userId: 'user8',
    name: '윤서준',
    totalDistance: 52.1,
    rank: 7,
    monthlyMedals: {
      2: 90.0,
      4: 100.0,
      6: 85.0,
    },
  ),
  RankingData(
    userId: 'user9',
    name: '임하늘',
    totalDistance: 48.5,
    rank: 8,
    monthlyMedals: {
      1: 85.0,
      3: 90.0,
      5: 100.0,
    },
  ),
  RankingData(
    userId: 'user10',
    name: '한도윤',
    totalDistance: 45.2,
    rank: 9,
    monthlyMedals: {
      2: 100.0,
      4: 90.0,
      6: 85.0,
    },
  ),
  RankingData(
    userId: 'user11',
    name: '송지원',
    totalDistance: 42.8,
    rank: 10,
    monthlyMedals: {
      1: 90.0,
      3: 85.0,
      5: 100.0,
    },
  ),
  RankingData(
    userId: 'user12',
    name: '오민준',
    totalDistance: 40.1,
    rank: 11,
    monthlyMedals: {
      2: 85.0,
      4: 100.0,
      6: 90.0,
    },
  ),
  RankingData(
    userId: 'user13',
    name: '신예진',
    totalDistance: 38.5,
    rank: 12,
    monthlyMedals: {
      1: 100.0,
      3: 90.0,
      5: 85.0,
    },
  ),
  RankingData(
    userId: 'user14',
    name: '황서연',
    totalDistance: 35.2,
    rank: 13,
    monthlyMedals: {
      2: 90.0,
      4: 85.0,
      6: 100.0,
    },
  ),
  RankingData(
    userId: 'user15',
    name: '조현우',
    totalDistance: 32.0,
    rank: 14,
    monthlyMedals: {
      1: 85.0,
      3: 100.0,
      5: 90.0,
    },
  ),

  // 초급자
  RankingData(
    userId: 'user7',
    name: '나',
    totalDistance: 27.0,
    rank: 15,
    monthlyMedals: {
      1: 27.0,
      3: 15.0,
      5: 8.0,
      7: 25.0,
      9: 12.0,
      11: 5.0,
    },
  ),
  RankingData(
    userId: 'user16',
    name: '권도현',
    totalDistance: 25.5,
    rank: 16,
    monthlyMedals: {
      2: 10.0,
      4: 70.0,
      6: 35.0,
    },
  ),
  RankingData(
    userId: 'user17',
    name: '류하진',
    totalDistance: 22.3,
    rank: 17,
    monthlyMedals: {
      1: 35.0,
      3: 60.0,
      5: 90.0,
    },
  ),
  RankingData(
    userId: 'user18',
    name: '문서율',
    totalDistance: 18.5,
    rank: 18,
    monthlyMedals: {
      2: 90.0,
      4: 85.0,
      6: 100.0,
    },
  ),
  RankingData(
    userId: 'user19',
    name: '양지수',
    totalDistance: 12.8,
    rank: 19,
    monthlyMedals: {
      1: 100.0,
      3: 90.0,
      5: 85.0,
    },
  ),
  RankingData(
    userId: 'user20',
    name: '백현진',
    totalDistance: 8.5,
    rank: 20,
    monthlyMedals: {
      2: 85.0,
      4: 100.0,
      6: 90.0,
    },
  ),
];

// 현재 사용자 ID (나중에 인증 시스템에서 가져올 예정)
const currentUserId = 'user7';
