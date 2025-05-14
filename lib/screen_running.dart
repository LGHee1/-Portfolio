import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'workout_summary_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sensors_plus/sensors_plus.dart';

class RunningScreen extends StatefulWidget {
  final LatLng initialPosition;

  const RunningScreen({
    super.key,
    required this.initialPosition,
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

  // Google Maps 관련 변수
  final Completer<GoogleMapController> _controller = Completer();
  Position? _currentPosition;
  final List<LatLng> _routePoints = [];
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
    _startTimer();
    _getCurrentLocation();
    _startAccelerometer();
    _loadUserData();
    _addStartMarker();
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
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
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

  void _updatePace() {
    if (_distance > 0 && _seconds > 0) {
      double minutesPerKm = (_seconds / 60) / _distance;
      int minutes = minutesPerKm.floor();
      int seconds = ((minutesPerKm - minutes) * 60).round();
      _pace = '$minutes\'${seconds.toString().padLeft(2, '0')}"';
      
      // 칼로리 계산 (1km당 약 60kcal로 가정)
      _calories = (_distance * 60).floor();
      
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
    _timer?.cancel();
    _positionStream?.pause();
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

    final runningData = {
      'date': DateTime.now(),
      'distance': _distance,
      'duration': _seconds,
      'pace': _pace,
      'calories': _calories,
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
        ),
      ),
    );
  }

  void _onLongPressStart(_) {
    _isHolding = true;
    _holdTimer = Timer(const Duration(seconds: 3), () {
      if (_isHolding) {
        _stopWorkout();
      }
    });
  }

  void _onLongPressEnd(_) {
    _isHolding = false;
    _holdTimer?.cancel();
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
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_circle, size: 36, color: Colors.grey),
                    SizedBox(height: 4),
                    Text('임덕현', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...['랭킹', '기록', '친구관리', '문의', '환경 설정'].map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
                child: Text(item, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              );
            }).toList(),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(left: 16.0, bottom: 12),
              child: Icon(Icons.logout),
            ),
          ],
        ),
      ),


      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
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
                  },
                  markers: {
                    if (_startLocationMarker != null) _startLocationMarker!,
                    if (_currentLocationMarker != null) _currentLocationMarker!,
                  },
                ),

                // 현재 위치 이동 버튼
                Positioned(
                  top: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: _moveCamera,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset('assets/img/now_position.png'),
                      ),
                    ),
                  ),
                ),
              ],
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
                      icon: const Icon(Icons.pause),
                      label: const Text('일시정지'),
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

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber.shade100,
        onPressed: _startTimer,
        child: const Icon(Icons.play_arrow, color: Colors.black),
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
                onPressed: () {},
                icon: const Icon(Icons.directions_run, color: Colors.amber),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.star_border),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 