import 'package:flutter/material.dart';

import '../../core/services/session_service.dart';
import '../../routes/app_routes.dart';

import 'dashboard/admin_dashboard_screen.dart';
import 'leads/admin_leads_screen.dart';
import 'followups/admin_followups_screen.dart';
import 'franchises/admin_franchises_screen.dart';
import 'inventory/admin_inventory_screen.dart';
import 'products/admin_products_screen.dart';
import 'suppliers/admin_suppliers_screen.dart';
import 'orders/admin_orders_screen.dart';
import 'billing/admin_billing_screen.dart';
import 'reports/admin_reports_screen.dart';
import 'whatsapp/admin_whatsapp_screen.dart';
import 'settings/admin_settings_screen.dart';
import 'notifications/admin_notifications_screen.dart';
import 'profile/admin_profile_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int currentIndex = 0;

  // =========================================================
  // MENU
  // =========================================================

  final List<_AdminMenuItem> menuItems = const [
    _AdminMenuItem(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
    ),
    _AdminMenuItem(
      title: 'Leads',
      icon: Icons.people_alt_outlined,
    ),
    _AdminMenuItem(
      title: 'Follow-ups',
      icon: Icons.calendar_month_outlined,
    ),
    _AdminMenuItem(
      title: 'Franchises',
      icon: Icons.storefront_outlined,
    ),
    _AdminMenuItem(
      title: 'Inventory',
      icon: Icons.inventory_2_outlined,
    ),
    _AdminMenuItem(
      title: 'Products',
      icon: Icons.category_outlined,
    ),
    _AdminMenuItem(
      title: 'Suppliers',
      icon: Icons.local_shipping_outlined,
    ),
    _AdminMenuItem(
      title: 'Orders',
      icon: Icons.shopping_cart_outlined,
    ),
    _AdminMenuItem(
      title: 'Billing',
      icon: Icons.receipt_long_outlined,
    ),
    _AdminMenuItem(
      title: 'Reports',
      icon: Icons.bar_chart_outlined,
    ),
    _AdminMenuItem(
      title: 'WhatsApp settings',
      icon: Icons.chat_outlined,
    ),
    
  ];

  // =========================================================
  // CURRENT SCREEN
  // =========================================================

