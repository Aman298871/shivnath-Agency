import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/app_toast.dart';

class AdminPerformanceScreen extends StatefulWidget {
  const AdminPerformanceScreen({super.key});

  @override
  State<AdminPerformanceScreen> createState() => _AdminPerformanceScreenState();
}

class _AdminPerformanceScreenState extends State<AdminPerformanceScreen> {
  static const Color primaryBlue = Color(0xFF0284C7);
  final AuthService _authService = AuthService();

  String _selectedFilter = 'today';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isLoading = true;

  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _adminsList = [];

  final List<Map<String, String>> _dateFilters = [
    {'key': 'today', 'label': 'Today'},
    {'key': 'yesterday', 'label': 'Yesterday'},
    {'key': 'last_7_days', 'label': 'Last 7 Days'},
    {'key': 'this_month', 'label': 'This Month'},
    {'key': 'custom', 'label': 'Custom'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchPerformance();
  }

  Future<void> _fetchPerformance() async {
    setState(() => _isLoading = true);
    String? startStr;
    String? endStr;
    if (_selectedFilter == 'custom') {
      if (_customStartDate != null) startStr = _customStartDate!.toIso8601String().substring(0, 10);
      if (_customEndDate != null) endStr = _customEndDate!.toIso8601String().substring(0, 10);
    }

    final res = await _authService.getSuperAdminAdminPerformance(
      dateFilter: _selectedFilter,
      startDate: startStr,
      endDate: endStr,
    );

    if (mounted) {
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _summary = data['summary'] is Map ? Map<String, dynamic>.from(data['summary']) : {};
          _adminsList = data['admins'] is List ? List<Map<String, dynamic>>.from(data['admins']) : [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        AppToast.error(context, res['message'] ?? 'Failed to load performance metrics.');
      }
    }
  }

  void _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _customStartDate ?? now.subtract(const Duration(days: 7)),
        end: _customEndDate ?? now,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedFilter = 'custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _fetchPerformance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Admin Activity & Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Metrics',
            onPressed: _fetchPerformance,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Filter Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _dateFilters.map((f) {
                  final isSelected = _selectedFilter == f['key'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f['label']!),
                      selected: isSelected,
                      selectedColor: primaryBlue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      onSelected: (val) {
                        if (val) {
                          if (f['key'] == 'custom') {
                            _pickCustomDateRange();
                          } else {
                            setState(() => _selectedFilter = f['key']!);
                            _fetchPerformance();
                          }
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              // Summary KPI Grid
              const Text('Enterprise Operational Output',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  _kpiCard('Orders Handled', _summary['total_orders_handled'] ?? 0, Icons.shopping_bag_outlined, Colors.indigo),
                  _kpiCard('Orders Approved', _summary['orders_approved'] ?? 0, Icons.check_circle_outline, Colors.teal),
                  _kpiCard('Orders Prepared', _summary['orders_prepared'] ?? 0, Icons.inventory_2_outlined, Colors.blue),
                  _kpiCard('Dispatched', _summary['orders_dispatched'] ?? 0, Icons.local_shipping_outlined, Colors.amber.shade800),
                  _kpiCard('Delivered', _summary['orders_delivered'] ?? 0, Icons.done_all_rounded, Colors.green),
                  _kpiCard('Dealer Requests', _summary['dealer_stock_requests_reviewed'] ?? 0, Icons.swap_horiz_rounded, Colors.deepPurple),
                  _kpiCard('Leads Converted', _summary['leads_converted'] ?? 0, Icons.trending_up_rounded, Colors.orange.shade800),
                  _kpiCard('Follow-ups', _summary['followups_completed'] ?? 0, Icons.event_available_outlined, Colors.cyan.shade800),
                ],
              ),
              const SizedBox(height: 24),

              // Staff Output Breakdown
              const Text('Individual Staff Performance',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
              const SizedBox(height: 10),
              if (_adminsList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Center(
                    child: Text('No operational admin activity recorded in this date range.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _adminsList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final adm = _adminsList[i];
                    final perf = adm['performance'] is Map ? Map<String, dynamic>.from(adm['performance']) : {};

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: primaryBlue.withAlpha(20),
                                child: Text(
                                  (adm['name'] ?? adm['username'] ?? 'A').toString().substring(0, 1).toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: primaryBlue),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(adm['name'] ?? adm['username'] ?? 'Admin',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('${adm['email']} • ${(adm['role'] ?? 'admin').toString().toUpperCase()}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Chip(
                                label: Text(adm['data_scope'] ?? 'all_data', style: const TextStyle(fontSize: 10)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.blue.shade50,
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _metricBadge('Orders Handled', perf['orders_handled'] ?? 0),
                              _metricBadge('Approved', perf['orders_approved'] ?? 0),
                              _metricBadge('Prepared', perf['orders_prepared'] ?? 0),
                              _metricBadge('Dispatched', perf['orders_dispatched'] ?? 0),
                              _metricBadge('Delivered', perf['orders_delivered'] ?? 0),
                              _metricBadge('Dealer Requests', perf['dealer_requests_reviewed'] ?? 0),
                              _metricBadge('Leads Converted', perf['leads_converted'] ?? 0),
                              _metricBadge('Follow-ups', perf['followups_completed'] ?? 0),
                              _metricBadge('Adjustments', perf['inventory_adjustments'] ?? 0),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String title, dynamic count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(
            count.toString(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _metricBadge(String label, dynamic count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
