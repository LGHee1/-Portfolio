import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/workout_record.dart';
import '../../utils/theme.dart';
import 'workout_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Widgets/bottom_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _firstDay;
  late DateTime _lastDay;
  DateTime? _selectedDay;
  List<WorkoutRecord> _selectedDayRecords = [];
  int _currentRecordIndex = 0;
  String _currentUser = '나';
  final List<String> _friends = ['나', '친구1', '친구2', '친구3', '친구4', '친구5'];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<WorkoutRecord> _workoutRecords = [];
  final PageController _pageController = PageController();
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _firstDay = DateTime(_focusedDay.year - 1, 1, 1);
    _lastDay = DateTime(_focusedDay.year + 1, 12, 31);
    _selectedDay = _focusedDay;
    _loadWorkoutData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkoutData() async {
    final user = _auth.currentUser;
    List<WorkoutRecord> records = [];

    if (user != null) {
      try {
        print('운동 데이터 로드 시작 - 사용자: ${user.uid}');
        final snapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('Running_Data')
            .orderBy('date', descending: true)
            .get();

        print('가져온 운동 데이터 수: ${snapshot.docs.length}');

        records.addAll(snapshot.docs.map((doc) {
          final data = doc.data();
          print('운동 데이터: ${data['date']} - 거리: ${data['distance']}km');

          final List<Map<String, double>> routePoints =
          (data['routePoints'] as List)
              .map((point) => Map<String, double>.from(point))
              .toList();

          // Convert pace string (e.g., "5'30"") to double
          String paceStr = data['pace'] as String;
          double pace = 0.0;
          if (paceStr.contains("'")) {
            final parts = paceStr.split("'");
            final minutes = int.parse(parts[0]);
            final seconds = int.parse(parts[1].replaceAll('"', ''));
            pace = minutes + (seconds / 60);
          }

          final record = WorkoutRecord(
            userId: user.uid,
            date: (data['date'] as Timestamp).toDate(),
            distance: (data['distance'] as num).toDouble(),
            duration: Duration(seconds: data['duration'] as int),
            pace: pace,
            cadence: 0, // Not stored in Firebase yet
            calories: data['calories'] as int,
            routePoints: routePoints,
          );

          print('변환된 운동 기록: ${record.date} - 거리: ${record.distance}km');
          return record;
        }).toList());
      } catch (e) {
        print('운동 데이터 로드 중 오류 발생: $e');
      }
    }

    setState(() {
      _workoutRecords = records;
      _updateSelectedRecords();
    });
  }

  void _updateSelectedRecords() {
    if (_selectedDay == null) return;

    setState(() {
      _selectedDayRecords = _workoutRecords
          .where((record) => isSameDay(record.date, _selectedDay))
          .toList();
      _currentRecordIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('캘린더'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(height: 16.h),
          _buildUserSelector(),
          SizedBox(height: 24.h),
          Container(
            height: 80.h,
            margin: EdgeInsets.only(bottom: 24.h),
            child: _selectedDayRecords.isNotEmpty
                ? _buildWorkoutSummary()
                : _buildEmptyWorkoutSummary(),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _buildCalendar(),
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
        },
      ),
    );
  }

  Widget _buildUserSelector() {
    return Container(
      height: 60.h,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          final isSelected = friend == _currentUser;
          return Container(
            width: 80.w,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentUser = friend;
                  _updateSelectedRecords();
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.lightTextColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    friend,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.darkTextColor
                          : AppTheme.lightTextColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyWorkoutSummary() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '날짜를 선택해 주세요',
                  style: TextStyle(
                    color: AppTheme.darkTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutSummary() {
    if (_selectedDayRecords.isEmpty) return _buildEmptyWorkoutSummary();

    return Column(
      children: [
        Container(
          height: 80.h,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _selectedDayRecords.length,
            onPageChanged: (index) {
              setState(() {
                _currentRecordIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final record = _selectedDayRecords[index];
              return Container(
                padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
                margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${record.distance.toStringAsFixed(1)}km',
                            style: TextStyle(
                              color: AppTheme.darkTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('•', style: TextStyle(color: Colors.grey)),
                          ),
                          Text(
                            '${record.duration.inMinutes}분',
                            style: TextStyle(
                              color: AppTheme.darkTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('•', style: TextStyle(color: Colors.grey)),
                          ),
                          Text(
                            '${record.pace.toStringAsFixed(2)}분/km',
                            style: TextStyle(
                              color: AppTheme.darkTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                     TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkoutDetailScreen(record: record),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '상세보기',
                            style: TextStyle(
                              color: AppTheme.darkTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: AppTheme.darkTextColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_selectedDayRecords.length > 1)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _selectedDayRecords.length,
                (index) => Container(
                  width: 8.w,
                  height: 8.h,
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentRecordIndex == index
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCalendar() {
    print('캘린더 빌드 - 현재 운동 기록 수: ${_workoutRecords.length}');
    return TableCalendar(
      firstDay: _firstDay,
      lastDay: _lastDay,
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.sunday,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextFormatter: (date, locale) {
          return '${date.year}년 ${date.month}월';
        },
        leftChevronIcon: 
        Icon(Icons.chevron_left, color: AppTheme.darkTextColor),
        rightChevronIcon: 
        Icon(Icons.chevron_right, color: AppTheme.darkTextColor),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        weekendTextStyle: TextStyle(color: Colors.red),
        holidayTextStyle: TextStyle(color: Colors.red),
        todayDecoration: BoxDecoration(
          border: Border.all(color: AppTheme.primaryColor, width: 2),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(color: AppTheme.darkTextColor,
        ),
        selectedDecoration: BoxDecoration(
          color: AppTheme.primaryColor,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(color: Colors.white),
        defaultTextStyle: TextStyle(color: AppTheme.darkTextColor),
        markerSize: 0,
        markersAlignment: AlignmentDirectional.center,
        cellMargin: const EdgeInsets.all(4),
        rangeHighlightScale: 1.0,
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final hasWorkout = _workoutRecords.any((record) => isSameDay(record.date, day));

          if (hasWorkout) {
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(color: AppTheme.darkTextColor),
                ),
              ),
            );
          }
          return null;
        },
      ),
      onDaySelected: _onDaySelected,
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
      },
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _updateSelectedRecords();
    });
  }
}