import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/workout_record.dart';
import '../../utils/theme.dart';
import 'workout_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Widgets/bottom_bar.dart';

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
    // 화면 크기 정보 가져오기
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // 동적 크기 계산
    final titleFontSize = screenWidth * 0.06; // 화면 너비의 6%
    final subtitleFontSize = screenWidth * 0.04; // 화면 너비의 4%
    final padding = screenWidth * 0.04; // 화면 너비의 4%
    final spacing = screenHeight * 0.015; // 화면 높이의 1.5%
    final userSelectorHeight = screenHeight * 0.06; // 화면 높이의 6%
    final summaryHeight = screenHeight * 0.1; // 화면 높이의 10%

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '캘린더',
          style: TextStyle(fontSize: titleFontSize),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(height: spacing * 0.5),
          _buildUserSelector(userSelectorHeight),
          SizedBox(height: spacing * 0.3),
          Container(
            height: summaryHeight,
            margin: EdgeInsets.only(bottom: spacing * 0.2),
            child: _selectedDayRecords.isNotEmpty
                ? _buildWorkoutSummary(subtitleFontSize)
                : _buildEmptyWorkoutSummary(subtitleFontSize),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: _buildCalendar(subtitleFontSize),
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

  Widget _buildUserSelector(double height) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(vertical: height * 0.1),
      margin: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.04),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          final isSelected = friend == _currentUser;
          return Container(
            width: (MediaQuery.of(context).size.width - 32) / 4,
            padding: EdgeInsets.symmetric(horizontal: 4),
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
                      fontSize: MediaQuery.of(context).size.width * 0.035,
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

  Widget _buildEmptyWorkoutSummary(double fontSize) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: MediaQuery.of(context).size.height * 0.02,
        horizontal: MediaQuery.of(context).size.width * 0.05,
      ),
      margin: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.04,
        vertical: MediaQuery.of(context).size.height * 0.01,
      ),
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
                    fontSize: fontSize,
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

  Widget _buildWorkoutSummary(double fontSize) {
    if (_selectedDayRecords.isEmpty) return _buildEmptyWorkoutSummary(fontSize);

    return Column(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.1,
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
                padding: EdgeInsets.symmetric(
                  vertical: MediaQuery.of(context).size.height * 0.02,
                  horizontal: MediaQuery.of(context).size.width * 0.05,
                ),
                margin: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.04,
                  vertical: MediaQuery.of(context).size.height * 0.01,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${record.distance.toStringAsFixed(1)}km',
                            style: TextStyle(
                              color: AppTheme.darkTextColor,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.03),
                            child: Text('•', style: TextStyle(color: Colors.grey)),
                          ),
                          Text(
                            '${record.duration.inMinutes}분',
                            style: TextStyle(
                              color: AppTheme.darkTextColor,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.03),
                            child: Text('•', style: TextStyle(color: Colors.grey)),
                          ),
                          Text(
                            '${record.pace.toStringAsFixed(2)}분/km',
                            style: TextStyle(
                              color: AppTheme.darkTextColor,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkoutDetailScreen(record: record),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '상세보기',
                              style: TextStyle(
                                color: AppTheme.darkTextColor,
                                fontSize: fontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: fontSize,
                              color: AppTheme.darkTextColor,
                            ),
                          ],
                        ),
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
            padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.01),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _selectedDayRecords.length,
                (index) => Container(
                  width: MediaQuery.of(context).size.width * 0.02,
                  height: MediaQuery.of(context).size.width * 0.02,
                  margin: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.01),
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

  Widget _buildCalendar(double fontSize) {
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
        titleTextStyle: TextStyle(
          fontSize: fontSize * 1.1,
          fontWeight: FontWeight.bold,
        ),
        titleTextFormatter: (date, locale) {
          return '${date.year}년 ${date.month}월';
        },
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: AppTheme.darkTextColor,
          size: fontSize * 1.3,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: AppTheme.darkTextColor,
          size: fontSize * 1.3,
        ),
        headerPadding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.005),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        weekendTextStyle: TextStyle(
          color: Colors.red,
          fontSize: fontSize * 0.9,
        ),
        holidayTextStyle: TextStyle(
          color: Colors.red,
          fontSize: fontSize * 0.9,
        ),
        todayDecoration: BoxDecoration(
          border: Border.all(color: AppTheme.primaryColor, width: 1.5),
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: AppTheme.darkTextColor,
          fontSize: fontSize * 0.9,
        ),
        selectedDecoration: BoxDecoration(
          color: AppTheme.primaryColor,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(
          color: Colors.white,
          fontSize: fontSize * 0.9,
        ),
        defaultTextStyle: TextStyle(
          color: AppTheme.darkTextColor,
          fontSize: fontSize * 0.9,
        ),
        markerSize: 0,
        markersAlignment: AlignmentDirectional.center,
        cellMargin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.003),
        cellPadding: EdgeInsets.zero,
        rangeHighlightScale: 1.0,
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final hasWorkout = _workoutRecords.any((record) => isSameDay(record.date, day));

          if (hasWorkout) {
            return Container(
              margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.003),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: AppTheme.darkTextColor,
                    fontSize: fontSize * 0.9,
                  ),
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