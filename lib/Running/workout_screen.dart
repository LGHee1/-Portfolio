import 'dart:async';
import 'package:app_project/Running/screen_running.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../user_provider.dart';
import '../home_screen.dart';
import 'workout_summary_screen.dart';
import '../Widgets/menu.dart';
import '../Widgets/bottom_bar.dart';

class WorkoutScreen extends StatefulWidget {
  final bool isRecommendedCourse;
  final List<LatLng> recommendedRoutePoints;
  final String recommendedCourseName;

  const WorkoutScreen({
    super.key,
    this.isRecommendedCourse = false,
    this.recommendedRoutePoints = const [],
    this.recommendedCourseName = '',
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  String _userNickname = '';
  bool _isRecommendedCourse = false;
  String _recommendedCourseName = '';
  List<LatLng> _recommendedRoutePoints = [];

  int _selectedIndex = 1;

  // 운동 데이터
  double _distance = 0.0; // km
  Duration _duration = Duration.zero;
  int _cadence = 0;
  String _pace = '0\'00"';
  int _calories = 0;

  // 운동 상태
  bool _isWorkoutStarted = false;
  Timer? _timer;
  final List<LatLng> _routePoints = [];
  DateTime? _workoutStartTime;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _loadUserData();
    _isRecommendedCourse = widget.isRecommendedCourse;
    _recommendedCourseName = widget.recommendedCourseName;
    _recommendedRoutePoints = widget.recommendedRoutePoints;
  }

  Future<void> _loadUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() {
      _userNickname = userProvider.nickname;
    });
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    debugPrint('위치 권한 상태: $status');

