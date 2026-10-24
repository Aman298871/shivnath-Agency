import 'package:flutter/material.dart';

import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/inventory_repository.dart';
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
  final InventoryRepository _invService = InventoryRepository();
  final AuthRepository _authRepository = AuthRepository();

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
      _user = await _authRepository.getCachedUser();
      final dealerId = int.tryParse(_user?.id ?? '0') ?? 0;

      // 1. Fetch credit profile
      if (dealerId > 0) {
        final cpRes = await _invService.getDealerCreditProfile(dealerId);
        if (cpRes['success'] == true) {
          final data = cpRes['data'] is Map ? cpRes['data'] : cpRes;
          _creditProfile = data is Map ? Map<String, dynamic>.from(data) : {};
        }

        // 2. Fetch aging report
        final arRes = await _invService.getDealerAgingReport(dealerId);
        if (arRes['success'] == true) {
          final data = arRes['data'] is Map ? arRes['data'] : arRes;
          _agingReport = data is Map ? Map<String, dynamic>.from(data) : {};
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
            icon: const Icon(
              Icons.refresh_rounded,
              color: BrandColors.greenDark,
            ),
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
        double.tryParse(
          _creditProfile?['current_outstanding']?.toString() ??
          _creditProfile?['current_balance']?.toString() ?? '0',
        ) ??
        0.0;
    final availableCredit = _creditProfile?['available_credit'] != null
        ? (double.tryParse(_creditProfile!['available_credit'].toString()) ?? (creditLimit - currentBalance).clamp(0.0, double.infinity))
        : (creditLimit - currentBalance).clamp(0.0, double.infinity);
    final paymentTerms =
        _creditProfile?['payment_terms_days']?.toString() ?? '15';
    final commissionPct =
        _creditProfile?['commission_percentage']?.toString() ?? '0';

    final d16_30 =
        double.tryParse(
          _agingReport?['days_16_30']?.toString() ??
          _agingReport?['bucket_16_to_30']?.toString() ?? '0',
        ) ?? 0.0;
    final dOver30 =
        double.tryParse(
          _agingReport?['days_over_30']?.toString() ??
          _agingReport?['bucket_60_plus']?.toString() ?? '0',
        ) ??
        0.0;
    final overdueAmount = d16_30 + dOver30;

    final percentUsed = creditLimit > 0
        ? (currentBalance / creditLimit).clamp(0.0, 1.0)
        : 0.0;

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: BrandColors.red,
                  ),
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
        double.tryParse(
          _agingReport?['days_1_15']?.toString() ??
          _agingReport?['current_terms_bucket']?.toString() ??
          _agingReport?['current']?.toString() ?? '0',
        ) ?? 0.0;
    final d1_15 =
        double.tryParse(
          _agingReport?['days_1_15']?.toString() ??
          _agingReport?['current_terms_bucket']?.toString() ?? '0',
        ) ?? 0.0;
    final d16_30 =
        double.tryParse(
          _agingReport?['days_16_30']?.toString() ??
          _agingReport?['bucket_16_to_30']?.toString() ?? '0',
        ) ?? 0.0;
    final dOver30 =
        double.tryParse(
          _agingReport?['days_over_30']?.toString() ??
          _agingReport?['bucket_60_plus']?.toString() ?? '0',
        ) ??
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
              Icon(
                Icons.history_rounded,
                size: 18,
                color: BrandColors.greenDark,
              ),
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
              _buildAgingPill(
                'Current',
                current,
                BrandColors.greenDark,
                context,
                description: 'Not yet overdue — within payment terms',
                advice: 'These invoices are within your payment window. Pay before the due date to avoid overdue charges.',
              ),
              _buildAgingPill(
                '1-15 Days',
                d1_15,
                BrandColors.yellowDark,
                context,
                description: 'Overdue by 1-15 days',
                advice: 'These invoices have recently gone past due. Pay now to avoid further delay charges and maintain a good credit standing.',
              ),
              _buildAgingPill(
                '16-30 Days',
                d16_30,
                BrandColors.yellowDark,
                context,
                description: 'Overdue by 16-30 days',
                advice: 'These invoices are significantly overdue. Immediate payment is required to avoid credit hold.',
              ),
              _buildAgingPill(
                '> 30 Days',
                dOver30,
                BrandColors.redDark,
                context,
                description: 'Overdue by more than 30 days',
                advice: 'Critical: These invoices are severely overdue and may result in credit suspension. Please contact admin immediately.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgingPill(String title, double amount, Color color, BuildContext context, {String description = '', String advice = ''}) {
    return Expanded(
      child: InkWell(
        onTap: () {
          // Filter invoices that belong to this aging bucket
          final bucketInvoices = _getInvoicesForBucket(title);

          showDialog(
            context: context,
            builder: (ctx) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.schedule_rounded, color: color, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
                              ),
                              Text(
                                description.isNotEmpty ? description : 'Aging bucket breakdown',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color),
                          ),
                          Text(
                            'Total in "$title" bucket',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    if (advice.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.tips_and_updates_rounded, size: 15, color: Color(0xFF16A34A)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                advice,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (bucketInvoices.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Invoices in this bucket (${bucketInvoices.length})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: bucketInvoices.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final inv = bucketInvoices[i];
                            final total = double.tryParse(inv['grand_total']?.toString() ?? inv['total_amount']?.toString() ?? '0') ?? 0.0;
                            final paid = double.tryParse(inv['amount_paid']?.toString() ?? '0') ?? 0.0;
                            final bal = (total - paid).clamp(0.0, total);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(Icons.receipt_outlined, size: 15, color: color),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          inv['invoice_number']?.toString() ?? 'INV',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                        if ((inv['due_date']?.toString() ?? '').isNotEmpty)
                                          Text(
                                            'Due: ${inv['due_date']}',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${bal.toStringAsFixed(0)} due',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ] else if (amount == 0) ...[
                      const SizedBox(height: 14),
                      const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                          SizedBox(width: 8),
                          Text('No outstanding in this bucket!', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: color.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Close', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(height: 2),
              Icon(Icons.touch_app_rounded, size: 11, color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns invoices that belong to a given aging bucket based on due date
  List<Map<String, dynamic>> _getInvoicesForBucket(String bucketTitle) {
    final now = DateTime.now();
    return _invoices.where((inv) {
      final status = (inv['status']?.toString() ?? '').toUpperCase();
      if (status == 'PAID') return false; // Paid invoices don't age

      final dueDateStr = inv['due_date']?.toString() ?? '';
      if (dueDateStr.isEmpty) return bucketTitle == 'Current';

      final dueDate = DateTime.tryParse(dueDateStr);
      if (dueDate == null) return false;

      final daysOverdue = now.difference(dueDate).inDays;

      switch (bucketTitle) {
        case 'Current':
          return daysOverdue <= 0; // Not yet overdue
        case '1-15 Days':
          return daysOverdue > 0 && daysOverdue <= 15;
        case '16-30 Days':
          return daysOverdue > 15 && daysOverdue <= 30;
        default: // > 30 Days
          return daysOverdue > 30;
      }
    }).toList();
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
            double.tryParse(inv['grand_total']?.toString() ?? inv['total_amount']?.toString() ?? '0') ?? 0.0;
        final amountPaid =
            double.tryParse(inv['amount_paid']?.toString() ?? '0') ?? 0.0;
        final balance = (total - amountPaid).clamp(0.0, total);
        final status = (inv['status']?.toString() ?? 'UNPAID').toUpperCase();
        final dueDateStr = inv['due_date']?.toString() ?? '';
        final invDateStr = inv['issued_at']?.toString().split('T').first ?? inv['invoice_date']?.toString().split('T').first ?? '';

        Color statusColor = BrandColors.redDark;
        String statusDisplay = 'UNPAID';
        IconData statusIcon = Icons.receipt_long_rounded;

        if (status == 'PAID') {
          statusColor = BrandColors.greenDark;
          statusDisplay = 'PAID';
          statusIcon = Icons.check_circle_outline_rounded;
        } else if (status == 'PARTIALLY_PAID') {
          statusColor = const Color(0xFFD97706);
          statusDisplay = 'PARTIALLY PAID';
          statusIcon = Icons.pie_chart_outline_rounded;
        } else if (status == 'PAYMENT_PENDING_VERIFICATION') {
          statusColor = const Color(0xFFD97706);
          statusDisplay = 'VERIFICATION PENDING';
          statusIcon = Icons.hourglass_top_rounded;
        }

        final isPendingVerification = (status == 'PAYMENT_PENDING_VERIFICATION');

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          color: Colors.white,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isPendingVerification ? const Color(0xFFFDE68A) : BrandColors.border,
                width: isPendingVerification ? 1.5 : 1.0,
              ),
              color: isPendingVerification ? const Color(0xFFFFFBEB) : Colors.white,
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
                          backgroundColor: statusColor.withValues(alpha: 0.12),
                          child: Icon(
                            statusIcon,
                            color: statusColor,
                            size: 18,
                          ),
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
                      dueDateStr.isNotEmpty ? 'Due: $dueDateStr' : 'Net Terms',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusDisplay,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (balance > 0 && !isPendingVerification) ...[
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
                            child: const Text(
                              'Pay Now',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (isPendingVerification) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: Color(0xFFB45309),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Payment submitted. Admin is verifying bank receipt.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (balance > 0) ...[
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
        double.tryParse(inv['grand_total']?.toString() ?? inv['total_amount']?.toString() ?? '0') ?? 0.0;
    final amountPaid =
        double.tryParse(inv['amount_paid']?.toString() ?? '0') ?? 0.0;
    final balance = (total - amountPaid).clamp(0.0, total);

    final amtCtrl = TextEditingController(text: balance.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String method = 'UPI';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            title: Row(
              children: [
                const Icon(Icons.payment_rounded, color: BrandColors.greenDark, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Submit Payment (${inv['invoice_number']})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Outstanding Balance:',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Text(
                          '₹${balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: BrandColors.redDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Payment Amount (INR) *',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'UPI',
                        child: Text('UPI (GPay / PhonePe / Paytm)'),
                      ),
                      DropdownMenuItem(
                        value: 'Bank Transfer',
                        child: Text('Bank Transfer (NEFT / RTGS / IMPS)'),
                      ),
                      DropdownMenuItem(
                        value: 'Cash',
                        child: Text('Cash Handover'),
                      ),
                      DropdownMenuItem(
                        value: 'Cheque',
                        child: Text('Cheque Deposit'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => method = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: refCtrl,
                    decoration: const InputDecoration(
                      labelText: 'UTR / Transaction Reference No *',
                      hintText: 'e.g. 423589123456 or Cheque #',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'e.g. Paid via ICICI bank',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Note: Admin will verify arrival of funds before updating your ledger.',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
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
                        if (amt <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid amount.'),
                              backgroundColor: BrandColors.error,
                            ),
                          );
                          return;
                        }
                        if (amt > balance) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Amount cannot exceed outstanding balance of ₹${balance.toStringAsFixed(2)}'),
                              backgroundColor: BrandColors.error,
                            ),
                          );
                          return;
                        }

                        final ref = refCtrl.text.trim();
                        if (ref.isEmpty && method != 'Cash') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter UTR or Transaction reference number for verification.'),
                              backgroundColor: BrandColors.error,
                            ),
                          );
                          return;
                        }

                        setDlgState(() => isSubmitting = true);
                        final res = await _invService.recordInvoicePayment(
                          invoiceId: invId is int
                              ? invId
                              : int.parse(invId.toString()),
                          amount: amt,
                          paymentMethod: method,
                          referenceNumber: ref,
                          notes: notesCtrl.text.trim(),
                        );

                        if (!context.mounted) return;
                        Navigator.pop(dlgCtx);

                        if (res['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res['message']?.toString() ??
                                    'Payment submitted! Admin will verify bank receipt.',
                              ),
                              backgroundColor: BrandColors.greenDark,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                          _loadData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res['message']?.toString() ??
                                    'Failed to submit payment',
                              ),
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
