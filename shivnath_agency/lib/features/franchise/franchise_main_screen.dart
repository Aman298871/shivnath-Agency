import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/repositories/app_repositories.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/session_service.dart';
import '../../core/widgets/support_desk_modal.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../customer/orders/order_detail_screen.dart';

import 'categories/franchise_categories_screen.dart';
import 'customers/franchise_customers_screen.dart';
import 'dashboard/franchise_dashboard_screen.dart';
import 'documents/franchise_documents_screen.dart';
import 'franchise_settings_screen.dart';
import 'inventory/dealer_stock_screen.dart';
import 'invoices/dealer_credit_ledger_screen.dart';
import 'notifications/franchise_notifications_screen.dart';
import 'orders/franchise_orders_screen.dart';
import 'products/franchise_products_screen.dart';
import 'profile/franchise_profile_screen.dart';
import 'reports/franchise_reports_screen.dart';
import 'territory/franchise_territory_screen.dart';
import 'widgets/franchise_approval_guard.dart';

class FranchiseMainScreen extends StatefulWidget {
  const FranchiseMainScreen({super.key});

  @override
  State<FranchiseMainScreen> createState() => _FranchiseMainScreenState();
}

class _FranchiseMainScreenState extends State<FranchiseMainScreen> {
  final AuthRepository _authRepository = AuthRepository();
  final OrderRepository _orderRepository = OrderRepository();
  int currentIndex = 0;
  UserModel? _currentUser;
  Timer? _orderPollingTimer;
  int _lastMaxOrderId = 0;
  bool _baselineOrdersLoaded = false;
  final Set<int> _alertedOrderIds = <int>{};
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    NotificationService().registerDeviceTokenWithBackend();
    _startOrderPolling();
  }

  @override
  void dispose() {
    _orderPollingTimer?.cancel();
    super.dispose();
  }

  void _startOrderPolling() {
    _orderPollingTimer?.cancel();
    _pollFranchiseOrders();
    _orderPollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _pollFranchiseOrders();
    });
  }

  Future<void> _pollFranchiseOrders() async {
    final sessionEpoch = SessionService.currentSessionEpoch;
    if (!mounted || !SessionService.isSessionActive(sessionEpoch)) return;
    try {
      final res = await _orderRepository.getOrders();
      if (!mounted || !SessionService.isSessionActive(sessionEpoch)) return;
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final List items = data is Map ? (data['orders'] ?? []) : (data is List ? data : []);
        if (items.isEmpty) {
          _baselineOrdersLoaded = true;
          return;
        }

        int currentMaxId = 0;
        Map<String, dynamic>? latestNewOrder;

        for (final it in items) {
          final idVal = it['id'] is int
              ? it['id'] as int
              : int.tryParse(it['id']?.toString() ?? '0') ?? 0;
          if (idVal > currentMaxId) {
            currentMaxId = idVal;
            latestNewOrder = Map<String, dynamic>.from(it as Map);
          }
        }

        if (!_baselineOrdersLoaded) {
          _lastMaxOrderId = currentMaxId;
          _baselineOrdersLoaded = true;
          // Check for active unfulfilled customer orders assigned to this franchise
          final pendingOrders = items.where((it) {
            final st = (it['status'] ?? '').toString().toLowerCase();
            return st == 'order_placement' ||
                st == 'pending' ||
                st == 'created' ||
                st == 'plant_approval' ||
                st == 'preparing';
          }).toList();

          if (pendingOrders.isNotEmpty) {
            final ordersMapped = pendingOrders
                .map((it) => Map<String, dynamic>.from(it as Map))
                .toList();
            final firstPending = ordersMapped.first;
            final pId = firstPending['id'] is int ? firstPending['id'] as int : int.tryParse('${firstPending['id']}') ?? 0;
            if (!_alertedOrderIds.contains(pId)) {
              _alertedOrderIds.add(pId);
              _showNewOrderAlert(
                firstPending,
                isPendingOnLogin: true,
                pendingCount: pendingOrders.length,
              );
            }
          }
        } else if (currentMaxId > _lastMaxOrderId && latestNewOrder != null) {
          _lastMaxOrderId = currentMaxId;
          if (!_alertedOrderIds.contains(currentMaxId)) {
            _alertedOrderIds.add(currentMaxId);
            _showNewOrderAlert(latestNewOrder);
          }
        }
      }
    } catch (_) {}
  }

  void _showNewOrderAlert(Map<String, dynamic> order, {bool isPendingOnLogin = false, int pendingCount = 1}) {
    if (!mounted || !SessionService.isSessionActive(SessionService.currentSessionEpoch)) return;
    final orderNum = order['order_id'] ?? order['order_code'] ?? order['id'] ?? 'New';
    final cust = order['customer_name'] ?? order['name'] ?? 'Customer';
    final amt = order['total_amount'] ?? order['amount'] ?? '';
    final address = order['delivery_address'] ?? order['address'] ?? '';

    void openTargetOrder() {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final tRawId = order['id'] is int ? order['id'] as int : int.tryParse('${order['id']}') ?? 0;
      final tCode = (order['order_id'] ?? order['orderId'] ?? order['order_code'] ?? 'ORD-$tRawId')
          .toString()
          .replaceAll('#', '');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(
            orderId: tCode,
            initialOrder: order,
            dbId: tRawId,
          ),
        ),
      );
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 12),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: InkWell(
          onTap: openTargetOrder,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFF38BDF8),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPendingOnLogin
                          ? (pendingCount > 1 ? '$pendingCount NEW ORDERS WAITING' : 'NEW INCOMING ORDER!')
                          : 'URGENT: INCOMING ORDER!',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order #$orderNum from $cust • ₹$amt${address.isNotEmpty ? ' • $address' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        action: SnackBarAction(
          label: 'OPEN ORDER',
          textColor: const Color(0xFF38BDF8),
          onPressed: openTargetOrder,
        ),
      ),
    );
  }

  Future<void> _loadUser() async {
    // 1. Load local cached user first
    final cached = await _authRepository.getSessionUser();
    if (mounted && cached != null) {
      setState(() => _currentUser = cached);
    }

    // 2. Fetch fresh real-time status from backend
    final res = await _authRepository.getCurrentUser();
    if (res['success'] == true && res['data'] is Map<String, dynamic>) {
      final updated = UserModel.fromJson(res['data'] as Map<String, dynamic>);
      final token = await _authRepository.getAccessToken() ?? '';
      await _authRepository.saveSession(token: token, user: updated, role: updated.role);
      if (mounted) {
        setState(() => _currentUser = updated);
      }
    }
  }

  static const List<_FranchiseNavGroup> navGroups = [
    _FranchiseNavGroup(
      title: 'MAIN',
      items: [
        _FranchiseNavItem(
          index: 0,
          title: 'Dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
        ),
        _FranchiseNavItem(
          index: 1,
          title: 'Customer Orders',
          icon: Icons.shopping_bag_outlined,
          selectedIcon: Icons.shopping_bag_rounded,
        ),
        _FranchiseNavItem(
          index: 2,
          title: 'Customers',
          icon: Icons.people_outline,
          selectedIcon: Icons.people_rounded,
        ),
        _FranchiseNavItem(
          index: 3,
          title: 'Company Catalog',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
        ),
        _FranchiseNavItem(
          index: 5,
          title: 'My Stock',
          icon: Icons.warehouse_outlined,
          selectedIcon: Icons.warehouse_rounded,
        ),
      ],
    ),
    _FranchiseNavGroup(
      title: 'OPERATIONS',
      items: [
        _FranchiseNavItem(
          index: 6,
          title: 'Stock Requests',
          icon: Icons.add_shopping_cart_outlined,
          selectedIcon: Icons.add_shopping_cart_rounded,
        ),
        _FranchiseNavItem(
          index: 8,
          title: 'Credit & Ledger',
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet_rounded,
        ),
        _FranchiseNavItem(
          index: 9,
          title: 'Follow-ups',
          icon: Icons.phone_callback_outlined,
          selectedIcon: Icons.phone_callback_rounded,
        ),
      ],
    ),
    _FranchiseNavGroup(
      title: 'BUSINESS',
      items: [
        _FranchiseNavItem(
          index: 11,
          title: 'Franchise Information',
          icon: Icons.folder_outlined,
          selectedIcon: Icons.folder_rounded,
        ),
        _FranchiseNavItem(
          index: 12,
          title: 'Territory',
          icon: Icons.location_on_outlined,
          selectedIcon: Icons.location_on_rounded,
        ),
        _FranchiseNavItem(
          index: 13,
          title: 'Reports',
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart_rounded,
        ),
      ],
    ),
    _FranchiseNavGroup(
      title: 'ACCOUNT',
      items: [
        _FranchiseNavItem(
          index: 14,
          title: 'Profile',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
        ),
        _FranchiseNavItem(
          index: 15,
          title: 'Settings',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_rounded,
        ),
        _FranchiseNavItem(
          index: 99,
          title: 'Logout',
          icon: Icons.logout_rounded,
          selectedIcon: Icons.logout_rounded,
          isLogout: true,
        ),
      ],
    ),
  ];

  String _getScreenTitle() {
    for (final group in navGroups) {
      for (final item in group.items) {
        if (item.index == currentIndex) {
          return item.title;
        }
      }
    }
    return 'Dashboard';
  }

  // =========================================================
  // CURRENT SCREEN
  // =========================================================

  Widget _currentScreen() {
    switch (currentIndex) {
      case 0:
        return FranchiseDashboardScreen(
          onOpenOrders: () => setState(() => currentIndex = 1),
          onOpenCustomers: () => setState(() => currentIndex = 2),
          onOpenProducts: () => setState(() => currentIndex = 3),
          onOpenCategories: () => setState(() => currentIndex = 4),
          onOpenInventory: () => setState(() => currentIndex = 5),
          onOpenRawMaterials: () => setState(() => currentIndex = 6),
          onOpenFinishedProducts: () => setState(() => currentIndex = 7),
          onOpenStock: () => setState(() => currentIndex = 8),
          onOpenSupport: () => _openSupportDialog(),
          onOpenDocuments: () => setState(() => currentIndex = 11),
          onOpenTerritory: () => setState(() => currentIndex = 12),
          onOpenReports: () => setState(() => currentIndex = 13),
          onOpenProfile: () => setState(() => currentIndex = 14),
          onOpenSettings: () => setState(() => currentIndex = 15),
        );
      case 1:
        return const FranchiseOrdersScreen();
      case 2:
        return const FranchiseCustomersScreen();
      case 3:
        return const FranchiseProductsScreen();
      case 4:
        return const FranchiseCategoriesScreen();
      case 5:
        return const DealerStockScreen();
      case 6:
        return const DealerStockScreen(); // Stock Requests
      case 7:
        return const DealerStockScreen(); // 5 Official Variants
      case 8:
        return const DealerCreditLedgerScreen(); // Credit & Ledger
      case 9:
        return const FranchiseCustomersScreen(); // Follow-ups
      case 10:
        return const FranchiseDashboardScreen(); // Support fallback
      case 11:
        return const FranchiseDocumentsScreen(); // Dealer Information
      case 12:
        return const FranchiseTerritoryScreen();
      case 13:
        return FranchiseReportsScreen(
          onOpenCreditLedger: () => setState(() => currentIndex = 8),
        );
      case 14:
        return const FranchiseProfileScreen();
      case 15:
        return const FranchiseSettingsScreen();
      default:
        return const FranchiseDashboardScreen();
    }
  }

  void _openSupportDialog() {
    SupportDeskModal.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return FranchiseApprovalGuard(
      user: _currentUser,
      onRefreshStatus: _loadUser,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool desktop = constraints.maxWidth >= 800;

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
            SizedBox(width: 250, child: _buildSidebar()),

            // =========================
            // RIGHT AREA
            // =========================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // HEADER
                  SizedBox(height: 72, child: _buildHeader()),

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =========================
            // LOGO
            // =========================
            SizedBox(
              height: 76,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(12),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shivnath Agency',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Franchise Portal',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
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

            const Divider(height: 1, thickness: 1, color: Color(0xFF1F2937)),

            // =========================
            // FRANCHISE USER CARD
            // =========================
            Container(
              margin: const EdgeInsets.fromLTRB(14, 16, 14, 10),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xFF0EA5E9),
                    child: Text(
                      _currentUser?.name.isNotEmpty == true
                          ? _currentUser!.name.substring(0, 1).toUpperCase()
                          : 'FP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser?.name.isNotEmpty == true
                              ? _currentUser!.name
                              : 'Franchise',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _currentUser?.phone.isNotEmpty == true
                              ? _currentUser!.phone
                              : 'Authorized Franchise',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // =========================
            // MENU ITEMS IN 4 STRICT GROUPS
            // =========================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 4,
                ),
                children: [
                  for (final group in navGroups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                      child: Text(
                        group.title,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    for (final item in group.items) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () {
                              if (item.isLogout) {
                                _logout();
                              } else if (item.isSupport) {
                                _openSupportDialog();
                              } else {
                                setState(() => currentIndex = item.index);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (!item.isLogout &&
                                        currentIndex == item.index)
                                    ? const Color(0xFF059669)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    (!item.isLogout &&
                                            currentIndex == item.index)
                                        ? item.selectedIcon
                                        : item.icon,
                                    size: 19,
                                    color: item.isLogout
                                        ? const Color(0xFFFCA5A5)
                                        : ((!item.isLogout &&
                                                  currentIndex == item.index)
                                              ? Colors.white
                                              : const Color(0xFF9CA3AF)),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        color: item.isLogout
                                            ? const Color(0xFFFCA5A5)
                                            : ((!item.isLogout &&
                                                      currentIndex ==
                                                          item.index)
                                                  ? Colors.white
                                                  : const Color(0xFF9CA3AF)),
                                        fontSize: 11,
                                        fontWeight:
                                            (!item.isLogout &&
                                                currentIndex == item.index)
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
                      ),
                    ],
                  ],
                ],
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
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE8EBF0))),
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Franchise Portal',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Manage orders, payments and franchise operations',
                  style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: 280,
              height: 42,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search orders, products...',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF0EA5E9)),
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
                    builder: (_) => const FranchiseNotificationsScreen(),
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
                      currentIndex = 14;
                    });
                    break;

                  case 'settings':
                    setState(() {
                      currentIndex = 15;
                    });
                    break;

                  case 'logout':
                    await _logout();
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('My Profile'),
                    ],
                  ),
                ),

                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 20),
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
                      Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xFFE0F2FE),
                    child: Text(
                      _currentUser?.name.isNotEmpty == true
                          ? _currentUser!.name.substring(0, 1).toUpperCase()
                          : 'FP',
                      style: const TextStyle(
                        color: Color(0xFF0284C7),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(width: 9),

                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser?.name.isNotEmpty == true
                            ? _currentUser!.name
                            : 'Franchise Partner',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Franchise',
                        style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),

                  const SizedBox(width: 5),

                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
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
    final screenTitle = _getScreenTitle();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Builder(
          builder: (ctx) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded, color: Color(0xFF111827)),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              tooltip: 'Menu',
            );
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 26,
              width: 26,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.water_drop_rounded,
                color: Color(0xFF059669),
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                screenTitle == 'Dashboard' ? 'Shivnath Agency' : screenTitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF475569),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FranchiseNotificationsScreen(),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF111827),
        width: 270,
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LOGO + BRAND
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.water_drop_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shivnath Agency',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Franchise Portal',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // USER INFO
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF0284C7),
                      child: Text(
                        _currentUser?.name.isNotEmpty == true
                            ? _currentUser!.name.substring(0, 1).toUpperCase()
                            : 'FP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentUser?.name.isNotEmpty == true
                                ? _currentUser!.name
                                : 'Franchise Partner',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Franchise',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // MENU ITEMS IN 4 STRICT GROUPS
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final group in navGroups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
                        child: Text(
                          group.title,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      for (final item in group.items) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(9),
                              onTap: () {
                                Navigator.pop(context);
                                if (item.isLogout) {
                                  _logout();
                                } else if (item.isSupport) {
                                  _openSupportDialog();
                                } else {
                                  setState(() => currentIndex = item.index);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                height: 42,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (!item.isLogout &&
                                          currentIndex == item.index)
                                      ? const Color(0xFF059669)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      (!item.isLogout &&
                                              currentIndex == item.index)
                                          ? item.selectedIcon
                                          : item.icon,
                                      size: 19,
                                      color: item.isLogout
                                          ? const Color(0xFFFCA5A5)
                                          : ((!item.isLogout &&
                                                    currentIndex == item.index)
                                                ? Colors.white
                                                : const Color(0xFF9CA3AF)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: TextStyle(
                                          color: item.isLogout
                                              ? const Color(0xFFFCA5A5)
                                              : ((!item.isLogout &&
                                                        currentIndex ==
                                                            item.index)
                                                    ? Colors.white
                                                    : const Color(0xFF9CA3AF)),
                                          fontSize: 13,
                                          fontWeight:
                                              (!item.isLogout &&
                                                  currentIndex == item.index)
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
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: ClipRect(child: _currentScreen()),
    );
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
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

    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    try {
      if (mounted) {
        await context.read<AuthProvider>().logout();
      }
    } catch (_) {
      await AuthRepository().logout();
    }

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

class _FranchiseNavGroup {
  final String title;
  final List<_FranchiseNavItem> items;

  const _FranchiseNavGroup({required this.title, required this.items});
}

class _FranchiseNavItem {
  final int index;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final bool isLogout;
  final bool isSupport;

  const _FranchiseNavItem({
    required this.index,
    required this.title,
    required this.icon,
    required this.selectedIcon,
    this.isLogout = false,
  }) : isSupport = false;
}
