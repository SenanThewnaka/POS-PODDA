import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/home/home_screen.dart';
import 'package:sme_buddy/features/inventory/inventory_screen.dart';
import 'package:sme_buddy/features/credit/customer_list_screen.dart';
import 'package:sme_buddy/features/settings/settings_screen.dart';
import 'package:sme_buddy/features/reports/reports_screen.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/features/procurement/grn_history_screen.dart';
import 'package:sme_buddy/features/shifts/shift_history_screen.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/connectivity_banner.dart';
import 'package:sme_buddy/utils/responsive_layout.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  bool? _isSidebarCollapsedOverride;
  final PageController _pageController = PageController();

  bool _isCollapsed(BuildContext context) {
    if (_isSidebarCollapsedOverride != null) return _isSidebarCollapsedOverride!;
    return context.isTablet;
  }

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = context.isTabletOrDesktop;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(userProfileProvider).value;

    final contentPages = [
      const HomeScreen(),
      const InventoryScreen(),
      const CustomerListScreen(),
      isDesktopOrTablet ? const ReportsScreen() : const MenuScreen(),
      const SettingsScreen(),
    ];

    Widget body = PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        setState(() => _currentIndex = index);
      },
      children: contentPages,
    );

    if (isDesktopOrTablet) {
      return GlassScaffold(
        extendBody: false,
        body: ConnectivityBanner(
          child: Row(
            children: [
              _buildDesktopSidebar(context, isDark, user),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return GlassScaffold(
      extendBody: true, // Important for glass effect behind nav bar on mobile
      body: ConnectivityBanner(child: body),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        height: 64, // Floating style
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.black.withValues(alpha: 0.5) 
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark 
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

  Widget _buildDesktopSidebar(BuildContext context, bool isDark, dynamic user) {
    final activeColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
    final sidebarBg = isDark ? const Color(0xFF1E293B).withOpacity(0.9) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final isCollapsed = _isCollapsed(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isCollapsed ? 76 : 230,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sidebarBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight > 32 ? constraints.maxHeight - 32 : 0),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: isCollapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      // 1. Header & Collapse Toggle
                      if (isCollapsed) ...[
                        IconButton(
                          icon: const Icon(Icons.store_mall_directory_rounded, size: 24),
                          color: activeColor,
                          tooltip: user?.shopName ?? "POS Podda",
                          onPressed: () => setState(() => _isSidebarCollapsedOverride = false),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 18),
                          color: isDark ? Colors.white54 : Colors.black45,
                          tooltip: "Expand Sidebar",
                          onPressed: () => setState(() => _isSidebarCollapsedOverride = false),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: activeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.store_mall_directory_rounded, color: activeColor, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.shopName ?? "POS Podda",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      "POS + ERP",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: activeColor,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_left, size: 20),
                                color: isDark ? Colors.white54 : Colors.black45,
                                tooltip: "Collapse Sidebar",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => setState(() => _isSidebarCollapsedOverride = true),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Divider(height: 1, color: borderColor),
                      const SizedBox(height: 16),

                      // 2. Navigation Items
                      _buildSidebarItem(0, Icons.point_of_sale_rounded, "POS Register", activeColor, isDark, isCollapsed),
                      const SizedBox(height: 6),
                      _buildSidebarItem(1, Icons.inventory_2_rounded, "Inventory / Stock", activeColor, isDark, isCollapsed),
                      const SizedBox(height: 6),
                      _buildSidebarItem(2, Icons.account_balance_wallet_rounded, "Credit Book (Naya)", activeColor, isDark, isCollapsed),
                      const SizedBox(height: 6),
                      _buildSidebarItem(3, Icons.bar_chart_rounded, "Sales Reports", activeColor, isDark, isCollapsed),
                      const SizedBox(height: 6),
                      _buildSidebarItem(4, Icons.settings_rounded, "Settings", activeColor, isDark, isCollapsed),

                      const Spacer(),
                      const SizedBox(height: 16),

                      // 3. Current Cashier Profile & Sign Out
                      if (isCollapsed) ...[
                        Tooltip(
                          message: "${user?.name ?? 'Cashier'} (${user?.role ?? 'Staff'})",
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: activeColor.withOpacity(0.18),
                            child: Text(
                              (user?.name != null && user!.name.isNotEmpty) ? user.name[0].toUpperCase() : "U",
                              style: TextStyle(fontWeight: FontWeight.bold, color: activeColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        IconButton(
                          icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                          tooltip: "Sign Out",
                          onPressed: () => ref.read(authRepositoryProvider).signOut(),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: activeColor.withOpacity(0.18),
                                child: Text(
                                  (user?.name != null && user!.name.isNotEmpty) ? user.name[0].toUpperCase() : "U",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: activeColor, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.name ?? "Cashier",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      (user?.role ?? "Staff").toString().toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isDark ? Colors.white54 : Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout, size: 16, color: Colors.redAccent),
                                tooltip: "Sign Out",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label, Color activeColor, bool isDark, bool isCollapsed) {
    final isSelected = _currentIndex == index;

    if (isCollapsed) {
      return Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 300),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _navigateTo(index),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? activeColor.withOpacity(0.4) : Colors.transparent,
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateTo(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeColor.withOpacity(0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? activeColor : (isDark ? Colors.white : Colors.black87),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
        behavior: HitTestBehavior.opaque,
        onTap: () => _navigateTo(index),
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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

          if (user?.hasPermission(AppPermissions.canManageInventory) ?? true)
            _buildMenuItem(context, Icons.local_shipping_outlined, "Procurement & ERP (GRN)", Colors.cyanAccent, () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const GRNHistoryScreen()));
            }),

          _buildMenuItem(context, Icons.point_of_sale_rounded, "Shifts & Cash Balancing", Colors.greenAccent, () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const ShiftHistoryScreen()));
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
