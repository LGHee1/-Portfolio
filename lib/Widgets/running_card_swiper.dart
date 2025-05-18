import 'package:flutter/material.dart';

class RunningCardSwiper extends StatefulWidget {
  const RunningCardSwiper({super.key});

  @override
  State<RunningCardSwiper> createState() => _RunningCardSwiperState();
}

class _RunningCardSwiperState extends State<RunningCardSwiper> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _dataList = [
    {
      '거리': '10km',
      '시간': '38.59초',
      '칼로리': '239 kcal',
      '메시지': '오늘 하루도 파이팅!!!',
    },
    {
      '거리': '5.2km',
      '시간': '20분',
      '칼로리': '170 kcal',
      '메시지': '꾸준함이 답입니다!',
    },
    {
      '거리': '7.8km',
      '시간': '30분',
      '칼로리': '210 kcal',
      '메시지': '목표에 가까워지고 있어요!',
    },
    {
      '거리': '3.4km',
      '시간': '15분',
      '칼로리': '100 kcal',
      '메시지': '가볍게 몸을 풀었어요!',
    },
    {
      '거리': '12.0km',
      '시간': '45분',
      '칼로리': '300 kcal',
      '메시지': '최고의 기록이에요! 👏',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // 화면 크기 정보 가져오기
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // 동적 크기 계산
    final cardHeight = screenHeight * 0.5; // 화면 높이의 50%
    final cardPadding = screenWidth * 0.06; // 화면 너비의 6%
    final cardMargin = screenWidth * 0.05; // 화면 너비의 5%
    final textFontSize = screenWidth * 0.04; // 화면 너비의 4%
    final messageFontSize = screenWidth * 0.045; // 화면 너비의 4.5%
    final spacing = screenHeight * 0.015; // 화면 높이의 1.5%
    final dotSize = screenWidth * 0.015; // 화면 너비의 1.5%
    final activeDotSize = screenWidth * 0.03; // 화면 너비의 3%

    return Column(
      children: [
        SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _dataList.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final item = _dataList[index];
              return Container(
                margin: EdgeInsets.symmetric(horizontal: cardMargin, vertical: spacing),
                padding: EdgeInsets.all(cardPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _infoText('러닝 거리', item['거리']!, textFontSize),
                    SizedBox(height: spacing),
                    _infoText('러닝 시간', item['시간']!, textFontSize),
                    SizedBox(height: spacing),
                    _infoText('소모 칼로리', item['칼로리']!, textFontSize),
                    SizedBox(height: spacing * 1.5),
                    Text(
                      item['메시지']!,
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: messageFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_dataList.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _currentPage == index ? activeDotSize : dotSize,
              height: dotSize,
              margin: EdgeInsets.symmetric(horizontal: dotSize * 0.3),
              decoration: BoxDecoration(
                color: _currentPage == index ? Colors.black : Colors.grey,
                borderRadius: BorderRadius.circular(dotSize * 0.5),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _infoText(String label, String value, double fontSize) {
    return Text(
      '$label : $value',
      style: TextStyle(
        fontSize: fontSize,
        color: Colors.blue,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}