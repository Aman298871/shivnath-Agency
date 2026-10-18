import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/repositories/inventory_repository.dart';
import '../../../core/theme/brand_colors.dart';

enum _DateFilter {
  all,
  today,
  yesterday,
  thisWeek,
  thisMonth,
  custom,
}

/// Super Admin & Operations Daily Business Report & P&L Analysis Screen
class DailyPlReportScreen extends StatefulWidget {
  const DailyPlReportScreen({super.key});

  @override
  State<DailyPlReportScreen> createState() => _DailyPlReportScreenState();
}

class _DailyPlReportScreenState extends State<DailyPlReportScreen>
    with SingleTickerProviderStateMixin {
  final InventoryRepository _invService = InventoryRepository();

  bool _loading = false;
  String? _error;

  // Raw API response fields
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _productWise = [];
  List<Map<String, dynamic>> _customerActivity = [];
  List<Map<String, dynamic>> _franchiseActivity = [];

  _DateFilter _selectedFilter = _DateFilter.thisMonth;
  String? _startDate;
  String? _endDate;
  String _customRangeLabel = '';
  String? _period;

  String? _selectedProductSku;
  int? _selectedOrderId;
  String? _selectedOrderCode;
  int? _selectedFranchiseId;
  String? _selectedFranchiseName;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Default to this month
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    _startDate = fmt.format(DateTime(now.year, now.month, 1));
    _endDate = fmt.format(now);
    _loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onFilterSelected(_DateFilter filter) async {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');

    setState(() {
      _selectedFilter = filter;
      _period = null;
    });

    switch (filter) {
      case _DateFilter.all:
        _startDate = null;
        _endDate = null;
        _period = 'all';
        _customRangeLabel = '';
        break;
      case _DateFilter.today:
        _startDate = fmt.format(now);
        _endDate = fmt.format(now);
        _period = 'today';
        _customRangeLabel = '';
        break;
      case _DateFilter.yesterday:
        final yest = now.subtract(const Duration(days: 1));
        _startDate = fmt.format(yest);
        _endDate = fmt.format(yest);
        _period = 'yesterday';
        _customRangeLabel = '';
        break;
      case _DateFilter.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        _startDate = fmt.format(weekStart);
        _endDate = fmt.format(now);
        _period = 'this_week';
        _customRangeLabel = '';
        break;
      case _DateFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        _startDate = fmt.format(monthStart);
        _endDate = fmt.format(now);
        _period = 'this_month';
        _customRangeLabel = '';
        break;
      case _DateFilter.custom:
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2024),
          lastDate: DateTime.now().add(const Duration(days: 1)),
          initialDateRange: _startDate != null && _endDate != null
              ? DateTimeRange(
                  start: DateTime.parse(_startDate!),
                  end: DateTime.parse(_endDate!),
                )
              : null,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: BrandColors.redDark,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          _startDate = fmt.format(picked.start);
          _endDate = fmt.format(picked.end);
          _customRangeLabel =
              '${DateFormat('dd MMM').format(picked.start)} – ${DateFormat('dd MMM').format(picked.end)}';
        } else {
          return;
        }
        break;
    }

    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _invService.getDailyBusinessReports(
        startDate: _startDate,
        endDate: _endDate,
        period: _period,
        productSku: _selectedProductSku,
        orderId: _selectedOrderId,
        franchiseId: _selectedFranchiseId,
      );

      if (res['success'] == false || res.containsKey('detail')) {
        _error = res['message']?.toString() ?? res['detail']?.toString() ?? 'Failed to load report from server.';
        if (mounted) setState(() => _loading = false);
        return;
      }

      // ── Unpack response payload (InventoryService wraps decoded JSON in res['data'])
      Map<String, dynamic> payload = res;
      if (res['data'] is Map) {
        payload = Map<String, dynamic>.from(res['data'] as Map);
      }

      // ── 1. Parse summary (always present from live computation) ──────────
      if (payload['summary'] is Map) {
        _summary = Map<String, dynamic>.from(payload['summary'] as Map);
      } else if (res['summary'] is Map) {
        _summary = Map<String, dynamic>.from(res['summary'] as Map);
      } else {
        _summary = null;
      }

      // ── 2. Parse reports list (stored DB rows OR synthetic row) ──────────
      List rawList = [];
      if (payload['reports'] is List) {
        rawList = payload['reports'] as List;
      } else if (payload['data'] is List) {
        rawList = payload['data'] as List;
      } else if (res['reports'] is List) {
        rawList = res['reports'] as List;
      } else if (res['data'] is List) {
        rawList = res['data'] as List;
      }
      _reports = rawList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // ── 3. Product-wise breakdown (from payload or first report) ──
      if (payload['product_wise'] is List) {
        _productWise = (payload['product_wise'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (res['product_wise'] is List) {
        _productWise = (res['product_wise'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (_reports.isNotEmpty &&
          _reports.first['product_wise'] is List) {
        _productWise = (_reports.first['product_wise'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _productWise = [];
      }

      // ── 4. Activity logs ──────────────────────────────────────────────────
      final custRaw = payload['customer_activity'] ?? payload['customer_orders'] ?? res['customer_activity'];
      if (custRaw is List) {
        _customerActivity = custRaw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _customerActivity = [];
      }
      final franRaw = payload['franchise_activity'] ?? res['franchise_activity'];
      if (franRaw is List) {
        _franchiseActivity = franRaw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _franchiseActivity = [];
      }
    } catch (e) {
      _error = 'Failed to load P&L report: $e';
    }

    if (mounted) setState(() => _loading = false);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  double _sumVal(String key) {
    // 1. Live-computed summary always takes priority (most accurate)
    if (_summary != null) {
      return double.tryParse(_summary![key]?.toString() ?? '0') ?? 0.0;
    }
    // 2. Sum across all stored daily report rows for the period
    if (_reports.isEmpty) return 0.0;
    // Special additive fields: aggregate across all rows
    const additiveKeys = {
      'gross_revenue', 'cogs', 'total_operating_expenses', 'net_profit_or_loss',
      'direct_company_revenue', 'franchise_revenue', 'gross_profit',
      'total_units_produced', 'total_units_dispatched',
      'total_collected', 'cash_collected', 'online_collected',
      'total_order_amount', 'total_booking_value',
    };
    if (additiveKeys.contains(key)) {
      return _reports.fold(
          0.0,
          (sum, r) =>
              sum + (double.tryParse(r[key]?.toString() ?? '0') ?? 0.0));
    }
    // For non-additive keys (e.g., stock balances), read the latest row
    return double.tryParse(_reports.first[key]?.toString() ?? '0') ?? 0.0;
  }

  int _intVal(String key) {
    if (_summary != null) {
      return int.tryParse(_summary![key]?.toString() ?? '0') ?? 0;
    }
    if (_reports.isEmpty) return 0;
    // Additive int fields: sum across all daily rows
    const additiveIntKeys = {
      'total_units_produced', 'total_units_dispatched',
      'total_orders', 'orders_placed', 'orders_approved',
      'orders_preparing', 'orders_dispatched', 'orders_delivered',
      'orders_cancelled', 'franchise_requests_count', 'new_leads_count',
      'converted_leads_count', 'quantity_sold',
    };
    if (additiveIntKeys.contains(key)) {
      return _reports.fold(
          0,
          (sum, r) =>
              sum + (int.tryParse(r[key]?.toString() ?? '0') ?? 0));
    }
    // Non-additive: latest row
    return int.tryParse(_reports.first[key]?.toString() ?? '0') ?? 0;
  }

  bool get _hasData =>
      _summary != null ||
      _reports.isNotEmpty ||
      _customerActivity.isNotEmpty ||
      _franchiseActivity.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Daily Business & P&L Report',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        bottom: _hasData && !_loading
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: BrandColors.redDark,
                labelColor: BrandColors.redDark,
                unselectedLabelColor: BrandColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                tabs: const [
                  Tab(text: 'P&L OVERVIEW'),
                  Tab(text: 'ORDERS'),
                  Tab(text: 'PRODUCTS'),
                  Tab(text: 'FRANCHISE'),
                ],
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: BrandColors.redDark),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          _buildFilterBar(),
          const Divider(height: 1, color: BrandColors.border),

          // Content
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: BrandColors.redDark),
                  )
                : _error != null
                    ? _buildError()
                    : !_hasData
                        ? _buildEmpty()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildOverviewTab(),
                              _buildOrdersTab(),
                              _buildProductsTab(),
                              _buildFranchiseTab(),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  // ── Filter Bar ────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Date Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('ALL', _DateFilter.all),
                const SizedBox(width: 8),
                _chip('TODAY', _DateFilter.today),
                const SizedBox(width: 8),
                _chip('YESTERDAY', _DateFilter.yesterday),
                const SizedBox(width: 8),
                _chip('THIS WEEK', _DateFilter.thisWeek),
                const SizedBox(width: 8),
                _chip('THIS MONTH', _DateFilter.thisMonth),
                const SizedBox(width: 8),
                _chip(
                  _customRangeLabel.isNotEmpty ? _customRangeLabel : 'CUSTOM',
                  _DateFilter.custom,
                  icon: Icons.date_range_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 2. Product Sizing Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('SKU: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BrandColors.textSecondary)),
                _productFilterChip('All Products', null),
                const SizedBox(width: 6),
                _productFilterChip('SHV-200', 'SHV-200'),
                const SizedBox(width: 6),
                _productFilterChip('SHV-250', 'SHV-250'),
                const SizedBox(width: 6),
                _productFilterChip('SHV-500', 'SHV-500'),
                const SizedBox(width: 6),
                _productFilterChip('SHV-1L', 'SHV-1L'),
                const SizedBox(width: 6),
                _productFilterChip('SHV-20L', 'SHV-20L'),
              ],
            ),
          ),

          // 3. Active Order Filter Banner (if selected)
          if (_selectedOrderId != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_alt_rounded, size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text(
                    'Filtering by Order: ${_selectedOrderCode ?? "#$_selectedOrderId"}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedOrderId = null;
                        _selectedOrderCode = null;
                      });
                      _loadReports();
                    },
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF1E40AF)),
                  ),
                ],
              ),
            ),
          ],

          // 4. Active Franchise Filter Banner (if selected)
          if (_selectedFranchiseId != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store_rounded, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Text(
                    'Filtering by Franchise: ${_selectedFranchiseName ?? "#$_selectedFranchiseId"}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedFranchiseId = null;
                        _selectedFranchiseName = null;
                      });
                      _loadReports();
                    },
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF92400E)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _productFilterChip(String label, String? sku) {
    final selected = _selectedProductSku == sku;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedProductSku = sku;
        });
        _loadReports();
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF0F172A) : BrandColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : BrandColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, _DateFilter filter, {IconData? icon}) {
    final selected = _selectedFilter == filter;
    return InkWell(
      onTap: () => _onFilterSelected(filter),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? BrandColors.redDark : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? BrandColors.redDark : BrandColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color:
                      selected ? Colors.white : BrandColors.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : BrandColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error / Empty ─────────────────────────────────────────────────────────

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: BrandColors.error),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: BrandColors.error, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadReports,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.redDark),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.insert_chart_outlined_rounded,
                  size: 60, color: BrandColors.textMuted),
              const SizedBox(height: 14),
              const Text(
                'No business activity found\nfor the selected period.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BrandColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Place orders, process deliveries, or log expenses\nto see the P&L dashboard here.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: BrandColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: P&L OVERVIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    final grossRev = _sumVal('gross_revenue');
    final cogs = _sumVal('cogs');
    final expenses = _sumVal('expenses') > 0
        ? _sumVal('expenses')
        : _sumVal('total_operating_expenses');
    final netProfit = _sumVal('net_profit') > 0 || _sumVal('net_profit') < 0
        ? _sumVal('net_profit')
        : _sumVal('net_profit_or_loss');
    final grossProfit = _sumVal('gross_profit');
    final directRev = _sumVal('direct_company_revenue');
    final franchiseRev = _sumVal('franchise_revenue');
    final totalCollected = _sumVal('collected_amount') > 0
        ? _sumVal('collected_amount')
        : _sumVal('total_collected');
    final cashCollected = _sumVal('cash_collected');
    final onlineCollected = _sumVal('online_collected');
    final outstanding = _sumVal('pending_amount') > 0
        ? _sumVal('pending_amount')
        : _sumVal('outstanding_receivables');
    final bookingValue = _sumVal('total_order_amount') > 0
        ? _sumVal('total_order_amount')
        : _sumVal('total_booking_value');
    final isProfitable = netProfit >= 0;
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    final fmt2 = NumberFormat('#,##,##0.00', 'en_IN');

    return RefreshIndicator(
      onRefresh: _loadReports,
      color: BrandColors.redDark,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Net P&L Hero Card ──────────────────────────────────────────
          _heroCard(
            isProfitable: isProfitable,
            netProfit: netProfit,
            fmt2: fmt2,
            onTap: () => _showPLBreakdownModal(
              context,
              isProfitable,
              netProfit,
              grossRev,
              cogs,
              expenses,
              grossProfit,
            ),
          ),
          const SizedBox(height: 14),

          // ── Revenue Breakdown ─────────────────────────────────────────
          _sectionTitle('Revenue Breakdown (Tap for Details)'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Gross Revenue',
                  '₹${fmt.format(grossRev)}',
                  const Color(0xFF3B82F6),
                  Icons.trending_up_rounded,
                  onTap: () => _showDetailModal(
                    context,
                    'Gross Recognized Revenue',
                    'Total authoritative revenue from delivered customer orders & wholesale supplies.',
                    [
                      {'label': 'Delivered Sales', 'value': '₹${fmt.format(grossRev)}', 'color': '0xFF3B82F6'},
                      {'label': 'Direct Deliveries', 'value': '₹${fmt.format(directRev)}'},
                      {'label': 'Franchise Supplies', 'value': '₹${fmt.format(franchiseRev)}'},
                      {'label': 'Pipeline Booking Value', 'value': '₹${fmt.format(bookingValue)}'},
                    ],
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Gross Profit',
                  '₹${fmt.format(grossProfit)}',
                  const Color(0xFF10B981),
                  Icons.price_check_rounded,
                  onTap: () => _showDetailModal(
                    context,
                    'Gross Profit Margin',
                    'Realized margin after deducting material manufacturing cost from sales.',
                    [
                      {'label': 'Delivered Revenue', 'value': '₹${fmt.format(grossRev)}'},
                      {'label': 'COGS Cost', 'value': '− ₹${fmt.format(cogs)}', 'color': '0xFFEF4444'},
                      {'label': 'Gross Margin', 'value': '₹${fmt.format(grossProfit)}', 'color': '0xFF10B981'},
                      {'label': 'Gross Margin %', 'value': '${grossRev > 0 ? ((grossProfit / grossRev) * 100).toStringAsFixed(1) : '0'}%'},
                    ],
                    icon: Icons.price_check_rounded,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Direct Sales',
                  '₹${fmt.format(directRev)}',
                  const Color(0xFF6366F1),
                  Icons.storefront_rounded,
                  onTap: () => _showDetailModal(
                    context,
                    'Direct Company Sales',
                    'Orders fulfilled directly from Shivnath Agency central bottling plant.',
                    [
                      {'label': 'Direct Company Revenue', 'value': '₹${fmt.format(directRev)}', 'color': '0xFF6366F1'},
                      {'label': 'Plant Facility', 'value': 'Shivnath Central Plant'},
                    ],
                    icon: Icons.storefront_rounded,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Franchise Sales',
                  '₹${fmt.format(franchiseRev)}',
                  const Color(0xFFF59E0B),
                  Icons.people_alt_rounded,
                  onTap: () => _showDetailModal(
                    context,
                    'Franchise Network Sales',
                    'Wholesale supply invoices and dealer fulfilled customer deliveries.',
                    [
                      {'label': 'Franchise Network Revenue', 'value': '₹${fmt.format(franchiseRev)}', 'color': '0xFFF59E0B'},
                      {'label': 'Active Network Partners', 'value': '${_franchiseActivity.length} wholesale partners'},
                    ],
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Cost & Expenses ───────────────────────────────────────────
          _sectionTitle('Cost & Expenses (Tap for Breakdown)'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'COGS',
                  '₹${fmt.format(cogs)}',
                  const Color(0xFFEF4444),
                  Icons.factory_rounded,
                  onTap: () => _showDetailModal(
                    context,
                    'Cost of Goods Sold (COGS)',
                    'Exact raw material manufacturing costs (Preforms, caps, RO water, labels, cartons).',
                    [
                      {'label': 'Material Manufacturing Cost', 'value': '₹${fmt.format(cogs)}', 'color': '0xFFEF4444'},
                      {'label': 'BOM Cost per Bottle', 'value': '₹2.80 (500ml) / ₹4.80 (1L)'},
                    ],
                    icon: Icons.factory_rounded,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Operating Exp.',
                  '₹${fmt.format(expenses)}',
                  const Color(0xFFDC2626),
                  Icons.receipt_long_rounded,
                  onTap: () => _showDetailModal(
                    context,
                    'Operating Expenses (OpEx)',
                    'Plant overheads, RO electricity, weekly labour wages, fuel & logistics.',
                    [
                      {'label': 'Total Logged OpEx', 'value': '₹${fmt.format(expenses)}', 'color': '0xFFDC2626'},
                      {'label': 'Coverage', 'value': 'Labour wages, RO power, Fuel, Maintenance'},
                    ],
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Collections ──────────────────────────────────────────────
          _sectionTitle('Collections & Receivables (Tap for Receipts)'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Total Collected',
                  '₹${fmt.format(totalCollected)}',
                  const Color(0xFF059669),
                  Icons.account_balance_wallet_rounded,
                  onTap: () => _showDetailModal(
                    context,
                    'Verified Payment Collections',
                    'Total confirmed receipts credited from customer orders & franchise settlements.',
                    [
                      {'label': 'Total Realized Collections', 'value': '₹${fmt.format(totalCollected)}', 'color': '0xFF059669'},
                      {'label': 'Cash Handover', 'value': '₹${fmt.format(cashCollected)}'},
                      {'label': 'Online UPI / NEFT', 'value': '₹${fmt.format(onlineCollected)}'},
                    ],
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Outstanding',
                  '₹${fmt.format(outstanding)}',
                  const Color(0xFFF97316),
                  Icons.pending_actions_rounded,
                  onTap: () => _showDetailModal(
                    context,
                    'Outstanding Credit Receivables',
                    'Uncollected invoices and dealer credit accounts pending payment.',
                    [
                      {'label': 'Total Uncollected Receivables', 'value': '₹${fmt.format(outstanding)}', 'color': '0xFFF97316'},
                    ],
                    icon: Icons.pending_actions_rounded,
                    color: const Color(0xFFF97316),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Cash Collected',
                  '₹${fmt.format(cashCollected)}',
                  const Color(0xFF0D9488),
                  Icons.money_rounded,
                  onTap: () => _showDetailModal(
                    context,
                    'Cash In Hand Receipts',
                    'Verified physical cash received by delivery personnel and central office.',
                    [
                      {'label': 'Verified Cash Amount', 'value': '₹${fmt.format(cashCollected)}', 'color': '0xFF0D9488'},
                    ],
                    icon: Icons.money_rounded,
                    color: const Color(0xFF0D9488),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Online Collected',
                  '₹${fmt.format(onlineCollected)}',
                  const Color(0xFF7C3AED),
                  Icons.payment_rounded,
                  onTap: () => _showDetailModal(
                    context,
                    'Digital Online Payments',
                    'Direct bank transfers, QR scan UPI, and online gateway receipts.',
                    [
                      {'label': 'Digital Collections', 'value': '₹${fmt.format(onlineCollected)}', 'color': '0xFF7C3AED'},
                    ],
                    icon: Icons.payment_rounded,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Inventory ────────────────────────────────────────────────
          _sectionTitle('Inventory & Production (Tap to Switch Tab)'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Units Produced',
                  '${_intVal('production_volume_units')} units',
                  const Color(0xFF0369A1),
                  Icons.precision_manufacturing_rounded,
                  onTap: () => _tabController.animateTo(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Units Dispatched',
                  '${_intVal('dealer_dispatch_units')} units',
                  const Color(0xFF0891B2),
                  Icons.local_shipping_rounded,
                  onTap: () => _tabController.animateTo(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Central Stock',
                  '${_intVal('central_stock_units')} units',
                  const Color(0xFF475569),
                  Icons.warehouse_rounded,
                  onTap: () => _tabController.animateTo(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Franchise Stock',
                  '${_intVal('franchise_stock_units')} units',
                  const Color(0xFF64748B),
                  Icons.inventory_2_rounded,
                  onTap: () => _tabController.animateTo(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _heroCard({
    required bool isProfitable,
    required double netProfit,
    required NumberFormat fmt2,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: isProfitable
                  ? [const Color(0xFF059669), const Color(0xFF10B981)]
                  : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (isProfitable
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626))
                    .withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isProfitable ? '📈 NET PROFIT' : '📉 NET LOSS',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.info_outline, size: 14, color: Colors.white70),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${fmt2.format(netProfit.abs())}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap to view authoritative P&L formula calculation',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                isProfitable
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: Colors.white,
                size: 36,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: ORDERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOrdersTab() {
    final total = _intVal('total_orders');
    final delivered = _intVal('orders_delivered');
    final cancelled = _intVal('orders_cancelled');
    final dispatched = _intVal('orders_dispatched');
    final preparing = _intVal('orders_preparing') + _intVal('orders_approved');
    final placed = _intVal('orders_placed');
    final bookingValue = _sumVal('total_order_amount') > 0
        ? _sumVal('total_order_amount')
        : _sumVal('total_booking_value');
    final grossRev = _sumVal('gross_revenue');
    final fmt = NumberFormat('#,##,##0', 'en_IN');

    return RefreshIndicator(
      onRefresh: _loadReports,
      color: BrandColors.redDark,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Order Summary Highlights
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Total Booked',
                  '$total Orders',
                  const Color(0xFF6366F1),
                  Icons.shopping_bag_outlined,
                  onTap: () => _showDetailModal(
                    context,
                    'Orders Booking Pipeline',
                    'Total volume of client orders booked during this period.',
                    [
                      {'label': 'Total Orders Count', 'value': '$total Orders', 'color': '0xFF6366F1'},
                      {'label': 'Total Booking Value', 'value': '₹${fmt.format(bookingValue)}'},
                      {'label': 'Delivered Count', 'value': '$delivered Delivered'},
                      {'label': 'In Pipeline', 'value': '${total - delivered - cancelled} In Progress'},
                    ],
                    icon: Icons.shopping_bag_outlined,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Delivered Value',
                  '₹${fmt.format(grossRev)}',
                  const Color(0xFF059669),
                  Icons.task_alt_rounded,
                  onTap: () => _showDetailModal(
                    context,
                    'Delivered Order Sales',
                    'Revenue recognized upon customer delivery confirmation.',
                    [
                      {'label': 'Delivered Sales', 'value': '₹${fmt.format(grossRev)}', 'color': '0xFF059669'},
                      {'label': 'Delivered Units Confirmed', 'value': '$delivered Orders'},
                    ],
                    icon: Icons.task_alt_rounded,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionTitle('Order Pipeline Stages (Tap for Details)'),
          const SizedBox(height: 10),
          // Pipeline funnel
          _pipelineRow('New Placed Orders', placed, total, const Color(0xFF6366F1),
              subtitle: 'Awaiting admin / plant approval'),
          _pipelineRow('Approved & Preparing', preparing, total, const Color(0xFF0891B2),
              subtitle: 'Bottling & packaging in progress'),
          _pipelineRow('Out for Delivery', dispatched, total, const Color(0xFFF59E0B),
              subtitle: 'En route via logistics vehicles'),
          _pipelineRow('Delivered Successfully ✓', delivered, total, const Color(0xFF059669),
              subtitle: 'Verified & revenue recognized'),
          _pipelineRow('Cancelled ✗', cancelled, total, const Color(0xFFEF4444),
              subtitle: 'Duplicate or cancelled booking'),
          const SizedBox(height: 16),
          _sectionTitle('Recent Customer Orders'),
          const SizedBox(height: 8),
          if (_customerActivity.isEmpty)
            _emptyListPlaceholder('No customer orders in this period.')
          else
            ..._customerActivity.take(30).map(_buildOrderRow),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _pipelineRow(String label, int count, int total, Color color, {String? subtitle}) {
    final pct = total > 0 ? count / total : 0.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetailModal(
          context,
          label,
          subtitle ?? 'Pipeline stage detail',
          [
            {'label': 'Orders in this status', 'value': '$count Orders', 'color': '0x${color.toARGB32().toRadixString(16)}'},
            {'label': 'Percentage of Pipeline', 'value': '${(pct * 100).toStringAsFixed(1)}%'},
            {'label': 'Total Pipeline Orders', 'value': '$total Orders'},
          ],
          icon: Icons.timeline_rounded,
          color: color,
        ),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: BrandColors.border),
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
                        Text(label,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: BrandColors.textPrimary)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: const TextStyle(
                                  fontSize: 10, color: BrandColors.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  Text('$count ($total > 0 ? ${(pct * 100).toStringAsFixed(0)}% : 0%)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: color,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildOrderRow(Map<String, dynamic> o) {
    final statusColor = _orderStatusColor(o['status']?.toString() ?? '');
    final orderId = int.tryParse('${o['id']}');
    final isSelected = _selectedOrderId != null && _selectedOrderId == orderId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isSelected) {
            setState(() {
              _selectedOrderId = null;
              _selectedOrderCode = null;
            });
          } else {
            setState(() {
              _selectedOrderId = orderId;
              _selectedOrderCode = o['order_code']?.toString();
            });
          }
          _loadReports();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : BrandColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          o['order_code']?.toString() ?? '—',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? const Color(0xFF1E40AF) : BrandColors.textPrimary),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          const Text('(Filtered)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      o['customer']?.toString() ?? 'Customer',
                      style: const TextStyle(
                          fontSize: 11, color: BrandColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${double.tryParse(o['amount']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      o['status_display']?.toString() ??
                          o['status']?.toString() ??
                          '',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _orderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return const Color(0xFF059669);
      case 'dispatch':
        return const Color(0xFF0891B2);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'invoice_generated':
      case 'preparing':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6366F1);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: PRODUCTS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildProductsTab() {
    final fmt = NumberFormat('#,##,##0', 'en_IN');

    return RefreshIndicator(
      onRefresh: _loadReports,
      color: BrandColors.redDark,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Product-wise Profitability'),
          const SizedBox(height: 4),
          const Text(
            'Revenue recognition: DELIVERED orders only.',
            style: TextStyle(color: BrandColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (_productWise.isEmpty)
            _emptyListPlaceholder(
                'No delivered orders in this period. Revenue is recognized only upon delivery.')
          else
            ..._productWise.map((p) {
              final sku = p['sku']?.toString();
              final isSelected = _selectedProductSku != null && _selectedProductSku == sku;
              final rev = double.tryParse(p['revenue']?.toString() ?? '0') ?? 0;
              final cogs = double.tryParse(p['cogs']?.toString() ?? '0') ?? 0;
              final gp = double.tryParse(p['gross_profit']?.toString() ?? '0') ?? 0;
              final margin =
                  double.tryParse(p['margin_pct']?.toString() ?? '0') ?? 0;
              final qty = int.tryParse(p['quantity']?.toString() ?? '0') ?? 0;
              final isProfitable = gp >= 0;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedProductSku = null;
                      } else {
                        _selectedProductSku = sku;
                      }
                    });
                    _loadReports();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF10B981) : BrandColors.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
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
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          p['name']?.toString() ?? '—',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: BrandColors.textPrimary),
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'FILTERED',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    'SKU: ${p['sku'] ?? '—'}   |   Qty: $qty units  (Tap to ${isSelected ? 'clear' : 'filter'})',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: BrandColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isProfitable
                                    ? const Color(0xFFD1FAE5)
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${margin.toStringAsFixed(1)}% margin',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isProfitable
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _miniMetric('Revenue', '₹${fmt.format(rev)}',
                                const Color(0xFF3B82F6)),
                            _miniMetric('COGS', '₹${fmt.format(cogs)}',
                                const Color(0xFFEF4444)),
                            _miniMetric(
                                'Gross Profit',
                                '₹${fmt.format(gp)}',
                                isProfitable
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: BrandColors.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ---------------------------------------------------------
  // TAB 4: FRANCHISE
  // ---------------------------------------------------------

  Widget _buildFranchiseTab() {


    // Extract unique franchises from activity
    final Map<int, String> franchiseMap = {};
    for (final req in _franchiseActivity) {
      final fId = int.tryParse('');
      final fName = req['franchise_name']?.toString() ?? 'Franchise';
      if (fId != null) {
        franchiseMap[fId] = fName;
      }
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      color: BrandColors.redDark,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('CRM & Franchise Summary'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _metricCard(
                      'Stock Requests',
                      '',
                      const Color(0xFFF59E0B),
                      Icons.inventory_rounded)),
              const SizedBox(width: 10),
              Expanded(
                  child: _metricCard(
                      'New Leads',
                      '',
                      const Color(0xFF6366F1),
                      Icons.person_add_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          _metricCard(
              'Leads Converted',
              '',
              const Color(0xFF059669),
              Icons.how_to_reg_rounded),
          const SizedBox(height: 16),

          if (franchiseMap.isNotEmpty) ...[
            _sectionTitle('Filter by Franchise Network Partner'),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _franchiseFilterChip('All Franchises', null),
                  ...franchiseMap.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _franchiseFilterChip(entry.value, entry.key),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          _sectionTitle('Franchise Stock Requests'),
          const SizedBox(height: 8),
          if (_franchiseActivity.isEmpty)
            _emptyListPlaceholder('No franchise stock requests in this period.')
          else
            ..._franchiseActivity.take(30).map((req) {
              final reqQty =
                  int.tryParse(req['requested_quantity']?.toString() ?? '0') ??
                      0;
              final dispQty =
                  int.tryParse(req['dispatched_quantity']?.toString() ?? '0') ??
                      0;
              final outstanding =
                  double.tryParse(req['outstanding']?.toString() ?? '0') ?? 0;
              final fId = int.tryParse('');
              final fName = req['franchise_name']?.toString() ?? 'Franchise';
              final isSelected = _selectedFranchiseId != null && _selectedFranchiseId == fId;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _showFranchiseRequestDetailsModal(req, fId, fName);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFEF3C7) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFD97706) : BrandColors.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      fName,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: BrandColors.textPrimary),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'FILTERED',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '  *  ',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: BrandColors.textSecondary),
                              ),
                              Text(
                                'Req:   Dispatched:   (Tap for details)',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: BrandColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (outstanding > 0)
                              Text(
                                'Rs. due',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEF4444)),
                              ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                req['status']?.toString() ?? '-',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: BrandColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _franchiseFilterChip(String label, int? franchiseId) {
    final isSelected = _selectedFranchiseId == franchiseId;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : BrandColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFD97706),
      backgroundColor: Colors.grey.shade100,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFFD97706) : BrandColors.border,
        ),
      ),
      onSelected: (_) {
        setState(() {
          if (isSelected) {
            _selectedFranchiseId = null;
            _selectedFranchiseName = null;
          } else {
            _selectedFranchiseId = franchiseId;
            _selectedFranchiseName = franchiseId != null ? label : null;
          }
        });
        _loadReports();
      },
    );
  }

  void _showFranchiseRequestDetailsModal(Map<String, dynamic> req, int? fId, String fName) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    final reqQty = int.tryParse(req['requested_quantity']?.toString() ?? '0') ?? 0;
    final dispQty = int.tryParse(req['dispatched_quantity']?.toString() ?? '0') ?? 0;
    final outstanding = double.tryParse(req['outstanding']?.toString() ?? '0') ?? 0;
    final isSelected = _selectedFranchiseId != null && _selectedFranchiseId == fId;

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
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store_rounded, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Stock Request: ',
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
            const Divider(),
            const SizedBox(height: 8),
            _modalRow('Product', req['product_name']?.toString() ?? '-'),
            _modalRow('Requested Qty', ' units'),
            _modalRow('Dispatched Qty', ' units'),
            _modalRow('Status', req['status']?.toString() ?? '-'),
            _modalRow('Outstanding Due', 'Rs.'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        if (isSelected) {
                          _selectedFranchiseId = null;
                          _selectedFranchiseName = null;
                        } else {
                          _selectedFranchiseId = fId;
                          _selectedFranchiseName = fName;
                        }
                      });
                      _loadReports();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(isSelected ? 'Clear Filter' : 'Filter by this Franchise'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Shared Widgets
  // ---------------------------------------------------------

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: BrandColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      );

  Widget _metricCard(
      String label, String value, Color color, IconData icon, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BrandColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                          fontSize: 11, color: BrandColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailModal(
    BuildContext context,
    String title,
    String subtitle,
    List<Map<String, String>> items, {
    IconData? icon,
    Color? color,
  }) {
    final themeColor = color ?? BrandColors.redDark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
            const SizedBox(height: 16),
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: themeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: BrandColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: BrandColors.border),
            const SizedBox(height: 12),
            ...items.map((it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        it['label'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        it['value'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: it['color'] != null
                              ? Color(int.parse(it['color']!))
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPLBreakdownModal(
    BuildContext context,
    bool isProfitable,
    double netProfit,
    double grossRev,
    double cogs,
    double expenses,
    double grossProfit,
  ) {
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');
    final marginPct = grossRev > 0 ? ((netProfit / grossRev) * 100).toStringAsFixed(1) : '0';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  isProfitable ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: isProfitable ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text(
                  isProfitable ? 'Net Profit Statement' : 'Net Loss Statement',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Authoritative ERP Formula: Revenue (Delivered) − Snapshot COGS − Operating Expenses',
              style: TextStyle(fontSize: 12, color: BrandColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BrandColors.border),
              ),
              child: Column(
                children: [
                  _formulaRow('Gross Revenue (Delivered)', '₹${fmt.format(grossRev)}', const Color(0xFF0284C7)),
                  const SizedBox(height: 8),
                  _formulaRow('− Snapshot COGS', '₹${fmt.format(cogs)}', const Color(0xFFEF4444)),
                  const Divider(height: 16),
                  _formulaRow('= Gross Profit Margin', '₹${fmt.format(grossProfit)}', const Color(0xFF10B981)),
                  const SizedBox(height: 8),
                  _formulaRow('− Operating Expenses', '₹${fmt.format(expenses)}', const Color(0xFFDC2626)),
                  const Divider(height: 16),
                  _formulaRow(
                    isProfitable ? '═ Net Profit' : '═ Net Loss',
                    '₹${fmt.format(netProfit.abs())}',
                    isProfitable ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Operating Margin: $marginPct% on realized turnover.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulaRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _emptyListPlaceholder(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: BrandColors.textMuted, fontSize: 13),
          ),
        ),
      );
}
