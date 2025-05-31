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
  // Constants
  static const int INITIAL_GRACE_PERIOD = 5; // 초기 5초 동안은 속도 체크하지 않음
  static const double MAX_SPEED_KMH = 20.0; // 최대 속도 제한 (km/h)
  static const double MAX_AVG_SPEED_KMH = 15.0; // 최대 평균 속도 제한 (km/h)

  // UI Constants
  static const double _kDefaultPadding = 16.0;
  static const double _kDefaultBorderRadius = 12.0;
  static const double _kButtonHeight = 48.0;
  static const double _kDataBoxHeight = 80.0;

  // Text Styles
  static const TextStyle _kTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
    letterSpacing: 0.2,
  );

  static const TextStyle _kSubtitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black54,
    letterSpacing: 0.1,
  );

  static const TextStyle _kButtonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle _kCountdownStyle = TextStyle(
    fontSize: 120,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 2,
  );

  static const TextStyle _kHodadakStyle = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 4,
  );

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
  List<LatLng> _pausedRoutePoints = []; // 일시정지 구간의 경로 포인트
  List<LatLng> _activeRoutePoints = []; // 현재 활성화된 경로 포인트
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
  bool _isAccelerometerPaused = false; // 가속도계 일시정지 상태 추가

  String _userNickname = '';

  List<Polyline> _polylines = [];

  // 속도 제한 상수 추가
  bool _isSpeedValid = true;

  // 마커 관련 변수 추가
  Marker? _pauseMarker;
  Marker? _resumeMarker;
  List<Marker> _pauseMarkers = [];
  List<Marker> _resumeMarkers = [];

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
    if (widget.initialPosition != null) {
      setState(() {
        _startLocationMarker = Marker(
          markerId: const MarkerId('startLocation'),
          position: widget.initialPosition,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: '시작점'),
          anchor: const Offset(0.5, 1.0),
        );
      });
    }
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

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
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

          // 현재 속도 계산 (km/h)
          double currentSpeed = (position.speed ?? 0) * 3.6; // m/s -> km/h 변환

          // 평균 속도 계산 (km/h)
          double avgSpeed = 0;
          if (_seconds > 0 && _distance > 0) {
            avgSpeed = (_distance / (_seconds / 3600));
          }

          // 속도 제한 체크 (운동이 시작된 후에만 체크)
          if (!_isCountingDown && _seconds > INITIAL_GRACE_PERIOD) {
            if (currentSpeed > MAX_SPEED_KMH || avgSpeed > MAX_AVG_SPEED_KMH) {
              if (_isSpeedValid) {
                _isSpeedValid = false;
                _pauseTimer();

                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('속도 제한 초과'),
                        content: Text('비정상적인 속도가 감지되어 일시정지되었습니다.'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _pauseTimer(); // 다이얼로그 닫고 운동 재개
                            },
                            child: Text('확인'),
                          ),
                        ],
                      );
                    },
                  );
                }
              }
            } else {
              _isSpeedValid = true;
            }
          }
        }
        _currentPosition = position;
        LatLng newPoint = LatLng(position.latitude, position.longitude);
        _routePoints.add(newPoint);

        // 일시정지 상태에 따라 경로 추가
        if (_isPaused) {
          _pausedRoutePoints.add(newPoint);
        } else {
          _activeRoutePoints.add(newPoint);
        }

        _updateCurrentLocationMarker(position);
        _updatePace();

        // 시작점 마커가 없으면 다시 추가
        if (_startLocationMarker == null) {
          _addStartMarker();
        }
      });

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
          target:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
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
      // users 컬렉션에서 사용자 정보 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      if (userData == null) return 0.0;

      print('calculateCalories: Fetched user data: $userData');

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

      // 성별에 따른 보정
      if (gender == 'female') {
        calories *= 0.9; // 여성은 약 10% 감소
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
        _isAccelerometerPaused = false;
        // 재개 시점에 마커 추가
        if (_currentPosition != null) {
          _resumeMarker = Marker(
            markerId: MarkerId('resume_${DateTime.now().millisecondsSinceEpoch}'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
            infoWindow: const InfoWindow(title: '운동 재개'),
          );
          _resumeMarkers.add(_resumeMarker!);
        }
        // 재개 시점의 경로를 새로운 활성 경로로 시작
        _activeRoutePoints = [];
      });
      _startTimer();
    } else {
      // 일시정지 상태로 전환
      setState(() {
        _isPaused = true;
        _isAccelerometerPaused = true;
        // 일시정지 시점에 마커 추가
        if (_currentPosition != null) {
          _pauseMarker = Marker(
            markerId: MarkerId('pause_${DateTime.now().millisecondsSinceEpoch}'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
            infoWindow: const InfoWindow(title: '일시정지'),
          );
          _pauseMarkers.add(_pauseMarker!);
        }
        // 현재까지의 경로를 활성 경로로 유지
        _activeRoutePoints = List.from(_routePoints);
        // 일시정지 구간 초기화
        _pausedRoutePoints = [];
      });
      _timer?.cancel();
    }
  }

  Future<void> saveRunningData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // LatLng 객체들을 Map으로 변환
    final List<Map<String, dynamic>> routePointsData =
        _routePoints.map((point) {
      return {
        'latitude': point.latitude,
        'longitude': point.longitude,
      };
    }).toList();

    // 일시정지 구간도 Map으로 변환
    final List<Map<String, dynamic>> pausedRoutePointsData =
        _pausedRoutePoints.map((point) {
      return {
        'latitude': point.latitude,
        'longitude': point.longitude,
      };
    }).toList();

    // 활성 경로도 Map으로 변환
    final List<Map<String, dynamic>> activeRoutePointsData =
        _activeRoutePoints.map((point) {
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
      'pausedRoutePoints': pausedRoutePointsData,
      'activeRoutePoints': activeRoutePointsData, // 활성 경로 추가
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
    return Container(
      height: _kDataBoxHeight,
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kDefaultBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: _kTitleStyle.copyWith(
              fontSize: 20,
              color: Colors.blue,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: _kSubtitleStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
          pausedRoutePoints: _pausedRoutePoints,
          activeRoutePoints: _activeRoutePoints,
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
            borderRadius: BorderRadius.circular(_kDefaultBorderRadius),
          ),
          title: Text(
            '운동 종료',
            textAlign: TextAlign.center,
            style: _kTitleStyle.copyWith(fontSize: 24),
          ),
          content: Text(
            '운동을 종료하시겠습니까?',
            textAlign: TextAlign.center,
            style: _kSubtitleStyle.copyWith(fontSize: 16),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _kDefaultPadding,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    '취소',
                    style: _kButtonTextStyle.copyWith(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _stopWorkout();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _kDefaultPadding,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    '확인',
                    style: _kButtonTextStyle.copyWith(
                      color: Colors.blue,
                      fontSize: 16,
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
    _accelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      if (_isAccelerometerPaused) return; // 일시정지 상태면 데이터 처리 중단

      // 가속도 벡터의 크기 계산
      double magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      // 걸음 감지 알고리즘
      _magnitudeWindow.add(magnitude);
      if (_magnitudeWindow.length > _stepWindow) {
        _magnitudeWindow.removeAt(0);
      }

      // 걸음 감지 로직
      if (!_isStep &&
          magnitude > _stepThreshold &&
          _magnitudeWindow.length == _stepWindow) {
        // 피크 감지
        if (_magnitudeWindow[1] > _magnitudeWindow[0] &&
            _magnitudeWindow[1] > _magnitudeWindow[2]) {
          _isStep = true;
          _stepCount++;
          setState(() {
            _cadence =
                (_stepCount * 60) ~/ (_seconds > 0 ? _seconds : 1); // 분당 걸음 수
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
            points: widget.recommendedRoutePoints,
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
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5FBFF),
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kDefaultPadding),
          child: Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black87, size: 24),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: Colors.black87, size: 24),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if (widget.isRecommendedCourse)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(left: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(_kDefaultBorderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.route,
                              color: Colors.blue, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.recommendedCourseName,
                            style: _kSubtitleStyle.copyWith(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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
                    // 활성 경로 (보라색)
                    if (_activeRoutePoints.isNotEmpty)
                      Polyline(
                        polylineId: const PolylineId('activeRoute'),
                        points: _activeRoutePoints,
                        color: const Color(0xFF764BA2),
                        width: 8,
                        startCap: Cap.roundCap,
                        endCap: Cap.roundCap,
                        jointType: JointType.round,
                      ),
                    // 일시정지된 경로 (회색)
                    if (_pausedRoutePoints.isNotEmpty)
                      Polyline(
                        polylineId: const PolylineId('pausedRoute'),
                        points: _pausedRoutePoints,
                        color: Colors.grey,
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
                    ..._pauseMarkers,
                    ..._resumeMarkers,
                  },
                ),
              ),
              Container(
                color: const Color(0xFFE5FBFF),
                padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 16 : 24,
                  horizontal: _kDefaultPadding,
                ),
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
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _dataBox('평균 페이스', _pace),
                        _dataBox('칼로리(kcal)', _calories.toString()),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(
                          height: _kButtonHeight,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(_kDefaultBorderRadius),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _pauseTimer,
                            icon: Icon(
                              _isPaused ? Icons.play_arrow : Icons.pause,
                              size: 24,
                            ),
                            label: Text(
                              _isPaused ? '운동 재생' : '일시정지',
                              style: _kButtonTextStyle,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    _kDefaultBorderRadius),
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onLongPressStart: _onLongPressStart,
                          onLongPressEnd: _onLongPressEnd,
                          child: Container(
                            height: _kButtonHeight,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(_kDefaultBorderRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.stop_circle,
                                  color: Colors.red, size: 24),
                              label: Text(
                                '3초간 누르면 종료',
                                style: _kButtonTextStyle.copyWith(
                                    color: Colors.red),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      _kDefaultBorderRadius),
                                ),
                              ),
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
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: _showHodadak
                    ? const Text(
                        '호다닥!',
                        style: _kHodadakStyle,
                      )
                    : (_countdownValue > 0
                        ? Text(
                            _countdownValue.toString(),
                            style: _kCountdownStyle,
                          )
                        : const SizedBox()),
              ),
            ),
        ],
      ),
    );
  }
}