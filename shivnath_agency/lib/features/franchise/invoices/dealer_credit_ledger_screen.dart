import 'package:flutter/material.dart';

import '../../../core/services/InventoryService.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../models/user_model.dart';

/// Franchise Credit Ledger & Aging Report Screen
/// Provides clear view of credit limit, outstanding balances,
/// payment terms, aging breakdown, and financial ledger.
class DealerCreditLedgerScreen extends StatefulWidget {
  const DealerCreditLedgerScreen({super.key});

  @override
  State<DealerCreditLedgerScreen> createState() =>
      _DealerCreditLedgerScreenState();
}

class _DealerCreditLedgerScreenState extends State<DealerCreditLedgerScreen> {
  final InventoryService _invService = InventoryService();
  final SessionService _sessionService = SessionService();

  bool _loading = false;
  String? _error;
  UserModel? _user;

  Map<String, dynamic>? _creditProfile;
  Map<String, dynamic>? _agingReport;
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _user = await _sessionService.getCurrentUser();
      final dealerId = int.tryParse(_user?.id ?? '0') ?? 0;

      // 1. Fetch credit profile
      if (dealerId > 0) {
        final cpRes = await _invService.getDealerCreditProfile(dealerId);
        if (cpRes['success'] == true && cpRes['data'] is Map<String, dynamic>) {
          _creditProfile = cpRes['data'] as Map<String, dynamic>;
        }

        // 2. Fetch aging report
        final arRes = await _invService.getDealerAgingReport(dealerId);
        if (arRes['success'] == true && arRes['data'] is Map<String, dynamic>) {
          _agingReport = arRes['data'] as Map<String, dynamic>;
        }
      }

