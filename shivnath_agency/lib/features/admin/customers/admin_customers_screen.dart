import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/repositories/customer_repository.dart';
import '../../../core/utils/app_toast.dart';
import 'admin_customer_detail_screen.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final CustomerRepository _customerRepo = CustomerRepository();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic> _summary = {
    'total_customers': 0,
    'active_customers': 0,
    'total_orders': 0,
    'total_revenue': 0.0,
  };

  // Pagination State
  int _currentPage = 1;
  final int _pageSize = 20;
  int _totalCount = 0;
  int _totalPages = 1;

  // Filters State
  String _statusFilter = 'All';
  String _zoneFilter = '';
  String _franchiseFilter = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _currentPage = 1;
      });
      _loadCustomers();
    });
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _customerRepo.getCustomers(
      search: _searchController.text.trim(),
      status: _statusFilter,
      zone: _zoneFilter,
      franchise: _franchiseFilter,
      page: _currentPage,
      pageSize: _pageSize,
    );

    if (!mounted) return;

    if (res['success'] == true && res['data'] is Map) {
      final data = Map<String, dynamic>.from(res['data']);
      final results = data['results'] as List? ?? [];

      setState(() {
        _isLoading = false;
        _totalCount = data['count'] is int ? data['count'] as int : int.tryParse('${data['count']}') ?? 0;
        _totalPages = data['total_pages'] is int ? data['total_pages'] as int : int.tryParse('${data['total_pages']}') ?? 1;
        _currentPage = data['page'] is int ? data['page'] as int : _currentPage;
        if (data['summary'] is Map) {
          _summary = Map<String, dynamic>.from(data['summary']);
        }
        _customers = results.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res['message']?.toString() ?? 'Unable to load customers.';
      });
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

  void _openCustomerDetail(Map<String, dynamic> customer) {
    final customerId = customer['id'] is int ? customer['id'] as int : int.tryParse('${customer['id']}') ?? 0;
    final customerName = customer['name']?.toString() ?? 'Customer';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCustomerDetailScreen(
          customerId: customerId,
          customerName: customerName,
        ),
      ),
    ).then((_) => _loadCustomers());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 950;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF5F7FB),
          child: RefreshIndicator(
            onRefresh: () async {
              _currentPage = 1;
              await _loadCustomers();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(desktop ? 28 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1350),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(desktop),
                      const SizedBox(height: 20),
                      _buildKpiCards(desktop),
                      const SizedBox(height: 20),
                      _buildToolbar(desktop),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        _buildLoading()
                      else if (_errorMessage != null)
                        _buildError()
                      else if (_customers.isEmpty)
                        _buildEmpty()
                      else ...[
                        desktop ? _buildDesktopTable() : _buildMobileCards(),
                        const SizedBox(height: 16),
                        _buildPaginationBar(desktop),
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

  Widget _buildHeader(bool desktop) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer CRM',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Authoritative customer directory, franchise attribution, territory mapping & lifetime value',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _loadCustomers,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCards(bool desktop) {
    final totalCustomers = _summary['total_customers'] ?? 0;
    final activeCustomers = _summary['active_customers'] ?? 0;
    final totalOrders = _summary['total_orders'] ?? 0;
    final totalRevenue = (_summary['total_revenue'] as num?)?.toDouble() ?? 0.0;

    final cards = [
      _kpiCard(
        title: 'Total Customers',
        value: totalCustomers.toString(),
        icon: Icons.groups_outlined,
        color: const Color(0xFF0284C7),
        subtitle: 'Registered consumer accounts',
      ),
      _kpiCard(
        title: 'Active Accounts',
        value: activeCustomers.toString(),
        icon: Icons.verified_user_outlined,
        color: const Color(0xFF10B981),
        subtitle: 'Verified & active service',
      ),
      _kpiCard(
        title: 'Total Orders Placed',
        value: totalOrders.toString(),
        icon: Icons.shopping_bag_outlined,
        color: const Color(0xFF8B5CF6),
        subtitle: 'Across all channels & dealers',
      ),
      _kpiCard(
        title: 'Total CRM Spend',
        value: '₹${totalRevenue.toStringAsFixed(2)}',
        icon: Icons.currency_rupee,
        color: const Color(0xFFF59E0B),
        subtitle: 'Customer lifetime gross revenue',
      ),
    ];

    if (desktop) {
      return Row(
        children: cards
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: c,
                  ),
                ))
            .toList(),
      );
    }

    return Column(
      children: cards
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: c,
              ))
          .toList(),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool desktop) {
    return Container(
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
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by Customer name, phone, email, CUST-ID, city, district...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _statusFilter = val;
                          _currentPage = 1;
                        });
                        _loadCustomers();
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('Status: All')),
                      DropdownMenuItem(value: 'active', child: Text('Active Only')),
                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                      DropdownMenuItem(value: 'hold', child: Text('On Hold')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 44),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'An error occurred while loading customers.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadCustomers,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, color: Color(0xFF94A3B8), size: 48),
          const SizedBox(height: 12),
          const Text(
            'No customers match the current filters.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try clearing your search term or selecting another status filter.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _statusFilter = 'All';
                _zoneFilter = '';
                _franchiseFilter = '';
                _currentPage = 1;
              });
              _loadCustomers();
            },
            child: const Text('Reset All Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.2), // Customer Info & Code
            1: FlexColumnWidth(1.8), // Contact & Phone
            2: FlexColumnWidth(1.6), // Zone & Location
            3: FlexColumnWidth(2.2), // Franchise Attribution
            4: FlexColumnWidth(1.8), // Orders & Lifetime Spend
            5: FlexColumnWidth(1.2), // Status
            6: FlexColumnWidth(1.2), // Actions
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              children: [
                _th('Customer'),
                _th('Contact'),
                _th('Territory / Zone'),
                _th('Dealer Attribution'),
                _th('Orders & Value'),
                _th('Status'),
                _th('Action', align: TextAlign.right),
              ],
            ),
            ..._customers.map((c) => _tableRow(c)),
          ],
        ),
      ),
    );
  }

  Widget _th(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  TableRow _tableRow(Map<String, dynamic> c) {
    final metrics = (c['metrics'] as Map?) ?? {};
    final totalOrders = metrics['total_orders'] ?? 0;
    final totalSpent = (metrics['total_spent'] as num?)?.toDouble() ?? 0.0;
    final regFranchise = c['registered_franchise'] as Map?;
    final servingFranchise = c['current_serving_franchise'] as Map?;
    final zone = c['zone'] as Map?;

    final status = c['status']?.toString() ?? 'Active';
    Color statusBg = const Color(0xFFDCFCE7);
    Color statusFg = const Color(0xFF15803D);
    if (status.toLowerCase().contains('hold')) {
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFFB45309);
    } else if (status.toLowerCase().contains('inactive')) {
      statusBg = const Color(0xFFFEE2E2);
      statusFg = const Color(0xFFB91C1C);
    }

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      children: [
        // Customer
        InkWell(
          onTap: () => _openCustomerDetail(c),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['name']?.toString() ?? 'Customer',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        c['customer_code']?.toString() ?? 'CUST',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Joined: ${c['date_joined_formatted'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Contact
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _makePhoneCall(c['phone']?.toString() ?? ''),
                    child: Text(
                      c['phone']?.toString() ?? 'No phone',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              if (c['email']?.toString().isNotEmpty == true) ...[
                const SizedBox(height: 3),
                Text(
                  c['email']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),
        ),

        // Territory / Zone
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  zone?['name']?.toString() ?? 'No Zone',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0369A1),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${c['city'] ?? ''}${c['district'] != null && c['district'] != '' ? ', ${c['district']}' : ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),

        // Franchise Attribution
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (servingFranchise != null)
                Row(
                  children: [
                    const Icon(Icons.storefront, size: 14, color: Color(0xFF0D9488)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Serving: ${servingFranchise['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: const [
                    Icon(Icons.factory_outlined, size: 14, color: Color(0xFF6366F1)),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Direct Central Plant',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4338CA)),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 3),
              if (regFranchise != null)
                Text(
                  'Origin Dealer: ${regFranchise['name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
            ],
          ),
        ),

        // Orders & Value
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$totalOrders orders placed',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 3),
              Text(
                '₹${totalSpent.toStringAsFixed(2)} spent',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
              ),
            ],
          ),
        ),

        // Status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusFg,
                ),
              ),
            ),
          ),
        ),

        // Action
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => _openCustomerDetail(c),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                side: const BorderSide(color: Color(0xFF0284C7)),
              ),
              child: const Text('View Profile', style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCards() {
    return Column(
      children: _customers.map((c) {
        final metrics = (c['metrics'] as Map?) ?? {};
        final totalOrders = metrics['total_orders'] ?? 0;
        final totalSpent = (metrics['total_spent'] as num?)?.toDouble() ?? 0.0;
        final regFranchise = c['registered_franchise'] as Map?;
        final servingFranchise = c['current_serving_franchise'] as Map?;
        final zone = c['zone'] as Map?;

        final status = c['status']?.toString() ?? 'Active';
        Color statusBg = const Color(0xFFDCFCE7);
        Color statusFg = const Color(0xFF15803D);
        if (status.toLowerCase().contains('hold')) {
          statusBg = const Color(0xFFFEF3C7);
          statusFg = const Color(0xFFB45309);
        } else if (status.toLowerCase().contains('inactive')) {
          statusBg = const Color(0xFFFEE2E2);
          statusFg = const Color(0xFFB91C1C);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name']?.toString() ?? 'Customer',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                c['customer_code']?.toString() ?? 'CUST',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Joined: ${c['date_joined_formatted'] ?? ''}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusFg),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _makePhoneCall(c['phone']?.toString() ?? ''),
                    child: Text(
                      c['phone']?.toString() ?? 'No phone',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      zone?['name']?.toString() ?? 'No Zone',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0369A1)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (servingFranchise != null)
                Text(
                  'Serving Dealer: ${servingFranchise['name']}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                )
              else
                const Text(
                  'Fulfillment: Direct Central Plant',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4338CA)),
                ),
              if (regFranchise != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Registered Origin: ${regFranchise['name']}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalOrders Orders',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        '₹${totalSpent.toStringAsFixed(2)} Spent',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => _openCustomerDetail(c),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('View Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaginationBar(bool desktop) {
    final start = (_currentPage - 1) * _pageSize + 1;
    final end = (_currentPage * _pageSize) > _totalCount ? _totalCount : (_currentPage * _pageSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $start to $end of $_totalCount customers',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _loadCustomers();
                      }
                    : null,
              ),
              Text(
                'Page $_currentPage of $_totalPages',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _loadCustomers();
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
