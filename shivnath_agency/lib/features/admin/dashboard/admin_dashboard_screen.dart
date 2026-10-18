import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/followup_service.dart';
import '../../../core/services/lead_service.dart';
import '../../../core/repositories/app_repositories.dart';
import '../../../core/services/notification_service.dart';
import '../inventory/dealer_stock_request_fulfillment_screen.dart';
import '../../customer/orders/order_detail_screen.dart';
import '../orders/pending_orders_picker_dialog.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/utils/app_toast.dart';

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenLeads;
  final VoidCallback? onOpenFollowups;
  final VoidCallback? onOpenFranchises;
  final VoidCallback? onOpenInventory;
  final VoidCallback? onOpenProducts;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenChatbot;
  final VoidCallback? onOpenQuotations;
  final VoidCallback? onOpenUsers;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenStockRequests;
  final void Function(String? batchNumber)? onOpenInventoryWithBatch;
  final void Function(String? orderCode)? onOpenOrdersWithCode;

  const AdminDashboardScreen({
    super.key,
    this.onOpenLeads,
    this.onOpenFollowups,
    this.onOpenFranchises,
    this.onOpenInventory,
    this.onOpenProducts,
    this.onOpenOrders,
    this.onOpenChatbot,
    this.onOpenQuotations,
    this.onOpenUsers,
    this.onOpenNotifications,
    this.onOpenStockRequests,
    this.onOpenInventoryWithBatch,
    this.onOpenOrdersWithCode,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final LeadService _leadService = LeadService();
  final FollowupService _followupService = FollowupService();
  final InventoryRepository _inventoryRepository = InventoryRepository();
  final OrderRepository _orderRepository = OrderRepository();
  final NotificationService _notificationService = NotificationService();

  List<Map<String, dynamic>> _pendingStockAlerts = [];
  bool _pendingStockDialogShown = false;

  List<Map<String, dynamic>> _pendingStockRequests = [];
  List<Map<String, dynamic>> _pendingPaymentVerifications = [];
  List<Map<String, dynamic>> _pendingCustomerOrders = [];
  final Set<int> _dismissedRequestIds = {};
  final Set<int> _dismissedNotificationIds = {};

  List<Map<String, dynamic>> _recentOrders = [];
  int _newOrdersCount = 0;
  int _pendingApprovalCount = 0;
  int _preparingCount = 0;
  int _dispatchedCount = 0;
  int _deliveredCount = 0;

  List<Map<String, dynamic>> _stats = [
    {
      'title': 'Total Leads',
      'value': '0',
      'change': '0 active',
      'icon': Icons.people_alt_outlined,
      'color': const Color(0xFF0284C7),
      'bgColor': const Color(0xFFE0F2FE),
    },
    {
      'title': 'Customer Orders',
      'value': '0',
      'change': '0 placed',
      'icon': Icons.shopping_bag_outlined,
      'color': const Color(0xFF2563EB),
      'bgColor': const Color(0xFFEFF6FF),
    },
    {
      'title': 'Franchise Stock Reqs',
      'value': '0',
      'change': '0 requests',
      'icon': Icons.storefront_outlined,
      'color': const Color(0xFF7C3AED),
      'bgColor': const Color(0xFFF5F3FF),
    },
    {
      'title': 'Hot Leads',
      'value': '0',
      'change': '0 priority',
      'icon': Icons.local_fire_department_outlined,
      'color': const Color(0xFFEF4444),
      'bgColor': const Color(0xFFFEF2F2),
    },
    {
      'title': 'Follow-ups Today',
      'value': '0',
      'change': '0 pending',
      'icon': Icons.calendar_month_outlined,
      'color': const Color(0xFFD97706),
      'bgColor': const Color(0xFFFFFBEB),
    },
    {
      'title': 'Confirmed Dealers',
      'value': '0',
      'change': '0 confirmed',
      'icon': Icons.storefront_outlined,
      'color': const Color(0xFF10B981),
      'bgColor': const Color(0xFFECFDF5),
    },
  ];

  List<Map<String, dynamic>> _pipeline = [
    {'name': 'New Lead', 'value': 0},
    {'name': 'Contacted', 'value': 0},
    {'name': 'Follow-up', 'value': 0},
    {'name': 'Interested', 'value': 0},
    {'name': 'Site Visit', 'value': 0},
    {'name': 'Agreement', 'value': 0},
    {'name': 'Confirmed', 'value': 0},
  ];

  List<Map<String, String>> _followups = [];
  List<Map<String, String>> _leads = [];

  Timer? _liveAlertTimer;
  int _lastSeenOrderId = 0;
  int _lastSeenStockReqId = 0;
  bool _isCheckingLiveAlerts = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _startLiveOrderWatcher();
  }

  @override
  void dispose() {
    _liveAlertTimer?.cancel();
    super.dispose();
  }

  void _startLiveOrderWatcher() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _checkLiveOrdersAndStockRequests();
    });
    _liveAlertTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _checkLiveOrdersAndStockRequests();
    });
  }

  Future<void> _checkLiveOrdersAndStockRequests() async {
    if (_isCheckingLiveAlerts || !mounted) return;
    _isCheckingLiveAlerts = true;

    try {
      // 1. Check Customer Orders
      final orderRes = await _orderRepository.getOrders();
      if (orderRes['success'] == true) {
        List ordersList = [];
        if (orderRes['data'] is List) {
          ordersList = orderRes['data'] as List;
        } else if (orderRes['data'] is Map && orderRes['data']['orders'] is List) {
          ordersList = orderRes['data']['orders'] as List;
        } else if (orderRes['orders'] is List) {
          ordersList = orderRes['orders'] as List;
        }

        if (ordersList.isNotEmpty) {
          int maxOrderId = 0;
          Map<String, dynamic>? newestOrder;
          for (final ord in ordersList) {
            if (ord is Map) {
              final id = ord['id'] is int ? ord['id'] as int : int.tryParse('${ord['id']}') ?? 0;
              if (id > maxOrderId) {
                maxOrderId = id;
                newestOrder = Map<String, dynamic>.from(ord);
              }
            }
          }

          if (_lastSeenOrderId == 0) {
            _lastSeenOrderId = maxOrderId;
          } else if (maxOrderId > _lastSeenOrderId && newestOrder != null) {
            _lastSeenOrderId = maxOrderId;
            if (mounted) {
              final isDirect = newestOrder['order_source'] == 'DIRECT_COMPANY';
              final orderCode = newestOrder['order_code']?.toString() ?? 'ORD-$maxOrderId';
              final custName = newestOrder['client_name']?.toString() ?? newestOrder['customer_name']?.toString() ?? newestOrder['franchise_name']?.toString() ?? 'Customer';
              final summary = newestOrder['items_summary']?.toString() ?? '${newestOrder['items_count'] ?? 1} Items';
              final amt = '₹${newestOrder['amount'] ?? newestOrder['grand_total'] ?? 0}';
              final dateStr = newestOrder['created_at']?.toString() ?? '';
              final payStatus = newestOrder['payment_status']?.toString() ?? newestOrder['payment']?.toString() ?? 'PENDING';
              final address = newestOrder['delivery_address']?.toString() ?? newestOrder['city']?.toString() ?? '';
              final source = isDirect ? 'Direct Company' : (newestOrder['franchise_name']?.toString() ?? 'Franchise');
              final orderStatus = newestOrder['status']?.toString() ?? 'PENDING';

              _showLiveOrderAlertDialog(
                type: isDirect ? 'Direct Customer Order' : 'Customer Order Placed',
                code: orderCode,
                partyName: custName,
                details: summary,
                amountOrQty: amt,
                time: dateStr,
                paymentStatus: payStatus,
                deliveryAddress: address,
                fulfillmentSource: source,
                orderStatus: orderStatus,
                onView: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(
                        orderId: orderCode,
                        initialOrder: newestOrder,
                        dbId: maxOrderId,
                      ),
                    ),
                  );
                },
                onFulfill: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(
                        orderId: orderCode,
                        initialOrder: newestOrder,
                        dbId: maxOrderId,
                      ),
                    ),
                  );
                },
              );
            }
          }
        }
      }

      // 2. Check Franchise Stock Requests
      final reqRes = await _inventoryRepository.getDealerStockRequests();
      if (reqRes['success'] == true) {
        List reqList = [];
        if (reqRes['data'] is List) {
          reqList = reqRes['data'] as List;
        } else if (reqRes['data'] is Map && reqRes['data']['requests'] is List) {
          reqList = reqRes['data']['requests'] as List;
        } else if (reqRes['requests'] is List) {
          reqList = reqRes['requests'] as List;
        }

        if (reqList.isNotEmpty) {
          int maxReqId = 0;
          Map<String, dynamic>? newestReq;
          for (final r in reqList) {
            if (r is Map) {
              final status = (r['status'] ?? '').toString().toUpperCase();
              final isPending = status == 'REQUESTED' || status == 'PENDING' || status == 'SUBMITTED';
              final id = r['id'] is int ? r['id'] as int : int.tryParse('${r['id']}') ?? 0;
              if (isPending && id > maxReqId && !_dismissedRequestIds.contains(id)) {
                maxReqId = id;
                newestReq = Map<String, dynamic>.from(r);
              }
            }
          }

          if (newestReq != null && maxReqId > 0 && maxReqId != _lastSeenStockReqId) {
            _lastSeenStockReqId = maxReqId;
            if (mounted) {
              final reqProd = newestReq['product_name'] ?? newestReq['product_sku'] ?? 'Water Bottles';
              final reqQty = newestReq['requested_quantity'] ?? 0;
              final party = newestReq['dealer_name'] ?? newestReq['franchise_name'] ?? 'Franchise Partner';
              _showLiveOrderAlertDialog(
                type: 'Franchise Stock Request',
                code: newestReq['request_number']?.toString() ?? 'SR-$maxReqId',
                partyName: party,
                details: '$reqProd ($reqQty Units Requested)',
                amountOrQty: '$reqQty Units',
                time: newestReq['created_at']?.toString() ?? '',
                isStockRequest: true,
                onView: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DealerStockRequestFulfillmentScreen(
                        requestId: maxReqId,
                        initialRequest: newestReq,
                      ),
                    ),
                  ).then((_) {
                    _loadActionableAlerts();
                    _loadDashboardData();
                  });
                },
              );
            }
          }
        }
      }
    } catch (_) {
    } finally {
      _isCheckingLiveAlerts = false;
      _loadActionableAlerts();
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
    VoidCallback? onFulfill,
    String? paymentStatus,
    String? deliveryAddress,
    String? fulfillmentSource,
    String? orderStatus,
    bool isStockRequest = false,
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isStockRequest
                        ? [const Color(0xFF7C3AED), const Color(0xFF6D28D9)]
                        : [const Color(0xFF0284C7), const Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
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
                      child: Icon(
                        isStockRequest ? Icons.storefront_rounded : Icons.shopping_bag_rounded,
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
                      onPressed: () => Navigator.pop(ctx),
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
                          child: Icon(
                            isStockRequest ? Icons.business_rounded : Icons.person_rounded,
                            size: 20,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isStockRequest ? 'Franchise Partner' : 'Customer Name',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                            Text(isStockRequest ? 'Quantity' : 'Total Amount', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(
                              amountOrQty,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isStockRequest ? const Color(0xFF7C3AED) : const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (fulfillmentSource != null && fulfillmentSource.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.hub_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            'Fulfillment Source: ',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          Text(
                            fulfillmentSource,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                    if (deliveryAddress != null && deliveryAddress.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              deliveryAddress,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                              maxLines: 1,
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
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('CLOSE', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              side: const BorderSide(color: Color(0xFF0284C7)),
                              foregroundColor: const Color(0xFF0284C7),
                            ),
                            icon: const Icon(Icons.receipt_long_rounded, size: 14),
                            label: const Text('VIEW ORDER', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                            onPressed: onView,
                          ),
                        ),
                        if (onFulfill != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isStockRequest ? const Color(0xFF7C3AED) : const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.local_shipping_outlined, size: 14),
                              label: const Text(
                                'FULFILL',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                              ),
                              onPressed: onFulfill,
                            ),
                          ),
                        ],
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

  Future<void> _loadDashboardData() async {
    try {
      final leadStatsResult = await _leadService.getLeadStats();
      final fuStatsResult = await _followupService.getStats();
      final leadsResult = await _leadService.getLeads();
      final fuResult = await _followupService.getFollowups();

      int ordersCount = 0;
      List<Map<String, dynamic>> parsedOrders = [];
      int newCount = 0;
      int pendingCount = 0;
      int prepCount = 0;
      int dispCount = 0;
      int delivCount = 0;
      try {
        final orderRes = await _orderRepository.getOrders();
        if (orderRes['success'] == true) {
          final dynamic ordData = orderRes['data'];
          List rawOrders = [];
          if (ordData is List) {
            rawOrders = ordData;
          } else if (ordData is Map && ordData['orders'] is List) {
            rawOrders = ordData['orders'] as List;
          } else if (orderRes['orders'] is List) {
            rawOrders = orderRes['orders'] as List;
          }
          ordersCount = rawOrders.length;
          for (final ord in rawOrders) {
            if (ord is Map) {
              final mapped = _orderRepository.mapOrder(Map<String, dynamic>.from(ord));
              parsedOrders.add(mapped);
              final status = (mapped['status_raw'] ?? mapped['status'] ?? '').toString().toLowerCase();
              if (status.contains('place') || status.contains('new') || status.contains('created')) {
                newCount++;
              } else if (status.contains('pending') || status.contains('approval')) {
                pendingCount++;
              } else if (status.contains('prep') || status.contains('process')) {
                prepCount++;
              } else if (status.contains('dispatch') || status.contains('transit')) {
                dispCount++;
              } else if (status.contains('deliv')) {
                delivCount++;
              }
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _recentOrders = parsedOrders.take(6).toList();
          _newOrdersCount = newCount;
          _pendingApprovalCount = pendingCount;
          _preparingCount = prepCount;
          _dispatchedCount = dispCount;
          _deliveredCount = delivCount;
        });
      }

      int franchiseReqCount = 0;
      try {
        final reqRes = await _inventoryRepository.getDealerStockRequests();
        if (reqRes['success'] == true) {
          final dynamic reqData = reqRes['data'];
          if (reqData is List) {
            franchiseReqCount = reqData.length;
          } else if (reqData is Map && reqData['requests'] is List) {
            franchiseReqCount = (reqData['requests'] as List).length;
          }
        }
      } catch (_) {}

      if (leadStatsResult['success'] == true && leadStatsResult['data'] is Map) {
        final statsData = leadStatsResult['data']['stats'] ?? {};
        final totalLeads = statsData['total_leads'] ?? 0;
        final hotLeads = statsData['hot_leads'] ?? 0;
        final confirmed = statsData['confirmed'] ?? 0;
        final pipelineMap = statsData['pipeline'] is Map ? statsData['pipeline'] as Map : {};

        int todayFu = 0;
        if (fuStatsResult['success'] == true && fuStatsResult['data'] is Map) {
          todayFu = fuStatsResult['data']['stats']?['today'] ?? 0;
        }

        _stats = [
          {
            'title': 'Total Leads',
            'value': '$totalLeads',
            'change': 'Live',
            'icon': Icons.people_alt_outlined,
            'color': const Color(0xFF0284C7),
            'bgColor': const Color(0xFFE0F2FE),
          },
          {
            'title': 'Customer Orders',
            'value': '$ordersCount',
            'change': 'Database orders',
            'icon': Icons.shopping_bag_outlined,
            'color': const Color(0xFF2563EB),
            'bgColor': const Color(0xFFEFF6FF),
          },
          {
            'title': 'Franchise Stock Reqs',
            'value': '$franchiseReqCount',
            'change': 'Stock Requests',
            'icon': Icons.storefront_outlined,
            'color': const Color(0xFF7C3AED),
            'bgColor': const Color(0xFFF5F3FF),
          },
          {
            'title': 'Hot Leads',
            'value': '$hotLeads',
            'change': 'Priority',
            'icon': Icons.local_fire_department_outlined,
            'color': const Color(0xFFEF4444),
            'bgColor': const Color(0xFFFEF2F2),
          },
          {
            'title': 'Follow-ups Today',
            'value': '$todayFu',
            'change': '$todayFu pending',
            'icon': Icons.calendar_month_outlined,
            'color': const Color(0xFFD97706),
            'bgColor': const Color(0xFFFFFBEB),
          },
          {
            'title': 'Confirmed Dealers',
            'value': '$confirmed',
            'change': 'Confirmed',
            'icon': Icons.storefront_outlined,
            'color': const Color(0xFF10B981),
            'bgColor': const Color(0xFFECFDF5),
          },
        ];

        _pipeline = [
          {'name': 'New Lead', 'value': pipelineMap['new_lead'] ?? 0},
          {'name': 'Contacted', 'value': pipelineMap['contacted'] ?? 0},
          {'name': 'Follow-up', 'value': (pipelineMap['followup_1'] ?? 0) + (pipelineMap['followup_2'] ?? 0)},
          {'name': 'Interested', 'value': pipelineMap['interested'] ?? 0},
          {'name': 'Site Visit', 'value': pipelineMap['site_visit_scheduled'] ?? 0},
          {'name': 'Agreement', 'value': pipelineMap['agreement_pending'] ?? 0},
          {'name': 'Confirmed', 'value': pipelineMap['franchise_confirmed'] ?? 0},
        ];
      }

      if (fuResult['success'] == true && fuResult['data'] is Map) {
        final List rawFu = fuResult['data']['followups'] ?? [];
        _followups = rawFu.take(5).map((f) {
          return {
            'time': '${f['time'] ?? '10:00 AM'}',
            'name': '${f['lead'] ?? 'Lead'}',
            'text': '${f['note'] ?? f['followup_type'] ?? 'Follow-up'}',
          };
        }).toList();
      }

      if (leadsResult['success'] == true && leadsResult['data'] is Map) {
        final List rawLeads = leadsResult['data']['leads'] ?? [];
        _leads = rawLeads.take(5).map((l) {
          final mapped = _leadService.mapLead(l);
          return {
            'name': '${mapped['name']}',
            'phone': '${mapped['phone']}',
            'city': '${mapped['city']}',
            'budget': '${mapped['budget']}',
            'score': '${mapped['score']}',
            'status': '${mapped['status']}',
          };
        }).toList();
      }
    } catch (_) {}

    _loadPendingStockAlerts();
    _loadActionableAlerts();
  }

  Future<void> _loadPendingStockAlerts() async {
    try {
      final res = await _inventoryRepository.getPendingStockExpiryAlerts();
      if (!mounted) return;
      List? alerts;
      bool hasUnacknowledged = false;
      if (res['success'] == true) {
        hasUnacknowledged = res['has_unacknowledged_popup'] == true;
        if (res['data'] is List) {
          alerts = res['data'];
        } else if (res['data'] is Map && res['data']['alerts'] is List) {
          alerts = res['data']['alerts'];
        } else if (res['alerts'] is List) {
          alerts = res['alerts'];
        }
      }
      if (alerts != null) {
        setState(() {
          _pendingStockAlerts = alerts!.cast<Map<String, dynamic>>();
        });

        // Only pop up if backend has an active unacknowledged alert AND hasn't popped in this session
        if (hasUnacknowledged && !_pendingStockDialogShown) {
          _pendingStockDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showPendingStockExpiryDialog(context);
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadActionableAlerts() async {
    try {
      // 1. Pending Stock Requests from real backend API
      final reqRes = await _inventoryRepository.getDealerStockRequests();
      if (!mounted) return;
      if (reqRes['success'] == true) {
        List rawList = [];
        if (reqRes['data'] is List) {
          rawList = reqRes['data'] as List;
        } else if (reqRes['data'] is Map && reqRes['data']['requests'] is List) {
          rawList = reqRes['data']['requests'] as List;
        } else if (reqRes['requests'] is List) {
          rawList = reqRes['requests'] as List;
        }

        // Include REQUESTED and all active pending statuses
        final activeRequests = rawList.where((r) {
          if (r is! Map) return false;
          final status = (r['status'] ?? '').toString().toUpperCase();
          final id = r['id'] is int ? r['id'] as int : int.tryParse('${r['id']}') ?? 0;
          final isPending = status == 'REQUESTED' ||
              status == 'PENDING' ||
              status == 'SUBMITTED' ||
              status == 'PENDING_APPROVAL' ||
              status == 'APPROVED' ||
              status == 'PREPARED' ||
              status == 'PARTIALLY_FULFILLED';
          return isPending && !_dismissedRequestIds.contains(id);
        }).map((r) => Map<String, dynamic>.from(r as Map)).toList();

        // Group by request_number or (dealer + created_at) so multi-item requests appear as one card
        final Map<String, Map<String, dynamic>> grouped = {};
        for (final req in activeRequests) {
          final reqNum = req['request_number']?.toString().trim();
          final dealerName = (req['dealer_name'] ?? req['franchise_name'] ?? 'Franchise Partner').toString();
          final createdAt = req['created_at']?.toString() ?? '';
          final timeKey = createdAt.length >= 16 ? createdAt.substring(0, 16) : createdAt;
          final groupKey = (reqNum != null && reqNum.isNotEmpty) ? reqNum : '${dealerName}_$timeKey';

          final prodName = req['product_name'] ?? req['product_sku'] ?? 'Water Bottle';
          final qty = req['requested_quantity'] ?? req['quantity'] ?? 0;
          final reqId = req['id'] is int ? req['id'] as int : int.tryParse('${req['id']}') ?? 0;

          if (!grouped.containsKey(groupKey)) {
            grouped[groupKey] = {
              'primary_id': reqId,
              'all_ids': <int>[reqId],
              'request_number': reqNum?.isNotEmpty == true ? reqNum : 'SR-$reqId',
              'dealer_name': dealerName,
              'status': req['status'] ?? 'REQUESTED',
              'created_at': createdAt,
              'items': [
                {'product_name': prodName, 'quantity': qty, 'sku': req['product_sku'] ?? ''}
              ],
              'raw_request': req,
            };
          } else {
            (grouped[groupKey]!['all_ids'] as List<int>).add(reqId);
            (grouped[groupKey]!['items'] as List).add({
              'product_name': prodName,
              'quantity': qty,
              'sku': req['product_sku'] ?? '',
            });
          }
        }

        setState(() {
          _pendingStockRequests = grouped.values.toList();
        });
      }

      // 2. Pending Payment Verifications (from authoritative DB API + notifications)
      final List<Map<String, dynamic>> paymentList = [];
      final Set<int> seenTxnOrInvoice = {};

      // 2a. Direct authoritative database queries of pending transactions
      final directPayRes = await _inventoryRepository.getPendingPayments();
      if (!mounted) return;
      if (directPayRes['success'] == true) {
        List rawTxns = [];
        if (directPayRes['payments'] is List) {
          rawTxns = directPayRes['payments'] as List;
        } else if (directPayRes['data'] is List) {
          rawTxns = directPayRes['data'] as List;
        }
        for (var t in rawTxns) {
          if (t is Map) {
            final tMap = Map<String, dynamic>.from(t);
            final txnId = tMap['id'] is int ? tMap['id'] as int : int.tryParse('${tMap['id']}') ?? 0;
            if (!_dismissedNotificationIds.contains(txnId)) {
              seenTxnOrInvoice.add(txnId);
              paymentList.add(tMap);
            }
          }
        }
      }

      // 2b. Notifications fallback/merge
      final notifRes = await _notificationService.getAdminNotifications();
      if (!mounted) return;
      if (notifRes['success'] == true && notifRes['data'] is Map) {
        final List notifs = notifRes['data']['notifications'] ?? [];
        for (var n in notifs) {
          if (n is Map) {
            final type = (n['notification_type'] ?? '').toString();
            final isRead = n['is_read'] == true;
            final notifId = n['id'] is int ? n['id'] as int : int.tryParse('${n['id']}') ?? 0;
            final refId = n['reference_id'] is int ? n['reference_id'] as int : int.tryParse('${n['reference_id']}') ?? 0;
            if (type == 'payment_verification' && !isRead && !_dismissedNotificationIds.contains(notifId) && !seenTxnOrInvoice.contains(refId)) {
              paymentList.add(Map<String, dynamic>.from(n));
            }
          }
        }
      }

      // 3. Pending Customer Orders Awaiting Fulfillment
      final List<Map<String, dynamic>> orderAlertList = [];
      final Set<int> seenOrderIds = {};

      final ordersRes = await _orderRepository.getOrders(status: 'order_placement');
      if (!mounted) return;
      if (ordersRes['success'] == true && ordersRes['data'] != null) {
        final List rawOrders = ordersRes['data']['orders'] ?? (ordersRes['data'] is List ? ordersRes['data'] : []);
        for (var o in rawOrders) {
          if (o is Map) {
            final oMap = Map<String, dynamic>.from(o);
            final oId = oMap['id'] is int ? oMap['id'] as int : int.tryParse('${oMap['id']}') ?? 0;
            if (oId > 0 && !_dismissedRequestIds.contains(oId)) {
              seenOrderIds.add(oId);
              orderAlertList.add(oMap);
            }
          }
        }
      }

      if (notifRes['success'] == true && notifRes['data'] is Map) {
        final List notifs = notifRes['data']['notifications'] ?? [];
        for (var n in notifs) {
          if (n is Map) {
            final type = (n['notification_type'] ?? '').toString();
            final isRead = n['is_read'] == true;
            final notifId = n['id'] is int ? n['id'] as int : int.tryParse('${n['id']}') ?? 0;
            final refId = n['reference_id'] is int ? n['reference_id'] as int : int.tryParse('${n['reference_id']}') ?? 0;
            if ((type == 'order_placed' || type == 'bulk_order') &&
                !isRead &&
                !_dismissedNotificationIds.contains(notifId) &&
                !seenOrderIds.contains(refId)) {
              final nMap = Map<String, dynamic>.from(n);
              nMap['id'] = refId > 0 ? refId : notifId;
              nMap['notif_id'] = notifId;
              nMap['customer_name'] = nMap['title'] ?? 'Customer';
              orderAlertList.add(nMap);
            }
          }
        }
      }

      setState(() {
        _pendingPaymentVerifications = paymentList;
        _pendingCustomerOrders = orderAlertList;
      });
    } catch (_) {}
  }

  void _openSpecificOrderDetail(Map<String, dynamic> ord) {
    final rawId = ord['id'] is int ? ord['id'] as int : int.tryParse('${ord['id']}') ?? 0;
    final ordCode = (ord['order_id'] ?? ord['orderId'] ?? ord['order_code'] ?? 'ORD-$rawId')
        .toString()
        .replaceAll('#', '');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderId: ordCode,
          initialOrder: ord,
          dbId: rawId,
        ),
      ),
    ).then((_) {
      _loadDashboardData();
      _loadActionableAlerts();
    });
  }

  void _handlePendingOrdersTap() {
    if (_pendingCustomerOrders.length == 1) {
      _openSpecificOrderDetail(_pendingCustomerOrders.first);
    } else if (_pendingCustomerOrders.length > 1) {
      PendingOrdersPickerDialog.show(
        context,
        pendingOrders: _pendingCustomerOrders,
        onSelectOrder: (selectedOrder) {
          _openSpecificOrderDetail(selectedOrder);
        },
        onRefresh: () async {
          await _loadActionableAlerts();
          await _loadDashboardData();
        },
      );
    } else {
      widget.onOpenOrders?.call();
    }
  }

  Widget _actionableAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. Pending Customer Orders Awaiting Fulfillment
        ..._pendingCustomerOrders.map((ord) {
          final ordId = ord['id'] is int ? ord['id'] as int : int.tryParse('${ord['id']}') ?? 0;
          final notifId = ord['notif_id'] is int ? ord['notif_id'] as int : ordId;
          final ordCode = (ord['order_id'] ?? ord['orderId'] ?? ord['order_code'] ?? 'ORD-$ordId').toString().replaceAll('#', '');
          final custName = ord['customer_name']?.toString() ?? ord['client_name']?.toString() ?? 'Customer';
          final amt = ord['total_amount']?.toString() ?? ord['amount']?.toString() ?? '0';
          final itemsCount = ord['items_count']?.toString() ?? ord['items']?.toString() ?? '1';
          final message = ord['message']?.toString() ?? 'New order placed by customer awaiting approval and dispatch.';

          void openThisOrder() {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(
                  orderId: ordCode,
                  initialOrder: ord,
                  dbId: ordId,
                ),
              ),
            ).then((_) => _loadDashboardData());
          }

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: openThisOrder,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.08),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 5),
                              Text(
                                'NEW CUSTOMER ORDER RECEIVED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                          tooltip: 'Dismiss alert',
                          onPressed: () {
                            setState(() {
                              _dismissedRequestIds.add(ordId);
                              _dismissedNotificationIds.add(notifId);
                              _pendingCustomerOrders.removeWhere((o) => o['id'] == ordId);
                            });
                            _notificationService.markAdminNotificationRead(notifId);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$ordCode • $custName',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0369A1),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Amount: ₹$amt  •  Items: $itemsCount  •  Status: Order Placement',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0369A1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text(
                            'VIEW ORDER DETAILS',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: openThisOrder,
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.local_shipping_outlined, size: 16),
                          label: const Text(
                            'UPDATE STATUS / FULFILL',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: () => _handleQuickFulfillOrder(ord),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('OPEN ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: openThisOrder,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // 1. Grouped Stock Requests
        ..._pendingStockRequests.map((group) {
          final primaryId = group['primary_id'] is int ? group['primary_id'] as int : int.tryParse('${group['primary_id']}') ?? 0;
          final allIds = (group['all_ids'] as List?)?.cast<int>() ?? [primaryId];
          final dealerName = group['dealer_name']?.toString() ?? 'Franchise Partner';
          final reqNum = group['request_number']?.toString() ?? 'SR-$primaryId';
          final rawAt = group['created_at']?.toString() ?? '';
          String formattedDate = '';
          if (rawAt.isNotEmpty) {
            try {
              final parsed = DateTime.parse(rawAt).toLocal();
              formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
            } catch (_) {
              formattedDate = rawAt.split('T').first;
            }
          }
          final statusRaw = (group['status'] ?? 'REQUESTED').toString().toUpperCase();
          final statusDisplay = statusRaw == 'REQUESTED' ? 'Pending Review' : statusRaw.replaceAll('_', ' ');
          final items = (group['items'] as List?) ?? [];
          final rawReq = group['raw_request'] as Map<String, dynamic>? ?? {};

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFAF5FF), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC4B5FD), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header badge row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_active_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'NEW FRANCHISE STOCK REQUEST',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        statusDisplay,
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (reqNum.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          reqNum,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // Franchise Name
                const Text(
                  'Franchise:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  dealerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: 10),
                // Requested Stock
                const Text(
                  'Requested Stock:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                ...items.map((it) {
                  final pName = it['product_name'] ?? 'Water Bottle';
                  final qty = it['quantity'] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 6),
                        Text(
                          '$pName — $qty units',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6D28D9),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (formattedDate.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        'Requested: $formattedDate',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 1,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 17),
                        label: const Text(
                          'VIEW REQUEST',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DealerStockRequestFulfillmentScreen(
                                requestId: primaryId,
                                initialRequest: rawReq,
                              ),
                            ),
                          ).then((_) {
                            _loadActionableAlerts();
                            _loadDashboardData();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _dismissedRequestIds.addAll(allIds);
                          _pendingStockRequests.removeWhere((r) => r['primary_id'] == primaryId);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        }),

        // 2. Payment Verifications
        ..._pendingPaymentVerifications.map((notif) {
          final notifId = notif['id'] is int ? notif['id'] as int : int.tryParse('${notif['id']}') ?? 0;
          final franchiseName = notif['franchise_name']?.toString() ?? 'Franchise';
          final invNumber = notif['invoice_number']?.toString() ?? '';
          final orderCode = notif['order_code']?.toString() ?? '';
          final refNum = notif['reference_number']?.toString() ?? '';
          final payMethod = notif['payment_method']?.toString() ?? 'UPI';
          final amt = notif['amount'] ?? notif['amount_paid'];
          final amtStr = amt != null ? '₹$amt' : '';
          final title = notif['title']?.toString() ?? 'Payment Verification: $franchiseName ($amtStr)';
          final msg = notif['message']?.toString() ??
              '$franchiseName submitted $amtStr via $payMethod. Ref: ${refNum.isNotEmpty ? refNum : 'N/A'}${invNumber.isNotEmpty ? ' • Invoice: $invNumber' : ''}${orderCode.isNotEmpty ? ' • Order: #$orderCode' : ''}';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0FDF4), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.06),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'PAYMENT VERIFICATION REQUIRED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        setState(() {
                          _dismissedNotificationIds.add(notifId);
                          _pendingPaymentVerifications.removeWhere((n) => n['id'] == notifId);
                        });
                        _notificationService.markAdminNotificationRead(notifId);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  msg,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text(
                        'APPROVE PAYMENT',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () => _handleApprovePayment(notif),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('REJECT PAYMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _handleRejectPayment(notif),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _handleQuickFulfillOrder(Map<String, dynamic> ord) async {
    final ordId = ord['id'] is int ? ord['id'] as int : int.tryParse('${ord['id']}') ?? 0;
    final notifId = ord['notif_id'] is int ? ord['notif_id'] as int : ordId;
    final ordCode = ord['order_id']?.toString() ?? ord['orderId']?.toString() ?? ord['order_code']?.toString() ?? '#ORD-$ordId';

    String selectedStatus = 'dispatch';
    final targetStatuses = [
      {'label': 'Dispatch for Delivery', 'value': 'dispatch'},
      {'label': 'Mark Delivered', 'value': 'delivered'},
      {'label': 'Plant Approval', 'value': 'plant_approval'},
      {'label': 'Preparing / Packaging', 'value': 'preparing'},
      {'label': 'Invoice Generated', 'value': 'invoice_generated'},
      {'label': 'Cancel Order', 'value': 'cancelled'},
    ];

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF0284C7), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Fulfill Order $ordCode',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select new fulfillment status for this customer order. The customer will immediately receive an in-app status update and notification.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Fulfillment Status',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: targetStatuses.map((s) {
                      return DropdownMenuItem<String>(
                        value: s['value'],
                        child: Text(s['label']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedStatus = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('Confirm & Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated != true) return;

    final res = await _orderRepository.updateOrderStatus(ordId, selectedStatus);
    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _dismissedRequestIds.add(ordId);
        _dismissedNotificationIds.add(notifId);
        _pendingCustomerOrders.removeWhere((o) => o['id'] == ordId);
      });
      _notificationService.markAdminNotificationRead(notifId);
      await _loadDashboardData();
      if (!mounted) return;
      AppToast.success(context, 'Order $ordCode status updated to $selectedStatus successfully!');
    } else {
      AppToast.error(context, res['message'] ?? 'Failed to update order status.');
    }
  }

  Future<void> _handleApprovePayment(Map<String, dynamic> notif) async {
    final notifId = notif['id'] is int ? notif['id'] as int : int.tryParse('${notif['id']}') ?? 0;
    final invId = notif['invoice_id'] is int
        ? notif['invoice_id'] as int
        : (notif['reference_id'] is int ? notif['reference_id'] as int : int.tryParse('${notif['reference_id'] ?? notif['invoice_id']}') ?? 0);
    final txnId = notif['transaction_number'] != null ? notifId : 0;
    final amt = notif['amount'] ?? notif['amount_paid'] ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Payment'),
        content: Text('Are you sure you want to approve and confirm this payment of ₹$amt? This will update the company and franchise financial ledgers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve & Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    Map<String, dynamic> res;
    if (txnId > 0) {
      res = await _inventoryRepository.verifyPaymentByTxnId(txnId: txnId);
      if (res['success'] != true && invId > 0) {
        res = await _inventoryRepository.verifyInvoicePayment(invoiceId: invId);
      }
    } else {
      res = await _inventoryRepository.verifyInvoicePayment(invoiceId: invId);
    }

    if (!mounted) return;
    if (res['success'] == true) {
      AppToast.success(context, res['message']?.toString() ?? 'Payment confirmed successfully!');
      _notificationService.markAdminNotificationRead(notifId);
      setState(() {
        _dismissedNotificationIds.add(notifId);
        _pendingPaymentVerifications.removeWhere((n) => n['id'] == notifId);
      });
      _loadDashboardData();
      _loadActionableAlerts();
    } else {
      AppToast.error(context, res['message']?.toString() ?? 'Failed to approve payment');
    }
  }

  Future<void> _handleRejectPayment(Map<String, dynamic> notif) async {
    final notifId = notif['id'] is int ? notif['id'] as int : int.tryParse('${notif['id']}') ?? 0;
    final invId = notif['invoice_id'] is int
        ? notif['invoice_id'] as int
        : (notif['reference_id'] is int ? notif['reference_id'] as int : int.tryParse('${notif['reference_id'] ?? notif['invoice_id']}') ?? 0);
    final txnId = notif['transaction_number'] != null ? notifId : 0;

    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter reason for rejecting this payment submission:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Reference number not found in bank statement',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null) return;

    Map<String, dynamic> res;
    if (txnId > 0) {
      res = await _inventoryRepository.rejectPaymentByTxnId(txnId: txnId, reason: reason);
      if (res['success'] != true && invId > 0) {
        res = await _inventoryRepository.rejectInvoicePayment(invoiceId: invId, reason: reason);
      }
    } else {
      res = await _inventoryRepository.rejectInvoicePayment(invoiceId: invId, reason: reason);
    }

    if (!mounted) return;
    if (res['success'] == true) {
      AppToast.success(context, 'Payment rejected. Franchise has been notified.');
      _notificationService.markAdminNotificationRead(notifId);
      setState(() {
        _dismissedNotificationIds.add(notifId);
        _pendingPaymentVerifications.removeWhere((n) => n['id'] == notifId);
      });
      _loadDashboardData();
      _loadActionableAlerts();
    } else {
      AppToast.error(context, res['message']?.toString() ?? 'Failed to reject payment');
    }
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final desktop =
            constraints.maxWidth >= 900;

        return Container(
          color:
              const Color(
            0xFFF5F7FB,
          ),
          child:
              SingleChildScrollView(
            padding:
                EdgeInsets.all(
              desktop ? 28 : 16,
            ),
            child:
                ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 1300,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  _header(
                    desktop,
                  ),

                  if (_pendingStockAlerts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _pendingStockExpiryBanner(),
                  ],

                  if (_pendingStockRequests.isNotEmpty ||
                      _pendingPaymentVerifications.isNotEmpty ||
                      _pendingCustomerOrders.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _actionableAlertsSection(),
                  ],

                  const SizedBox(
                    height: 24,
                  ),

                  _statsSection(
                    desktop,
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  _actionableCustomerOrdersCard(desktop),

                  const SizedBox(
                    height: 22,
                  ),

                  if (desktop)
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Expanded(
                          child:
                              _pipelineCard(),
                        ),
                        const SizedBox(
                          width: 18,
                        ),
                        Expanded(
                          child:
                              _followupCard(),
                        ),
                      ],
                    )
                  else ...[
                    _pipelineCard(),
                    const SizedBox(
                      height: 16,
                    ),
                    _followupCard(),
                  ],

                  const SizedBox(
                    height: 22,
                  ),

                  _quickActionsGrid(desktop),

                  const SizedBox(
                    height: 22,
                  ),

                  _recentLeadsCard(
                    desktop,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(
  bool desktop,
) {
  return const Column(
    crossAxisAlignment:
        CrossAxisAlignment.start,
    children: [
      Text(
        'Dashboard',
        style: TextStyle(
          fontSize: 28,
          fontWeight:
              FontWeight.w800,
          color:
              Color(
            0xFF111827,
          ),
        ),
      ),
      SizedBox(
        height: 5,
      ),
      Text(
        'Overview of your franchise business',
        style: TextStyle(
          color:
              Color(
            0xFF64748B,
          ),
          fontSize: 13,
        ),
      ),
    ],
  );
}
  Widget _statsSection(
    bool desktop,
  ) {
    VoidCallback? getTapAction(int index) {
      switch (index) {
        case 0:
          return widget.onOpenLeads;
        case 1:
          return _handlePendingOrdersTap;
        case 2:
          return widget.onOpenStockRequests ?? widget.onOpenInventory;
        case 3:
          return widget.onOpenLeads;
        case 4:
          return widget.onOpenFollowups;
        case 5:
          return widget.onOpenFranchises;
        default:
          return null;
      }
    }

    if (desktop) {
      return Row(
        children: List.generate(
          _stats.length,
          (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == _stats.length - 1 ? 0 : 14,
                ),
                child: _StatCard(
                  item: _stats[index],
                  onTap: getTapAction(index),
                ),
              ),
            );
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVerySmall = constraints.maxWidth < 340;
        final crossAxisCount = isVerySmall ? 1 : 2;
        final childAspectRatio = isVerySmall
            ? 3.2
            : (constraints.maxWidth < 380 ? 1.35 : 1.45);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: _stats.length,
          itemBuilder: (_, index) {
            return _StatCard(
              item: _stats[index],
              onTap: getTapAction(index),
            );
          },
        );
      },
    );
  }

  Widget _actionableCustomerOrdersCard(bool desktop) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            title: 'Customer Orders & Action Center',
            subtitle: 'Real-time orders placed by customers across all territories',
            button: 'View All Orders (${_stats[1]['value']})',
            onTap: widget.onOpenOrders,
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _orderStageChip('New Placed', _newOrdersCount, const Color(0xFF2563EB), const Color(0xFFEFF6FF), onTap: widget.onOpenOrders),
                const SizedBox(width: 8),
                _orderStageChip(
                  'Pending Approval',
                  _pendingApprovalCount,
                  const Color(0xFFD97706),
                  const Color(0xFFFFFBEB),
                  onTap: _handlePendingOrdersTap,
                ),
                const SizedBox(width: 8),
                _orderStageChip('Preparing', _preparingCount, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), onTap: widget.onOpenOrders),
                const SizedBox(width: 8),
                _orderStageChip('Dispatched', _dispatchedCount, const Color(0xFF0284C7), const Color(0xFFE0F2FE), onTap: widget.onOpenOrders),
                const SizedBox(width: 8),
                _orderStageChip('Delivered', _deliveredCount, const Color(0xFF16A34A), const Color(0xFFF0FDF4), onTap: widget.onOpenOrders),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_recentOrders.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  const Text('No recent customer orders found', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentOrders.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (ctx, idx) {
                final ord = _recentOrders[idx];
                final code = ord['order_code']?.toString() ?? 'ORD-${ord['id']}';
                final client = ord['client_name']?.toString() ?? ord['customer_name']?.toString() ?? 'Customer';
                final amt = ord['amount']?.toString() ?? ord['grand_total']?.toString() ?? '0';
                final status = ord['status']?.toString() ?? 'Processing';
                final fulfilling = ord['fulfilling_entity'] is Map ? ord['fulfilling_entity']['name'] ?? 'Company Direct' : 'Company Direct';
                final date = ord['created_at']?.toString() ?? ord['order_date']?.toString() ?? '';

                return InkWell(
                  onTap: () {
                    final rawId = ord['id'] is int ? ord['id'] as int : int.tryParse('${ord['id']}') ?? 0;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(
                          orderId: code,
                          initialOrder: ord,
                          dbId: ord['db_id'] is int ? ord['db_id'] : rawId,
                        ),
                      ),
                    ).then((_) => _loadDashboardData());
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'By: $fulfilling',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$client • $date',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹$amt', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B))),
                            const SizedBox(height: 2),
                            AppStatusBadge.order(status, fontSize: 10),
                          ],
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _orderStageChip(String label, int count, Color fg, Color bg, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: fg.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: fg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pipelineCard() {
    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _cardHeader(
            title:
                'Lead Pipeline',
            subtitle:
                'Current lead distribution',
            button:
                'View All',
            onTap:
                widget.onOpenLeads,
          ),

          const SizedBox(
            height: 20,
          ),

          ..._pipeline.map(
            (item) {
              final value =
                  (item['value'] is num) ? (item['value'] as num).toInt() : 0;

              final progress =
                  (value * 1.7 /
                          100)
                      .clamp(
                0.0,
                1.0,
              );

              return InkWell(
                onTap: widget.onOpenLeads,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets
                          .only(
                    bottom: 15,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child:
                                Text(
                              item['name']
                                  .toString(),
                              style:
                                  const TextStyle(
                                fontSize:
                                    12,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ),
                          Text(
                            '$value',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 7,
                      ),
                      ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                        child:
                            LinearProgressIndicator(
                          value:
                              progress,
                          minHeight:
                              7,
                          backgroundColor:
                              const Color(
                            0xFFEFF1F5,
                          ),
                          valueColor:
                              const AlwaysStoppedAnimation(
                            Color(
                              0xFF0284C7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _followupCard() {
    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _cardHeader(
            title:
                "Today's Follow-ups",
            subtitle:
                'Upcoming actions',
            button:
                'View All',
            onTap:
                widget.onOpenFollowups,
          ),

          const SizedBox(
            height: 14,
          ),

          if (_followups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No upcoming follow-ups scheduled',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ),
            )
          else
            ..._followups.map(
            (item) {
              return InkWell(
                onTap: widget.onOpenFollowups,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 12,
                    horizontal: 6,
                  ),
                  decoration:
                      const BoxDecoration(
                    border: Border(
                      bottom:
                          BorderSide(
                        color:
                            Color(
                          0xFFF1F5F9,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          item['time']!,
                          style:
                              const TextStyle(
                            fontSize:
                                11,
                            color:
                                Color(
                              0xFF0284C7,
                            ),
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              item['name']!,
                              style:
                                  const TextStyle(
                                fontSize:
                                    12,
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              item['text']!,
                              style:
                                  const TextStyle(
                                fontSize:
                                    11,
                                color:
                                    Color(
                                  0xFF64748B,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _quickActionsGrid(bool desktop) {
    final actions = [
      {'title': 'Leads', 'icon': Icons.people_alt_outlined, 'color': const Color(0xFF0284C7), 'action': widget.onOpenLeads},
      {'title': 'Follow-ups', 'icon': Icons.calendar_month_outlined, 'color': const Color(0xFF0EA5E9), 'action': widget.onOpenFollowups},
      {'title': 'Users', 'icon': Icons.manage_accounts_outlined, 'color': const Color(0xFF6366F1), 'action': widget.onOpenUsers},
      {'title': 'Orders', 'icon': Icons.shopping_cart_outlined, 'color': const Color(0xFFF59E0B), 'action': widget.onOpenOrders},
      {'title': 'Franchise', 'icon': Icons.storefront_outlined, 'color': const Color(0xFF8B5CF6), 'action': widget.onOpenFranchises},
      {'title': 'Inventory', 'icon': Icons.inventory_2_outlined, 'color': const Color(0xFFEC4899), 'action': widget.onOpenInventory},
      {'title': 'Chatbot', 'icon': Icons.account_tree_outlined, 'color': const Color(0xFF10B981), 'action': widget.onOpenChatbot},
      {'title': 'Notifications', 'icon': Icons.notifications_none_outlined, 'color': const Color(0xFF06B6D4), 'action': widget.onOpenNotifications},
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            title: 'Quick Operations',
            subtitle: 'Direct shortcuts to system modules',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isVerySmall = constraints.maxWidth < 340;
              final isNarrow = constraints.maxWidth < 600;
              final crossAxisCount = isVerySmall ? 1 : (isNarrow ? 2 : 4);
              final childAspectRatio = isVerySmall
                  ? 3.8
                  : (isNarrow
                      ? (constraints.maxWidth < 380 ? 2.1 : 2.4)
                      : 2.8);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(act['icon'] as IconData, color: color, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              act['title'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
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

  Widget _recentLeadsCard(
    bool desktop,
  ) {
    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _cardHeader(
            title:
                'Recent Leads',
            subtitle:
                'Latest franchise enquiries',
            button:
                'View All',
            onTap:
                widget.onOpenLeads,
          ),

          const SizedBox(
            height: 18,
          ),

          if (_leads.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No recent leads found',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ),
            )
          else if (desktop)
            _leadsTable()
          else
            ..._leads.map(
              _mobileLeadCard,
            ),
        ],
      ),
    );
  }

  Widget _leadsTable() {
    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets
                  .symmetric(
            vertical: 12,
          ),
          child:
              const Row(
            children: [
              Expanded(
                flex: 2,
                child:
                    Text(
                  'LEAD',
                  style:
                      _headerTextStyle,
                ),
              ),
              Expanded(
                child:
                    Text(
                  'CITY',
                  style:
                      _headerTextStyle,
                ),
              ),
              Expanded(
                flex: 2,
                child:
                    Text(
                  'INVESTMENT BUDGET',
                  style:
                      _headerTextStyle,
                ),
              ),
              Expanded(
                child:
                    Text(
                  'SCORE',
                  style:
                      _headerTextStyle,
                ),
              ),
              Expanded(
                child:
                    Text(
                  'STATUS',
                  style:
                      _headerTextStyle,
                ),
              ),
            ],
          ),
        ),

        const Divider(
          height: 1,
        ),

        ..._leads.map(
          (lead) {
            return InkWell(
              onTap: widget.onOpenLeads,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 14,
                  horizontal: 6,
                ),
                decoration:
                    const BoxDecoration(
                  border: Border(
                    bottom:
                        BorderSide(
                      color:
                          Color(
                        0xFFF1F5F9,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            lead[
                                'name']!,
                            style:
                                const TextStyle(
                              fontSize:
                                  12,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            lead[
                                'phone']!,
                            style:
                                const TextStyle(
                              fontSize:
                                  10,
                              color:
                                  Color(
                                0xFF94A3B8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          Text(
                        lead[
                            'city']!,
                        style:
                            const TextStyle(
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child:
                          Text(
                        lead[
                            'budget']!,
                        style:
                            const TextStyle(
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          Align(
                        alignment:
                            Alignment
                                .centerLeft,
                        child:
                            _scoreBadge(
                          lead[
                              'score']!,
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          Text(
                        lead[
                            'status']!,
                        style:
                            const TextStyle(
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }


  Widget _mobileLeadCard(
    Map<String, String> lead,
  ) {
    return InkWell(
      onTap: widget.onOpenLeads,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
            const EdgeInsets.all(
          14,
        ),
        decoration:
            BoxDecoration(
          color:
              const Color(
            0xFFF8FAFC,
          ),
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                  lead['name']!,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),
              ),
              _scoreBadge(
                lead['score']!,
              ),
            ],
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            lead['phone']!,
            style:
                const TextStyle(
              fontSize: 11,
              color:
                  Color(
                0xFF64748B,
              ),
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            '${lead['city']} • ${lead['budget']}',
            style:
                const TextStyle(
              fontSize: 11,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            'Status: ${lead['status']}',
            style:
                const TextStyle(
              fontSize: 11,
              color:
                  Color(
                0xFF64748B,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _scoreBadge(
    String score,
  ) {
    Color bg;
    Color fg;

    if (score == 'Hot') {
      bg =
          const Color(
        0xFFFEF2F2,
      );
      fg =
          const Color(
        0xFFDC2626,
      );
    } else if (score ==
        'Warm') {
      bg =
          const Color(
        0xFFFFF7ED,
      );
      fg =
          const Color(
        0xFFEA580C,
      );
    } else {
      bg =
          const Color(
        0xFFF1F5F9,
      );
      fg =
          const Color(
        0xFF64748B,
      );
    }

    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color: bg,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        score,
        style:
            TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }

  Widget _cardHeader({
    required String title,
    required String subtitle,
    String? button,
    VoidCallback? onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (button != null && constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onTap,
                  child: Text(button),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            if (button != null)
              TextButton(
                onPressed: onTap,
                child: Text(
                  button,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _card({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: child,
    );
  }

  Widget _pendingStockExpiryBanner() {
    final alertCount = _pendingStockAlerts.length;
    final totalPendingQty = _pendingStockAlerts.fold<int>(
      0,
      (sum, item) => sum + (int.tryParse('${item['pending_quantity']}') ?? 0),
    );
    final earliestAlert = _pendingStockAlerts.isNotEmpty ? _pendingStockAlerts.first : <String, dynamic>{};
    final remainingDays = earliestAlert['remaining_days'] ?? 45;
    final dealerName = earliestAlert['dealer_or_customer'] ?? 'Maa Durga Distributors';
    final String daysLabel = remainingDays >= 30
        ? '⏳ $remainingDays Days Left (~${(remainingDays / 30).toStringAsFixed(1)} Mo)'
        : '⏳ $remainingDays Days Left';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBEB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0xFFFEF3C7))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE68A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFB45309),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'PENDING STOCK EXPIRY ALERT',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF92400E),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$alertCount Batch${alertCount > 1 ? 'es' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Text(
                        daysLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dealerName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${NumberFormat('#,##,###').format(totalPendingQty)} uncollected bottles approaching expiration. Action is required to clear or reallocate this batch before the shelf-life deadline.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPendingStockExpiryDialog(context),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Review Expiring Batches'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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

  void _showPendingStockExpiryDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFFBBF24),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Stock Expiry Clearance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${_pendingStockAlerts.length} batch requires immediate clearance',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),

                // Notice Banner
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFFBEB),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Uncollected stock allocated to wholesale orders must be delivered or cleared before the expiry date.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // List of alert items
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingStockAlerts.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                    itemBuilder: (c, idx) {
                      final alert = _pendingStockAlerts[idx];
                      final remainingDays = alert['remaining_days'] ?? 0;
                      final isExpired = alert['is_expired'] == true || remainingDays <= 0;
                      final pendingQty = alert['pending_quantity'] ?? 0;
                      final allocatedQty = alert['allocated_quantity'] ?? 0;
                      final collectedQty = alert['collected_quantity'] ?? 0;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isExpired ? const Color(0xFFEF4444) : const Color(0xFFFDE68A),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dealer & Status Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    alert['dealer_or_customer']?.toString() ?? 'Franchise',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isExpired ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isExpired
                                        ? 'EXPIRED'
                                        : (remainingDays >= 30
                                            ? '⏳ $remainingDays Days Left (~${(remainingDays / 30).toStringAsFixed(1)} Mo)'
                                            : '⏳ $remainingDays Days Left'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isExpired ? const Color(0xFFDC2626) : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Product
                            Text(
                              '${alert['product_name'] ?? 'Product'} (${alert['product_sku'] ?? ''})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Wrap metadata chips to PREVENT text going off screen!
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _metaBadge('Order: ${alert['order_number']}', const Color(0xFF0284C7)),
                                _metaBadge('Batch: ${alert['batch_number']}', const Color(0xFF475569)),
                                _metaBadge('Exp: ${alert['expiry_date']}', isExpired ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Quantities Breakdown
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      const Text('Allocated', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Text(
                                        NumberFormat('#,##,###').format(allocatedQty),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                      ),
                                    ],
                                  ),
                                  Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                                  Column(
                                    children: [
                                      const Text('Cleared', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Text(
                                        NumberFormat('#,##,###').format(collectedQty),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                                      ),
                                    ],
                                  ),
                                  Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                                  Column(
                                    children: [
                                      const Text('PENDING', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${NumberFormat('#,##,###').format(pendingQty)} pcs',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Actions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          // View Inventory Stock
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(ctx, rootNavigator: true).pop();
                                final firstAlert = _pendingStockAlerts.isNotEmpty ? _pendingStockAlerts.first : null;
                                final bNum = firstAlert?['batch_number']?.toString();
                                if (widget.onOpenInventoryWithBatch != null) {
                                  widget.onOpenInventoryWithBatch!(bNum);
                                } else if (widget.onOpenInventory != null) {
                                  widget.onOpenInventory!();
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0284C7),
                                side: const BorderSide(color: Color(0xFF0284C7)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('VIEW STOCK'),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // View Order
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(ctx, rootNavigator: true).pop();
                                final firstAlert = _pendingStockAlerts.isNotEmpty ? _pendingStockAlerts.first : null;
                                final oNum = firstAlert?['order_number']?.toString();
                                if (widget.onOpenOrdersWithCode != null) {
                                  widget.onOpenOrdersWithCode!(oNum);
                                } else if (widget.onOpenOrders != null) {
                                  widget.onOpenOrders!();
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF16A34A),
                                side: const BorderSide(color: Color(0xFF16A34A)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('VIEW ORDER'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Mark As Reviewed
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                for (final a in _pendingStockAlerts) {
                                  final aId = a['id'];
                                  if (aId != null) {
                                    await _inventoryRepository.actionPendingStockExpiryAlert(
                                      alertId: aId is int ? aId : int.tryParse(aId.toString()) ?? 0,
                                      action: 'ACKNOWLEDGE',
                                    );
                                  }
                                }
                                if (ctx.mounted) {
                                  Navigator.of(ctx, rootNavigator: true).pop();
                                }
                                _pendingStockDialogShown = true;
                                if (mounted) {
                                  AppToast.success(context, 'Alert reviewed. Popup will not appear repeatedly.');
                                  _loadPendingStockAlerts();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.check_circle_outline, size: 14),
                              label: const Text('MARK REVIEWED'),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Snooze
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                for (final a in _pendingStockAlerts) {
                                  final aId = a['id'];
                                  if (aId != null) {
                                    await _inventoryRepository.actionPendingStockExpiryAlert(
                                      alertId: aId is int ? aId : int.tryParse(aId.toString()) ?? 0,
                                      action: 'SNOOZE',
                                      snoozeDays: 3,
                                    );
                                  }
                                }
                                if (ctx.mounted) {
                                  Navigator.of(ctx, rootNavigator: true).pop();
                                }
                                _pendingStockDialogShown = true;
                                if (mounted) {
                                  AppToast.info(context, 'Alert snoozed for 3 days.');
                                  _loadPendingStockAlerts();
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('SNOOZE (3D)'),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Close
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(ctx, rootNavigator: true).pop();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              child: const Text('CLOSE'),
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
        );
      },
    );
  }

  Widget _metaBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  const _StatCard({
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item['title'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item['value'].toString(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['change'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (item['bgColor'] as Color?) ?? const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  color: (item['color'] as Color?) ?? const Color(0xFF0284C7),
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const TextStyle
    _headerTextStyle =
    TextStyle(
  fontSize: 9,
  fontWeight:
      FontWeight.w700,
  color:
      Color(0xFF64748B),
  letterSpacing: 0.4,
);