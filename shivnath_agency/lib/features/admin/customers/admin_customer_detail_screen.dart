import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/repositories/customer_repository.dart';
import '../../../core/utils/app_toast.dart';
import '../../customer/orders/order_detail_screen.dart';

class AdminCustomerDetailScreen extends StatefulWidget {
  final int customerId;
  final String customerName;

  const AdminCustomerDetailScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<AdminCustomerDetailScreen> createState() => _AdminCustomerDetailScreenState();
}

class _AdminCustomerDetailScreenState extends State<AdminCustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  final CustomerRepository _customerRepo = CustomerRepository();

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _customerData;
  Map<String, dynamic>? _statistics;
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _ordersPagination;

  int _ordersPage = 1;
  final int _ordersPageSize = 10;
  bool _loadingOrders = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _customerRepo.getCustomerDetail(
      widget.customerId,
      page: _ordersPage,
      pageSize: _ordersPageSize,
    );

    if (!mounted) return;

    if (res['success'] == true && res['data'] is Map) {
      final data = Map<String, dynamic>.from(res['data']);
      final ordersMap = data['orders'] as Map? ?? {};
      final ordersList = ordersMap['results'] as List? ?? [];

      setState(() {
        _isLoading = false;
        _customerData = data['customer'] is Map ? Map<String, dynamic>.from(data['customer']) : null;
        _statistics = data['statistics'] is Map ? Map<String, dynamic>.from(data['statistics']) : null;
        _orders = ordersList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _ordersPagination = {
          'count': ordersMap['count'] ?? 0,
          'total_pages': ordersMap['total_pages'] ?? 1,
          'page': ordersMap['page'] ?? 1,
          'page_size': ordersMap['page_size'] ?? _ordersPageSize,
        };
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res['message']?.toString() ?? 'Unable to load customer profile.';
      });
    }
  }

  Future<void> _changeOrdersPage(int newPage) async {
    setState(() {
      _ordersPage = newPage;
      _loadingOrders = true;
    });

    final res = await _customerRepo.getCustomerDetail(
      widget.customerId,
      page: _ordersPage,
      pageSize: _ordersPageSize,
    );

    if (!mounted) return;

    if (res['success'] == true && res['data'] is Map) {
      final data = Map<String, dynamic>.from(res['data']);
      final ordersMap = data['orders'] as Map? ?? {};
      final ordersList = ordersMap['results'] as List? ?? [];

      setState(() {
        _loadingOrders = false;
        _orders = ordersList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _ordersPagination = {
          'count': ordersMap['count'] ?? 0,
          'total_pages': ordersMap['total_pages'] ?? 1,
          'page': ordersMap['page'] ?? 1,
          'page_size': ordersMap['page_size'] ?? _ordersPageSize,
        };
      });
    } else {
      setState(() => _loadingOrders = false);
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      AppToast.info(context, 'No phone number available.');
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) AppToast.error(context, 'Could not launch dialer.');
    }
  }

  Future<void> _sendEmail(String email) async {
    if (email.isEmpty) return;
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _customerData?['name']?.toString() ?? widget.customerName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: _loadDetail,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildContentView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to load customer details.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF7F1D1D)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadDetail, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView() {
    final cust = _customerData ?? {};
    final stats = _statistics ?? {};
    final wallet = cust['wallet'] as Map? ?? {};

    return Column(
      children: [
        // Top Profile Summary Header Card
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFE0F2FE),
                    child: Text(
                      (cust['name']?.toString().isNotEmpty == true)
                          ? cust['name'].toString().substring(0, 1).toUpperCase()
                          : 'C',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0284C7),
                      ),
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
                              cust['name']?.toString() ?? 'Customer',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                cust['customer_code']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Joined: ${cust['date_joined_formatted'] ?? ''}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (cust['phone']?.toString().isNotEmpty == true)
                        IconButton.filledTonal(
                          icon: const Icon(Icons.phone, size: 18),
                          onPressed: () => _makePhoneCall(cust['phone'].toString()),
                        ),
                      if (cust['email']?.toString().isNotEmpty == true) ...[
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.email, size: 18),
                          onPressed: () => _sendEmail(cust['email'].toString()),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // KPI Metric Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _miniStat('Total Orders', '${stats['total_orders'] ?? 0}', Icons.shopping_bag_outlined, const Color(0xFF0284C7)),
                    _miniStat('Delivered', '${stats['delivered_orders'] ?? 0}', Icons.check_circle_outline, const Color(0xFF10B981)),
                    _miniStat('Pending', '${stats['pending_orders'] ?? 0}', Icons.hourglass_top_outlined, const Color(0xFFF59E0B)),
                    _miniStat('Cancelled', '${stats['cancelled_orders'] ?? 0}', Icons.cancel_outlined, const Color(0xFFEF4444)),
                    _miniStat('Lifetime Spend', '₹${(stats['lifetime_spend'] as num?)?.toStringAsFixed(2) ?? '0.00'}', Icons.currency_rupee, const Color(0xFF6366F1)),
                    _miniStat('Wallet Balance', '₹${(wallet['balance'] as num?)?.toStringAsFixed(2) ?? '0.00'}', Icons.account_balance_wallet_outlined, const Color(0xFF0D9488)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tabs Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0284C7),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF0284C7),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'Profile & Attribution'),
              Tab(text: 'Order History'),
              Tab(text: 'Financials & Insights'),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProfileTab(cust),
              _buildOrdersTab(),
              _buildFinancialsTab(stats),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: PROFILE & FRANCHISE ATTRIBUTION
  // =========================================================================
  Widget _buildProfileTab(Map<String, dynamic> cust) {
    final attribution = cust['attribution'] as Map? ?? {};
    final regFranchise = attribution['registered_franchise'] as Map?;
    final servingFranchise = attribution['current_serving_franchise'] as Map?;
    final zone = cust['zone'] as Map? ?? {};
    final gst = cust['gst_profile'] as Map? ?? {};
    final cycles = cust['stock_cycles'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact & Personal Details Card
              _sectionCard(
                title: 'Contact & Account Details',
                icon: Icons.person_outline,
                children: [
                  _infoRow('Full Name', cust['name']?.toString() ?? 'N/A'),
                  _infoRow('Username', cust['username']?.toString() ?? 'N/A'),
                  _infoRow('Phone', cust['phone']?.toString() ?? 'N/A'),
                  _infoRow('Email', cust['email']?.toString() ?? 'N/A'),
                  _infoRow('Account Status', cust['status']?.toString() ?? 'Active'),
                  _infoRow('Registration Date', cust['date_joined_formatted']?.toString() ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 16),

              // Territory & Address Card
              _sectionCard(
                title: 'Territory & Address Information',
                icon: Icons.map_outlined,
                children: [
                  _infoRow('Zone', zone['name']?.toString() ?? 'Unassigned'),
                  _infoRow('Zone Code', zone['code']?.toString() ?? 'N/A'),
                  _infoRow('Street Address', cust['address']?.toString() ?? 'N/A'),
                  _infoRow('Locality', cust['locality']?.toString() ?? 'N/A'),
                  _infoRow('City', cust['city']?.toString() ?? 'N/A'),
                  _infoRow('District', cust['district']?.toString() ?? 'N/A'),
                  _infoRow('Pincode', cust['pincode']?.toString() ?? 'N/A'),
                  _infoRow('Territory', cust['territory']?.toString() ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 16),

              // Dealer / Franchise Attribution Card
              _sectionCard(
                title: 'Dealer & Franchise Attribution',
                icon: Icons.storefront_outlined,
                children: [
                  _infoRow(
                    'Registered Origin Dealer',
                    regFranchise != null
                        ? '${regFranchise['name']} (${regFranchise['city'] ?? ''}) - ${regFranchise['phone'] ?? ''}'
                        : 'Direct Company Registered (Shivnath Agency Central)',
                  ),
                  _infoRow(
                    'Current Serving Dealer',
                    servingFranchise != null
                        ? '${servingFranchise['name']} (${servingFranchise['city'] ?? ''}) - ${servingFranchise['phone'] ?? ''}'
                        : 'Direct Central Plant Fulfillment (Shivnath Agency)',
                  ),
                  _infoRow('Service Status', attribution['service_status']?.toString().toUpperCase() ?? 'ACTIVE'),
                ],
              ),
              const SizedBox(height: 16),

              // GST Billing Profile
              _sectionCard(
                title: 'GST & Commercial Profile',
                icon: Icons.receipt_long_outlined,
                children: [
                  _infoRow('GSTIN', gst['gstin']?.toString().isNotEmpty == true ? gst['gstin'].toString() : 'Not Provided'),
                  _infoRow('Legal Entity Name', gst['legal_name']?.toString() ?? 'N/A'),
                  _infoRow('GST Billing Address', gst['billing_address']?.toString() ?? 'N/A'),
                  _infoRow('State', gst['state_name']?.toString() ?? 'Chhattisgarh'),
                  _infoRow('GST Pincode', gst['pincode']?.toString() ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 16),

              // Active Stock Cycles
              _sectionCard(
                title: 'Active Water Stock Cycles',
                icon: Icons.repeat_rounded,
                children: [
                  if (cycles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No active recurring water consumption cycles registered.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    )
                  else
                    ...cycles.map((c) {
                      final item = Map<String, dynamic>.from(c as Map);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.water_drop, color: Color(0xFF0284C7)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item['product_name']} - Qty: ${item['quantity']}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  Text(
                                    'Duration: ${item['duration_days']} days (Ends: ${item['expected_end_date']})',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (item['is_low_stock'] == true) ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${item['days_remaining']} days left',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: (item['is_low_stock'] == true) ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: PAGINATED ORDER HISTORY
  // =========================================================================
  Widget _buildOrdersTab() {
    if (_loadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 12),
              Text(
                'No orders placed by this customer yet.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      );
    }

    final totalPages = _ordersPagination?['total_pages'] ?? 1;
    final totalCount = _ordersPagination?['count'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              ..._orders.map((o) => _orderCard(o)),
              const SizedBox(height: 16),
              // Pagination Controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: $totalCount orders',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _ordersPage > 1 ? () => _changeOrdersPage(_ordersPage - 1) : null,
                        ),
                        Text(
                          'Page $_ordersPage of $totalPages',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _ordersPage < totalPages ? () => _changeOrdersPage(_ordersPage + 1) : null,
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

  Widget _orderCard(Map<String, dynamic> o) {
    final status = o['status']?.toString() ?? 'pending';
    final orderSource = o['order_source']?.toString() ?? 'FRANCHISE';
    final serving = o['serving_franchise'] as Map?;
    final items = o['items'] as List? ?? [];
    final grandTotal = (o['grand_total'] as num?)?.toDouble() ?? 0.0;
    final paymentStatus = o['payment_status']?.toString() ?? 'Pending';

    Color statusColor = const Color(0xFF0284C7);
    if (status.toLowerCase() == 'delivered') {
      statusColor = const Color(0xFF16A34A);
    } else if (status.toLowerCase() == 'cancelled') {
      statusColor = const Color(0xFFDC2626);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    o['order_code']?.toString() ?? 'ORD-${o['id']}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    o['order_date']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      o['status_display']?.toString() ?? status.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Payment: $paymentStatus',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fulfillment Attribution Badge
          Row(
            children: [
              if (orderSource == 'DIRECT_COMPANY' || serving == null)
                const Text(
                  'Fulfillment: Direct Central Plant (Shivnath Agency)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4338CA)),
                )
              else
                Text(
                  'Fulfillment: Dealer ${serving['name']} (${serving['city'] ?? ''})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          // Items Summary
          ...items.map((it) {
            final itemMap = Map<String, dynamic>.from(it as Map);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${itemMap['product_name']} (${itemMap['size'] ?? ''}) × ${itemMap['quantity']}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                  ),
                  Text(
                    '₹${(itemMap['total_price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount: ₹${grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
              ),
              OutlinedButton(
                onPressed: () {
                  final dbId = o['id'] is int ? o['id'] as int : int.tryParse('${o['id']}') ?? 0;
                  final code = o['order_code']?.toString() ?? 'ORD-$dbId';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(
                        orderId: code,
                        initialOrder: o,
                        dbId: dbId,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                ),
                child: const Text('View Full Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: FINANCIALS & LIFETIME STATS
  // =========================================================================
  Widget _buildFinancialsTab(Map<String, dynamic> stats) {
    final lifetimeSpend = (stats['lifetime_spend'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (stats['total_paid'] as num?)?.toDouble() ?? 0.0;
    final outstanding = (stats['outstanding_balance'] as num?)?.toDouble() ?? 0.0;
    final directOrders = stats['direct_orders'] ?? 0;
    final franchiseOrders = stats['franchise_orders'] ?? 0;
    final totalOrders = stats['total_orders'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionCard(
                title: 'Customer Lifetime Financial Summary',
                icon: Icons.account_balance_outlined,
                children: [
                  _infoRow('Lifetime Gross Spend', '₹${lifetimeSpend.toStringAsFixed(2)}'),
                  _infoRow('Total Verified Payments', '₹${totalPaid.toStringAsFixed(2)}'),
                  _infoRow('Outstanding Balance', '₹${outstanding.toStringAsFixed(2)}'),
                  _infoRow('Average Order Value (AOV)', totalOrders > 0 ? '₹${(lifetimeSpend / totalOrders).toStringAsFixed(2)}' : '₹0.00'),
                ],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Order Fulfillment Channels',
                icon: Icons.pie_chart_outline,
                children: [
                  _infoRow('Total Orders Placed', '$totalOrders'),
                  _infoRow('Direct Company Fulfilled', '$directOrders'),
                  _infoRow('Franchise / Dealer Fulfilled', '$franchiseOrders'),
                  _infoRow('First Order Date', stats['first_order_date']?.toString() ?? 'N/A'),
                  _infoRow('Last Order Date', stats['last_order_date']?.toString() ?? 'N/A'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
