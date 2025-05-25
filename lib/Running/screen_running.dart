import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../user_provider.dart';
import 'workout_summary_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../Widgets/menu.dart';

class RunningScreen extends StatefulWidget {
  final LatLng initialPosition;
  final bool isRecommendedCourse;
  final List<LatLng> recommendedRoutePoints;
  final String recommendedCourseName;

  const RunningScreen({
    super.key,
    required this.initialPosition,
    this.isRecommendedCourse = false,
    this.recommendedRoutePoints = const [],
    this.recommendedCourseName = '',
  });

  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen> {
  // 타이머 관련 변수
  Timer? _timer;
  int _seconds = 0;
  bool _isHolding = false;
  Timer? _holdTimer;
  bool _isCountingDown = true; // 카운트다운 상태
  int _countdownValue = 3; // 카운트다운 값
  bool _showHodadak = false; // 호다닥 표시 상태 추가
  bool _isPaused = false; // 일시정지 상태 추가

  // Google Maps 관련 변수
  final Completer<GoogleMapController> _controller = Completer();
  Position? _currentPosition;
  List<LatLng> _routePoints = [];
  StreamSubscription<Position>? _positionStream;
  double _distance = 0.0; // km
  int _calories = 0;
  int _cadence = 0;
  String _pace = '0\'00"';
  bool _isTracking = true; // 위치 추적 상태

  // 현재 위치 마커
  Marker? _currentLocationMarker;
  Marker? _startLocationMarker;

  // 가속도계 관련 변수
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _lastMagnitude = 0;
  int _stepCount = 0;
  bool _isStep = false;
  static const double _stepThreshold = 12.0; // 걸음 감지 임계값
  static const int _stepWindow = 3; // 걸음 감지 시간 윈도우 (프레임)
  List<double> _magnitudeWindow = [];

  String _userNickname = '';

  List<Polyline> _polylines = [];

  String get formattedTime {
    final duration = Duration(seconds: _seconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void initState() {
    super.initState();
    _currentPosition = Position(
      latitude: widget.initialPosition.latitude,
      longitude: widget.initialPosition.longitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    _startCountdown();
    _getCurrentLocation();
    _startAccelerometer();
    _loadUserData();
    _addStartMarker();
    
    if (widget.isRecommendedCourse) {
      _initializeRecommendedRoute();
    }
  }

  void _loadUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() {
      _userNickname = userProvider.nickname;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
        _updateCurrentLocationMarker(position);
      });

      _startLocationUpdates();
    } catch (e) {
      debugPrint('위치 가져오기 오류: $e');
    }
  }

  void _addStartMarker() {
    _startLocationMarker = Marker(
      markerId: const MarkerId('startLocation'),
      position: widget.initialPosition,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: '시작점'),
    );
  }

  void _updateCurrentLocationMarker(Position position) {
    _currentLocationMarker = Marker(
      markerId: const MarkerId('currentLocation'),
      position: LatLng(position.latitude, position.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: '현재 위치'),
      rotation: position.heading,
    );
  }

  void _startLocationUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      setState(() {
        if (_currentPosition != null) {
          double newDistance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          _distance += newDistance / 1000;
        }
        _currentPosition = position;
        _routePoints.add(LatLng(position.latitude, position.longitude));
        _updateCurrentLocationMarker(position);
        _updatePace();
      });

      // 경로가 제대로 업데이트 되는지 디버깅용 코드
      print('Route points count: ${_routePoints.length}');
      
