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