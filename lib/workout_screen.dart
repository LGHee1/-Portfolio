import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      body: Column(
        children: [
          // 지도 영역
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: _currentPosition == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 17,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    mapType: MapType.normal,
                    zoomControlsEnabled: true,
                    zoomGesturesEnabled: true,
                    compassEnabled: false,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
                    onTap: (LatLng position) {
                      _getCurrentLocation(); // 지도 탭 시 위치 갱신
                    },
                    polylines: {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: _routePoints,
                        color: Colors.blue,
                        width: 5,
                      ),
                    },
                  ),
          ),
          // 운동 정보 영역
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 첫 번째 줄: 거리, 시간, 케이던스
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatBox('거리(km)', _distance.toStringAsFixed(2)),
                      _buildStatBox('시간', _formatDuration(_duration)),
                      _buildStatBox('케이던스', _cadence.toString()),
                    ],
                  ),
                  // 두 번째 줄: 평균 페이스, 칼로리
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatBox('평균 페이스', _pace),
                      _buildStatBox('칼로리(kcal)', _calories.toString()),
                    ],
                  ),
                  // 운동 제어 버튼
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: _toggleWorkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isWorkoutStarted ? Colors.red : Colors.green,
                          minimumSize: const Size(200, 50),
                        ),
                        child: Text(
                          _isWorkoutStarted ? '일시정지' : '운동시작',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _endWorkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: const Size(200, 50),
                        ),
                        child: const Text(
                          '운동 종료',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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