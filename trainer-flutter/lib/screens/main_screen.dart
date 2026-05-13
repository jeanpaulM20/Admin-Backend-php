import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/trainer_provider.dart';
import '../config/app_colors.dart';
import 'home_screen.dart';
import 'clients_screen.dart';
import 'trainings_screen.dart';
import 'calendar_screen.dart';
import 'nachrichten_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<_TabItem> _tabs = const [
    _TabItem(label: 'Home',      icon: Icons.home_outlined,          activeIcon: Icons.home),
    _TabItem(label: 'Kunden',    icon: Icons.people_outline,         activeIcon: Icons.people),
    _TabItem(label: 'Trainings', icon: Icons.fitness_center_outlined,activeIcon: Icons.fitness_center),
    _TabItem(label: 'Kalender',  icon: Icons.calendar_month_outlined,activeIcon: Icons.calendar_month),
    _TabItem(label: 'Nachrichten', icon: Icons.chat_bubble_outline,   activeIcon: Icons.chat_bubble),
    _TabItem(label: 'Einstellungen', icon: Icons.settings_outlined,   activeIcon: Icons.settings),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: const [
                    HomeScreen(),
                    ClientsScreen(),
                    TrainingsScreen(),
                    CalendarScreen(),
                    NachrichtenScreen(),
                    SettingsScreen(),
                  ],
                ),
              ),
              SafeArea(top: false, child: _buildBottomNav()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.muted,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        elevation: 0,
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
