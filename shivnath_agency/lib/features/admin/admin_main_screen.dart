import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/services/OrderService.dart';
import '../../core/services/InventoryService.dart';
import '../../core/services/session_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/ai_chatbot_modal.dart';
import '../../core/widgets/support_desk_modal.dart';
import '../../routes/app_routes.dart';

import 'dashboard/admin_dashboard_screen.dart';
import 'leads/admin_leads_screen.dart';
import 'followups/admin_followups_screen.dart';
import 'franchises/admin_franchises_screen.dart';
import 'inventory/admin_stock_management_screen.dart';
import 'inventory/central_plant_inventory_screen.dart';
import 'inventory/dealer_stock_request_fulfillment_screen.dart';
import 'products/bom_recipe_screen.dart';
import 'suppliers/admin_suppliers_screen.dart';
import 'orders/admin_orders_screen.dart';
import 'billing/admin_billing_screen.dart';
import 'package:shivnath_agency/features/admin/reports/admin_reports_screen.dart';
import 'chat/admin_chatbot_management_screen.dart';
import 'chat/admin_chat_conversations_screen.dart';
import 'chat/admin_quotations_screen.dart';
import 'users/admin_users_screen.dart';
import 'users/admin_management_tab.dart';
import 'dashboard/admin_performance_screen.dart';
import 'settings/admin_settings_screen.dart';
import 'notifications/admin_notifications_screen.dart';
import 'profile/admin_profile_screen.dart';
import '../../models/user_model.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int currentIndex = 0;
  String? _targetBatchNumber;
  UserModel? _currentUser;
  Timer? _orderPollTimer;
  int _lastMaxOrderId = 0;
  bool _baselineOrdersLoaded = false;
  final OrderService _orderService = OrderService();
  final InventoryService _inventoryService = InventoryService();
  int _lastMaxStockRequestId = 0;
  bool _baselineStockRequestsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _startOrderPolling();
    NotificationService().registerDeviceTokenWithBackend();
  }

  @override
  void dispose() {
    _orderPollTimer?.cancel();
    super.dispose();
  }

  void _startOrderPolling() {
    _pollOrders();
    _pollStockRequests();
    _orderPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pollOrders();
      _pollStockRequests();
    });
  }

  Future<void> _pollOrders() async {
    try {
      final res = await _orderService.getOrders();
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        final List items =
            res['data']['orders'] ?? (res['data'] is List ? res['data'] : []);
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
          // Check for active unfulfilled customer orders waiting for admin fulfillment
          final pendingOrders = items.where((it) {
            final st = (it['status'] ?? '').toString().toLowerCase();
            return st == 'order_placement' ||
                st == 'pending' ||
                st == 'created' ||
                st == 'plant_approval';
          }).toList();
          if (pendingOrders.isNotEmpty) {
            final firstPending = Map<String, dynamic>.from(pendingOrders.first as Map);
            _showNewOrderAlert(
              firstPending,
              isPendingOnLogin: true,
              pendingCount: pendingOrders.length,
            );
          }
        } else if (currentMaxId > _lastMaxOrderId && latestNewOrder != null) {
          _lastMaxOrderId = currentMaxId;
          _showNewOrderAlert(latestNewOrder);
        }
      }
    } catch (_) {}
  }

  void _showNewOrderAlert(
    Map<String, dynamic> order, {
    bool isPendingOnLogin = false,
    int pendingCount = 1,
  }) {
    if (!mounted) return;
    final orderNum = order['order_id'] ?? order['id'] ?? 'New';
    final cust = order['customer_name'] ?? 'Customer';
    final amt = order['total_amount'] ?? order['amount'] ?? '';

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFF38BDF8),
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPendingOnLogin
                        ? (pendingCount > 1
                            ? '$pendingCount PENDING ORDERS TO FULFILL'
                            : 'NEW ORDER AWAITING FULFILLMENT!')
                        : 'NEW ORDER RECEIVED!',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Order #$orderNum from $cust • ₹$amt',
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
        action: SnackBarAction(
          label: 'VIEW ORDERS',
          textColor: const Color(0xFF38BDF8),
          onPressed: () {
            _selectMenu(7);
          },
        ),
      ),
    );
  }

  Future<void> _pollStockRequests() async {
    try {
      final res = await _inventoryService.getDealerStockRequests();
      if (!mounted) return;
      if (res['success'] == true && res['data'] is List) {
        final List items = res['data'] as List;
        if (items.isEmpty) {
          _baselineStockRequestsLoaded = true;
          return;
        }

        int currentMaxId = 0;
        Map<String, dynamic>? latestNewRequest;

        for (final it in items) {
          final idVal = it['id'] is int
              ? it['id'] as int
              : int.tryParse(it['id']?.toString() ?? '0') ?? 0;
          if (idVal > currentMaxId) {
            currentMaxId = idVal;
            latestNewRequest = Map<String, dynamic>.from(it as Map);
          }
        }

        if (!_baselineStockRequestsLoaded) {
          _lastMaxStockRequestId = currentMaxId;
          _baselineStockRequestsLoaded = true;
        } else if (currentMaxId > _lastMaxStockRequestId && latestNewRequest != null) {
          _lastMaxStockRequestId = currentMaxId;
          _showNewStockRequestDialog(latestNewRequest);
        }
      }
    } catch (_) {}
  }

  void _showNewStockRequestDialog(Map<String, dynamic> req) {
    if (!mounted) return;
    final reqNum = req['request_number'] ?? 'REQ-${req['id']}';
    final dealerName = req['dealer_name'] ?? 'Franchise';
    final prodName = req['product_name'] ?? req['product_sku'] ?? 'Packaged Water Products';
    final qty = req['requested_quantity'] ?? req['quantity_cases'] ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Colors.orange,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stock Request Received!',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Franchise Needs Central Stock',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dealerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Requested: $qty Cases of $prodName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reference: $reqNum',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Dismiss', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Open & Allocate', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () {
              Navigator.pop(dlgCtx);
              final reqId = req['id'] is int ? req['id'] as int : int.tryParse(req['id']?.toString() ?? '0') ?? 0;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DealerStockRequestFulfillmentScreen(
                    requestId: reqId,
                    initialRequest: req,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _loadUser() async {
    final u = await SessionService().getCurrentUser();
    if (mounted && u != null) {
      setState(() => _currentUser = u);
    }
  }

  // =========================================================
  // MENU
  // =========================================================

  List<_AdminMenuItem> get menuItems {
    final isSuperAdmin = _currentUser?.isSuperAdmin == true;
    return [
      const _AdminMenuItem(
        index: 0,
        title: 'Dashboard',
        icon: Icons.dashboard_outlined,
      ),
      const _AdminMenuItem(
        index: 1,
        title: 'Leads',
        icon: Icons.people_alt_outlined,
      ),
      const _AdminMenuItem(
        index: 2,
        title: 'Follow-ups',
        icon: Icons.calendar_month_outlined,
      ),
      const _AdminMenuItem(
        index: 3,
        title: 'Franchises',
        icon: Icons.storefront_outlined,
      ),
      const _AdminMenuItem(
        index: 4,
        title: 'Plant Batches & Stock',
        icon: Icons.inventory_2_outlined,
      ),
      const _AdminMenuItem(
        index: 21,
        title: 'Central Stock Requests',
        icon: Icons.move_to_inbox_outlined,
      ),
      const _AdminMenuItem(
        index: 5,
        title: 'BOM & Pricing Master',
        icon: Icons.science_outlined,
      ),
      const _AdminMenuItem(
        index: 6,
        title: 'Suppliers',
        icon: Icons.local_shipping_outlined,
      ),
      const _AdminMenuItem(
        index: 7,
        title: 'Orders',
        icon: Icons.shopping_cart_outlined,
      ),
      const _AdminMenuItem(
        index: 8,
        title: 'Billing',
        icon: Icons.receipt_long_outlined,
      ),
      const _AdminMenuItem(
        index: 9,
        title: 'Daily P&L Reports',
        icon: Icons.bar_chart_outlined,
      ),
      if (isSuperAdmin || _currentUser?.isAdmin == true) ...[
        const _AdminMenuItem(
          index: 19,
          title: 'Admin Management',
          icon: Icons.admin_panel_settings_outlined,
        ),
        const _AdminMenuItem(
          index: 20,
          title: 'Staff Performance',
          icon: Icons.insights_outlined,
        ),
      ],
      const _AdminMenuItem(
        index: 10,
        title: 'Chatbot Builder',
        icon: Icons.account_tree_outlined,
      ),
      const _AdminMenuItem(
        index: 11,
        title: 'Quotations',
        icon: Icons.request_quote_outlined,
      ),
      // HIDDEN / COMMENTED OUT PER CLIENT REQUIREMENT (Can be re-enabled in future if needed):
      // if (isSuperAdmin)
      //   const _AdminMenuItem(
      //     index: 12,
      //     title: 'WhatsApp settings',
      //     icon: Icons.chat_outlined,
      //   ),
      const _AdminMenuItem(
        index: 13,
        title: 'Customer Inquiries',
        icon: Icons.forum_outlined,
      ),
      const _AdminMenuItem(
        index: 14,
        title: 'User Directory',
        icon: Icons.manage_accounts_outlined,
      ),
      const _AdminMenuItem(
        index: 15,
        title: 'Notifications',
        icon: Icons.notifications_none_outlined,
      ),
      const _AdminMenuItem(
        index: 16,
        title: 'Settings',
        icon: Icons.settings_outlined,
      ),
    ];
  }

  // =========================================================
  // CURRENT SCREEN
  // =========================================================

  Widget _currentScreen() {
    switch (currentIndex) {
      case 0:
        return AdminDashboardScreen(
          onOpenLeads: () => _selectMenu(1),
          onOpenFollowups: () => _selectMenu(2),
          onOpenFranchises: () => _selectMenu(3),
          onOpenInventory: () => _selectMenu(4),
          onOpenProducts: () => _selectMenu(5),
          onOpenOrders: () => _selectMenu(7),
          onOpenChatbot: () => _selectMenu(10),
          onOpenQuotations: () => _selectMenu(11),
          onOpenUsers: () => _selectMenu(14),
          onOpenNotifications: () => _selectMenu(15),
          onOpenStockRequests: () => _selectMenu(21),
          onOpenInventoryWithBatch: (batch) {
            setState(() {
              _targetBatchNumber = batch;
              _selectMenu(4);
            });
          },
          onOpenOrdersWithCode: (code) {
            setState(() {
              _selectMenu(7);
            });
          },
        );

      case 1:
        return const AdminLeadsScreen();

      case 2:
        return const AdminFollowupsScreen();

      case 3:
        return const AdminFranchisesScreen();

      case 4:
        return CentralPlantInventoryScreen(highlightBatchNumber: _targetBatchNumber);

      case 5:
        return const BomRecipeScreen();

      case 6:
        return const AdminSuppliersScreen();

      case 7:
        return const AdminOrdersScreen();

      case 8:
        return const AdminBillingScreen();

      case 9:
        return const AdminReportsScreen();

      case 10:
        return const AdminChatbotManagementScreen();

      case 11:
        return const AdminQuotationsScreen();

      // case 12:
      //   // Commented out per client request (can be re-enabled in future if needed):
      //   return const AdminWhatsAppScreen();

      case 13:
        return const AdminChatConversationsScreen();

      case 14:
        return const AdminUsersScreen();

      case 15:
        return const AdminNotificationsScreen();

      case 16:
        return const AdminSettingsScreen();

      case 17:
        return const AdminStockManagementScreen();

      case 18:
        return const AdminProfileScreen();

      case 19:
        return const AdminManagementTab();

      case 20:
        return const AdminPerformanceScreen();

      case 21:
        return const CentralPlantInventoryScreen(initialTab: 2);

      default:
        return AdminDashboardScreen(
          onOpenLeads: () => _selectMenu(1),
          onOpenFollowups: () => _selectMenu(2),
          onOpenFranchises: () => _selectMenu(3),
          onOpenInventory: () => _selectMenu(4),
          onOpenProducts: () => _selectMenu(5),
          onOpenOrders: () => _selectMenu(7),
          onOpenChatbot: () => _selectMenu(10),
          onOpenQuotations: () => _selectMenu(11),
          onOpenUsers: () => _selectMenu(14),
          onOpenNotifications: () => _selectMenu(15),
          onOpenStockRequests: () => _selectMenu(21),
          onOpenInventoryWithBatch: (batch) {
            setState(() {
              _targetBatchNumber = batch;
              _selectMenu(4);
            });
          },
          onOpenOrdersWithCode: (code) {
            setState(() {
              _selectMenu(7);
            });
          },
        );
    }
  }

  // =========================================================
  // MENU SELECT
  // =========================================================

  void _selectMenu(int index) {
    setState(() {
      currentIndex = index;
      if (index != 4) {
        _targetBatchNumber = null;
      }
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
      'whatsapp': 12,
      'automation': 12,
      'chatbot': 10,
      'template': 12,
      'message': 12,
      'welcome message': 12,
      'quick reply': 12,

      // Inquiries / Chat
      'inquiry': 13,
      'inquiries': 13,
      'chat log': 13,
      'chats': 13,
      'conversation': 13,

      // Users
      'user': 14,
      'users': 14,
      'directory': 14,
      'staff': 14,
      'customers': 14,

      // Notifications
      'notification': 15,
      'notifications': 15,
      'alert': 15,
      'alerts': 15,

      // Settings
      'settings': 16,
      'setting': 16,
      'role': 16,
      'roles': 16,
      'permission': 16,
      'permissions': 16,

      // Customer Stocks
      'stocks': 17,
      'customer stock': 17,
      'customer stocks': 17,

      // Profile
      'profile': 18,
      'admin': 18,

      // Admin Management & Performance
      'admins': 19,
      'admin management': 19,
      'admin accounts': 19,
      'performance': 20,
      'staff performance': 20,
    };

    for (final entry in searchMap.entries) {
      if (query.contains(entry.key)) {
        setState(() {
          currentIndex = entry.value;
        });

        return;
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No matching section found')));
  }

  void _handleProfileMenu(String value) {
    if (value == 'profile') {
      setState(() => currentIndex = 18);
    } else if (value == 'settings') {
      setState(() => currentIndex = 16);
    } else if (value == 'support') {
      SupportDeskModal.show(context);
    } else if (value == 'logout') {
      _logout();
    }
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
      builder: (context, constraints) {
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
            SizedBox(width: 250, child: _buildSidebar()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 72, child: _buildHeader()),
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

      drawer: Drawer(child: _buildSidebar(isMobile: true)),

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
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
                color: Color(0xFFEF4444),
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _currentTitle() == 'Dashboard'
                    ? 'Shivnath Agency'
                    : _currentTitle(),
                maxLines: 1,
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
            tooltip: 'AI Assistant',
            onPressed: () =>
                AiChatbotModal.show(context, mode: ChatbotMode.admin),
            icon: const Icon(
              Icons.smart_toy_outlined,
              color: Color(0xFF0284C7),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              setState(() {
                currentIndex = 15;
              });
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),

          PopupMenuButton<String>(
            onSelected: _handleProfileMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('My Profile')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'support', child: Text('Support Desk')),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Text('Logout', style: TextStyle(color: Colors.red)),
              ),
            ],
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF0284C7),
              child: Text(
                'AD',
                style: TextStyle(color: Colors.white, fontSize: 10),
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

  Widget _buildSidebar({bool isMobile = false}) {
    return Material(
      color: const Color(0xFF111827),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // =================================================
            // LOGO
            // =================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFEF4444),
                      child: Icon(
                        Icons.water_drop,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Shivnath Agency',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.6),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFCA5A5),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _currentUser?.roleDisplay.isNotEmpty == true
                            ? '${_currentUser!.roleDisplay} Panel'
                            : 'Admin Control Panel',
                        style: const TextStyle(
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
              padding: EdgeInsets.symmetric(horizontal: 20),
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
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: menuItems.length,
                itemBuilder: (context, index) {
                  final item = menuItems[index];

                  final selected = currentIndex == item.index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () {
                          _selectMenu(item.index);

                          if (isMobile) {
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 13),
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
                    padding: const EdgeInsets.symmetric(horizontal: 13),
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
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
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
                  hintText: 'Search leads, franchise, orders...',
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
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
            // AI ASSISTANT
            // =================================================
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () =>
                  AiChatbotModal.show(context, mode: ChatbotMode.admin),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.smart_toy_rounded,
                      size: 18,
                      color: Color(0xFF0284C7),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AI Assistant',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 14),

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
                            currentIndex = 15;
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
              offset: const Offset(0, 62),
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
                      Icon(Icons.person_outline, size: 18),
                      SizedBox(width: 10),
                      Text('My Profile'),
                    ],
                  ),
                ),

                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Settings'),
                    ],
                  ),
                ),

                PopupMenuItem<String>(
                  value: 'support',
                  child: Row(
                    children: [
                      Icon(
                        Icons.headset_mic_outlined,
                        size: 18,
                        color: Color(0xFF0284C7),
                      ),
                      SizedBox(width: 10),
                      Text('Support Desk'),
                    ],
                  ),
                ),

                PopupMenuDivider(),

                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                      SizedBox(width: 10),
                      Text('Logout', style: TextStyle(color: Colors.red)),
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
        return 'Chatbot Builder';

      case 11:
        return 'Quotations';

      case 12:
        return 'WhatsApp Settings';

      case 13:
        return 'Customer Inquiries';

      case 14:
        return 'User Directory';

      case 15:
        return 'Notifications';

      case 16:
        return 'Settings';

      case 17:
        return 'Customer Stocks';

      case 18:
        return 'Profile';

      case 19:
        return 'Admin Management';

      case 20:
        return 'Staff Performance';

      default:
        return 'Admin';
    }
  }
}

// ===========================================================
// MENU MODEL
// ===========================================================

class _AdminMenuItem {
  final int index;
  final String title;
  final IconData icon;

  const _AdminMenuItem({
    required this.index,
    required this.title,
    required this.icon,
  });
}
