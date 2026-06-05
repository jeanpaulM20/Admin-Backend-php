import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/appointment_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/credits_provider.dart';
import '../providers/performance_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/training_plan_provider.dart';
import '../services/push_notification_service.dart';
import 'start_screen.dart';
import 'calendar_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'performance_screen.dart';
import 'training_plan_list_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _mockLoaded = false;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_rounded, label: 'Start'),
    _NavItem(icon: Icons.fitness_center_rounded, label: 'Training'),
    _NavItem(icon: Icons.calendar_month_rounded, label: 'Kalender'),
    _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Chat'),
    _NavItem(icon: Icons.show_chart_rounded, label: 'Analytics'),
  ];

  final List<Widget> _screens = const [
    StartScreen(),
    TrainingPlanListScreen(),
    CalendarScreen(),
    ChatScreen(),
    PerformanceScreen(),
  ];

  String get _currentTitle {
    switch (_currentIndex) {
      case 0: return 'Start';
      case 1: return 'Training';
      case 2: return 'Kalender';
      case 3: return 'Chat';
      case 4: return 'Analytics';
      default: return 'Sihl Training';
    }
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_mockLoaded) {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      if (token == 'demo-token-preview') {
        _mockLoaded = true;
        _loadMockData();
      } else if (auth.clientId != null) {
        _mockLoaded = true;
        _initPushNotifications(auth.clientId!);
      }
    }
  }

  Future<void> _initPushNotifications(String clientId) async {
    try {
      await PushNotificationService.instance.init(clientId);
      await PushNotificationService.instance.subscribe(clientId);
    } catch (e) {
      debugPrint('Push init failed: $e');
    }
  }

  void _loadMockData() {
    context.read<AppointmentProvider>().loadMockData();
    context.read<ProfileProvider>().loadMockData();
    context.read<CreditsProvider>().loadMockData();
    context.read<PerformanceProvider>().loadMockData();
    context.read<ChatProvider>().loadMockData();
    context.read<TrainingPlanProvider>().loadMockData();
  }

  Widget _buildNavIcon(BuildContext context, IconData icon, int index, bool isSelected) {
    final widget = Icon(icon, size: 22,
        color: isSelected ? AppColors.primary : AppColors.muted);
    // Chat tab (index 3) — show unread badge
    if (index == 3) {
      final unread = context.watch<ChatProvider>().totalUnreadCount;
      if (unread > 0) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget,
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      }
    }
    return widget;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'ST',
                        style: GoogleFonts.montserrat(
                          color: AppColors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _currentTitle,
                    style: GoogleFonts.montserrat(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  // Profile avatar — tap to open Profil screen
                  GestureDetector(
                    onTap: _openProfile,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = index == _currentIndex;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildNavIcon(context, item.icon, index, isSelected),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 16 : 0,
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
