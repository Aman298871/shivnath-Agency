import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/session_service.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';

import 'dashboard/franchise_dashboard_screen.dart';
import 'documents/franchise_documents_screen.dart';
import 'franchise_settings_screen.dart';
import 'invoices/franchise_invoices_screen.dart';
import 'notifications/franchise_notifications_screen.dart';
import 'orders/franchise_orders_screen.dart';
import 'payments/franchise_payments_screen.dart';
import 'products/franchise_products_screen.dart';
import 'profile/franchise_profile_screen.dart';
import 'territory/franchise_territory_screen.dart';
import 'widgets/franchise_approval_guard.dart';

class FranchiseMainScreen extends StatefulWidget {
  const FranchiseMainScreen({super.key});

  @override
  State<FranchiseMainScreen> createState() =>
      _FranchiseMainScreenState();
}

class _FranchiseMainScreenState extends State<FranchiseMainScreen> {
  int currentIndex = 0;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    // 1. Load local cached user first
    final cached = await SessionService().getCurrentUser();
    if (mounted && cached != null) {
      setState(() => _currentUser = cached);
    }

    // 2. Fetch fresh real-time status from backend
    final res = await AuthService().getCurrentUser();
    if (res['success'] == true && res['data'] is Map<String, dynamic>) {
      final updated = UserModel.fromJson(res['data'] as Map<String, dynamic>);
      await SessionService().saveUser(updated);
      if (mounted) {
        setState(() => _currentUser = updated);
      }
    }
  }

  final List<_FranchiseMenuItem> menuItems = const [
    _FranchiseMenuItem(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    _FranchiseMenuItem(
      title: 'Products',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
    ),
    _FranchiseMenuItem(
      title: 'Orders',
      icon: Icons.shopping_bag_outlined,
      selectedIcon: Icons.shopping_bag_rounded,
    ),
    _FranchiseMenuItem(
      title: 'Invoices',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
    ),
    _FranchiseMenuItem(
      title: 'Payments',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments_rounded,
    ),
    _FranchiseMenuItem(
      title: 'Documents',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
    ),
    _FranchiseMenuItem(
      title: 'Territory',
      icon: Icons.location_on_outlined,
      selectedIcon: Icons.location_on_rounded,
    ),
    _FranchiseMenuItem(
      title: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  // =========================================================
  // CURRENT SCREEN
  // =========================================================

  Widget _currentScreen() {
    switch (currentIndex) {
      case 0:
        return const FranchiseDashboardScreen();

      case 1:
        return const FranchiseProductsScreen();

      case 2:
        return const FranchiseOrdersScreen();

      case 3:
        return const FranchiseInvoicesScreen();

      case 4:
        return const FranchisePaymentsScreen();

      case 5:
        return const FranchiseDocumentsScreen();

      case 6:
        return const FranchiseTerritoryScreen();

      case 7:
        return const FranchiseProfileScreen();

      case 8:
        return const FranchiseSettingsScreen();

      default:
        return const FranchiseDashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FranchiseApprovalGuard(
      user: _currentUser,
      onRefreshStatus: _loadUser,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool desktop =
              constraints.maxWidth >= 800;

          if (desktop) {
            return _buildDesktop();
          }

          return _buildMobile();
        },
      ),
    );
  }

  // =========================================================
  // DESKTOP
  // =========================================================

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SizedBox.expand(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =========================
            // LEFT SIDEBAR
            // =========================
            SizedBox(
              width: 250,
              child: _buildSidebar(),
            ),

            // =========================
            // RIGHT AREA
            // =========================
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  // HEADER
                  SizedBox(
                    height: 72,
                    child: _buildHeader(),
                  ),

                  // SCREEN CONTENT
                  Expanded(
                    child: ClipRect(
                      child: ColoredBox(
                        color: const Color(0xFFF6F7FB),
                        child: _currentScreen(),
                      ),
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
  // SIDEBAR
  // =========================================================

  Widget _buildSidebar() {
    return Material(
      color: const Color(0xFF111827),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            // =========================
            // LOGO
            // =========================
            SizedBox(
              height: 76,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.water_drop_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shivnath Agency',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Franchise Portal',
                            style: TextStyle(
                              color:
                                  Color(0xFF94A3B8),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFF1F2937),
            ),

            // =========================
            // FRANCHISE USER CARD
            // =========================
            Container(
              margin: const EdgeInsets.fromLTRB(
                14,
                16,
                14,
                10,
              ),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.055,
                ),
                borderRadius:
                    BorderRadius.circular(11),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: 0.06,
                  ),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor:
                        const Color(0xFF0EA5E9),
                    child: Text(
                      _currentUser?.name.isNotEmpty == true
                          ? _currentUser!.name.substring(0, 1).toUpperCase()
                          : 'FP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser?.name.isNotEmpty == true
                              ? _currentUser!.name
                              : 'Franchise Partner',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _currentUser?.phone.isNotEmpty == true
                              ? _currentUser!.phone
                              : 'Authorized Partner',
                          style: const TextStyle(
                            color:
                                Color(0xFF94A3B8),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(
                21,
                8,
                21,
                9,
              ),
              child: Text(
                'FRANCHISE MENU',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 8,
                  fontWeight:
                      FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            // =========================
            // MENU ITEMS
            // =========================
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 11,
                ),
                itemCount: menuItems.length,
                itemBuilder: (
                  context,
                  index,
                ) {
                  final item =
                      menuItems[index];

                  final bool selected =
                      currentIndex == index;

                  return Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 4,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(9),
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(
                          9,
                        ),
                        onTap: () {
                          if (currentIndex ==
                              index) {
                            return;
                          }

                          setState(() {
                            currentIndex = index;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(
                            milliseconds: 150,
                          ),
                          height: 44,
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 12,
                          ),
                          decoration:
                              BoxDecoration(
                            color: selected
                                ? const Color(
                                    0xFF0284C7,
                                  )
                                : Colors
                                    .transparent,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              9,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? item
                                        .selectedIcon
                                    : item.icon,
                                size: 20,
                                color: selected
                                    ? Colors.white
                                    : const Color(
                                        0xFF9CA3AF,
                                      ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Expanded(
                                child: Text(
                                  item.title,
                                  style:
                                      TextStyle(
                                    color: selected
                                        ? Colors
                                            .white
                                        : const Color(
                                            0xFF9CA3AF,
                                          ),
                                    fontSize: 11,
                                    fontWeight:
                                        selected
                                            ? FontWeight
                                                .w700
                                            : FontWeight
                                                .w500,
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

            // =========================
            // LOGOUT
            // =========================
            Container(
              padding:
                  const EdgeInsets.all(12),
              decoration:
                  const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color:
                        Color(0xFF1F2937),
                  ),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius:
                    BorderRadius.circular(9),
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(9),
                  onTap: _logout,
                  child: const SizedBox(
                    height: 44,
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 20,
                            color: Color(
                              0xFFFCA5A5,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: Color(
                                0xFFFCA5A5,
                              ),
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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
  // HEADER
  // =========================================================

  Widget _buildHeader() {
    return Material(
      color: Colors.white,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 28,
        ),
        decoration:
            const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFE8EBF0),
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.storefront_rounded,
              color: Color(0xFF0284C7),
              size: 22,
            ),

            const SizedBox(width: 11),

            const Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Franchise Portal',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Manage orders, payments and franchise operations',
                  style: TextStyle(
                    fontSize: 9,
                    color:
                        Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: 280,
              height: 42,
              child: TextField(
                decoration:
                    InputDecoration(
                  hintText:
                      'Search orders, products...',
                  hintStyle:
                      const TextStyle(
                    fontSize: 12,
                  ),
                  prefixIcon:
                      const Icon(
                    Icons.search_rounded,
                    size: 20,
                  ),
                  filled: true,
                  fillColor:
                      const Color(
                    0xFFF8FAFC,
                  ),
                  contentPadding:
                      EdgeInsets.zero,
                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                    borderSide:
                        const BorderSide(
                      color:
                          Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                    borderSide:
                        const BorderSide(
                      color:
                          Color(0xFF0EA5E9),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            IconButton(
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const FranchiseNotificationsScreen(),
                  ),
                );
              },
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF475569),
              ),
            ),

            const SizedBox(width: 10),

            PopupMenuButton<String>(
              tooltip: '',
              onSelected: (value) async {
                switch (value) {
                  case 'profile':
                    setState(() {
                      currentIndex = 7;
                    });
                    break;

                  case 'settings':
                    setState(() {
                      currentIndex = 8;
                    });
                    break;

                  case 'logout':
                    await _logout();
                    break;
                }
              },
              itemBuilder: (_) =>
                  const [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .person_outline_rounded,
                        size: 20,
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
                        Icons
                            .settings_outlined,
                        size: 20,
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
                        size: 20,
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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor:
                        const Color(0xFFE0F2FE),
                    child: Text(
                      _currentUser?.name.isNotEmpty == true
                          ? _currentUser!.name.substring(0, 1).toUpperCase()
                          : 'FP',
                      style: const TextStyle(
                        color:
                            Color(0xFF0284C7),
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(width: 9),

                  Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser?.name.isNotEmpty == true
                            ? _currentUser!.name
                            : 'Franchise Partner',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w700,
                          color:
                              Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Franchise',
                        style: TextStyle(
                          fontSize: 9,
                          color:
                              Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 5),

                  const Icon(
                    Icons
                        .keyboard_arrow_down_rounded,
                    size: 18,
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
    int mobileIndex = currentIndex;

    if (mobileIndex < 0 ||
        mobileIndex > 4) {
      mobileIndex = 0;
    }

    Widget mobileScreen;

    switch (mobileIndex) {
      case 1:
        mobileScreen =
            const FranchiseProductsScreen();
        break;

      case 2:
        mobileScreen =
            const FranchiseOrdersScreen();
        break;

      case 3:
        mobileScreen =
            const FranchiseInvoicesScreen();
        break;

      case 4:
        mobileScreen =
            const FranchisePaymentsScreen();
        break;

      case 0:
      default:
        mobileScreen =
            const FranchiseDashboardScreen();
        break;
    }

    return Scaffold(
      body: mobileScreen,
      bottomNavigationBar:
          NavigationBar(
        selectedIndex: mobileIndex,
        onDestinationSelected: (
          index,
        ) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.dashboard_outlined,
            ),
            selectedIcon: Icon(
              Icons.dashboard_rounded,
            ),
            label: 'Home',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.inventory_2_outlined,
            ),
            selectedIcon: Icon(
              Icons.inventory_2_rounded,
            ),
            label: 'Products',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.shopping_bag_outlined,
            ),
            selectedIcon: Icon(
              Icons.shopping_bag_rounded,
            ),
            label: 'Orders',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.receipt_long_outlined,
            ),
            selectedIcon: Icon(
              Icons.receipt_long_rounded,
            ),
            label: 'Invoices',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.payments_outlined,
            ),
            selectedIcon: Icon(
              Icons.payments_rounded,
            ),
            label: 'Payments',
          ),
        ],
      ),
    );
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logout() async {
    final bool? shouldLogout =
        await showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title:
              const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

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
}

// =========================================================
// MENU MODEL
// =========================================================

class _FranchiseMenuItem {
  final String title;
  final IconData icon;
  final IconData selectedIcon;

  const _FranchiseMenuItem({
    required this.title,
    required this.icon,
    required this.selectedIcon,
  });
}