      // 3. Fetch invoices
      final invRes = await _invService.getInvoices();
      if (invRes['success'] == true && invRes['data'] is List) {
        _invoices = List<Map<String, dynamic>>.from(invRes['data']);
      }
    } catch (e) {
      _error = 'Failed to load ledger data: $e';
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Franchise Credit & Ledger',
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
            icon: const Icon(Icons.refresh_rounded, color: BrandColors.greenDark),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: BrandColors.greenDark),
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
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BrandColors.greenDark,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildCreditOverviewCard(),
                    const SizedBox(height: 16),
                    _buildAgingBreakdownCard(),
                    const SizedBox(height: 20),
                    const Text(
                      'Franchise Invoices & Billing Ledger',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildInvoicesList(),
                  ],
                ),
    );
  }

  Widget _buildCreditOverviewCard() {
    final creditLimit =
        double.tryParse(_creditProfile?['credit_limit']?.toString() ?? '0') ??
            0.0;
    final currentBalance =
        double.tryParse(_creditProfile?['current_balance']?.toString() ?? '0') ??
            0.0;
    final availableCredit = creditLimit - currentBalance;
    final paymentTerms =
        _creditProfile?['payment_terms_days']?.toString() ?? '15';
    final commissionPct =
        _creditProfile?['commission_percentage']?.toString() ?? '0';

    final d16_30 =
        double.tryParse(_agingReport?['days_16_30']?.toString() ?? '0') ?? 0.0;
    final dOver30 =
        double.tryParse(_agingReport?['days_over_30']?.toString() ?? '0') ??
            0.0;
    final overdueAmount = d16_30 + dOver30;

    final percentUsed =
        creditLimit > 0 ? (currentBalance / creditLimit).clamp(0.0, 1.0) : 0.0;

    final isOverdue = overdueAmount > 0;
    final creditStatus = isOverdue
        ? 'OVERDUE'
        : (percentUsed >= 1.0 ? 'LIMIT REACHED' : 'HEALTHY');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Credit Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? BrandColors.redSoft
                          : BrandColors.greenSoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isOverdue ? BrandColors.red : BrandColors.green,
                      ),
                    ),
                    child: Text(
                      creditStatus,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isOverdue
                            ? BrandColors.redDark
                            : BrandColors.greenDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BrandColors.greenSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$paymentTerms Days Net',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.greenDark,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Credit Limit',
                  '₹${creditLimit.toStringAsFixed(0)}',
                  const Color(0xFF0F172A),
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Outstanding',
                  '₹${currentBalance.toStringAsFixed(0)}',
                  currentBalance > 0
                      ? BrandColors.redDark
                      : BrandColors.greenDark,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Available Credit',
                  '₹${availableCredit.toStringAsFixed(0)}',
                  availableCredit > 0
                      ? BrandColors.greenDark
                      : BrandColors.redDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (overdueAmount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: BrandColors.red),
                  const SizedBox(width: 6),
                  Text(
                    'Overdue Amount: ₹${overdueAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: BrandColors.redDark,
                    ),
                  ),
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentUsed,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                percentUsed > 0.85 ? BrandColors.red : BrandColors.greenDark,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Margin / Commission: $commissionPct%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                '${(percentUsed * 100).toStringAsFixed(0)}% credit utilized',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAgingBreakdownCard() {
    final current =
        double.tryParse(_agingReport?['current']?.toString() ?? '0') ?? 0.0;
    final d1_15 =
        double.tryParse(_agingReport?['days_1_15']?.toString() ?? '0') ?? 0.0;
    final d16_30 =
        double.tryParse(_agingReport?['days_16_30']?.toString() ?? '0') ?? 0.0;
    final dOver30 =
        double.tryParse(_agingReport?['days_over_30']?.toString() ?? '0') ??
            0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: BrandColors.greenDark),
              SizedBox(width: 8),
              Text(
                'Payment Aging Analysis',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildAgingPill('Current', current, BrandColors.greenDark),
              _buildAgingPill('1-15 Days', d1_15, BrandColors.yellowDark),
              _buildAgingPill('16-30 Days', d16_30, BrandColors.yellowDark),
              _buildAgingPill('> 30 Days', dOver30, BrandColors.redDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgingPill(String title, double amount, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesList() {
    if (_invoices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BrandColors.border),
        ),
        child: const Text(
          'No purchase invoices found.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return Column(
      children: _invoices.map((inv) {
        final invNum = inv['invoice_number']?.toString() ?? 'INV';
        final total =
            double.tryParse(inv['total_amount']?.toString() ?? '0') ?? 0.0;
        final amountPaid =
            double.tryParse(inv['amount_paid']?.toString() ?? '0') ?? 0.0;
        final balance = total - amountPaid;
        final status = (inv['status']?.toString() ?? 'UNPAID').toUpperCase();
        final dueDateStr = inv['due_date']?.toString() ?? '';
        final invDateStr = inv['invoice_date']?.toString() ?? '';

        Color statusColor = BrandColors.redDark;
        if (status == 'PAID') statusColor = BrandColors.greenDark;
        if (status == 'PARTIALLY_PAID') statusColor = BrandColors.yellowDark;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          color: Colors.white,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BrandColors.border),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: statusColor.withOpacity(0.12),
                          child: Icon(Icons.receipt_long_rounded,
                              color: statusColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invNum,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: BrandColors.textPrimary,
                              ),
                            ),
                            if (invDateStr.isNotEmpty)
                              Text(
                                'Date: $invDateStr',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: BrandColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: BrandColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: BrandColors.border, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Due: $dueDateStr',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (balance > 0) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BrandColors.greenDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _openRecordPaymentDialog(inv),
                            child: const Text('Pay',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (balance > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Balance Due: ₹${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.redDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _openRecordPaymentDialog(Map<String, dynamic> inv) {
    final invId = inv['id'];
    final total =
        double.tryParse(inv['total_amount']?.toString() ?? '0') ?? 0.0;
    final amountPaid =
        double.tryParse(inv['amount_paid']?.toString() ?? '0') ?? 0.0;
    final balance = total - amountPaid;

    final amtCtrl = TextEditingController(text: balance.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    String method = 'UPI';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: Text('Record Payment for ${inv['invoice_number']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amtCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (INR)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                    DropdownMenuItem(
                        value: 'Bank Transfer',
                        child: Text('NEFT / RTGS / IMPS')),
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => method = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reference Number / UTR',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.greenDark,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                        if (amt <= 0) return;

                        setDlgState(() => isSubmitting = true);
                        final res = await _invService.recordInvoicePayment(
                          invoiceId: invId is int
                              ? invId
                              : int.parse(invId.toString()),
                          amount: amt,
                          paymentMethod: method,
                          referenceNumber: refCtrl.text.trim(),
                        );

                        if (!context.mounted) return;
                        Navigator.pop(dlgCtx);

                        if (res['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payment recorded successfully!'),
                              backgroundColor: BrandColors.greenDark,
                            ),
                          );
                          _loadData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message']?.toString() ??
                                  'Failed to record payment'),
                              backgroundColor: BrandColors.error,
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Payment'),
              ),
            ],
          );
        },
      ),
    );
  }
}
