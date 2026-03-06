import 'package:flutter/material.dart';
import '../Color/AppColor.dart';
// Screens
import 'DashboardScreen.dart';
import 'ApplicationScreen.dart'; // Reordered to match mockup
import 'GatewayScreen.dart';
import 'MoreScreen.dart';

class HomeScreen extends StatefulWidget {
  final String tenantId;
  final String tenantName;

  const HomeScreen({
    super.key,
    required this.tenantId,
    required this.tenantName
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Use a getter to dynamically inject widget.tenantId into the screens.
  // IndexedStack will keep their state alive once loaded.
  List<Widget> get _screens => [
    // FIXED: Removed 'const' and passed the required tenantId
    DashboardScreen(tenantId: widget.tenantId),

    // REORDERED: Application is 2nd in your Figma mockup
    ApplicationScreen(tenantId: widget.tenantId),

    // REORDERED: Gateway is 3rd in your Figma mockup
    GatewayScreen(tenantId: widget.tenantId),

    // More Screen
    MoreScreen(
      tenantId: widget.tenantId,
      tenantName: widget.tenantName,
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Reordered to match the _screens array
  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.apps_outlined),
      activeIcon: Icon(Icons.apps),
      label: 'Application',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.router_outlined),
      activeIcon: Icon(Icons.router),
      label: 'Gateway',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.more_horiz_outlined),
      activeIcon: Icon(Icons.more_horiz),
      label: 'More',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // 1. Get dynamic colors
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Background for the nav bar
    final navBarColor = isDark ? AppColors.cardBackground(context) : Colors.white;

    // Active Item Color
    final activeColor = AppColors.iconColor(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),

      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      bottomNavigationBar: BottomNavigationBar(
        elevation: 8, // Added slight elevation so it pops out from the scaffold background
        type: BottomNavigationBarType.fixed,
        backgroundColor: navBarColor,
        selectedItemColor: activeColor,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: _navItems,
      ),
    );
  }
}