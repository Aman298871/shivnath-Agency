import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/stock_service.dart';

class AdminStockManagementScreen extends StatefulWidget {
  const AdminStockManagementScreen({super.key});

  @override
  State<AdminStockManagementScreen> createState() =>
      _AdminStockManagementScreenState();
}

class _AdminStockManagementScreenState
    extends State<AdminStockManagementScreen> {
  final StockService _stockService = StockService();

  bool _isLoading = true;
  String _selectedFilter =
      'all'; // all, active, low_stock, expiring_7_days, expired, held
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _stocks = [];
  Map<String, dynamic> _metrics = {
    'total_stocks': 0,
    'active_stocks': 0,
    'low_stock_alerts': 0,
    'expiring_in_7_days': 0,
    'expired_stocks': 0,
    'held_stocks': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchStocks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStocks() async {
    setState(() => _isLoading = true);

    final res = await _stockService.getAdminStocks(
      filter: _selectedFilter,
      search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
    );

    if (!mounted) return;

    if (res['success'] == true && res['data'] is Map<String, dynamic>) {
      final data = res['data'] as Map<String, dynamic>;
      final list = data['stocks'] as List? ?? [];
      final metrics = data['metrics'] as Map<String, dynamic>? ?? {};

      setState(() {
        _stocks = List<Map<String, dynamic>>.from(list);
        _metrics = metrics;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showHoldHistoryDialog(Map<String, dynamic> stock) {
    final holdHistory = stock['hold_history'] as List? ?? [];
    final customer = stock['customer'] as Map<String, dynamic>? ?? {};
    final custName = customer['name']?.toString() ?? 'Customer';
    final prodName = stock['product_name'] ?? 'Product';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.history_toggle_off_rounded,
                  color: Color(0xFF9333EA),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Service Hold / Resume Audit Log',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$custName • $prodName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (holdHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No hold or pause events recorded for this stock cycle.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 350),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: holdHistory.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = holdHistory[i] as Map<String, dynamic>;
                    final action = item['action']?.toString() ?? '';
                    final isHold = action == 'hold';
                    final reason =
                        item['reason']?.toString() ?? 'No reason provided';
                    final remainingDays = item['remaining_days'];
                    final createdAt = item['created_at']?.toString() ?? '';
                    final actorName =
                        item['actor_name']?.toString() ?? 'System';
                    final actorRole = item['actor_role']?.toString() ?? '';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isHold
                            ? const Color(0xFFFDF2F8)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isHold
                              ? const Color(0xFFFBCFE8)
                              : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isHold
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_fill,
                                    size: 16,
                                    color: isHold
                                        ? const Color(0xFFBE185D)
                                        : const Color(0xFF15803D),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    action.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: isHold
                                          ? const Color(0xFFBE185D)
                                          : const Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ),
                              if (remainingDays != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$remainingDays days preserved',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Reason: $reason',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'By $actorName ($actorRole) on $createdAt',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status, bool isLowStock) {
    if (status == 'hold') return const Color(0xFF9333EA);
    if (status == 'expired') return const Color(0xFFDC2626);
    if (isLowStock) return const Color(0xFFD97706);
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text(
          'Stock Management & Monitoring',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchStocks),
        ],
      ),
      body: Column(
        children: [
          // Metric cards summary
          _buildMetricsBar(),

          // Filter bar
          _buildFilterChips(),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    'Search by customer, product, order #, or franchise...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _fetchStocks();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              onSubmitted: (val) {
                setState(() => _searchQuery = val);
                _fetchStocks();
              },
            ),
          ),

          // Main list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                  )
                : _stocks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 54,
                            color: Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No stock cycles found for filter "$_selectedFilter"',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchStocks,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: _stocks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _buildStockCard(_stocks[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _metricItem(
              'Total Stocks',
              '${_metrics['total_stocks'] ?? 0}',
              Icons.inventory_2_rounded,
              const Color(0xFF0284C7),
            ),
            const SizedBox(width: 10),
            _metricItem(
              'Active',
              '${_metrics['active_stocks'] ?? 0}',
              Icons.check_circle_rounded,
              const Color(0xFF16A34A),
            ),
            const SizedBox(width: 10),
            _metricItem(
              'Low Stock (≤7d)',
              '${_metrics['low_stock_alerts'] ?? 0}',
              Icons.warning_amber_rounded,
              const Color(0xFFD97706),
            ),
            const SizedBox(width: 10),
            _metricItem(
              'Expiring in 7d',
              '${_metrics['expiring_in_7_days'] ?? 0}',
              Icons.timer_outlined,
              const Color(0xFFEA580C),
            ),
            const SizedBox(width: 10),
            _metricItem(
              'On Hold',
              '${_metrics['held_stocks'] ?? 0}',
              Icons.pause_circle_filled,
              const Color(0xFF9333EA),
            ),
            const SizedBox(width: 10),
            _metricItem(
              'Expired',
              '${_metrics['expired_stocks'] ?? 0}',
              Icons.cancel_rounded,
              const Color(0xFFDC2626),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                val,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip('all', 'All'),
            const SizedBox(width: 8),
            _chip('active', 'Active'),
            const SizedBox(width: 8),
            _chip('low_stock', '⚠️ Low Stock (≤ 7 Days)'),
            const SizedBox(width: 8),
            _chip('expiring_7_days', 'Expiring Soon'),
            const SizedBox(width: 8),
            _chip('held', 'On Hold'),
            const SizedBox(width: 8),
            _chip('expired', 'Expired'),
          ],
        ),
      ),
    );
  }

  Widget _chip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 11,
        ),
      ),
      selectedColor: const Color(0xFF0284C7),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedFilter = key);
          _fetchStocks();
        }
      },
    );
  }

  Widget _buildStockCard(Map<String, dynamic> stock) {
    final customer = stock['customer'] as Map<String, dynamic>? ?? {};
    final custName = customer['name']?.toString() ?? 'Customer';
    final custPhone = customer['phone']?.toString() ?? '';
    final custCode =
        customer['customer_code']?.toString() ?? 'CUST-${customer['id']}';

    final productName = stock['product_name'] ?? 'Pure Drinking Water';
    final variantSize = stock['variant_size'] ?? '';
    final quantity = stock['quantity'] ?? 1;
    final orderNumber = stock['order_number'] ?? 'N/A';
    final durationChoice = stock['duration_choice'] ?? '';
    final durationDays = stock['duration_days'] ?? 30;
    final startDate = stock['start_date'] ?? '';
    final expectedEndDate = stock['expected_end_date'] ?? '';
    final daysRemaining = stock['days_remaining'] ?? 0;
    final isLowStock = stock['is_low_stock'] == true;
    final status = stock['service_status'] ?? 'active';

    final servingFranchise =
        stock['serving_franchise'] as Map<String, dynamic>?;
    final registeredFranchise =
        stock['registered_franchise'] as Map<String, dynamic>?;
    final territory = stock['territory'] as Map<String, dynamic>?;
    final holdHistory = stock['hold_history'] as List? ?? [];

    final statusColor = _getStatusColor(status, isLowStock);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLowStock && status != 'hold'
              ? const Color(0xFFF59E0B)
              : const Color(0xFFE5E7EB),
          width: isLowStock && status != 'hold' ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Customer + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE0F2FE),
                child: Text(
                  custName.isNotEmpty ? custName[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      custName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$custCode • $custPhone',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status == 'hold'
                      ? 'ON HOLD'
                      : isLowStock
                      ? '$daysRemaining DAYS LEFT'
                      : status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Product & Order info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$productName ($variantSize) x $quantity',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$daysRemaining Days Left',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order: $orderNumber',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      durationChoice.isNotEmpty
                          ? durationChoice.toUpperCase()
                          : '$durationDays Days',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Started: $startDate',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      'Expected: $expectedEndDate',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Territory & Franchise Mapping
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 14,
                color: Color(0xFF0284C7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Serving: ${servingFranchise?['business_name'] ?? servingFranchise?['name'] ?? 'Franchise'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              if (servingFranchise?['phone'] != null)
                InkWell(
                  onTap: () =>
                      _callPhone(servingFranchise!['phone']?.toString()),
                  child: const Icon(
                    Icons.phone,
                    size: 14,
                    color: Color(0xFF0284C7),
                  ),
                ),
            ],
          ),
          if (registeredFranchise != null &&
              registeredFranchise['id'] != servingFranchise?['id']) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Registered: ${registeredFranchise['business_name'] ?? registeredFranchise['name'] ?? 'Franchise'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (territory != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Zone: ${territory['zone'] ?? ''}, ${territory['district'] ?? ''} (${territory['pincode'] ?? ''})',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (holdHistory.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _showHoldHistoryDialog(stock),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_toggle_off_rounded,
                    size: 14,
                    color: Color(0xFF9333EA),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'View Hold History (${holdHistory.length} events)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9333EA),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: Color(0xFF9333EA),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
