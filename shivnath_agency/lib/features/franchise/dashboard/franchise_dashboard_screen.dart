import 'package:flutter/material.dart';

import '../../../core/services/InventoryService.dart';
import '../../../core/services/franchise_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/widgets/ai_chatbot_modal.dart';
import '../../../core/widgets/support_desk_modal.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';
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
  final FranchiseService _franchiseService = FranchiseService();
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

  @override
  void initState() {
    super.initState();
    _loadSession();
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
    final res = await _franchiseService.getDashboardStats();
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
        final batchRes = await InventoryService().getDealerBatches();
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
      await _sessionService.logout();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.roleSelection,
        (_) => false,
      );
    }
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
              final isNarrow = constraints.maxWidth < 600;
              final crossAxisCount = isNarrow ? 2 : (desktop ? 4 : 3);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: isNarrow ? 2.3 : 2.7,
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

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: desktop ? 4 : 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: desktop ? 2.1 : 1.15,
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
                    ),

                    const SizedBox(height: 22),

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
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
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

    return Container(
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
