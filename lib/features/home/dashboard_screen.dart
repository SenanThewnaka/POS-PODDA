import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/home/home_screen.dart';
import 'package:sme_buddy/features/inventory/inventory_screen.dart';
import 'package:sme_buddy/features/credit/customer_list_screen.dart';
import 'package:sme_buddy/features/settings/settings_screen.dart';
import 'package:sme_buddy/features/reports/reports_screen.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/connectivity_banner.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      extendBody: true, // Important for glass effect behind nav bar
      body: ConnectivityBanner(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
          },
          children: [
            const HomeScreen(),
            const InventoryScreen(),
            const CustomerListScreen(),
            const MenuScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        height: 64, // Floating style
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.black.withValues(alpha: 0.5) 
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white.withValues(alpha: 0.1) 
                : Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
              children: [
                _buildNavItem(0, Icons.point_of_sale, "POS"),
                _buildNavItem(1, Icons.inventory_2_outlined, "Stock"),
                _buildNavItem(2, Icons.account_balance_wallet_outlined, "Credit"),
                _buildNavItem(3, Icons.grid_view, "Menu"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected 
        ? (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent)
        : (Theme.of(context).brightness == Brightness.dark ? Colors.grey : Colors.black54);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // Ensures the entire area is clickable
        onTap: () {
          _pageController.jumpToPage(index);
          setState(() => _currentIndex = index);
        },
        child: SizedBox(
          height: double.infinity, // Fill vertical space of the navbar
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center vertically
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple internal Menu Screen to replace Drawer items
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text("Menu"), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            _buildMenuCard(
              context, 
              Icons.person, 
              user.name, 
              user.shopName ?? "My Shop",
              onTap: () {}, // Maybe profile edit later
            ),
            
          const SizedBox(height: 16),
          
          if (user?.isAdmin == true)
            _buildMenuItem(context, Icons.bar_chart, "Reports", Colors.purpleAccent, () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
            }),
            
          _buildMenuItem(context, Icons.settings, "Settings", Colors.blueAccent, () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
              Text(subtitle, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, Color color, VoidCallback onTap) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
        onTap: onTap,
      ),
    );
  }
}
