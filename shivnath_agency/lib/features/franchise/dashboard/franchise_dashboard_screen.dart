import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/repositories/app_repositories.dart';
import '../../../core/services/session_service.dart';
import '../../../core/widgets/ai_chatbot_modal.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/support_desk_modal.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../../customer/orders/order_detail_screen.dart';
import '../profile/franchise_profile_screen.dart';

class FranchiseDashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenCustomers;
  final VoidCallback? onOpenProducts;
  final VoidCallback? onOpenCategories;
  final VoidCallback? onOpenInventory;
  final VoidCallback? onOpenRawMaterials;
  final VoidCallback? onOpenFinishedProducts;
  final VoidCallback? onOpenStock;
  final VoidCallback? onOpenTerritory;
  final VoidCallback? onOpenReports;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenSupport;
  final VoidCallback? onOpenDocuments;

  const FranchiseDashboardScreen({
    super.key,
    this.onOpenOrders,
    this.onOpenCustomers,
    this.onOpenProducts,
    this.onOpenCategories,
    this.onOpenInventory,
    this.onOpenRawMaterials,
    this.onOpenFinishedProducts,
    this.onOpenStock,
    this.onOpenTerritory,
    this.onOpenReports,
    this.onOpenProfile,
    this.onOpenSettings,
    this.onOpenSupport,
    this.onOpenDocuments,
  });

  @override
  State<FranchiseDashboardScreen> createState() =>
      _FranchiseDashboardScreenState();
}

class _FranchiseDashboardScreenState extends State<FranchiseDashboardScreen> {
  final SessionService _sessionService = SessionService();
  final FranchiseRepository _franchiseRepository = FranchiseRepository();
  final InventoryRepository _inventoryRepository = InventoryRepository();
  final OrderRepository _orderRepository = OrderRepository();
  UserModel? _currentUser;
  Map<String, dynamic> _stats = {
    'customers_served': 0,
    'registered_customers': 0,
    'active_stock': 0,
    'low_stock': 0,
    'on_hold': 0,
    'expired_stock': 0,
    'pending_orders': 0,
    'total_orders': 0,
  };
  bool _loadingStats = true;

  // Real-time live order alert & polling mechanism (matching Admin experience)
  Timer? _liveAlertTimer;
  int _lastSeenOrderId = 0;
  final Set<int> _dismissedOrderIds = {};
  bool _isCheckingLiveAlerts = false;
  bool _isLoggingOut = false;
  List<Map<String, dynamic>> _pendingOrders = [];

  @override
  void initState() {
    super.initState();
    _loadSession();
    _startLiveOrderWatcher();
  }

  @override
  void dispose() {
    _liveAlertTimer?.cancel();
    _isLoggingOut = true;
    super.dispose();
  }

