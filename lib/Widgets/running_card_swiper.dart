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
    return Column(
      children: [
        SizedBox(
          height: 300,
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
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                padding: const EdgeInsets.all(24),
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
                    _infoText('러닝 거리', item['거리']!, 16),
                    const SizedBox(height: 12),
                    _infoText('러닝 시간', item['시간']!, 16),
                    const SizedBox(height: 12),
                    _infoText('소모 칼로리', item['칼로리']!, 16),
                    const SizedBox(height: 24),
                    Text(
                      item['메시지']!,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_dataList.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _currentPage == index ? 12 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _currentPage == index ? Colors.black : Colors.grey,
                borderRadius: BorderRadius.circular(3),
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
        fontSize: 16,
        color: Colors.blue,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}