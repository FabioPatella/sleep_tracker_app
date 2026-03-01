import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/sleep_log_screen.dart';
import 'screens/sleep_stats_screen.dart';

void main() {
  runApp(SleepTrackerApp());
}

class SleepTrackerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sleep Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Automatically switch based on system theme
      home: NavigationWrapper(),
    );
  }
}

class NavigationWrapper extends StatefulWidget {
  @override
  _NavigationWrapperState createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  
  final List<Widget> _pages = [
    SleepLogScreen(),
    SleepStatsScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, -5),
            )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            _pageController.animateToPage(
              index,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Registra Sonno',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              activeIcon: Icon(Icons.insert_chart),
              label: 'Statistiche',
            ),
          ],
        ),
      ),
    );
  }
}