      // 카메라 이동
      if (_isTracking && _controller.isCompleted) {
        _moveCamera();
      }
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
          bearing: _currentPosition!.heading, // 카메라 방향도 현재 방향으로
        ),
      ),
    );
  }

  Future<double> calculateCalories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0.0;

    try {
      // 사용자 정보 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      if (userData == null) return 0.0;

      final weight = userData['weight'] as double;
      final gender = userData['gender'] as String;
      final age = userData['age'] as int;

      // MET 값 계산 (속도 기반)
      double speed = _distance / (_seconds / 3600); // km/h
      double met = 9.8; // 기본값

      if (speed < 6.4) {
        met = 6.0; // 걷기
      } else if (speed < 8.0) {
        met = 8.3; // 천천히 달리기
      } else if (speed < 9.7) {
        met = 9.8; // 보통 속도 달리기
      } else {
        met = 11.0; // 빠르게 달리기
      }

      // 칼로리 계산
      double hours = _seconds / 3600;
      double calories = met * weight * hours;

      // 성별과 나이에 따른 보정
      if (gender == 'female') {
        calories *= 0.9; // 여성은 남성보다 약 10% 적은 칼로리 소모
      }
      
      // 나이에 따른 보정 (20대 기준)
      if (age > 30) {
        calories *= 0.95; // 30대 이상은 약 5% 감소
      }

      return calories;
    } catch (e) {
      print('칼로리 계산 중 오류 발생: $e');
      return 0.0;
    }
  }

  void _updatePace() {
    if (_distance > 0 && _seconds > 0) {
      double minutesPerKm = (_seconds / 60) / _distance;
      int minutes = minutesPerKm.floor();
      int seconds = ((minutesPerKm - minutes) * 60).round();
      _pace = '$minutes\'${seconds.toString().padLeft(2, '0')}"';
      
      // 칼로리 계산
      calculateCalories().then((calories) {
        if (mounted) {
          setState(() {
            _calories = calories.round();
          });
        }
      });
      
      // 케이던스 계산 (임시로 랜덤값 사용, 실제로는 가속도계 데이터 필요)
      _cadence = 150 + DateTime.now().second % 20;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _seconds++;
        _updatePace();
      });
    });
  }

  void _pauseTimer() {
    if (_isPaused) {
      // 재생 상태로 전환
      setState(() {
        _isPaused = false;
      });
      _startTimer();
      _positionStream?.resume();
    } else {
      // 일시정지 상태로 전환
      setState(() {
        _isPaused = true;
      });
      _timer?.cancel();
      _positionStream?.pause();
    }
  }

  Future<void> saveRunningData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // LatLng 객체들을 Map으로 변환
    final List<Map<String, dynamic>> routePointsData = _routePoints.map((point) {
      return {
        'latitude': point.latitude,
        'longitude': point.longitude,
      };
    }).toList();

    // 칼로리 계산
    final calories = await calculateCalories();

    final runningData = {
      'date': DateTime.now(),
      'distance': _distance,
      'duration': _seconds,
      'pace': _pace,
      'calories': calories,
      'routePoints': routePointsData,
      'nickname': _userNickname,
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Running_Data')
        .add(runningData);

    // 사용자의 총 운동 거리 업데이트
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'totalDistance': FieldValue.increment(_distance),
      'totalWorkouts': FieldValue.increment(1),
    });
  }

  Widget _dataBox(String title, String value) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _stopWorkout() async {
    setState(() {
      _isTracking = false;
    });
    _timer?.cancel();
    await saveRunningData();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutSummaryScreen(
          distance: _distance,
          duration: Duration(seconds: _seconds),
          pace: _pace,
          cadence: _cadence,
          calories: _calories,
          routePoints: _routePoints,
          isRecommendedCourse: widget.isRecommendedCourse,
          recommendedRoutePoints: widget.recommendedRoutePoints,
          recommendedCourseName: widget.recommendedCourseName,
        ),
      ),
    );
  }

  void _onLongPressStart(_) {
    _isHolding = true;
    _holdTimer = Timer(const Duration(seconds: 3), () {
      if (_isHolding) {
        _showEndWorkoutDialog();
      }
    });
  }

  void _onLongPressEnd(_) {
    _isHolding = false;
    _holdTimer?.cancel();
  }

  void _showEndWorkoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '운동 종료',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '운동을 종료하시겠습니까?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _stopWorkout();
                  },
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;
    });
  }

  void _startAccelerometer() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      // 가속도 벡터의 크기 계산
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // 걸음 감지 알고리즘
      _magnitudeWindow.add(magnitude);
      if (_magnitudeWindow.length > _stepWindow) {
        _magnitudeWindow.removeAt(0);
      }

      // 걸음 감지 로직
      if (!_isStep && magnitude > _stepThreshold && _magnitudeWindow.length == _stepWindow) {
        // 피크 감지
        if (_magnitudeWindow[1] > _magnitudeWindow[0] && _magnitudeWindow[1] > _magnitudeWindow[2]) {
          _isStep = true;
          _stepCount++;
          setState(() {
            _cadence = (_stepCount * 60) ~/ (_seconds > 0 ? _seconds : 1); // 분당 걸음 수
          });
        }
      } else if (_isStep && magnitude < _stepThreshold) {
        _isStep = false;
      }

      _lastMagnitude = magnitude;
    });
  }

  void _startCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdownValue > 1) {
          _countdownValue--;
        } else if (_countdownValue == 1) {
          _countdownValue = 0;
          _showHodadak = true;
          // 1초 후 호다닥만 보이게
          Future.delayed(const Duration(seconds: 1), () {
            setState(() {
              _showHodadak = false;
              _isCountingDown = false;
              _startTimer();
            });
          });
          timer.cancel();
        }
      });
    });
  }

  void _initializeRecommendedRoute() {
    if (widget.recommendedRoutePoints.isNotEmpty) {
      setState(() {
        _routePoints = List.from(widget.recommendedRoutePoints);
        // 추천 코스의 경로를 초록색 선으로 표시
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('recommendedRoute'),
            points: _routePoints,
            color: Colors.green,
            width: 8,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _timer?.cancel();
    _holdTimer?.cancel();
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
        title: Row(
          children: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (widget.isRecommendedCourse)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '추천 코스: ${widget.recommendedCourseName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
      drawer: const Menu(),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: widget.initialPosition,
                    zoom: 17,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: _routePoints,
                      color: const Color(0xFF764BA2),
                      width: 8,
                      startCap: Cap.roundCap,
                      endCap: Cap.roundCap,
                      jointType: JointType.round,
                    ),
                    ..._polylines,
                  },
                  markers: {
                    if (_startLocationMarker != null) _startLocationMarker!,
                    if (_currentLocationMarker != null) _currentLocationMarker!,
                  },
                ),
              ),
              Container(
                color: const Color(0xFFE5FBFF),
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _dataBox('거리(km)', _distance.toStringAsFixed(2)),
                        _dataBox('시간', formattedTime),
                        _dataBox('케이던스', _cadence.toString()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _dataBox('평균 페이스', _pace),
                        _dataBox('칼로리(kcal)', _calories.toString()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pauseTimer,
                          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                          label: Text(_isPaused ? '운동 재생' : '일시정지'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                        ),
                        GestureDetector(
                          onLongPressStart: _onLongPressStart,
                          onLongPressEnd: _onLongPressEnd,
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.stop_circle, color: Colors.red),
                            label: const Text('3초간 누르면 종료'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isCountingDown)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: _showHodadak
                    ? const Text(
                        '호다닥!',
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : (_countdownValue > 0
                        ? Text(
                            _countdownValue.toString(),
                            style: const TextStyle(
                              fontSize: 120,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : const SizedBox()),
              ),
            ),
        ],
      ),
    );
  }
} 