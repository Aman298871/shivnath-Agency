import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/followup_service.dart';
import '../../../core/services/lead_service.dart';
import '../../../core/services/InventoryService.dart';
import '../../../core/services/OrderService.dart';
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
  final InventoryService _inventoryService = InventoryService();
  final OrderService _orderService = OrderService();

  List<Map<String, dynamic>> _pendingStockAlerts = [];
  bool _pendingStockDialogShown = false;

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

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final leadStatsResult = await _leadService.getLeadStats();
      final fuStatsResult = await _followupService.getStats();
      final leadsResult = await _leadService.getLeads();
      final fuResult = await _followupService.getFollowups();

      int ordersCount = 0;
      try {
        final orderRes = await _orderService.getOrders();
        if (orderRes['success'] == true) {
          final dynamic ordData = orderRes['data'];
          if (ordData is List) {
            ordersCount = ordData.length;
          } else if (ordData is Map && ordData['orders'] is List) {
            ordersCount = (ordData['orders'] as List).length;
          }
        }
      } catch (_) {}

      int franchiseReqCount = 0;
      try {
        final reqRes = await _inventoryService.getDealerStockRequests();
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
  }

  Future<void> _loadPendingStockAlerts() async {
    try {
      final res = await _inventoryService.getPendingStockExpiryAlerts();
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

                  const SizedBox(
                    height: 24,
                  ),

                  _statsSection(
                    desktop,
                  ),

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
          return widget.onOpenOrders;
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.02,
      ),
      itemCount: _stats.length,
      itemBuilder: (_, index) {
        return _StatCard(
          item: _stats[index],
          onTap: getTapAction(index),
        );
      },
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
              final isNarrow = constraints.maxWidth < 600;
              final crossAxisCount = isNarrow ? 2 : (desktop ? 4 : 4);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isNarrow ? 2.4 : 2.8,
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
                                    await _inventoryService.actionPendingStockExpiryAlert(
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
                                    await _inventoryService.actionPendingStockExpiryAlert(
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