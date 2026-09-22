import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/InventoryService.dart';
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

class _DailyPlReportScreenState extends State<DailyPlReportScreen> {
  final InventoryService _invService = InventoryService();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _reports = [];

  _DateFilter _selectedFilter = _DateFilter.all;
  String? _startDate;
  String? _endDate;
  String _customRangeLabel = '';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  void _onFilterSelected(_DateFilter filter) async {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');

    setState(() {
      _selectedFilter = filter;
    });

    switch (filter) {
      case _DateFilter.all:
        _startDate = null;
        _endDate = null;
        _customRangeLabel = '';
        break;
      case _DateFilter.today:
        _startDate = fmt.format(now);
        _endDate = fmt.format(now);
        _customRangeLabel = '';
        break;
      case _DateFilter.yesterday:
        final yest = now.subtract(const Duration(days: 1));
        _startDate = fmt.format(yest);
        _endDate = fmt.format(yest);
        _customRangeLabel = '';
        break;
      case _DateFilter.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        _startDate = fmt.format(weekStart);
        _endDate = fmt.format(now);
        _customRangeLabel = '';
        break;
      case _DateFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        _startDate = fmt.format(monthStart);
        _endDate = fmt.format(now);
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
              '${DateFormat('dd MMM').format(picked.start)} - ${DateFormat('dd MMM').format(picked.end)}';
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
      );
      if (res['success'] == true && res['data'] is List) {
        _reports = List<Map<String, dynamic>>.from(res['data']);
      } else {
        _reports = [];
      }
    } catch (e) {
      _error = 'Failed to load daily business reports: $e';
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Daily Business & P&L Reports',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
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
          // Filter Chips Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', _DateFilter.all),
                  const SizedBox(width: 8),
                  _buildFilterChip('TODAY', _DateFilter.today),
                  const SizedBox(width: 8),
                  _buildFilterChip('YESTERDAY', _DateFilter.yesterday),
                  const SizedBox(width: 8),
                  _buildFilterChip('THIS WEEK', _DateFilter.thisWeek),
                  const SizedBox(width: 8),
                  _buildFilterChip('THIS MONTH', _DateFilter.thisMonth),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    _customRangeLabel.isNotEmpty
                        ? _customRangeLabel
                        : 'CUSTOM',
                    _DateFilter.custom,
                    icon: Icons.date_range_rounded,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: BrandColors.border),

          // Content Area
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: BrandColors.redDark),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: BrandColors.error),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadReports,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _reports.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.insert_chart_outlined_rounded,
                                    size: 52,
                                    color: BrandColors.textMuted,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No daily reports found for selected range.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: BrandColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Reports are generated automatically during daily business closing.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: BrandColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadReports,
                            color: BrandColors.redDark,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _reports.length,
                              itemBuilder: (context, idx) {
                                return _buildReportCard(_reports[idx]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    _DateFilter filter, {
    IconData? icon,
  }) {
    final selected = _selectedFilter == filter;
    return InkWell(
      onTap: () => _onFilterSelected(filter),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : BrandColors.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : BrandColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> r) {
    final reportDate = r['report_date']?.toString() ?? 'Date';
    final grossRev =
        double.tryParse(r['gross_revenue']?.toString() ?? '0') ?? 0.0;
    final cogs = double.tryParse(r['cogs']?.toString() ?? '0') ?? 0.0;
    final expenses =
        double.tryParse(r['total_operating_expenses']?.toString() ?? '0') ??
            0.0;
    final netProfit =
        double.tryParse(r['net_profit_or_loss']?.toString() ?? '0') ?? 0.0;
    final unitsProd = r['total_units_produced'] ?? 0;
    final unitsDisp = r['total_units_dispatched'] ?? 0;

    final isProfitable = netProfit >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BrandColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: BrandColors.redDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      reportDate,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: BrandColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isProfitable
                        ? BrandColors.greenSoft
                        : BrandColors.redSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isProfitable
                          ? BrandColors.green
                          : BrandColors.red,
                    ),
                  ),
                  child: Text(
                    isProfitable ? 'NET PROFIT' : 'NET LOSS',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: isProfitable
                          ? BrandColors.greenDark
                          : BrandColors.redDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    'Gross Revenue',
                    '₹${grossRev.toStringAsFixed(0)}',
                    BrandColors.primaryBlue,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    'COGS',
                    '₹${cogs.toStringAsFixed(0)}',
                    BrandColors.yellowDark,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    'Operating Exp.',
                    '₹${expenses.toStringAsFixed(0)}',
                    BrandColors.redDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Divider(color: BrandColors.border),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Net Profit / Loss',
                      style: TextStyle(
                        fontSize: 11,
                        color: BrandColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${netProfit.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isProfitable
                            ? BrandColors.greenDark
                            : BrandColors.redDark,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Produced: $unitsProd units',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BrandColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Dispatched: $unitsDisp units',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BrandColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: BrandColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}
