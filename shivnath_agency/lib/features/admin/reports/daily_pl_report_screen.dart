import 'package:flutter/material.dart';

import '../../../core/services/InventoryService.dart';

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

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _invService.getDailyBusinessReports();
      if (res['success'] == true && res['data'] is List) {
        _reports = List<Map<String, dynamic>>.from(res['data']);
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
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0284C7)),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
          : _error != null
              ? Center(child: Text(_error!))
              : _reports.isEmpty
                  ? const Center(
                      child: Text(
                        'No daily reports generated yet.\nReports are aggregated nightly via background command.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reports.length,
                      itemBuilder: (context, idx) {
                        return _buildReportCard(_reports[idx]);
                      },
                    ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> r) {
    final reportDate = r['report_date']?.toString() ?? 'Date';
    final grossRev = double.tryParse(r['gross_revenue']?.toString() ?? '0') ?? 0.0;
    final cogs = double.tryParse(r['cogs']?.toString() ?? '0') ?? 0.0;
    final grossProfit = double.tryParse(r['gross_profit']?.toString() ?? '0') ?? 0.0;
    final expenses = double.tryParse(r['total_operating_expenses']?.toString() ?? '0') ?? 0.0;
    final netProfit = double.tryParse(r['net_profit_or_loss']?.toString() ?? '0') ?? 0.0;
    final unitsProd = r['total_units_produced'] ?? 0;
    final unitsDisp = r['total_units_dispatched'] ?? 0;

    final isProfitable = netProfit >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Text(
                      reportDate,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isProfitable ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isProfitable ? Colors.green.shade200 : Colors.red.shade200),
                  ),
                  child: Text(
                    isProfitable ? 'NET PROFIT' : 'NET LOSS',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: isProfitable ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Metrics Grid
            Row(
              children: [
                Expanded(child: _buildMetric('Gross Revenue', 'INR ${grossRev.toStringAsFixed(0)}', const Color(0xFF0284C7))),
                Expanded(child: _buildMetric('Raw Material COGS', 'INR ${cogs.toStringAsFixed(0)}', Colors.orange.shade800)),
                Expanded(child: _buildMetric('Operating Exp.', 'INR ${expenses.toStringAsFixed(0)}', Colors.red.shade700)),
              ],
            ),
            const SizedBox(height: 14),

            const Divider(),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Net Profit / Loss', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text(
                      'INR ${netProfit.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isProfitable ? const Color(0xFF10B981) : Colors.red,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Produced: $unitsProd units', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('Dispatched: $unitsDisp units', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
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
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