Widget _currentScreen() {
  switch (currentIndex) {
    case 0:
      return const AdminDashboardScreen();

    case 1:
      return const AdminLeadsScreen();

    case 2:
      return const AdminFollowupsScreen();

    case 3:
      return const AdminFranchisesScreen();

    case 4:
      return const AdminInventoryScreen();

    case 5:
      return const AdminProductsScreen();

    case 6:
      return const AdminSuppliersScreen();

    case 7:
      return const AdminOrdersScreen();

    case 8:
      return const AdminBillingScreen();

    case 9:
      return const AdminReportsScreen();

    case 10:
      return const AdminWhatsAppScreen();

    case 11:
      return const AdminSettingsScreen();

    case 12:
      return const AdminNotificationsScreen();

    case 13:
      return const AdminProfileScreen();

    default:
      return const AdminDashboardScreen();
  }
}

  // =========================================================
  // MENU SELECT
  // =========================================================

  void _selectMenu(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  // =========================================================
  // SEARCH
  // =========================================================

  void _searchSection(String value) {
    final query = value.trim().toLowerCase();

    if (query.isEmpty) {
      return;
    }

    final searchMap = {
      // Dashboard
      'dashboard': 0,
      'home': 0,

      // Leads
      'lead': 1,
      'leads': 1,
      'crm': 1,
      'customer': 1,

      // Follow-ups
      'followup': 2,
      'follow-up': 2,
      'follow ups': 2,
      'follow-ups': 2,

      // Franchise
      'franchise': 3,
      'franchises': 3,

      // Inventory
      'inventory': 4,
      'stock': 4,

      // Products
      'product': 5,
      'products': 5,

      // Suppliers
      'supplier': 6,
      'suppliers': 6,
      'purchase': 6,

      // Orders
      'order': 7,
      'orders': 7,
      'dispatch': 7,

      // Billing
      'billing': 8,
      'invoice': 8,
      'payment': 8,
      'accounts': 8,

      // Reports
      'report': 9,
      'reports': 9,
      'analytics': 9,

      // WhatsApp
      'whatsapp': 10,
      'automation': 10,
      'chatbot': 10,
      'template': 10,
      'message': 10,
      'welcome message': 10,
      'quick reply': 10,

      // Settings
      'settings': 11,
      'setting': 11,
      'role': 11,
      'roles': 11,
      'permission': 11,
      'permissions': 11,
      'user': 11,
      'users': 11,

      // Notifications
      'notification': 12,
      'notifications': 12,
      'alert': 12,
      'alerts': 12,

      // Profile
      'profile': 13,
      'admin': 13,
    };

    for (final entry in searchMap.entries) {
      if (query.contains(entry.key)) {
        setState(() {
          currentIndex = entry.value;
        });

        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No matching section found',
        ),
      ),
    );
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logout() async {
    await SessionService().logout();

    if (!mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.roleSelection,
      (_) => false,
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          return _buildDesktop();
        }

        return _buildMobile();
      },
    );
  }

  // =========================================================
  // DESKTOP
  // =========================================================

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SizedBox.expand(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 250,
              child: _buildSidebar(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 72,
                    child: _buildHeader(),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: const Color(0xFFF5F7FB),
                      child: _currentScreen(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // MOBILE
  // =========================================================

  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      drawer: Drawer(
        child: _buildSidebar(
          isMobile: true,
        ),
      ),

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Text(
          _currentTitle(),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              setState(() {
                currentIndex = 12;
              });
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),

          PopupMenuButton<String>(
            onSelected: _handleProfileMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'profile',
                child: Text(
                  'My Profile',
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Text(
                  'Settings',
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            ],
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF0284C7),
              child: Text(
                'AD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),

      body: _currentScreen(),
    );
  }

  // =========================================================
  // SIDEBAR
  // =========================================================

  Widget _buildSidebar({
    bool isMobile = false,
  }) {
    return Material(
      color: const Color(0xFF111827),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // =================================================
            // LOGO
            // =================================================

            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: Color(0xFF0284C7),
                    child: Text(
                      'F',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Franchise',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Management',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MAIN MENU',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // =================================================
            // MENU LIST
            // =================================================

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                ),
                itemCount: menuItems.length,
                itemBuilder: (
                  context,
                  index,
                ) {
                  final item = menuItems[index];

                  final selected = currentIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 4,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () {
                          _selectMenu(index);

                          if (isMobile) {
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF0284C7)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 19,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFFD1D5DB),
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // =================================================
            // LOGOUT
            // =================================================

            Padding(
              padding: const EdgeInsets.all(10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: _logout,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFEF4444),
                          size: 19,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DESKTOP HEADER
  // =========================================================

  Widget _buildHeader() {
    return Material(
      color: Colors.white,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFE5E7EB),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // =================================================
            // SEARCH
            // =================================================

            SizedBox(
              width: 360,
              height: 44,
              child: TextField(
                onSubmitted: _searchSection,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText:
                      'Search leads, franchise, orders...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: Color(0xFF475569),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF0284C7),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // =================================================
            // NOTIFICATIONS
            // =================================================

            SizedBox(
              width: 44,
              height: 72,
              child: Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: () {
                          setState(() {
                            currentIndex = 12;
                          });
                        },
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 24,
                          color: Color(0xFF334155),
                        ),
                      ),

                      Positioned(
                        right: 6,
                        top: 5,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // =================================================
            // ADMIN PROFILE
            // =================================================

            PopupMenuButton<String>(
              tooltip: '',
              offset: const Offset(
                0,
                62,
              ),
              color: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: _handleProfileMenu,

              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  enabled: false,
                  height: 58,
                  child: SizedBox(
                    width: 210,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin',
                          style: TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'admin@company.com',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                PopupMenuDivider(),

                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text('My Profile'),
                    ],
                  ),
                ),

                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text('Settings'),
                    ],
                  ),
                ),

                PopupMenuDivider(),

                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: Colors.red,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // =================================================
              // VISIBLE PROFILE AREA
              // =================================================

              child: SizedBox(
                height: 72,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0284C7),
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          'AD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      const SizedBox(
                        height: 40,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1,
                                color: Color(0xFF111827),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Super Admin',
                              style: TextStyle(
                                fontSize: 10,
                                height: 1,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 21,
                        color: Color(0xFF334155),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // PROFILE MENU
  // =========================================================

  void _handleProfileMenu(String value) {
    if (value == 'profile') {
      setState(() {
        currentIndex = 13;
      });
    } else if (value == 'settings') {
      setState(() {
        currentIndex = 11;
      });
    } else if (value == 'logout') {
      _logout();
    }
  }

  // =========================================================
  // CURRENT TITLE
  // =========================================================

  String _currentTitle() {
  switch (currentIndex) {
    case 0:
      return 'Dashboard';

    case 1:
      return 'Leads';

    case 2:
      return 'Follow-ups';

    case 3:
      return 'Franchises';

    case 4:
      return 'Inventory';

    case 5:
      return 'Products';

    case 6:
      return 'Suppliers';

    case 7:
      return 'Orders';

    case 8:
      return 'Billing & Accounts';

    case 9:
      return 'Reports & Analytics';

    case 10:
      return 'WhatsApp Settings';

    case 11:
      return 'Settings';

    case 12:
      return 'Notifications';

    case 13:
      return 'Profile';

    default:
      return 'Admin';
  }
}
}

// ===========================================================
// MENU MODEL
// ===========================================================

class _AdminMenuItem {
  final String title;
  final IconData icon;

  const _AdminMenuItem({
    required this.title,
    required this.icon,
  });
}