  void _startLiveOrderWatcher() {
    _liveAlertTimer?.cancel();
    _liveAlertTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _checkLiveOrders();
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _checkLiveOrders();
    });
  }

  Future<void> _checkLiveOrders() async {
    if (_isCheckingLiveAlerts || _isLoggingOut) return;
    final sessionEpoch = SessionService.currentSessionEpoch;
    if (!mounted || !SessionService.isSessionActive(sessionEpoch)) return;

    _isCheckingLiveAlerts = true;
    try {
      final res = await _orderRepository.getOrders();
      if (!mounted || _isLoggingOut || !SessionService.isSessionActive(sessionEpoch)) return;

      if (res['success'] == true && res['data'] is Map) {
        final rawOrders = res['data']['orders'];
        if (rawOrders is List) {
          int maxOrderId = 0;
          Map<String, dynamic>? newestOrder;
          final List<Map<String, dynamic>> pendingList = [];

          for (final item in rawOrders) {
            if (item is Map) {
              final mapped = _orderRepository.mapOrder(Map<String, dynamic>.from(item));
              final rawDbId = item['id'] is int
                  ? item['id'] as int
                  : (int.tryParse(item['id']?.toString() ?? '') ??
                        (mapped['id'] is int ? mapped['id'] as int : null));
              final rawId = mapped['orderId']?.toString();
              final fallbackId = rawDbId != null ? 'ORD-${1000 + rawDbId}' : '';
              final orderCode = (rawId != null && rawId.isNotEmpty) ? rawId : fallbackId;
              final rawStatus = item['status']?.toString() ?? mapped['status']?.toString() ?? '';
              final canonical = _orderRepository.canonicalStatus(rawStatus);

              final orderData = {
                'db_id': rawDbId,
                'id': orderCode,
                'customer_name': item['created_by_name']?.toString() ?? mapped['customer_name']?.toString() ?? 'Customer',
                'customer_phone': item['customer_phone']?.toString() ?? mapped['customer_phone']?.toString() ?? '',
                'delivery_address': item['delivery_address']?.toString() ?? mapped['delivery_address']?.toString() ?? '',
                'city': item['city']?.toString() ?? mapped['city']?.toString() ?? '',
                'amount': mapped['amount'] ?? item['total_amount'] ?? 0,
                'status': _orderRepository.getStatusLabel(canonical),
                'raw_status': canonical,
                'created_at': mapped['date']?.toString() ?? item['created_at']?.toString() ?? '',
                'product': mapped['franchise']?.toString() ?? 'Packaged Water',
                'raw': item,
              };

              if (['plant_approval', 'order_placement', 'preparing', 'invoice_generated'].contains(canonical)) {
                pendingList.add(orderData);
              }

              final idNum = rawDbId ?? 0;
              if (idNum > maxOrderId) {
                maxOrderId = idNum;
                newestOrder = orderData;
              }
            }
          }

          if (mounted) {
            setState(() {
              _pendingOrders = pendingList;
              _stats['pending_orders'] = pendingList.length;
              _stats['total_orders'] = rawOrders.length;
            });
          }

          if (_lastSeenOrderId == 0) {
            _lastSeenOrderId = maxOrderId;
          } else if (maxOrderId > _lastSeenOrderId && newestOrder != null && !_dismissedOrderIds.contains(maxOrderId)) {
            _lastSeenOrderId = maxOrderId;
            if (mounted && !_isLoggingOut && SessionService.isSessionActive(sessionEpoch)) {
              final orderCode = newestOrder['id']?.toString() ?? 'ORD-$maxOrderId';
              final custName = newestOrder['customer_name']?.toString() ?? 'Customer';
              final summary = newestOrder['product']?.toString() ?? 'Packaged Water';
              final amt = '₹${newestOrder['amount'] ?? 0}';
              final dateStr = newestOrder['created_at']?.toString() ?? '';
              final address = newestOrder['delivery_address']?.toString() ?? newestOrder['city']?.toString() ?? '';
              final orderStatus = newestOrder['status']?.toString() ?? 'Pending';

              _showLiveOrderAlertDialog(
                type: 'Assigned Customer Order',
                code: orderCode,
                partyName: custName,
                details: summary,
                amountOrQty: amt,
                time: dateStr,
                deliveryAddress: address,
                orderStatus: orderStatus,
                onView: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(
                        orderId: orderCode,
                        initialOrder: newestOrder?['raw'] is Map ? Map<String, dynamic>.from(newestOrder!['raw'] as Map) : newestOrder,
                        dbId: maxOrderId,
                      ),
                    ),
                  ).then((_) {
                    _loadStats();
                    _checkLiveOrders();
                  });
                },
                onDismiss: () {
                  _dismissedOrderIds.add(maxOrderId);
                  Navigator.of(context, rootNavigator: true).pop();
                },
              );
            }
          }
        }
      }
    } catch (_) {
    } finally {
      _isCheckingLiveAlerts = false;
    }
  }

  Future<void> _loadSession() async {
    final user = await _sessionService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
    await _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final res = await _franchiseRepository.getDashboardStats();
    Map<String, dynamic> data = {};
    if (res['success'] == true && res['data'] is Map) {
      data = Map<String, dynamic>.from(res['data']);
      if (data['stats'] is Map) {
        data.addAll(Map<String, dynamic>.from(data['stats']));
      }
    }

    // Direct dealer batches verification: if active_stock is 0 or null, check batches
    if (data['active_stock'] == null || data['active_stock'] == 0) {
      try {
        final batchRes = await _inventoryRepository.getDealerBatches();
        if (batchRes['success'] == true && batchRes['data'] is List) {
          int totalActive = 0;
          int totalOnHold = 0;
          for (final b in batchRes['data']) {
            if (b is Map) {
              totalActive += (b['remaining_quantity'] as num? ?? 0).toInt();
              totalOnHold += (b['reserved_quantity'] as num? ?? 0).toInt();
            }
          }
          if (totalActive > 0) {
            data['active_stock'] = totalActive;
            data['on_hold'] = totalOnHold;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        if (data.isNotEmpty) {
          _stats = data;
        }
        _loadingStats = false;
      });
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout from Wholesale Dealer Portal?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      _isLoggingOut = true;
      _liveAlertTimer?.cancel();
      await _sessionService.logout();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.roleSelection,
        (_) => false,
      );
    }
  }

  void _showLiveOrderAlertDialog({
    required String type,
    required String code,
    required String partyName,
    required String details,
    required String amountOrQty,
    required String time,
    required VoidCallback onView,
    required VoidCallback onDismiss,
    String? deliveryAddress,
    String? orderStatus,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 440,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEW ${type.toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      onPressed: onDismiss,
                    ),
                  ],
                ),
              ),

              // Body Details
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 20,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Customer Name',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                              Text(
                                partyName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (orderStatus != null && orderStatus.isNotEmpty)
                          AppStatusBadge.order(orderStatus, fontSize: 10),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Item Details', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              Text(
                                details,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Total Amount', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(
                              amountOrQty,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (deliveryAddress != null && deliveryAddress.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              deliveryAddress,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            onPressed: onDismiss,
                            child: const Text('DISMISS', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.receipt_long_rounded, size: 16),
                            label: const Text('VIEW ORDER', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                            onPressed: onView,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionablePendingOrdersSection() {
    if (_pendingOrders.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Actionable Pending Orders (${_pendingOrders.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
              if (widget.onOpenOrders != null)
                TextButton(
                  onPressed: widget.onOpenOrders,
                  child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFB45309))),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 105,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pendingOrders.length,
              separatorBuilder: (_, index) => const SizedBox(width: 12),
              itemBuilder: (ctx, idx) {
                final ord = _pendingOrders[idx];
                final dbId = ord['db_id'] is int ? ord['db_id'] as int : int.tryParse('${ord['db_id']}');
                final code = ord['id']?.toString() ?? 'ORD';

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(
                          orderId: code,
                          initialOrder: ord['raw'] is Map ? Map<String, dynamic>.from(ord['raw'] as Map) : ord,
                          dbId: dbId,
                        ),
                      ),
                    ).then((_) {
                      _loadStats();
                      _checkLiveOrders();
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 250,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            AppStatusBadge.order(ord['raw_status'] ?? ord['status'], fontSize: 9),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          ord['customer_name']?.toString() ?? 'Customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                ord['product']?.toString() ?? 'Packaged Water',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ),
                            Text(
                              '₹${ord['amount'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String get _displayName {
    final name = _currentUser?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Franchise Partner';
  }

  Widget _quickOperationsGrid(bool desktop) {
    final actions = [
      {
        'title': 'Customer Orders',
        'icon': Icons.shopping_bag_outlined,
        'color': const Color(0xFF0284C7),
        'action': widget.onOpenOrders,
      },
      {
        'title': 'Customers',
        'icon': Icons.people_outline_rounded,
        'color': const Color(0xFF10B981),
        'action': widget.onOpenCustomers,
      },
      {
        'title': 'Company Catalog',
        'icon': Icons.inventory_2_outlined,
        'color': const Color(0xFF8B5CF6),
        'action': widget.onOpenProducts,
      },
      {
        'title': 'My Stock',
        'icon': Icons.warehouse_outlined,
        'color': const Color(0xFFF59E0B),
        'action': widget.onOpenInventory,
      },
      {
        'title': 'Stock Requests',
        'icon': Icons.add_shopping_cart_outlined,
        'color': const Color(0xFF0284C7),
        'action': widget.onOpenFinishedProducts ?? widget.onOpenInventory,
      },
      {
        'title': 'Credit & Ledger',
        'icon': Icons.account_balance_wallet_outlined,
        'color': const Color(0xFF059669),
        'action': widget.onOpenStock ?? widget.onOpenInventory,
      },
      {
        'title': 'Territory',
        'icon': Icons.location_on_outlined,
        'color': const Color(0xFF14B8A6),
        'action': widget.onOpenTerritory,
      },
      {
        'title': 'Documents',
        'icon': Icons.description_outlined,
        'color': const Color(0xFF6366F1),
        'action': widget.onOpenDocuments,
      },
      {
        'title': 'Reports',
        'icon': Icons.bar_chart_outlined,
        'color': const Color(0xFFF97316),
        'action': widget.onOpenReports,
      },
      {
        'title': 'Support Desk',
        'icon': Icons.headset_mic_outlined,
        'color': const Color(0xFF0284C7),
        'action': widget.onOpenSupport ?? () => SupportDeskModal.show(context),
      },
      {
        'title': 'Settings',
        'icon': Icons.settings_outlined,
        'color': const Color(0xFF64748B),
        'action': widget.onOpenSettings,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Operations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                'Direct Access',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isVerySmall = constraints.maxWidth < 340;
              final isNarrow = constraints.maxWidth < 600;
              final crossAxisCount = isVerySmall ? 1 : (isNarrow ? 2 : (desktop ? 4 : 3));
              final childAspectRatio = isVerySmall
                  ? 3.8
                  : (isNarrow
                      ? (constraints.maxWidth < 380 ? 2.1 : 2.4)
                      : 2.7);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final act = actions[index];
                  final color = act['color'] as Color;
                  return InkWell(
                    onTap: act['action'] as VoidCallback?,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: color.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              act['icon'] as IconData,
                              color: color,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              act['title'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: desktop
              ? null
              : AppBar(
                  title: const Text('Wholesale Dealer Dashboard'),
                  actions: [
                    IconButton(
                      tooltip: 'Refresh Dashboard',
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF0284C7),
                      ),
                      onPressed: _loadStats,
                    ),
                    IconButton(
                      tooltip: 'AI Operations Assistant',
                      icon: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF0077B6),
                      ),
                      onPressed: () => AiChatbotModal.show(
                        context,
                        mode: ChatbotMode.franchise,
                      ),
                    ),
                    IconButton(
                      tooltip: 'My Profile',
                      icon: const Icon(Icons.person_outline_rounded),
                      onPressed:
                          widget.onOpenProfile ??
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FranchiseProfileScreen(),
                              ),
                            );
                          },
                    ),
                    IconButton(
                      tooltip: 'Logout',
                      icon: const Icon(Icons.logout_rounded, color: Colors.red),
                      onPressed: () => _confirmLogout(context),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('AI Assistant'),
            onPressed: () =>
                AiChatbotModal.show(context, mode: ChatbotMode.franchise),
          ),
          body: RefreshIndicator(
            onRefresh: _loadStats,
            color: const Color(0xFF0284C7),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(desktop ? 28 : 16),
              child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1250),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desktop) ...[
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Welcome back, $_displayName. Here is your wholesale dealership overview.',
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (_loadingStats)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(
                          backgroundColor: Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF059669),
                          ),
                        ),
                      ),

                    _AuthoritativeTerritoryCard(
                      territoryInfo: _stats['territory_info'] is Map
                          ? Map<String, dynamic>.from(_stats['territory_info'])
                          : null,
                      user: _currentUser,
                      onSetupTerritory: () async {
                        if (widget.onOpenTerritory != null) {
                          widget.onOpenTerritory!();
                        } else {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FranchiseProfileScreen(),
                            ),
                          );
                          _loadSession();
                        }
                      },
                    ),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isVerySmall = constraints.maxWidth < 340;
                        final crossAxisCount = isVerySmall ? 1 : (desktop ? 4 : 2);
                        final childAspectRatio = isVerySmall
                            ? 3.2
                            : (desktop
                                ? 2.1
                                : (constraints.maxWidth < 380 ? 1.35 : 1.2));

                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: childAspectRatio,
                      children: [
                        _StatCard(
                          title: 'Customers Served',
                          value: '${_stats['customers_served'] ?? 0}',
                          icon: Icons.people_outline_rounded,
                          onTap: widget.onOpenCustomers,
                        ),
                        _StatCard(
                          title: 'Registered Cust.',
                          value: '${_stats['registered_customers'] ?? 0}',
                          icon: Icons.app_registration_rounded,
                          onTap: widget.onOpenCustomers,
                        ),
                        _StatCard(
                          title: 'Active Stock',
                          value: '${_stats['active_stock'] ?? 0}',
                          icon: Icons.water_drop_outlined,
                          onTap: widget.onOpenInventory,
                        ),
                        _StatCard(
                          title: 'Low Stock Alerts',
                          value: '${_stats['low_stock'] ?? 0}',
                          icon: Icons.warning_amber_rounded,
                          onTap:
                              widget.onOpenRawMaterials ??
                              widget.onOpenInventory,
                        ),
                        _StatCard(
                          title: 'Stock On Hold',
                          value: '${_stats['on_hold'] ?? 0}',
                          icon: Icons.pause_circle_outline_rounded,
                          onTap:
                              widget.onOpenFinishedProducts ??
                              widget.onOpenInventory,
                        ),
                        _StatCard(
                          title: 'Expired Stock',
                          value: '${_stats['expired_stock'] ?? 0}',
                          icon: Icons.history_toggle_off_rounded,
                          onTap: widget.onOpenStock ?? widget.onOpenInventory,
                        ),
                        _StatCard(
                          title: 'Pending Orders',
                          value: '${_stats['pending_orders'] ?? 0}',
                          icon: Icons.schedule_rounded,
                          onTap: widget.onOpenOrders,
                        ),
                        _StatCard(
                          title: 'Total Orders',
                          value: '${_stats['total_orders'] ?? 0}',
                          icon: Icons.shopping_bag_outlined,
                          onTap: widget.onOpenOrders,
                        ),
                      ],
                    );
                      },
                    ),

                    const SizedBox(height: 22),

                    _buildActionablePendingOrdersSection(),

                    _quickOperationsGrid(desktop),

                    const SizedBox(height: 22),

                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _RecentOrders(onTap: widget.onOpenOrders),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _AccountSummary(
                              user: _currentUser,
                              onTap: widget.onOpenProfile,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _RecentOrders(onTap: widget.onOpenOrders),
                      const SizedBox(height: 16),
                      _AccountSummary(
                        user: _currentUser,
                        onTap: widget.onOpenProfile,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor = const Color(0xFF059669);
    Color bgColor = const Color(0xFFECFDF5);
    if (title.contains('Low')) {
      iconColor = const Color(0xFFD97706);
      bgColor = const Color(0xFFFFFBEB);
    } else if (title.contains('Expired')) {
      iconColor = const Color(0xFFEF4444);
      bgColor = const Color(0xFFFEF2F2);
    } else if (title.contains('Hold')) {
      iconColor = const Color(0xFFD97706);
      bgColor = const Color(0xFFFFFBEB);
    } else if (title.contains('Pending')) {
      iconColor = const Color(0xFF0284C7);
      bgColor = const Color(0xFFE0F2FE);
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentOrders extends StatelessWidget {
  final VoidCallback? onTap;

  const _RecentOrders({this.onTap});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> sampleOrders = [
      {
        'id': '#ORD-701',
        'item': '20L Water Jars (x50)',
        'amount': '₹4,250',
        'status': 'Processing',
      },
      {
        'id': '#ORD-698',
        'item': '1L Packaged Water Box (x20)',
        'amount': '₹2,400',
        'status': 'Delivered',
      },
      {
        'id': '#ORD-694',
        'item': '500ml Bottled Water (x15)',
        'amount': '₹1,350',
        'status': 'Delivered',
      },
    ];

    return _Card(
      title: 'Recent Orders',
      action: onTap != null
          ? TextButton(onPressed: onTap, child: const Text('View All'))
          : null,
      child: Column(
        children: sampleOrders
            .map(
              (order) => InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2FE),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    title: Text(
                      '${order['id']} - ${order['item']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    subtitle: Text(
                      order['status']!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: order['status'] == 'Processing'
                            ? const Color(0xFFD97706)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                    trailing: Text(
                      order['amount']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  final UserModel? user;
  final VoidCallback? onTap;

  const _AccountSummary({this.user, this.onTap});

  @override
  Widget build(BuildContext context) {
    final franchiseId = user?.id != null ? 'FR-${user!.id}' : 'FR-Approved';
    final ownerName = user?.name.isNotEmpty == true
        ? user!.name
        : 'Franchise Partner';
    final email = user?.email.isNotEmpty == true ? user!.email : 'Not Provided';
    final status = 'Approved Partner';

    return _Card(
      title: 'Franchise Details',
      action: onTap != null
          ? TextButton(onPressed: onTap, child: const Text('Profile'))
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            _InfoRow('Franchise ID', franchiseId),
            const Divider(),
            _InfoRow('Owner', ownerName),
            const Divider(),
            _InfoRow('Email', email),
            const Divider(),
            _InfoRow('Status', status),
            const Divider(),
            const _InfoRow('Commission', '12%'),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget? action;
  final Widget child;

  const _Card({required this.title, this.action, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AuthoritativeTerritoryCard extends StatelessWidget {
  final Map<String, dynamic>? territoryInfo;
  final UserModel? user;
  final VoidCallback onSetupTerritory;

  const _AuthoritativeTerritoryCard({
    required this.territoryInfo,
    required this.user,
    required this.onSetupTerritory,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAssigned =
        territoryInfo?['is_assigned'] == true ||
        (user?.isTerritoryAssigned == true) ||
        ((territoryInfo?['territory'] != null &&
            territoryInfo!['territory'].toString().isNotEmpty));

    final String district =
        territoryInfo?['district']?.toString() ??
        user?.district ??
        user?.city ??
        'Unassigned';
    final String territory =
        territoryInfo?['territory']?.toString() ??
        user?.zoneName ??
        user?.territory ??
        'Unassigned';
    final String serviceArea =
        territoryInfo?['service_area']?.toString() ??
        user?.locality ??
        user?.serviceArea ??
        'All Assigned Localities';
    final String address =
        territoryInfo?['address']?.toString() ?? user?.address ?? '';

    return InkWell(
      onTap: onSetupTerritory,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAssigned ? const Color(0xFFBAE6FD) : const Color(0xFFFDE68A),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isAssigned
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: isAssigned
                      ? const Color(0xFF0284C7)
                      : const Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Authoritative Assigned Territory',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      isAssigned
                          ? 'Authoritative assignment managed by Admin'
                          : 'Action Required: Initial territory unassigned',
                      style: TextStyle(
                        fontSize: 11,
                        color: isAssigned
                            ? const Color(0xFF64748B)
                            : const Color(0xFFB45309),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isAssigned
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isAssigned ? 'ASSIGNED' : 'UNASSIGNED',
                  style: TextStyle(
                    color: isAssigned
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB45309),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TerritoryField(
                  label: 'District',
                  value: district,
                  icon: Icons.map_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TerritoryField(
                  label: 'Territory / Zone',
                  value: territory,
                  icon: Icons.location_city_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TerritoryField(
                  label: 'Service Area / Locality',
                  value: serviceArea,
                  icon: Icons.near_me_outlined,
                ),
              ),
              if (address.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _TerritoryField(
                    label: 'Registered Address',
                    value: address,
                    icon: Icons.home_work_outlined,
                  ),
                ),
              ],
            ],
          ),
          if (!isAssigned) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Complete Initial Territory Assignment'),
                onPressed: onSetupTerritory,
              ),
            ),
          ],
        ],
      ),
    ),
  );
  }
}

class _TerritoryField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TerritoryField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
