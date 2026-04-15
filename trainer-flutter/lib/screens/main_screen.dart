import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/trainer_provider.dart';
import 'home_screen.dart';
import 'clients_screen.dart';
import 'review_screen.dart';
import 'calendar_screen.dart';
import 'feedback_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<_TabItem> _tabs = const [
    _TabItem(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home),
    _TabItem(
        label: 'Clients',
        icon: Icons.people_outline,
        activeIcon: Icons.people),
    _TabItem(
        label: 'Review',
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart),
    _TabItem(
        label: 'Calendar',
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month),
    _TabItem(
        label: 'Feedback',
        icon: Icons.feedback_outlined,
        activeIcon: Icons.feedback),
    _TabItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final authProvider = context.read<AuthProvider>();
    final trainerProvider = context.read<TrainerProvider>();
    final trainer = authProvider.trainer;

    await Future.wait([
      trainerProvider.fetchAboutUs(),
      trainerProvider.fetchLocations(),
      if (trainer != null) trainerProvider.fetchClients(),
      if (trainer != null) trainerProvider.fetchTrainings(trainer.id),
    ]);
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const ClientsScreen();
      case 2:
        return const ReviewScreen();
      case 3:
        return const CalendarScreen();
      case 4:
        return const FeedbackScreen();
      case 5:
        return const SettingsScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          ClientsScreen(),
          ReviewScreen(),
          CalendarScreen(),
          FeedbackScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF333333), width: 0.5),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: _tabs
            .map((tab) => BottomNavigationBarItem(
                  icon: Icon(tab.icon),
                  activeIcon: Icon(tab.activeIcon),
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
