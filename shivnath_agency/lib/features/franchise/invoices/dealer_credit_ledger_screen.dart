import 'package:flutter/material.dart';

import '../../../core/services/InventoryService.dart';
import '../../../core/services/session_service.dart';
import '../../../models/user_model.dart';

/// Wholesale Dealer Credit Ledger & Aging Report Screen
/// Provides clear view of credit limit, outstanding balances,
/// payment terms (e.g. 15 days), aging breakdown, and invoices.
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
          'Dealer Credit & Billing Ledger',
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
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
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
                      'Wholesale Purchase Invoices',
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
    final creditLimit = double.tryParse(_creditProfile?['credit_limit']?.toString() ?? '0') ?? 0.0;
    final currentBalance = double.tryParse(_creditProfile?['current_balance']?.toString() ?? '0') ?? 0.0;
    final availableCredit = creditLimit - currentBalance;
    final paymentTerms = _creditProfile?['payment_terms_days']?.toString() ?? '15';
    final commissionPct = _creditProfile?['commission_percentage']?.toString() ?? '0';

    final percentUsed = creditLimit > 0 ? (currentBalance / creditLimit).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Terms: $paymentTerms Days Net',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Credit Limit',
                  'INR ${creditLimit.toStringAsFixed(0)}',
                  const Color(0xFF0F172A),
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Outstanding Balance',
                  'INR ${currentBalance.toStringAsFixed(0)}',
                  currentBalance > 0 ? Colors.red.shade700 : const Color(0xFF10B981),
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Available Credit',
                  'INR ${availableCredit.toStringAsFixed(0)}',
                  availableCredit > 0 ? const Color(0xFF10B981) : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentUsed,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                percentUsed > 0.85 ? Colors.red : const Color(0xFF0284C7),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Commission Rate: $commissionPct%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
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
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildAgingBreakdownCard() {
    final current = double.tryParse(_agingReport?['current']?.toString() ?? '0') ?? 0.0;
    final d1_15 = double.tryParse(_agingReport?['days_1_15']?.toString() ?? '0') ?? 0.0;
    final d16_30 = double.tryParse(_agingReport?['days_16_30']?.toString() ?? '0') ?? 0.0;
    final dOver30 = double.tryParse(_agingReport?['days_over_30']?.toString() ?? '0') ?? 0.0;

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
              Icon(Icons.history_rounded, size: 18, color: Color(0xFF0284C7)),
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
              _buildAgingPill('Current', current, const Color(0xFF10B981)),
              _buildAgingPill('1-15 Days', d1_15, Colors.amber.shade700),
              _buildAgingPill('16-30 Days', d16_30, Colors.orange.shade800),
              _buildAgingPill('> 30 Days', dOver30, Colors.red.shade700),
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              'INR ${amount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesList() {
    if (_invoices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No purchase invoices found.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Column(
      children: _invoices.map((inv) {
        final invNum = inv['invoice_number']?.toString() ?? 'INV';
        final total = double.tryParse(inv['total_amount']?.toString() ?? '0') ?? 0.0;
        final amountPaid = double.tryParse(inv['amount_paid']?.toString() ?? '0') ?? 0.0;
        final balance = total - amountPaid;
        final status = (inv['status']?.toString() ?? 'UNPAID').toUpperCase();
        final dueDateStr = inv['due_date']?.toString() ?? '';

        Color statusColor = Colors.red;
        if (status == 'PAID') statusColor = const Color(0xFF10B981);
        if (status == 'PARTIALLY_PAID') statusColor = Colors.orange;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.12),
              child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 22),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  invNum,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  'INR ${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Due: $dueDateStr',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  ],
                ),
                if (balance > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Balance: INR ${balance.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red.shade700),
                  ),
                ],
              ],
            ),
            trailing: balance > 0
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _openRecordPaymentDialog(inv),
                    child: const Text('Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  void _openRecordPaymentDialog(Map<String, dynamic> inv) {
    final invId = inv['id'];
    final total = double.tryParse(inv['total_amount']?.toString() ?? '0') ?? 0.0;
    final amountPaid = double.tryParse(inv['amount_paid']?.toString() ?? '0') ?? 0.0;
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Payment Amount (INR) *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: const [
                    DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('NEFT / RTGS / IMPS')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => method = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(labelText: 'UTR / Transaction Reference (Optional)'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                        if (amt <= 0) return;
                        setDlgState(() => isSubmitting = true);
                        final res = await _invService.recordPayment(invId, {
                          'amount': amt,
                          'payment_method': method,
                          'transaction_reference': refCtrl.text.trim(),
                        });
                        setDlgState(() => isSubmitting = false);
                        if (res['success'] == true) {
                          if (mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Payment recorded successfully!'), backgroundColor: Colors.green),
                            );
                            _loadData();
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirm Payment'),
              ),
            ],
          );
        },
      ),
    );
  }
}