    if (status.isGranted) {
      debugPrint('위치 권한이 허용됨');
      await _checkLocationPermission();
      _startLocationUpdates();
    } else {
      debugPrint('위치 권한이 거부됨');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 필요합니다.')),
        );
      }
    }
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('위치 가져오기 오류: $e');
    }
  }

  void _startLocationUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // 10미터마다 업데이트
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      setState(() {
        if (_currentPosition != null && _isWorkoutStarted) {
          // 거리 계산
          double newDistance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          _distance += newDistance / 1000; // 미터를 킬로미터로 변환

          // 경로 포인트 추가
          _routePoints.add(LatLng(position.latitude, position.longitude));
        }
        _currentPosition = position;
      });

      if (_controller.isCompleted) {
        _moveCamera();
      }
      _updateWorkoutStats();
    });
  }

  Future<void> _moveCamera() async {
    if (_currentPosition == null || !_controller.isCompleted) return;

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 17,
        ),
      ),
    );
  }

  void _toggleWorkout() {
    setState(() {
      _isWorkoutStarted = !_isWorkoutStarted;
      if (_isWorkoutStarted) {
        _startWorkout();
      } else {
        _pauseWorkout();
      }
    });
  }

  void _endWorkout() {
    if (_workoutStartTime == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('운동 종료'),
          content: const Text('정말로 운동을 종료하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                // 다이얼로그 닫기
                Navigator.of(context).pop();

                // 상태 초기화
                setState(() {
                  _isWorkoutStarted = false;
                  _timer?.cancel();
                  _positionStream?.cancel();
                });

                // 데이터 저장 및 화면 전환
                _saveWorkoutData().then((_) {
                  if (!mounted) return;

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkoutSummaryScreen(
                        distance: _distance,
                        duration: _duration,
                        pace: _pace,
                        cadence: _cadence,
                        calories: _calories,
                        routePoints: _routePoints,
                        isRecommendedCourse: _isRecommendedCourse,
                        recommendedRoutePoints: _recommendedRoutePoints,
                        recommendedCourseName: _recommendedCourseName,
                      ),
                    ),
                  );
                });
              },
              child: const Text('종료'),
            ),
          ],
        );
      },
    );
  }

  void _startWorkout() {
    _workoutStartTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isWorkoutStarted) {
        setState(() {
          _duration += const Duration(seconds: 1);
          _updateWorkoutStats();
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _pauseWorkout() {
    setState(() {
      _isWorkoutStarted = false;
      _timer?.cancel();
    });
  }

  void _updateWorkoutStats() {
    if (_duration.inSeconds > 0) {
      // 평균 페이스 계산 (분/km)
      double paceInMinutes = _duration.inMinutes / _distance;
      int minutes = paceInMinutes.floor();
      int seconds = ((paceInMinutes - minutes) * 60).floor();
      _pace = '$minutes\'${seconds.toString().padLeft(2, '0')}"';

      // 칼로리 계산 (매우 간단한 추정)
      _calories = (_distance * 60).floor(); // 1km당 약 60kcal로 가정
    }

    // 케이던스는 실제로는 가속도계를 사용하여 계산해야 하지만,
    // 여기서는 임시로 랜덤값 사용
    _cadence = (_isWorkoutStarted ? 150 + DateTime.now().second % 20 : 0);
  }

  Future<void> _saveWorkoutData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final workoutData = {
        'date': Timestamp.now(),
        'distance': _distance,
        'duration': _duration.inSeconds,
        'pace': _pace,
        'cadence': _cadence,
        'calories': _calories,
        'routePoints': _routePoints.map((point) => {
          'latitude': point.latitude,
          'longitude': point.longitude,
        }).toList(),
        'startTime': _workoutStartTime,
        'endTime': DateTime.now(),
        'nickname': _userNickname,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Running_Data')
          .add(workoutData);

      // 사용자의 총 운동 거리 업데이트
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'totalDistance': FieldValue.increment(_distance),
        'totalWorkouts': FieldValue.increment(1),
      });

    } catch (e) {
      print('운동 데이터 저장 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('운동 데이터 저장 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_isWorkoutStarted) {
      _saveWorkoutData();
    }
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5FBFF),
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            Expanded(
              child: Container(
                height: 36,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: '검색',
                    border: InputBorder.none,
                    icon: Icon(Icons.search, size: 25),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),

      drawer: const Menu(),

      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(37.5665, 126.9780),
              zoom: 17,
            ),
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: {
              if (_isRecommendedCourse && _recommendedRoutePoints.isNotEmpty) ...[
                // 추천 코스 시작점 마커
                Marker(
                  markerId: const MarkerId('recommendedStart'),
                  position: _recommendedRoutePoints.first,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  infoWindow: const InfoWindow(title: '추천 코스 시작점'),
                ),
                // 추천 코스 종료점 마커
                Marker(
                  markerId: const MarkerId('recommendedEnd'),
                  position: _recommendedRoutePoints.last,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  infoWindow: const InfoWindow(title: '추천 코스 종료점'),
                ),
              ],
            },
            polylines: {
              // 실제 달린 경로 (파란색)
              Polyline(
                polylineId: const PolylineId('route'),
                points: _routePoints,
                color: Colors.blue,
                width: 5,
              ),
              // 추천 코스 (초록색)
              if (_isRecommendedCourse)
                Polyline(
                  polylineId: const PolylineId('recommendedRoute'),
                  points: _recommendedRoutePoints,
                  color: Colors.green,
                  width: 5,
                ),
            },
          ),

          if (_isRecommendedCourse)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                width: 250,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '추천 코스: $_recommendedCourseName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: 32,
            left: 140,
            right: 140,
            child: ElevatedButton(
              onPressed: () {
                print("운동 시작 버튼 클릭됨");
                if (_isRecommendedCourse && !_isWithinRecommendedDistance()) {
                  _showDistanceWarningDialog();
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RunningScreen(
                      initialPosition: _currentPosition != null 
                          ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                          : const LatLng(37.5665, 126.9780),
                      isRecommendedCourse: _isRecommendedCourse,
                      recommendedRoutePoints: _recommendedRoutePoints,
                      recommendedCourseName: _recommendedCourseName,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text("운동 시작"),
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  // 추천 코스 시작점과의 거리 체크 함수 추가
  bool _isWithinRecommendedDistance() {
    if (!_isRecommendedCourse || _recommendedRoutePoints.isEmpty || _currentPosition == null) {
      return true;
    }

    final startPoint = _recommendedRoutePoints.first;
    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      startPoint.latitude,
      startPoint.longitude,
    );

    return distance <= 200; // 200m 이내인지 체크
  }

  void _showDistanceWarningDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('거리 경고'),
          content: const Text('추천 코스 시작점과 현재 위치가 200m 이상 떨어져 있습니다.\n추천 코스 시작점 근처로 이동해주세요.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}