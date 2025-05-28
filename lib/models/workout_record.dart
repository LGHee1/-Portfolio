class WorkoutRecord {
  final DateTime date;
  final double distance; // kilometers
  final Duration duration;
  final double pace; // minutes per kilometer
  final int cadence; // steps per minute
  final int calories;
  final List<Map<String, double>>
  routePoints; // List of {latitude, longitude} points
  final List<Map<String, double>> pausedRoutePoints; // 일시정지 구간 포인트 추가
  final String userId; // 사용자 구분을 위한 ID 추가

  WorkoutRecord({
    required this.date,
    required this.distance,
    required this.duration,
    required this.pace,
    required this.cadence,
    required this.calories,
    required this.routePoints,
    required this.pausedRoutePoints, // 일시정지 구간 추가
    required this.userId,
  });
}

// 임시 데이터 - 나중에 Firebase로 대체될 예정
final Map<String, List<WorkoutRecord>> userWorkoutRecords = {
  '나': [
    WorkoutRecord(
      userId: '나',
      date: DateTime(2025, 5, 1),
      distance: 8.5,
      duration: Duration(minutes: 50),
      pace: 5.88, // 5'53" per km
      cadence: 172,
      calories: 720,
      routePoints: [
        {'latitude': 37.5665, 'longitude': 126.9780},
        {'latitude': 37.5670, 'longitude': 126.9788},
        {'latitude': 37.5675, 'longitude': 126.9795},
        {'latitude': 37.5680, 'longitude': 126.9800},
      ],
      pausedRoutePoints: [],
    ),
    WorkoutRecord(
      userId: '나',
      date: DateTime(2025, 4, 27),
      distance: 5.2,
      duration: Duration(minutes: 30),
      pace: 5.77,
      cadence: 165,
      calories: 450,
      routePoints: [
        {'latitude': 37.5665, 'longitude': 126.9780},
        {'latitude': 37.5668, 'longitude': 126.9785},
        {'latitude': 37.5671, 'longitude': 126.9790},
        {'latitude': 37.5675, 'longitude': 126.9795},
      ],
      pausedRoutePoints: [],
    ),
  ],
  '친구1': [
    WorkoutRecord(
      userId: '친구1',
      date: DateTime(2025, 5, 1),
      distance: 12.0,
      duration: Duration(minutes: 65),
      pace: 5.42, // 5'25" per km
      cadence: 175,
      calories: 950,
      routePoints: [
        {'latitude': 37.5665, 'longitude': 126.9780},
        {'latitude': 37.5675, 'longitude': 126.9795},
      ],
      pausedRoutePoints: [],
    ),
    WorkoutRecord(
      userId: '친구1',
      date: DateTime(2025, 4, 29),
      distance: 6.0,
      duration: Duration(minutes: 35),
      pace: 5.83,
      cadence: 170,
      calories: 480,
      routePoints: [
        {'latitude': 37.5665, 'longitude': 126.9780},
        {'latitude': 37.5675, 'longitude': 126.9795},
      ],
      pausedRoutePoints: [],
    ),
  ],
  '친구2': [
    WorkoutRecord(
      userId: '친구2',
      date: DateTime(2025, 5, 1),
      distance: 5.0,
      duration: Duration(minutes: 28),
      pace: 5.60, // 5'36" per km
      cadence: 168,
      calories: 380,
      routePoints: [
        {'latitude': 37.5665, 'longitude': 126.9780},
        {'latitude': 37.5675, 'longitude': 126.9795},
      ],
      pausedRoutePoints: [],
    ),
    WorkoutRecord(
      userId: '친구2',
      date: DateTime(2025, 4, 30),
      distance: 7.5,
      duration: Duration(minutes: 45),
      pace: 6.0,
      cadence: 165,
      calories: 580,
      routePoints: [
        {'latitude': 37.5665, 'longitude': 126.9780},
        {'latitude': 37.5675, 'longitude': 126.9795},
      ],
      pausedRoutePoints: [],
    ),
  ],
  '친구3': [
    WorkoutRecord(
      userId: '친구3',
      date: DateTime(2025, 5, 1),
      distance: 15.0,
      duration: Duration(minutes: 90),
      pace: 6.0, // 6'00" per km
      cadence: 165,
      calories: 1200,
      routePoints: [
        {'latitude': 37.5665, 'longitude': 126.9780},
        {'latitude': 37.5675, 'longitude': 126.9795},
      ],
      pausedRoutePoints: [],
    ),
    WorkoutRecord(
      userId: '친구3',
      date: DateTime(2025, 4, 28),
      distance: 10.0,
      duration: Duration(minutes: 58),
      pace: 5.8,
      cadence: 170,
      calories: 820,
      routePoints: [
        {'latitude': 37.5665, 'longitude': 126.9780},
        {'latitude': 37.5675, 'longitude': 126.9795},
      ],
      pausedRoutePoints: [],
    ),
  ],
};