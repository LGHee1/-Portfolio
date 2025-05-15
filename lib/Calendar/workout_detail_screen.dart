import 'package:flutter/material.dart';
import '../../models/workout_record.dart';
import '../../utils/theme.dart';
import 'package:intl/intl.dart';
import '../Post/post_create.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('yyyy년 M월 d일').format(widget.record.date),
          style: TextStyle(fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '게시글 작성',
                style: TextStyle(
                  fontSize: 14,
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
            height: 250,
            margin: EdgeInsets.all(16),
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
                          fontSize: 16,
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
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '운동 정보',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildStatsGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildStatItem('거리', '${widget.record.distance.toStringAsFixed(2)} km'),
        _buildStatItem('시간', '${widget.record.duration.inMinutes} 분'),
        _buildStatItem('케이던스', '${widget.record.cadence} spm'),
        _buildStatItem(
            '평균 페이스', '${widget.record.pace.toStringAsFixed(2)} /km'),
        _buildStatItem('칼로리', '${widget.record.calories} kcal'),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: EdgeInsets.all(16),
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
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.darkTextColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}