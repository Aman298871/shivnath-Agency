import 'package:flutter/material.dart';

import '../../../core/services/franchise_service.dart';

class AdminFranchiseDetailScreen extends StatefulWidget {
  final int franchiseId;
  final String franchiseName;

  const AdminFranchiseDetailScreen({
    super.key,
    required this.franchiseId,
    required this.franchiseName,
  });

  @override
  State<AdminFranchiseDetailScreen> createState() =>
      _AdminFranchiseDetailScreenState();
}

class _AdminFranchiseDetailScreenState extends State<AdminFranchiseDetailScreen>
    with SingleTickerProviderStateMixin {
  final FranchiseService _franchiseService = FranchiseService();
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? detailData;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final res = await _franchiseService.getFranchiseDetail(widget.franchiseId);
    if (!mounted) return;

    if (res['success'] == true && res['data'] is Map) {
      setState(() {
        isLoading = false;
        detailData = Map<String, dynamic>.from(res['data']);
      });
    } else {
      setState(() {
        isLoading = false;
        errorMessage =
            res['message']?.toString() ?? 'Unable to load franchise details.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.franchiseName),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetail,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(errorMessage!, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadDetail,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final franchise = detailData?['franchise'] as Map? ?? {};
    final summary = detailData?['summary'] as Map? ?? {};
    final servedCustomers = (detailData?['served_customers'] as List? ?? []);
    final registeredCustomers =
        (detailData?['registered_customers'] as List? ?? []);
    final orders = (detailData?['orders'] as List? ?? []);
    final stockCycles = (detailData?['stock_cycles'] as List? ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Franchise Overview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Color(0xFF0284C7),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                franchise['business_name']?.toString() ??
                                    widget.franchiseName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: franchise['status'] == 'approved'
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (franchise['status']?.toString() ?? 'Pending')
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: franchise['status'] == 'approved'
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Owner: ${franchise['owner_name'] ?? 'N/A'} • Territory: ${franchise['territory'] ?? 'Unassigned'} • City: ${franchise['city'] ?? ''}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Phone: ${franchise['phone'] ?? 'N/A'} • Email: ${franchise['email'] ?? 'N/A'}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 4 Summary Metrics (Highlighting Registered vs Serving separation!)
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      title: 'Customers Served',
                      value:
                          '${summary['customers_served_count'] ?? servedCustomers.length}',
                      subtitle: 'Currently fulfilling orders',
                      icon: Icons.local_shipping_outlined,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metricCard(
                      title: 'Registered Cust.',
                      value:
                          '${summary['registered_customers_count'] ?? registeredCustomers.length}',
                      subtitle: 'Direct registration',
                      icon: Icons.how_to_reg_outlined,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metricCard(
                      title: 'Total Orders',
                      value:
                          '${summary['total_orders_count'] ?? orders.length}',
                      subtitle: 'Historical orders fulfilled',
                      icon: Icons.shopping_bag_outlined,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metricCard(
                      title: 'Stock Cycles',
                      value: '${stockCycles.length}',
                      subtitle: 'Customer jar inventory',
                      icon: Icons.water_drop_outlined,
                      color: const Color(0xFF9333EA),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF0284C7),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF0284C7),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.people_outline_rounded, size: 18),
                      text: 'Customers (Served vs Registered)',
                    ),
                    Tab(
                      icon: Icon(Icons.receipt_long_rounded, size: 18),
                      text: 'Orders & Stock Cycles',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tab Views
              SizedBox(
                height: 500,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCustomersTab(servedCustomers, registeredCustomers),
                    _buildOrdersTab(orders, stockCycles),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersTab(
    List<dynamic> servedList,
    List<dynamic> registeredList,
  ) {
    if (servedList.isEmpty && registeredList.isEmpty) {
      return const Center(
        child: Text('No customers associated with this franchise yet.'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: servedList.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (ctx, index) {
          final c = servedList[index] as Map? ?? {};
          final isRegisteredToThis = registeredList.any(
            (r) => r['id'] == c['id'],
          );

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE0F2FE),
              child: const Icon(Icons.person_outline, color: Color(0xFF0284C7)),
            ),
            title: Row(
              children: [
                Text(
                  c['name']?.toString() ?? 'Customer',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isRegisteredToThis
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isRegisteredToThis
                        ? 'Registered & Serving'
                        : 'Served (Registered to Other)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isRegisteredToThis
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Phone: ${c['phone'] ?? ''} • Territory: ${c['territory'] ?? 'Default'} • Orders: ${c['orders_count'] ?? 0}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            trailing: Text(
              '${c['active_stock'] ?? 0} active jars',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0284C7),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrdersTab(List<dynamic> orders, List<dynamic> stockCycles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: orders.isEmpty
          ? const Center(
              child: Text('No order records fulfilled by this franchise yet.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, index) {
                final o = orders[index] as Map? ?? {};
                return ListTile(
                  leading: const Icon(
                    Icons.receipt_outlined,
                    color: Color(0xFF64748B),
                  ),
                  title: Text(
                    'Order #${o['id']} • Customer: ${o['customer_name'] ?? 'Direct Customer'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    'Items: ${o['items']} • Status: ${o['status']} • Date: ${o['created_at'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  trailing: Text(
                    '₹${o['amount'] ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
