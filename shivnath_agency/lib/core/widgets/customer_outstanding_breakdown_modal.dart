import 'package:flutter/material.dart';
import '../repositories/order_repository.dart';
import '../utils/contact_action_helper.dart';
import '../../features/customer/orders/order_detail_screen.dart';

class CustomerOutstandingBreakdownModal extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback? onPaymentSuccess;

  const CustomerOutstandingBreakdownModal({
    super.key,
    this.initialData,
    this.onPaymentSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? initialData,
    VoidCallback? onPaymentSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerOutstandingBreakdownModal(
        initialData: initialData,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<CustomerOutstandingBreakdownModal> createState() =>
      _CustomerOutstandingBreakdownModalState();
}

class _CustomerOutstandingBreakdownModalState
    extends State<CustomerOutstandingBreakdownModal> {
  final OrderRepository _orderRepo = OrderRepository();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null && widget.initialData!['success'] == true) {
      _data = widget.initialData;
      _isLoading = false;
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _orderRepo.getCustomerOutstanding();
      if (res['success'] == true) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              res['error']?.toString() ?? 'Unable to fetch outstanding details';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFF0284C7),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Outstanding Balance & Breakdown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Authoritative accounting ledger & collector attribution',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // Content Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'Loading verified ledger...',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _buildBreakdownView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Failed to load details',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownView() {
    final summary = (_data?['summary'] as Map<String, dynamic>?) ?? {};
    final contacts = (_data?['contacts'] as Map<String, dynamic>?) ?? {};
    final items = (_data?['items'] as List<dynamic>?) ?? [];

    final double totalOut = (summary['total_outstanding'] as num?)?.toDouble() ?? 0.0;
    final double franchiseOut = (summary['franchise_outstanding'] as num?)?.toDouble() ?? 0.0;
    final double adminOut = (summary['admin_outstanding'] as num?)?.toDouble() ?? 0.0;
    final double unverifiedOut = (summary['unverified_outstanding'] as num?)?.toDouble() ?? 0.0;

    final franchiseContact = (contacts['franchise'] as Map<String, dynamic>?) ?? {};
    final adminContact = (contacts['admin'] as Map<String, dynamic>?) ?? {};

    if (totalOut <= 0.05 && items.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 52,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Zero Outstanding Balance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All your water deliveries and bills are completely paid and reconciled. Thank you!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            _buildHelpSection(franchiseContact, adminContact, isZeroBalance: true),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      children: [
        // Total Outstanding Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFEF2F2), Color(0xFFFFF1F2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL OUTSTANDING DUE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${items.length} Pending ${items.length == 1 ? 'Bill' : 'Bills'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '₹${totalOut.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFFCA5A5), height: 1),
              const SizedBox(height: 10),

              // Collector Routing Subtotals
              Row(
                children: [
                  if (franchiseOut > 0)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF87171).withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payable to Franchise',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0369A1)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${franchiseOut.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (franchiseOut > 0 && adminOut > 0) const SizedBox(width: 8),
                  if (adminOut > 0)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF87171).withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payable to Admin Support',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${adminOut.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Unverified Balance Warning (if any)
        if (unverifiedOut > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Balance Under Verification: ₹${unverifiedOut.toStringAsFixed(2)} is under accounting audit. It is not an unexplained charge. Please contact Admin Support if you have questions.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Itemized Breakdown Heading
        const Text(
          'Itemized Outstanding Records',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),

        // Items List
        ...items.map((itemRaw) {
          final item = itemRaw is Map ? Map<String, dynamic>.from(itemRaw) : <String, dynamic>{};
          return _buildOutstandingItemCard(item);
        }),

        const SizedBox(height: 20),

        // Official Contact & Help Section
        _buildHelpSection(franchiseContact, adminContact, isZeroBalance: false),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOutstandingItemCard(Map<String, dynamic> item) {
    final orderCode = item['order_code']?.toString() ?? 'ORD-${item['order_id']}';
    final invoiceNumber = item['invoice_number']?.toString() ?? '';
    final orderDate = item['order_date']?.toString() ?? '';
    final reason = item['reason']?.toString() ?? 'Pending payment collection';
    final status = item['status']?.toString() ?? 'Delivered';
    final collectorRoleLabel = item['collector_role_label']?.toString() ?? 'Payable to Franchise';
    final collectorPhone = item['collector_phone']?.toString() ?? 'Contact number not configured';
    final collectorType = item['collector_type']?.toString() ?? 'FRANCHISE';
    final isFranchise = collectorType == 'FRANCHISE';

    final double origTotal = (item['original_order_total'] as num?)?.toDouble() ?? 0.0;
    final double amountPaid = (item['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final double remainingDue = (item['remaining_due'] as num?)?.toDouble() ?? 0.0;
    final products = (item['products'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order code and due badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        orderCode.startsWith('#') ? orderCode : '#$orderCode',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  'Due: ₹${remainingDue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),

          if (invoiceNumber.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Invoice: $invoiceNumber',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
            ),
          ],

          const SizedBox(height: 6),
          Text(
            'Date: $orderDate | Status: $status',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),

          // Product items breakdown
          if (products.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: products.map((p) {
                  final pMap = p is Map ? p : {};
                  final pName = pMap['product_name'] ?? 'Item';
                  final qty = pMap['quantity'] ?? 1;
                  final totalP = (pMap['total_price'] as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$pName × $qty',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${totalP.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 8),
          // Price breakdown row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Original Total: ₹${origTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              Text(
                'Paid: ₹${amountPaid.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
              ),
            ],
          ),

          const SizedBox(height: 6),
          // Reason / Explanation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Reason: $reason',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          // Collector responsibility badge & action
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isFranchise ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isFranchise ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isFranchise ? Icons.storefront_outlined : Icons.admin_panel_settings_outlined,
                  size: 15,
                  color: isFranchise ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    collectorRoleLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isFranchise ? const Color(0xFF15803D) : const Color(0xFFB45309),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (collectorPhone != 'Contact number not configured') ...[
                  InkWell(
                    onTap: () => ContactActionHelper.makePhoneCall(context, collectorPhone),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_in_talk_rounded, size: 12, color: Color(0xFF0284C7)),
                          SizedBox(width: 4),
                          Text('Call', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),
          // View full order button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF0284C7)),
              label: const Text(
                'View Order / Bill Details',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(
                      orderId: (item['order_code'] ?? item['order_id'] ?? '').toString(),
                      dbId: item['order_id'] is int ? item['order_id'] as int : int.tryParse(item['order_id']?.toString() ?? ''),
                      initialOrder: {
                        'id': item['order_id'],
                        'orderId': item['order_code'],
                        'amount': origTotal,
                        'payment_status': item['payment_status'],
                        'status': item['status'],
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(
    Map<String, dynamic> franchise,
    Map<String, dynamic> admin, {
    required bool isZeroBalance,
  }) {
    final franchiseName = franchise['name']?.toString() ?? 'Assigned Franchise';
    final franchisePhone = franchise['phone']?.toString() ?? 'Contact number not configured';
    final isFranchiseConfigured = franchise['is_configured'] == true &&
        franchisePhone != 'Contact number not configured' &&
        franchisePhone.isNotEmpty;

    final adminName = admin['name']?.toString() ?? 'Shivnath Support / Central Plant';
    final adminPhone = admin['phone']?.toString() ?? '+91 98062 47194';
    final isAdminConfigured = adminPhone.isNotEmpty && adminPhone != 'Contact number not configured';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent_rounded, color: Color(0xFF0284C7), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Payment Help & Official Support',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Direct verified contacts for payment reconciliation and settlement.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          // Franchise Contact Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(Icons.storefront_outlined, size: 18, color: Color(0xFF0284C7)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        franchiseName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isFranchiseConfigured ? franchisePhone : 'Contact number not configured',
                        style: TextStyle(
                          fontSize: 11,
                          color: isFranchiseConfigured ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                          fontWeight: isFranchiseConfigured ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isFranchiseConfigured) ...[
                  IconButton(
                    icon: const Icon(Icons.phone_forwarded_rounded, color: Color(0xFF10B981)),
                    tooltip: 'Call Franchise',
                    onPressed: () => ContactActionHelper.makePhoneCall(context, franchisePhone),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Admin Support Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFFEF3C7),
                  child: Icon(Icons.shield_outlined, size: 18, color: Color(0xFFD97706)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAdminConfigured ? adminPhone : 'Contact number not configured',
                        style: TextStyle(
                          fontSize: 11,
                          color: isAdminConfigured ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                          fontWeight: isAdminConfigured ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdminConfigured) ...[
                  IconButton(
                    icon: const Icon(Icons.phone_forwarded_rounded, color: Color(0xFF0284C7)),
                    tooltip: 'Call Admin Support',
                    onPressed: () => ContactActionHelper.makePhoneCall(context, adminPhone),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
