import 'package:flutter/material.dart';
import '../../../core/widgets/app_components.dart';

/// Modal dialog allowing the administrator to inspect all active pending orders
/// and pick the exact order they wish to review and fulfill.
///
/// Prevents accidental index-based navigation or defaulting to list[0].
class PendingOrdersPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> pendingOrders;
  final void Function(Map<String, dynamic> selectedOrder) onSelectOrder;
  final Future<void> Function()? onRefresh;

  const PendingOrdersPickerDialog({
    super.key,
    required this.pendingOrders,
    required this.onSelectOrder,
    this.onRefresh,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Map<String, dynamic>> pendingOrders,
    required void Function(Map<String, dynamic> selectedOrder) onSelectOrder,
    Future<void> Function()? onRefresh,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PendingOrdersPickerDialog(
        pendingOrders: pendingOrders,
        onSelectOrder: onSelectOrder,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<PendingOrdersPickerDialog> createState() => _PendingOrdersPickerDialogState();
}

class _PendingOrdersPickerDialogState extends State<PendingOrdersPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.pendingOrders.where((ord) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final code = (ord['order_id'] ?? ord['orderId'] ?? ord['order_code'] ?? 'ORD-${ord['id']}').toString().toLowerCase();
      final cust = (ord['customer_name'] ?? ord['client_name'] ?? ord['title'] ?? '').toString().toLowerCase();
      final amount = (ord['amount'] ?? ord['total_amount'] ?? '').toString().toLowerCase();
      return code.contains(q) || cust.contains(q) || amount.contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFB45309)], // Amber gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pending_actions_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACTION REQUIRED',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Pending Orders (${widget.pendingOrders.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Instruction Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFFFFFBEB),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.pendingOrders.length > 1
                          ? 'Select an exact order below to open its specific status & fulfillment screen.'
                          : '1 order awaiting fulfillment. Tap to open directly.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar (if multiple orders)
            if (widget.pendingOrders.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by order ID, customer name...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),

            // List of Pending Orders
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 44,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No pending orders match "$_searchQuery"'
                                  : 'No pending orders awaiting review.',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final ord = filtered[idx];
                        final rawId = ord['id'] is int ? ord['id'] as int : int.tryParse('${ord['id']}') ?? 0;
                        final code = (ord['order_id'] ?? ord['orderId'] ?? ord['order_code'] ?? 'ORD-$rawId')
                            .toString()
                            .replaceAll('#', '');
                        final custName = ord['customer_name']?.toString() ??
                            ord['client_name']?.toString() ??
                            ord['title']?.toString() ??
                            'Customer';
                        final amount = ord['total_amount']?.toString() ??
                            ord['amount']?.toString() ??
                            ord['grand_total']?.toString() ??
                            '0';
                        final items = ord['items_count']?.toString() ?? ord['items']?.toString() ?? '1';
                        final statusStr = ord['status_display']?.toString() ??
                            ord['status']?.toString() ??
                            'Order Placement';
                        final dateStr = ord['created_at']?.toString() ?? ord['order_date']?.toString() ?? '';
                        final source = ord['order_source'] == 'DIRECT_COMPANY'
                            ? 'Shivnath Plant (Direct)'
                            : (ord['franchise_name']?.toString() ?? 'Franchise Fulfilled');

                        return Material(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelectOrder(ord);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon Badge
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_rounded,
                                      color: Color(0xFFD97706),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              code,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            AppStatusBadge.order(statusStr, fontSize: 9.5),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          custName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF334155),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Source: $source ${dateStr.isNotEmpty ? '• $dateStr' : ''}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              '₹$amount',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0369A1),
                                              ),
                                            ),
                                            Text(
                                              '• $items Items',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Open Action Chevron
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'OPEN',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          SizedBox(width: 3),
                                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.pendingOrders.length} pending total',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
