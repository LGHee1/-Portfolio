import 'package:flutter/material.dart';
import '../../models/workout_record.dart';
import '../../utils/theme.dart';
import 'package:intl/intl.dart';
import '../Post/post_create.dart';
import '../Post/post_list.dart';
import '../Running/workout_screen.dart';
import '../home_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Widgets/bottom_bar.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final WorkoutRecord record;

  const WorkoutDetailScreen({Key? key, required this.record}) : super(key: key);

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};
  LatLng? _initialPosition;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _initializePolylines();
  }

  void _initializePolylines() {
    if (widget.record.routePoints.isNotEmpty) {
      final List<LatLng> points = widget.record.routePoints
          .map((point) => LatLng(point['latitude']!, point['longitude']!))
          .toList();

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: const Color(0xFF764BA2),
          width: 8,
          patterns: [PatternItem.dash(30), PatternItem.gap(10)],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );

      // Set initial position to the first point of the route
      _initialPosition = points.first;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (widget.record.routePoints.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.animateCamera(
          CameraUpdate.newLatLngBounds(
            _getBoundsFromLatLngList(_polylines.first.points),
            50.0,
          ),
        );
      });
    }
  }

  LatLngBounds _getBoundsFromLatLngList(List<LatLng> list) {
    double? minLat, maxLat, minLng, maxLng;

    for (LatLng latLng in list) {
      if (minLat == null || latLng.latitude < minLat) minLat = latLng.latitude;
      if (maxLat == null || latLng.latitude > maxLat) maxLat = latLng.latitude;
      if (minLng == null || latLng.longitude < minLng)
        minLng = latLng.longitude;
      if (maxLng == null || latLng.longitude > maxLng)
        maxLng = latLng.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 정보 가져오기
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // 동적 크기 계산
    final titleFontSize = screenWidth * 0.045; // 화면 너비의 4.5%
    final subtitleFontSize = screenWidth * 0.035; // 화면 너비의 3.5%
    final padding = screenWidth * 0.04; // 화면 너비의 4%
    final spacing = screenHeight * 0.02; // 화면 높이의 2%
    final mapHeight = screenHeight * 0.3; // 화면 높이의 30%
    final buttonHeight = screenHeight * 0.05; // 화면 높이의 5%

    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('yyyy년 M월 d일').format(widget.record.date),
          style: TextStyle(fontSize: titleFontSize),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: padding),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostCreatePage(
                      workoutData: {
                        'routePoints': widget.record.routePoints,
                        'date': widget.record.date,
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: padding * 0.8,
                  vertical: buttonHeight * 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '게시글 작성',
                style: TextStyle(
                  fontSize: subtitleFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: mapHeight,
            margin: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _initialPosition == null
                  ? Center(
                      child: Text(
                        '경로 데이터가 없습니다',
                        style: TextStyle(
                          color: AppTheme.lightTextColor,
                          fontSize: subtitleFontSize,
                        ),
                      ),
                    )
                  : GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: _initialPosition!,
                        zoom: 15,
                      ),
                      polylines: _polylines,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(padding),
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '운동 정보',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkTextColor,
                      ),
                    ),
                    SizedBox(height: spacing),
                    _buildStatsGrid(subtitleFontSize),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const WorkoutScreen()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ScreenHome()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PostListPage()),
            );
          }
        },
      ),
    );
  }

  Widget _buildStatsGrid(double fontSize) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    
    final gridSpacing = screenWidth * 0.04; // 화면 너비의 4%
    final itemPadding = screenWidth * 0.04; // 화면 너비의 4%

    return GridView.count(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 2,
      mainAxisSpacing: gridSpacing,
      crossAxisSpacing: gridSpacing,
      children: [
        _buildStatItem('거리', '${widget.record.distance.toStringAsFixed(2)} km', fontSize, itemPadding),
        _buildStatItem('시간', '${widget.record.duration.inMinutes} 분', fontSize, itemPadding),
        _buildStatItem('케이던스', '${widget.record.cadence} spm', fontSize, itemPadding),
        _buildStatItem('평균 페이스', '${widget.record.pace.toStringAsFixed(2)} /km', fontSize, itemPadding),
        _buildStatItem('칼로리', '${widget.record.calories} kcal', fontSize, itemPadding),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, double fontSize, double padding) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.lightTextColor,
              fontSize: fontSize * 0.9,
            ),
          ),
          SizedBox(height: padding * 0.25),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.darkTextColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}