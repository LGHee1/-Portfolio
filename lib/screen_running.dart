import  'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'workout_summary_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RunningScreen extends StatefulWidget {
  const RunningScreen({super.key});

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

  String get formattedTime {
    final duration = Duration(seconds: _seconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startTimer(); // 화면이 시작되면 자동으로 타이머 시작
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

  void _updateCurrentLocationMarker(Position position) {
    _currentLocationMarker = Marker(
      markerId: const MarkerId('currentLocation'),
      position: LatLng(position.latitude, position.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: const InfoWindow(title: '현재 위치'),
      rotation: position.heading, // 방향 표시
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
    final runningData = {
      'date': DateTime.now(),
      'distance': _distance,
      'duration': _seconds,
      'pace': _pace,
      'calories': _calories,
    };
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Running_Data')
        .add(runningData);
  }

  void _completeWorkout() {
    _timer?.cancel();
    _positionStream?.cancel();
    saveRunningData();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('운동 종료'),
        content: const Text('운동이 종료되었습니다.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              // 운동 요약 화면으로 이동
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkoutSummaryScreen(
                    distance: _distance,
                    duration: Duration(seconds: _seconds),
                    calories: _calories,
                    pace: _pace,
                    cadence: _cadence,
                  ),
                ),
              );
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _onLongPressStart(_) {
    _isHolding = true;
    _holdTimer = Timer(const Duration(seconds: 3), () {
      if (_isHolding) {
        _completeWorkout();
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

  @override
  void dispose() {
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
                  compassEnabled: true, // 나침반 표시
                  rotateGesturesEnabled: true, // 회전 제스처 활성화
                  tiltGesturesEnabled: true, // 기울기 제스처 활성화
                  markers: _currentLocationMarker != null ? {_currentLocationMarker!} : {},
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
                  top: 16,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'tracking',
                    onPressed: _toggleTracking,
                    backgroundColor: Colors.white,
                    child: Icon(
                      _isTracking ? Icons.gps_fixed : Icons.gps_not_fixed,
                      color: _isTracking ? Colors.blue : Colors.grey,
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
} 