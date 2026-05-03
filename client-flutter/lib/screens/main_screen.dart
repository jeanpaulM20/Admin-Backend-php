import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/appointment_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/credits_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/performance_provider.dart';
import '../providers/chat_provider.dart';
import '../services/push_notification_service.dart';
import 'start_screen.dart';
import 'calendar_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'credits_screen.dart';
import 'performance_screen.dart';
import 'invoices_screen.dart';
import 'login_screen.dart';

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
    _NavItem(icon: Icons.calendar_month_rounded, label: 'Kalender'),
    _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Chat'),
    _NavItem(icon: Icons.person_rounded, label: 'Profil'),
    _NavItem(icon: Icons.credit_card_rounded, label: 'Credits'),
    _NavItem(icon: Icons.show_chart_rounded, label: 'Leistung'),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Rechnungen'),
  ];

  final List<Widget> _screens = const [
    StartScreen(),
    CalendarScreen(),
    ChatScreen(),
    ProfileScreen(),
    CreditsScreen(),
    PerformanceScreen(),
    InvoicesScreen(),
  ];

  String get _currentTitle {
    switch (_currentIndex) {
      case 0:
        return 'Start';
      case 1:
        return 'Kalender';
      case 2:
        return 'Chat';
      case 3:
        return 'Profil';
      case 4:
        return 'Credits';
      case 5:
        return 'Leistungsdaten';
      case 6:
        return 'Rechnungen';
      default:
        return 'Sihl Training';
    }
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
    context.read<InvoiceProvider>().loadMockData();
    context.read<PerformanceProvider>().loadMockData();
    context.read<ChatProvider>().loadMockData();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Abmelden',
            style: TextStyle(color: AppColors.text)),
        content: const Text('Moechtest du dich wirklich abmelden?',
            style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildNavIcon(BuildContext context, IconData icon, int index, bool isSelected) {
    final widget = Icon(icon, size: 22,
        color: isSelected ? AppColors.primary : AppColors.muted);
    // Chat tab (index 2) — show unread badge
    if (index == 2) {
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
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded,
                        color: AppColors.muted, size: 22),
                    tooltip: 'Abmelden',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
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
