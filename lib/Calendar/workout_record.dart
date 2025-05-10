class WorkoutRecord {
  final String userId;
  final DateTime date;
  final double distance;
  final Duration duration;
  final double pace;
  final int cadence;
  final int calories;
  final List<Map<String, double>> routePoints;

  WorkoutRecord({
    required this.userId,
    required this.date,
    required this.distance,
    required this.duration,
    required this.pace,
    required this.cadence,
    required this.calories,
    required this.routePoints,
  });
}

// 임시 데이터
final Map<String, List<WorkoutRecord>> userWorkoutRecords = {
  '나': [
    WorkoutRecord(
      userId: '나',
      date: DateTime.now(),
      distance: 5.2,
      duration: Duration(minutes: 30),
      pace: 5.77,
      cadence: 180,
      calories: 320,
      routePoints: [],
    ),
    WorkoutRecord(
      userId: '나',
      date: DateTime.now().subtract(Duration(days: 1)),
      distance: 3.8,
      duration: Duration(minutes: 22),
      pace: 5.79,
      cadence: 182,
      calories: 240,
      routePoints: [],
    ),
  ],
  '친구1': [
    WorkoutRecord(
      userId: '친구1',
      date: DateTime.now(),
      distance: 4.5,
      duration: Duration(minutes: 25),
      pace: 5.56,
      cadence: 178,
      calories: 280,
      routePoints: [],
    ),
  ],
}; 