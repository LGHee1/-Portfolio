import 'dart:async';
import 'package:app_project/screen_running.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'workout_summary_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;

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
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    debugPrint('위치 권한 상태: $status');

    if (status.isGranted) {
      debugPrint('위치 권한이 허용됨');
      await _getCurrentLocation();
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

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('위치 서비스 활성화 상태: $serviceEnabled');

      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 서비스를 활성화해주세요.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('현재 위치 권한 상태: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('새로 요청한 위치 권한 상태: $permission');

        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('위치 권한이 거부되었습니다.')),
            );
          }
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      debugPrint('현재 위치: ${position.latitude}, ${position.longitude}');

      setState(() {
        _currentPosition = position;
      });

      if (_controller.isCompleted) {
        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 17,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('위치 가져오기 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치를 가져오는 중 오류가 발생했습니다.')),
        );
      }
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
                        calories: _calories,
                        pace: _pace,
                        cadence: _cadence,
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
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final workoutData = {
        'startTime': _workoutStartTime,
        'endTime': DateTime.now(),
        'duration': _duration.inSeconds,
        'distance': _distance,
        'calories': _calories,
        'averagePace': _pace,
        'averageCadence': _cadence,
        'routePoints': _routePoints.map((point) => {
          'latitude': point.latitude,
          'longitude': point.longitude,
        }).toList(),
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .add(workoutData);

      debugPrint('운동 기록 저장 완료');
    } catch (e) {
      debugPrint('운동 기록 저장 중 오류 발생: $e');
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
            IconButton(
              icon: const Icon(Icons.location_pin, color: Colors.red),
              onPressed: () {},
            ),
          ],
        ),
      ),

      drawer: Drawer(
        width: 240,
        backgroundColor: const Color(0xFFE5FBFF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black26),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_circle, size: 36, color: Colors.grey),
                      SizedBox(height: 4),
                      Text('임덕현', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...['랭킹', '기록', '친구관리', '문의', '환경 설정'].map((item) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
                  child: Text(item, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
            ).toList(),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(left: 16.0, bottom: 12),
              child: Icon(Icons.logout),
            ),
          ],
        ),
      ),

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
            myLocationButtonEnabled: false,
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: _routePoints,
                color: Colors.blue,
                width: 5,
              ),
            },
          ),

          Positioned(
            bottom: 32,
            left: 140,
            right: 140,
            child: ElevatedButton(
              onPressed: () {
                print("운동 시작 버튼 클릭됨");
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RunningScreen()),
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

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber.shade100,
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ScreenHome()),
          );
        },
        child: const Icon(
          Icons.home,
          color: Colors.grey,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.directions_run,
                  color: Colors.amber,
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(
                  Icons.star_border,
                  color: Colors.black,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ),
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
}