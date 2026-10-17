import 'package:flutter/material.dart';

import '../../core/services/session_service.dart';
import '../../core/services/notification_service.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';

import 'cart/customer_cart_screen.dart';
import 'customer_settings_screen.dart';
import 'home/customer_home_screen.dart';
import 'orders/customer_orders_screen.dart';
import 'products/customer_products_screen.dart';
import 'profile/customer_profile_screen.dart';

class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({super.key});

  @override
  State<CustomerMainScreen> createState() =>
      _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  int currentIndex = 0;
  UserModel? _currentUser;
  Key _ordersKey = UniqueKey();
  Key _profileKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    NotificationService().registerDeviceTokenWithBackend();
  }

  Future<void> _loadCurrentUser() async {
    final user = await SessionService().getUser();
    if (mounted && user != null) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  // 0 = Home
  // 1 = Products
  // 2 = Cart
  // 3 = Orders
  // 4 = Profile
  // 5 = Settings
  List<Widget> get screens => [
    CustomerHomeScreen(
      onOpenProducts: () => setState(() => currentIndex = 1),
      onOpenCart: () => setState(() => currentIndex = 2),
      onOpenOrders: () => setState(() {
        _ordersKey = UniqueKey();
        currentIndex = 3;
      }),
      onOpenProfile: () => setState(() {
        _profileKey = UniqueKey();
        currentIndex = 4;
      }),
    ),
    const CustomerProductsScreen(),
    const CustomerCartScreen(),
    CustomerOrdersScreen(key: _ordersKey),
    CustomerProfileScreen(key: _profileKey),
    const CustomerSettingsScreen(),
  ];

  final List<_CustomerMenuItem> menuItems = const [
    _CustomerMenuItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _CustomerMenuItem(
      label: 'Products',
      icon: Icons.local_mall_outlined,
      selectedIcon: Icons.local_mall,
    ),
    _CustomerMenuItem(
      label: 'Cart',
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart,
    ),
    _CustomerMenuItem(
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    _CustomerMenuItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          return _buildDesktopLayout();
        }

        return _buildMobileLayout();
      },
    );
  }

  // =========================================================
  // MOBILE
  // =========================================================

  Widget _buildMobileLayout() {
    // Settings is not part of bottom navigation.
    // If desktop was resized while Settings was open,
    // show Profile on mobile instead.
    final mobileIndex = currentIndex > 4 ? 4 : currentIndex;

    return Scaffold(
      body: IndexedStack(
        index: mobileIndex,
        children: screens.take(5).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileIndex,
        indicatorColor: const Color(0xFFE0F2FE),
        backgroundColor: Colors.white,
        elevation: 3,
        onDestinationSelected: (index) {
          setState(() {
            if (index == 3) {
              _ordersKey = UniqueKey();
            } else if (index == 4) {
              _profileKey = UniqueKey();
            }
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF0284C7)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_mall_outlined),
            selectedIcon: Icon(Icons.local_mall, color: Color(0xFF0284C7)),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart, color: Color(0xFF0284C7)),
            label: 'Cart',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF0284C7)),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF0284C7)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logoutCustomer() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Colors.red,
              ),
              SizedBox(width: 10),
              Text('Logout'),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    await SessionService().logout();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.roleSelection,
      (_) => false,
    );
  }

  // =========================================================
  // DESKTOP
  // =========================================================

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      body: Row(
        children: [
          // =====================================================
          // LEFT SIDEBAR
          // =====================================================

          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // =================================================
                  // SIDEBAR BRAND
                  // =================================================

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 22,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.water_drop_rounded,
                            color: Color(0xFF0284C7),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Water Wala',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Customer Portal',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  const SizedBox(height: 18),

                  // =================================================
                  // SIDEBAR MENU
                  // =================================================

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      itemCount: menuItems.length,
                      itemBuilder: (context, index) {
                        final item = menuItems[index];

                        // Settings = index 5, so no sidebar menu
                        // will appear selected.
                        final selected = currentIndex == index;

                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: 6,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                if (index == 3) {
                                  _ordersKey = UniqueKey();
                                } else if (index == 4) {
                                  _profileKey = UniqueKey();
                                }
                                currentIndex = index;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(
                                milliseconds: 150,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFE0F2FE)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? item.selectedIcon
                                        : item.icon,
                                    size: 21,
                                    color: selected
                                        ? const Color(0xFF0284C7)
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // =================================================
                  // SUPPORT CARD
                  // =================================================

                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.support_agent_rounded,
                              color: Color(0xFF0284C7),
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Need Help?',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Contact our support team',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 36,
                            child: OutlinedButton(
                              onPressed: () {},
                              child: const Text(
                                'Contact Support',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // =====================================================
          // RIGHT SIDE
          // =====================================================

          Expanded(
            child: Column(
              children: [
                // =================================================
                // TOP HEADER
                // =================================================

                Container(
                  height: 82,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // =============================================
                      // HEADER BRAND
                      // =============================================

                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.water_drop_rounded,
                              size: 26,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(width: 13),
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Water Wala',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pure Water. Delivered.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const Spacer(),

                      // =============================================
                      // SEARCH
                      // =============================================

                      SizedBox(
                        width: 310,
                        height: 44,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search products, orders...',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 21,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 18),

                      // =============================================
                      // NOTIFICATION
                      // =============================================

                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.notifications_none_rounded,
                              size: 24,
                              color: Color(0xFF334155),
                            ),
                          ),
                          Positioned(
                            right: 7,
                            top: 7,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 12),

                      Container(
                        width: 1,
                        height: 34,
                        color: const Color(0xFFE2E8F0),
                      ),

                      const SizedBox(width: 14),

                      // =============================================
                      // PROFILE DROPDOWN
                      // =============================================

                      PopupMenuButton<String>(
                        tooltip: 'Account Menu',
                        offset: const Offset(0, 55),
                        color: Colors.white,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onSelected: (value) async {
                          // MY PROFILE
                          if (value == 'profile') {
                            setState(() {
                              currentIndex = 4;
                            });
                          }

                          // SETTINGS PAGE
                          if (value == 'settings') {
                            setState(() {
                              currentIndex = 5;
                            });
                          }

                          // LOGOUT
                          if (value == 'logout') {
                            await _logoutCustomer();
                          }
                        },
                        itemBuilder: (context) {
                          return [
                            // =========================================
                            // PROFILE
                            // =========================================

                            const PopupMenuItem<String>(
                              value: 'profile',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 20,
                                    color: Color(0xFF475569),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'My Profile',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // =========================================
                            // SETTINGS
                            // =========================================

                            const PopupMenuItem<String>(
                              value: 'settings',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.settings_outlined,
                                    size: 20,
                                    color: Color(0xFF475569),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Settings',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const PopupMenuDivider(),

                            // =========================================
                            // LOGOUT
                            // =========================================

                            const PopupMenuItem<String>(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.logout_rounded,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Logout',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ];
                        },

                        // =============================================
                        // DROPDOWN BUTTON
                        // =============================================

                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 20,
                                backgroundColor: Color(0xFFE0F2FE),
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 21,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentUser?.name.trim().isNotEmpty == true
                                        ? _currentUser!.name.trim()
                                        : 'Customer',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Customer',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 19,
                                color: Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // =================================================
                // PAGE CONTENT
                // =================================================

                Expanded(
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    child: IndexedStack(
                      index: currentIndex,
                      children: screens,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// CUSTOMER SIDEBAR MENU MODEL
// =========================================================

class _CustomerMenuItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _CustomerMenuItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}