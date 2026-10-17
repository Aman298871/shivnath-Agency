import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/InventoryService.dart';
import '../../../core/services/report_service.dart';
import '../../../core/widgets/app_toast.dart';

import 'daily_pl_report_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final InventoryService _inventoryService = InventoryService();
  final ReportService _reportService = ReportService();

  String period = 'THIS MONTH';
  DateTime? customStartDate;
  DateTime? customEndDate;
  bool _isExporting = false;
  bool isLoading = false;

  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> monthlySales = [];
  List<Map<String, dynamic>> customerActivity = [];
  List<Map<String, dynamic>> franchiseActivity = [];
  List<Map<String, dynamic>> leadActivity = [];
  List<Map<String, dynamic>> reportsLog = [];

  int _selectedActivityTab =
      0; // 0: Customer Orders, 1: Franchise Stock, 2: CRM Leads, 3: Daily Reports

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      String? apiPeriod;
      String? startDate;
      String? endDate;

      switch (period) {
        case 'TODAY':
          apiPeriod = 'today';
          break;
        case 'YESTERDAY':
          apiPeriod = 'yesterday';
          break;
        case 'THIS WEEK':
          apiPeriod = 'this_week';
          break;
        case 'THIS MONTH':
          apiPeriod = 'this_month';
          break;
        case 'CUSTOM DATE RANGE':
          if (customStartDate != null && customEndDate != null) {
            startDate = DateFormat('yyyy-MM-dd').format(customStartDate!);
            endDate = DateFormat('yyyy-MM-dd').format(customEndDate!);
          } else {
            apiPeriod = 'this_month';
          }
          break;
        default:
          apiPeriod = 'this_month';
      }

      final res = await _inventoryService.getDailyBusinessReports(
        period: apiPeriod,
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;

      Map<String, dynamic> data = {};
      if (res['success'] == true && res['data'] is Map) {
        data = Map<String, dynamic>.from(res['data'] as Map);
      } else if (res['summary'] is Map) {
        data = Map<String, dynamic>.from(res);
      }

      setState(() {
        summary = Map<String, dynamic>.from(data['summary'] ?? {});
        monthlySales = List<Map<String, dynamic>>.from(
          data['monthly_sales'] ?? [],
        );
        customerActivity = List<Map<String, dynamic>>.from(
          data['customer_activity'] ?? [],
        );
        franchiseActivity = List<Map<String, dynamic>>.from(
          data['franchise_activity'] ?? [],
        );
        leadActivity = List<Map<String, dynamic>>.from(
          data['lead_activity'] ?? [],
        );
        reportsLog = List<Map<String, dynamic>>.from(data['reports'] ?? []);
      });
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to fetch report data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: customStartDate ?? now.subtract(const Duration(days: 7)),
        end: customEndDate ?? now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0284C7),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        customStartDate = picked.start;
        customEndDate = picked.end;
        period = 'CUSTOM DATE RANGE';
      });
      _fetchReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF5F7FB),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(desktop),
                    if (isLoading) ...[
                      const SizedBox(height: 10),
                      const ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        child: LinearProgressIndicator(
                          backgroundColor: Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF0284C7),
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _summaryCards(desktop),
                    const SizedBox(height: 22),
                    _monthlySalesCard(),
                    const SizedBox(height: 24),
                    _activityTabsSection(desktop),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _header(bool desktop) {
    final periodSelector = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: desktop ? 190 : 160, child: _periodDropdown()),
        if (period == 'CUSTOM DATE RANGE') ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Select Custom Date Range',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE0F2FE),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(
              Icons.calendar_month,
              color: Color(0xFF0284C7),
              size: 20,
            ),
            onPressed: _pickCustomDateRange,
          ),
        ],
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Refresh Reports',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.refresh, color: Color(0xFF475569), size: 20),
          onPressed: _fetchReports,
        ),
      ],
    );

    final exportButton = SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0284C7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: _isExporting ? null : _exportReport,
        icon: _isExporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.download_outlined, size: 18),
        label: Text(
          _isExporting ? 'Exporting...' : 'Export CSV',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );

    final plButton = SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF0284C7)),
          foregroundColor: const Color(0xFF0284C7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DailyPlReportScreen(),
            ),
          );
        },
        icon: const Icon(Icons.analytics_outlined, size: 18),
        label: const Text(
          'Business P&L',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );

    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reports & Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _dateSubtitle(),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          periodSelector,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: plButton),
              const SizedBox(width: 8),
              Expanded(child: exportButton),
            ],
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
              const Text(
                'Reports & Analytics',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _dateSubtitle(),
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        plButton,
        const SizedBox(width: 8),
        periodSelector,
        const SizedBox(width: 8),
        exportButton,
      ],
    );
  }

  String _dateSubtitle() {
    if (period == 'CUSTOM DATE RANGE' &&
        customStartDate != null &&
        customEndDate != null) {
      final df = DateFormat('dd MMM yyyy');
      return 'Data range: ${df.format(customStartDate!)} - ${df.format(customEndDate!)}';
    }
    return 'Real-time database aggregated reporting for ${period.toLowerCase().replaceAll('_', ' ')}.';
  }

  Widget _periodDropdown() {
    const periodOptions = [
      'TODAY',
      'YESTERDAY',
      'THIS WEEK',
      'THIS MONTH',
      'CUSTOM DATE RANGE',
    ];

    return DropdownButtonFormField<String>(
      initialValue: period,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      items: periodOptions.map((val) {
        return DropdownMenuItem(
          value: val,
          child: Text(
            val,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        if (value == 'CUSTOM DATE RANGE') {
          _pickCustomDateRange();
        } else {
          setState(() {
            period = value;
          });
          _fetchReports();
        }
      },
    );
  }

  // =========================================================
  // SUMMARY CARDS
  // =========================================================

  Widget _summaryCards(bool desktop) {
    final grossRev = (summary['gross_revenue'] as num?)?.toDouble() ?? 0.0;
    final totalOrders = (summary['total_orders'] as num?)?.toInt() ?? 0;
    final franchiseReqs =
        (summary['franchise_requests_count'] as num?)?.toInt() ?? 0;
    final newLeads = (summary['new_leads_count'] as num?)?.toInt() ?? 0;
    final prodUnits =
        (summary['production_volume_units'] as num?)?.toInt() ?? 0;
    final dispUnits = (summary['dealer_dispatch_units'] as num?)?.toInt() ?? 0;
    final expenses = (summary['expenses'] as num?)?.toDouble() ?? 0.0;
    final netProfit = (summary['net_profit'] as num?)?.toDouble() ?? 0.0;
    final collectedAmt = (summary['collected_amount'] as num?)?.toDouble() ?? 0.0;
    final pendingAmt = (summary['pending_amount'] as num?)?.toDouble() ?? 0.0;
    final franchiseRev = (summary['franchise_revenue'] as num?)?.toDouble() ?? 0.0;
    final directRev = (summary['direct_company_revenue'] as num?)?.toDouble() ?? 0.0;

    final data = [
      {
        'title': 'Total Revenue',
        'value': _formatCurrency(grossRev),
        'subtitle': 'Gross order & invoice value',
        'icon': Icons.currency_rupee,
        'color': const Color(0xFF0284C7),
        'bg': const Color(0xFFE0F2FE),
      },
      {
        'title': 'Collected Payments',
        'value': _formatCurrency(collectedAmt),
        'subtitle': 'Total verified receipts',
        'icon': Icons.payments_outlined,
        'color': const Color(0xFF16A34A),
        'bg': const Color(0xFFDCFCE7),
      },
      {
        'title': 'Pending Outstanding',
        'value': _formatCurrency(pendingAmt),
        'subtitle': 'Uncollected invoices',
        'icon': Icons.pending_actions_outlined,
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFEF3C7),
      },
      {
        'title': 'Franchise Network Rev',
        'value': _formatCurrency(franchiseRev),
        'subtitle': 'Dealer orders & wholesale',
        'icon': Icons.storefront,
        'color': const Color(0xFF7C3AED),
        'bg': const Color(0xFFF5F3FF),
      },
      {
        'title': 'Direct Company Rev',
        'value': _formatCurrency(directRev),
        'subtitle': 'Direct deliveries & walk-ins',
        'icon': Icons.business,
        'color': const Color(0xFF0284C7),
        'bg': const Color(0xFFE0F2FE),
      },
      {
        'title': 'Customer Orders',
        'value': '$totalOrders',
        'subtitle': 'Customer placements',
        'icon': Icons.shopping_bag_outlined,
        'color': const Color(0xFF2563EB),
        'bg': const Color(0xFFEFF6FF),
      },
      {
        'title': 'Franchise Requests',
        'value': '$franchiseReqs',
        'subtitle': 'Stock requests received',
        'icon': Icons.storefront_outlined,
        'color': const Color(0xFF7C3AED),
        'bg': const Color(0xFFF5F3FF),
      },
      {
        'title': 'Chatbot & CRM Leads',
        'value': '$newLeads',
        'subtitle': 'Inquiries captured',
        'icon': Icons.people_outline,
        'color': const Color(0xFF0D9488),
        'bg': const Color(0xFFCCFBF1),
      },
      {
        'title': 'Units Produced',
        'value': NumberFormat.compact().format(prodUnits),
        'subtitle': 'Bottling plant output',
        'icon': Icons.water_drop_outlined,
        'color': const Color(0xFF0284C7),
        'bg': const Color(0xFFE0F2FE),
      },
      {
        'title': 'Units Dispatched',
        'value': NumberFormat.compact().format(dispUnits),
        'subtitle': 'To franchises & customers',
        'icon': Icons.local_shipping_outlined,
        'color': const Color(0xFFEA580C),
        'bg': const Color(0xFFFFEDD5),
      },
      {
        'title': 'Operating Expenses',
        'value': _formatCurrency(expenses),
        'subtitle': 'Recorded costs',
        'icon': Icons.receipt_long_outlined,
        'color': const Color(0xFFDC2626),
        'bg': const Color(0xFFFEE2E2),
      },
      {
        'title': 'Net Profit',
        'value': _formatCurrency(netProfit),
        'subtitle': 'Revenue - (COGS + Expenses)',
        'icon': Icons.trending_up_outlined,
        'color': const Color(0xFF16A34A),
        'bg': const Color(0xFFDCFCE7),
      },
    ];

    if (!desktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (_, index) => _statCard(data[index]),
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: data.map((item) {
        return SizedBox(width: 310, child: _statCard(item));
      }).toList(),
    );
  }

  Widget _statCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item['bg'] as Color? ?? const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: item['color'] as Color? ?? const Color(0xFF0284C7),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item['value'].toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['subtitle'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MONTHLY SALES CARD
  // =========================================================

  Widget _monthlySalesCard() {
    final hasData =
        monthlySales.isNotEmpty &&
        monthlySales.any((e) => (e['amount'] as num? ?? 0) > 0);

    final maxValue = monthlySales.fold<double>(0.0, (max, item) {
      final val = (item['amount'] as num?)?.toDouble() ?? 0.0;
      return val > max ? val : max;
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.bar_chart_rounded,
            'Year-to-Date Monthly Sales',
            'Real-time order revenue distribution by month across database records',
          ),
          const SizedBox(height: 20),
          if (!hasData)
            Container(
              height: 120,
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.query_stats, size: 36, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text(
                    'No orders placed yet for this year in the database.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: monthlySales.map((item) {
                  final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
                  final ratio = maxValue == 0
                      ? 0.0
                      : (amount / maxValue).clamp(0.0, 1.0);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _compactCurrency(amount.toInt()),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            height: (140 * ratio).clamp(8.0, 140.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF0284C7),
                                  const Color(
                                    0xFF0284C7,
                                  ).withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item['month'].toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // ACTIVITY TABS SECTION (CUSTOMER, FRANCHISE, LEADS)
  // =========================================================

  Widget _activityTabsSection(bool desktop) {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: _sectionTitle(
                    Icons.view_list_rounded,
                    'Activity Breakup & Details',
                    'Distinguished Customer Orders, Franchise Stock Requests, and CRM Leads',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Tab bar selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tabChip(
                    0,
                    'Customer Orders (${customerActivity.length})',
                    Icons.shopping_bag_outlined,
                  ),
                  const SizedBox(width: 8),
                  _tabChip(
                    1,
                    'Franchise Stock Requests (${franchiseActivity.length})',
                    Icons.storefront_outlined,
                  ),
                  const SizedBox(width: 8),
                  _tabChip(
                    2,
                    'CRM & Chatbot Leads (${leadActivity.length})',
                    Icons.people_outline,
                  ),
                  const SizedBox(width: 8),
                  _tabChip(
                    3,
                    'Daily Reports History (${reportsLog.length})',
                    Icons.auto_graph_outlined,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _buildSelectedTabContent(desktop),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(int index, String label, IconData icon) {
    final selected = _selectedActivityTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedActivityTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0284C7) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent(bool desktop) {
    switch (_selectedActivityTab) {
      case 0:
        return _customerOrdersTable();
      case 1:
        return _franchiseRequestsTable();
      case 2:
        return _leadsTable();
      case 3:
        return _dailyReportsLogTable();
      default:
        return const SizedBox();
    }
  }

  // =========================================================
  // 1. CUSTOMER ORDERS TABLE
  // =========================================================

  Widget _customerOrdersTable() {
    if (customerActivity.isEmpty) {
      return _emptyState('No customer orders found in this period.');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1000,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF1F5F9),
              child: const Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('ORDER ID', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('CUSTOMER', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('QUANTITY / ITEMS', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('AMOUNT', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('FULFILLMENT SOURCE', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('STATUS', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('DATE / TIME', style: _reportHeader),
                  ),
                ],
              ),
            ),
            ...customerActivity.map((order) {
              final orderCode =
                  order['order_code']?.toString() ?? '#${order['id']}';
              final customer = order['customer']?.toString() ?? 'Customer';
              final qty = order['quantity'] ?? order['items_count'] ?? 0;
              final amount = (order['amount'] as num?)?.toDouble() ?? 0.0;
              final source =
                  order['serving_franchise']?.toString() ?? 'Direct Company';
              final status =
                  order['status_display']?.toString() ??
                  order['status']?.toString() ??
                  'Placed';
              final date = order['created_at']?.toString() ?? '';

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        orderCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        customer,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('$qty units', style: _reportCell),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Expanded(flex: 3, child: Text(source, style: _reportCell)),
                    Expanded(flex: 2, child: _statusBadge(status)),
                    Expanded(
                      flex: 2,
                      child: Text(
                        date,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // 2. FRANCHISE STOCK REQUESTS TABLE
  // =========================================================

  Widget _franchiseRequestsTable() {
    if (franchiseActivity.isEmpty) {
      return _emptyState('No franchise stock requests found in this period.');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1150,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF1F5F9),
              child: const Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('REQ NUMBER', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('FRANCHISE', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('PRODUCT', style: _reportHeader),
                  ),
                  Expanded(flex: 1, child: Text('REQ', style: _reportHeader)),
                  Expanded(flex: 1, child: Text('APPR', style: _reportHeader)),
                  Expanded(flex: 1, child: Text('DISP', style: _reportHeader)),
                  Expanded(flex: 1, child: Text('RECV', style: _reportHeader)),
                  Expanded(flex: 1, child: Text('PEND', style: _reportHeader)),
                  Expanded(
                    flex: 2,
                    child: Text('STATUS', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('DATE / TIME', style: _reportHeader),
                  ),
                ],
              ),
            ),
            ...franchiseActivity.map((req) {
              final reqNumber =
                  req['request_number']?.toString() ?? 'REQ-${req['id']}';
              final franchise =
                  req['franchise_name']?.toString() ?? 'Franchise';
              final product = req['product_name']?.toString() ?? 'Product';
              final requested = req['requested_quantity'] ?? 0;
              final approved = req['approved_quantity'] ?? 0;
              final dispatched = req['dispatched_quantity'] ?? 0;
              final received = req['received_quantity'] ?? 0;
              final pending = req['pending_quantity'] ?? 0;
              final status = req['status']?.toString() ?? 'REQUESTED';
              final date = req['created_at']?.toString() ?? '';

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        reqNumber,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        franchise,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Expanded(flex: 3, child: Text(product, style: _reportCell)),
                    Expanded(
                      flex: 1,
                      child: Text('$requested', style: _reportCell),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text('$approved', style: _reportCell),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text('$dispatched', style: _reportCell),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text('$received', style: _reportCell),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '$pending',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: pending > 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                    Expanded(flex: 2, child: _statusBadge(status)),
                    Expanded(
                      flex: 2,
                      child: Text(
                        date,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // 3. CRM LEADS TABLE
  // =========================================================

  Widget _leadsTable() {
    if (leadActivity.isEmpty) {
      return _emptyState('No leads captured in this period.');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1050,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF1F5F9),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('NAME', style: _reportHeader)),
                  Expanded(
                    flex: 2,
                    child: Text('MOBILE', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('SOURCE', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('STATUS', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('SCORE / INTENT', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('CITY / TERRITORY', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('DATE / TIME', style: _reportHeader),
                  ),
                ],
              ),
            ),
            ...leadActivity.map((lead) {
              final name = lead['name']?.toString() ?? 'Visitor';
              final phone = lead['phone']?.toString() ?? '';
              final source = lead['source']?.toString() ?? 'PUBLIC_CHATBOT';
              final status = lead['status']?.toString() ?? 'NEW_LEAD';
              final score = lead['score_category']?.toString() ?? 'WARM';
              final city =
                  lead['city']?.toString() ??
                  lead['territory']?.toString() ??
                  'Raipur';
              final date = lead['created_at']?.toString() ?? '';

              final isChatbot = source == 'PUBLIC_CHATBOT';

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Expanded(flex: 2, child: Text(phone, style: _reportCell)),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isChatbot
                              ? const Color(0xFFE0F2FE)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isChatbot ? '🤖 Chatbot' : source,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isChatbot
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    Expanded(flex: 2, child: _statusBadge(status)),
                    Expanded(flex: 2, child: Text(score, style: _reportCell)),
                    Expanded(flex: 2, child: Text(city, style: _reportCell)),
                    Expanded(
                      flex: 2,
                      child: Text(
                        date,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // 4. DAILY REPORTS LOG TABLE
  // =========================================================

  Widget _dailyReportsLogTable() {
    if (reportsLog.isEmpty) {
      return _emptyState(
        'No daily business reports stored for this period yet.',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1050,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF1F5F9),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('DATE', style: _reportHeader)),
                  Expanded(
                    flex: 2,
                    child: Text('PROD UNITS', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('DISP UNITS', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('DEALER REV', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('DIRECT REV', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('GROSS REV', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('EXPENSES', style: _reportHeader),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('NET PROFIT', style: _reportHeader),
                  ),
                ],
              ),
            ),
            ...reportsLog.map((r) {
              final rDate = r['report_date']?.toString() ?? '';
              final pUnits = r['total_production_volume_units'] ?? 0;
              final dUnits = r['total_dealer_dispatch_units'] ?? 0;
              final dealerRev =
                  (r['total_dealer_sales_revenue_inr'] as num?)?.toDouble() ??
                  0.0;
              final directRev =
                  (r['total_direct_company_revenue_inr'] as num?)?.toDouble() ??
                  0.0;
              final gross =
                  (r['total_gross_revenue_inr'] as num?)?.toDouble() ?? 0.0;
              final exp =
                  (r['total_operating_expenses_inr'] as num?)?.toDouble() ??
                  0.0;
              final net = (r['net_profit_inr'] as num?)?.toDouble() ?? 0.0;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        rDate,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('$pUnits', style: _reportCell),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('$dUnits', style: _reportCell),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${dealerRev.toStringAsFixed(0)}',
                        style: _reportCell,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${directRev.toStringAsFixed(0)}',
                        style: _reportCell,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${gross.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${exp.toStringAsFixed(0)}',
                        style: _reportCell,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${net.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: net >= 0
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.folder_open_outlined,
            size: 36,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // STATUS BADGE
  // =========================================================

  Widget _statusBadge(String rawStatus) {
    final status = rawStatus.toUpperCase();
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF475569);

    if (status.contains('APPROVED') ||
        status.contains('CONFIRMED') ||
        status.contains('DELIVERED') ||
        status.contains('COMPLETED')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
    } else if (status.contains('DISPATCH') || status.contains('IN TRANSIT')) {
      bg = const Color(0xFFFFEDD5);
      fg = const Color(0xFFEA580C);
    } else if (status.contains('PENDING') ||
        status.contains('REQUESTED') ||
        status.contains('NEW')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else if (status.contains('CANCEL') || status.contains('REJECT')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          rawStatus,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // CSV EXPORT
  // =========================================================

  Future<void> _exportReport() async {
    setState(() => _isExporting = true);
    try {
      final buffer = StringBuffer();
      // UTF-8 BOM for Microsoft Excel
      buffer.write('\uFEFF');
      buffer.writeln('SHIVNATH AGENCY - BUSINESS REPORT');
      buffer.writeln('Period,$period');
      if (customStartDate != null && customEndDate != null) {
        buffer.writeln(
          'Custom Date Range,${DateFormat('yyyy-MM-dd').format(customStartDate!)} to ${DateFormat('yyyy-MM-dd').format(customEndDate!)}',
        );
      }
      buffer.writeln('Exported At,${DateTime.now().toIso8601String()}');
      buffer.writeln();

      buffer.writeln('--- FINANCIAL & OPERATIONAL SUMMARY ---');
      buffer.writeln('Metric,Value');
      buffer.writeln('Total Revenue,${summary['gross_revenue'] ?? 0}');
      buffer.writeln('Customer Orders Count,${summary['total_orders'] ?? 0}');
      buffer.writeln(
        'Franchise Requests Count,${summary['franchise_requests_count'] ?? 0}',
      );
      buffer.writeln('New CRM Leads,${summary['new_leads_count'] ?? 0}');
      buffer.writeln(
        'Production Units,${summary['production_volume_units'] ?? 0}',
      );
      buffer.writeln('Dispatch Units,${summary['dealer_dispatch_units'] ?? 0}');
      buffer.writeln('Operating Expenses,${summary['expenses'] ?? 0}');
      buffer.writeln('Net Profit,${summary['net_profit'] ?? 0}');
      buffer.writeln();

      buffer.writeln('--- CUSTOMER ORDERS ---');
      buffer.writeln(
        'Order Code,Customer,Quantity,Amount,Fulfillment,Status,Date',
      );
      for (final o in customerActivity) {
        buffer.writeln(
          '"${o['order_code']}","${o['customer']}",${o['quantity'] ?? o['items_count']},${o['amount']},"${o['serving_franchise']}","${o['status']}","${o['created_at']}"',
        );
      }
      buffer.writeln();

      buffer.writeln('--- FRANCHISE STOCK REQUESTS ---');
      buffer.writeln(
        'Request #,Franchise,Product,Requested,Approved,Dispatched,Received,Pending,Status,Date',
      );
      for (final f in franchiseActivity) {
        buffer.writeln(
          '"${f['request_number']}","${f['franchise_name']}","${f['product_name']}",${f['requested_quantity']},${f['approved_quantity']},${f['dispatched_quantity']},${f['received_quantity']},${f['pending_quantity']},"${f['status']}","${f['created_at']}"',
        );
      }
      buffer.writeln();

      buffer.writeln('--- CRM & PUBLIC CHATBOT LEADS ---');
      buffer.writeln('Name,Phone,Source,Status,Score,City,Date');
      for (final l in leadActivity) {
        buffer.writeln(
          '"${l['name']}","${l['phone']}","${l['source']}","${l['status']}","${l['score_category']}","${l['city']}","${l['created_at']}"',
        );
      }

      final fallbackBytes = Uint8List.fromList(utf8.encode(buffer.toString()));

      final result = await _reportService.exportReport(
        reportType: 'comprehensive',
        period: period,
        startDate: customStartDate,
        endDate: customEndDate,
        fallbackLocalBytes: fallbackBytes,
        openAfterDownload: true,
      );

      if (!mounted) return;

      if (result.success) {
        AppToast.success(
          context,
          result.message,
          title: 'Report Downloaded',
        );

        if (result.filePath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 8),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Saved: ${result.fileName}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'SHARE',
                textColor: const Color(0xFF38BDF8),
                onPressed: () {
                  _reportService.shareReportFile(result.filePath!, fileName: result.fileName);
                },
              ),
            ),
          );
        }
      } else {
        AppToast.error(context, result.message, title: 'Export Error');
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Export failed: $e', title: 'Export Error');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // =========================================================
  // HELPERS
  // =========================================================

  Widget _sectionTitle(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF0284C7)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double val) {
    if (val >= 10000000) {
      return '₹${(val / 10000000).toStringAsFixed(2)} Cr';
    }
    if (val >= 100000) {
      return '₹${(val / 100000).toStringAsFixed(2)} L';
    }
    if (val >= 1000) {
      return '₹${(val / 1000).toStringAsFixed(1)} K';
    }
    return '₹${val.toStringAsFixed(0)}';
  }

  String _compactCurrency(int val) {
    if (val >= 10000000) {
      return '₹${(val / 10000000).toStringAsFixed(1)}Cr';
    }
    if (val >= 100000) {
      return '₹${(val / 100000).toStringAsFixed(1)}L';
    }
    if (val >= 1000) {
      return '₹${(val / 1000).toStringAsFixed(1)}K';
    }
    return '₹$val';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x05000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    );
  }
}

const TextStyle _reportHeader = TextStyle(
  fontSize: 9,
  fontWeight: FontWeight.w700,
  color: Color(0xFF64748B),
  letterSpacing: .3,
);

const TextStyle _reportCell = TextStyle(
  fontSize: 10.5,
  color: Color(0xFF475569),
);
