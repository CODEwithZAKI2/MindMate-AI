import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/home/home_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/mood/mood_history_dashboard_screen.dart';
import '../screens/settings/settings_screen.dart';

/// Main shell with stunning bottom navigation
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late List<AnimationController> _iconControllers;

  final List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Chat',
    ),
    _NavItem(
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
      label: 'Mood',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  final List<Widget> _screens = [
    const HomeScreen(),
    const ChatScreen(),
    const MoodHistoryDashboardScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _iconControllers = List.generate(
      _navItems.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      ),
    );
    // Animate the initial selected icon
    _iconControllers[_currentIndex].forward();
  }

  @override
  void dispose() {
    for (final controller in _iconControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;

    // Animate out old, animate in new
    _iconControllers[_currentIndex].reverse();
    _iconControllers[index].forward();

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Handle back button: go to Home tab first, then exit
    return PopScope(
      canPop: _currentIndex == 0, // Only allow pop when on Home tab
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          // Go back to Home tab instead of exiting
          _iconControllers[_currentIndex].reverse();
          _iconControllers[0].forward();
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        // Hide bottom nav when on Chat screen (index 1)
        bottomNavigationBar: _currentIndex == 1
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(_navItems.length, (index) {
                        return _buildNavItem(index, theme);
                      }),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNavItem(int index, ThemeData theme) {
    final item = _navItems[index];
    final isSelected = index == _currentIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabSelected(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _iconControllers[index],
          builder: (context, child) {
            final progress = _iconControllers[index].value;
            final scale = 1.0 + (0.15 * progress);
            final color = Color.lerp(
              theme.colorScheme.onSurface.withOpacity(0.6),
              theme.colorScheme.primary,
              progress,
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated indicator dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  width: isSelected ? 24 : 0,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Animated icon
                Transform.scale(
                  scale: scale,
                  child: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 4),
                // Label
                Text(
                  item.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
