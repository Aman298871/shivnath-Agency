import 'package:flutter/material.dart';

import '../../../core/repositories/app_repositories.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/contact_action_helper.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/cancel_order_dialog.dart';

class FranchiseOrdersScreen extends StatefulWidget {
  const FranchiseOrdersScreen({super.key});

  @override
  State<FranchiseOrdersScreen> createState() => _FranchiseOrdersScreenState();
}

class _FranchiseOrdersScreenState extends State<FranchiseOrdersScreen> {
  final OrderRepository _orderRepository = OrderRepository();
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;

  String searchText = '';
  String selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => isLoading = true);
    final res = await _orderRepository.getOrders();
    if (!mounted) return;

    if (res['success'] == true && res['data'] is Map) {
      final rawOrders = res['data']['orders'];
      if (rawOrders is List) {
        final mapped = rawOrders.whereType<Map>().map((item) {
          final mappedItem = _orderRepository.mapOrder(
            Map<String, dynamic>.from(item),
          );
          final rawDbId = item['id'] is int
              ? item['id'] as int
              : (int.tryParse(item['id']?.toString() ?? '') ??
                    (mappedItem['id'] is int ? mappedItem['id'] as int : null));
          final rawId = mappedItem['orderId']?.toString();
          final fallbackId = rawDbId != null ? 'ORD-${1000 + rawDbId}' : '';
          final orderCode = (rawId != null && rawId.isNotEmpty)
              ? rawId
              : fallbackId;
          final rawItems = item['items'];
          final List<Map<String, dynamic>> itemsList = rawItems is List
              ? rawItems
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList()
              : (mappedItem['items_list'] is List
                    ? List<Map<String, dynamic>>.from(mappedItem['items_list'])
                    : []);

          final productDisplay = itemsList.isNotEmpty
              ? itemsList
                    .map(
                      (e) =>
                          '${e['product_name'] ?? e['name']} x${e['quantity'] ?? 1}',
                    )
                    .join(', ')
              : (mappedItem['franchise']?.toString().isNotEmpty == true
                    ? mappedItem['franchise']!.toString()
                    : 'Packaged Water');

          final double rawGrandTotal = double.tryParse(item['invoice_grand_total']?.toString() ?? item['grand_total']?.toString() ?? '') ?? 0.0;
          final double rawBaseAmount = double.tryParse(item['amount']?.toString() ?? mappedItem['amount']?.toString() ?? '0') ?? 0.0;
          final double totalAmt = rawGrandTotal > 0 ? rawGrandTotal : rawBaseAmount;

          final double rawAmtPaid = double.tryParse(item['amount_paid']?.toString() ?? mappedItem['amount_paid']?.toString() ?? '0') ?? 0.0;
          final double? rawOutstanding = double.tryParse(item['outstanding_balance']?.toString() ?? mappedItem['outstanding_balance']?.toString() ?? '') ??
              double.tryParse(item['outstanding_amount']?.toString() ?? mappedItem['outstanding_amount']?.toString() ?? '');

          final String paymentStatus = (item['payment_status'] ?? mappedItem['payment_status'] ?? '').toString().toLowerCase();
          final bool isExplicitlyPaid = paymentStatus == 'paid' ||
              mappedItem['payment_collected'] == true ||
              item['payment_collected'] == true ||
              (item['invoice_status']?.toString().toUpperCase() == 'PAID');

          final bool isSettledByMath = (totalAmt > 0 && rawAmtPaid >= totalAmt - 0.05) ||
              (rawOutstanding != null && rawOutstanding <= 0.05 && rawAmtPaid > 0);

          final bool isPaid = isExplicitlyPaid || isSettledByMath;

          final double amtPaid = isPaid ? totalAmt : rawAmtPaid;
          final double outstandingBal = isPaid
              ? 0.0
              : (rawOutstanding ?? (totalAmt - amtPaid).clamp(0.0, totalAmt));

          final bool isPartial = !isPaid && amtPaid > 0.05 && outstandingBal > 0.05;

          final String paymentLabel = isPaid
              ? 'PAYMENT COLLECTED'
              : (isPartial
                  ? 'PARTIALLY PAID'
                  : 'PAYMENT PENDING');

          final rawStatus = item['status']?.toString() ?? mappedItem['raw_status']?.toString() ?? mappedItem['status']?.toString() ?? 'plant_approval';
          final canonical = _orderRepository.canonicalStatus(rawStatus);
          final displayStatus = _orderRepository.getStatusLabel(canonical);

          return {
            'db_id': rawDbId,
            'id': orderCode,
            'date': mappedItem['date']?.toString() ?? '',
            'customer_name':
                item['created_by_name']?.toString() ??
                mappedItem['customer_name']?.toString() ??
                '',
            'customer_phone':
                item['customer_phone']?.toString() ??
                mappedItem['customer_phone']?.toString() ??
                item['phone']?.toString() ??
                '',
            'delivery_address':
                item['delivery_address']?.toString() ??
                mappedItem['delivery_address']?.toString() ??
                '',
            'product': productDisplay,
            'items_list': itemsList,
            'qty':
                mappedItem['items'] ??
                (itemsList.isNotEmpty ? itemsList.length : 1),
            'amount': totalAmt,
            'base_amount': rawBaseAmount,
            'subtotal': double.tryParse(item['invoice_subtotal']?.toString() ?? '') ?? rawBaseAmount,
            'tax_amount': double.tryParse(item['invoice_tax']?.toString() ?? '') ?? 0.0,
            'grand_total': totalAmt,
            'amount_paid': amtPaid,
            'outstanding_amount': outstandingBal,
            'outstanding_balance': outstandingBal,
            'payment_status': isPaid ? 'paid' : (isPartial ? 'partial' : 'pending'),
            'payment_collected': isPaid,
            'is_pending_verification': false,
            'raw_status': canonical,
            'status': displayStatus,
            'payment': paymentLabel,
            'city':
                item['city']?.toString() ??
                mappedItem['city']?.toString() ??
                '',
            'raw': item,
          };
        }).toList();

        setState(() {
          orders = mapped;
          isLoading = false;
        });
        return;
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  List<Map<String, dynamic>> get filteredOrders {
    final query = searchText.trim().toLowerCase();

    return orders.where((order) {
      final id = (order['id'] ?? '').toString().toLowerCase();

      final product = (order['product'] ?? '').toString().toLowerCase();

      final status = (order['status'] ?? '').toString();

      final matchesSearch =
          query.isEmpty || id.contains(query) || product.contains(query);

      final matchesStatus = selectedStatus == 'All' || status == selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;

        return desktop ? _buildDesktop() : _buildMobile();
      },
    );
  }

  // =========================================================
  // DESKTOP
  // =========================================================

  Widget _buildDesktop() {
    return Container(
      color: const Color(0xFFF6F7FB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1250),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _desktopHeader(),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Orders',
                        value: '${orders.length}',
                        subtitle: 'All orders',
                        icon: Icons.shopping_bag_outlined,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StatCard(
                        title: 'Pending Approval',
                        value:
                            '${orders.where((o) => ['plant_approval', 'order_placement', 'preparing', 'invoice_generated'].contains(_orderRepository.canonicalStatus(o['raw_status'] ?? o['status']))).length}',
                        subtitle: 'Action required',
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StatCard(
                        title: 'Dispatched',
                        value:
                            '${orders.where((o) => _orderRepository.canonicalStatus(o['raw_status'] ?? o['status']) == 'dispatch').length}',
                        subtitle: 'In transit',
                        icon: Icons.local_shipping_outlined,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StatCard(
                        title: 'Delivered',
                        value:
                            '${orders.where((o) => _orderRepository.canonicalStatus(o['raw_status'] ?? o['status']) == 'delivered').length}',
                        subtitle: 'Completed',
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                _buildPendingOrdersSection(),

                _desktopFilters(),

                const SizedBox(height: 18),

                _desktopOrdersTable(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingOrdersSection() {
    final pending = orders.where((o) {
      final s = _orderRepository.canonicalStatus(o['raw_status'] ?? o['status']);
      return s == 'plant_approval' || s == 'order_placement' || s == 'preparing' || s == 'invoice_generated';
    }).toList();

    if (pending.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Text(
                'Actionable Pending Orders (${pending.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 94,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pending.length,
              separatorBuilder: (_, index) => const SizedBox(width: 10),
              itemBuilder: (ctx, idx) {
                final ord = pending[idx];
                return InkWell(
                  onTap: () => _details(ord),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${ord['id']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            AppStatusBadge.order(ord['raw_status'] ?? ord['status'], fontSize: 9),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ord['customer_name']?.toString() ?? 'Customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${_formatAmount(ord['amount'])} • ${ord['product']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                      ],
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

  Widget _desktopHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Orders',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Track and manage franchise orders.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),

        const SizedBox(width: 20),

        IconButton(
          tooltip: 'Refresh Orders',
          onPressed: _fetchOrders,
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0284C7)),
        ),

        const SizedBox(width: 10),

        SizedBox(
          width: 180,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _newOrder,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Place New Order'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 44),
              maximumSize: const Size(180, 44),
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search order ID or product...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF0284C7)),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          Container(
            width: 210,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value:
                    const [
                      'All',
                      'Plant Approval',
                      'Invoice Generated',
                      'Dispatched',
                      'Delivered',
                    ].contains(selectedStatus)
                    ? selectedStatus
                    : 'All',
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'All',
                    child: Text('All Status', overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
                  DropdownMenuItem(
                    value: 'Plant Approval',
                    child: Text('Plant Approval', overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
                  DropdownMenuItem(
                    value: 'Invoice Generated',
                    child: Text('Invoice Generated', overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
                  DropdownMenuItem(
                    value: 'Dispatched',
                    child: Text('Dispatched', overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
                  DropdownMenuItem(
                    value: 'Delivered',
                    child: Text('Delivered', overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    selectedStatus = value;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopOrdersTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _tableHeader(),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 55),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 55),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 55,
                    color: Color(0xFFCBD5E1),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No orders found',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          else
            ...filteredOrders.map((order) => _desktopOrderRow(order)),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: const Row(
        children: [
          SizedBox(width: 55),

          Expanded(flex: 2, child: Text('ORDER', style: _tableHeaderStyle)),

          Expanded(flex: 2, child: Text('PRODUCT', style: _tableHeaderStyle)),

          Expanded(child: Text('QTY', style: _tableHeaderStyle)),

          Expanded(child: Text('AMOUNT', style: _tableHeaderStyle)),

          Expanded(flex: 2, child: Text('STATUS', style: _tableHeaderStyle)),

          Expanded(child: Text('PAYMENT', style: _tableHeaderStyle)),

          SizedBox(width: 55),
        ],
      ),
    );
  }

  Widget _desktopOrderRow(Map<String, dynamic> order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          SizedBox(width: 55, child: _orderIcon()),

          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order['id']}',
                  style: const TextStyle(
                    color: Color(0xFF0284C7),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${order['date']}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              '${order['product']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),

          Expanded(
            child: Text(
              '${order['qty']}',
              style: const TextStyle(fontSize: 11),
            ),
          ),

          Expanded(
            child: Text(
              '₹${_formatAmount(order['amount'])}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),

          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _statusBadge('${order['status']}'),
            ),
          ),

          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _paymentBadge('${order['payment']}'),
            ),
          ),

          SizedBox(
            width: 120,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((double.tryParse(order['outstanding_amount']?.toString() ?? '0') ?? 0) > 0)
                  IconButton(
                    tooltip: 'Collect Payment',
                    onPressed: () => _showCollectPaymentDialog(order),
                    icon: const Icon(
                      Icons.payment_rounded,
                      size: 20,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                IconButton(
                  tooltip: 'Update Status',
                  onPressed: () {
                    _showUpdateStatusDialog(order);
                  },
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    size: 20,
                    color: Color(0xFF0284C7),
                  ),
                ),
                IconButton(
                  tooltip: 'View Details',
                  onPressed: () {
                    _details(order);
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MOBILE
  // =========================================================

  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _fetchOrders,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newOrder,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Order'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOrders,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search orders...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _MobileStat(
                      title: 'Total',
                      value: '${orders.length}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MobileStat(
                      title: 'Pending',
                      value:
                          '${orders.where((o) => ['plant_approval', 'order_placement', 'preparing', 'invoice_generated'].contains(_orderRepository.canonicalStatus(o['raw_status'] ?? o['status']))).length}',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _MobileStat(
                      title: 'Dispatched',
                      value:
                          '${orders.where((o) => _orderRepository.canonicalStatus(o['raw_status'] ?? o['status']) == 'dispatch').length}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MobileStat(
                      title: 'Delivered',
                      value:
                          '${orders.where((o) => _orderRepository.canonicalStatus(o['raw_status'] ?? o['status']) == 'delivered').length}',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              _buildPendingOrdersSection(),

              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (filteredOrders.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Color(0xFFCBD5E1),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No orders found',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap "New Order" below or "Order" in Products.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...filteredOrders.map((order) => _mobileOrderCard(order)),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileOrderCard(Map<String, dynamic> order) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        onTap: () {
          _details(order);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _orderIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order['id']}',
                        style: const TextStyle(
                          color: Color(0xFF0284C7),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${order['date']}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              '${order['product']}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order['qty']} Qty',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                Text(
                  '₹${_formatAmount(order['amount'])}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _statusBadge('${order['status']}'),
                    _paymentBadge('${order['payment']}'),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ((double.tryParse(order['outstanding_amount']?.toString() ?? '0') ?? 0) > 0)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.payment_rounded, size: 15),
                        label: const Text('Collect', style: TextStyle(fontSize: 12)),
                        onPressed: () => _showCollectPaymentDialog(order),
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFFBAE6FD)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text('Update', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showUpdateStatusDialog(order),
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

  // =========================================================
  // NEW ORDER
  // =========================================================

  Future<void> _newOrder() async {
    final List<Map<String, dynamic>> productOptions = [
      {
        'id': '1',
        'name': 'Shivnath 200ml Event Bottle',
        'sku': 'SHV-200',
        'is_bottle': true,
        'units_per_case': 24,
        'rate': 3.50,
        'label': '200ml Bottle (24 btls/box) — ₹3.50/btl (₹84/box)',
      },
      {
        'id': '2',
        'name': 'Shivnath 250ml Mini Bottle',
        'sku': 'SHV-250',
        'is_bottle': true,
        'units_per_case': 24,
        'rate': 4.00,
        'label': '250ml Bottle (24 btls/box) — ₹4.00/btl (₹96/box)',
      },
      {
        'id': '3',
        'name': 'Shivnath 500ml Travel Bottle',
        'sku': 'SHV-500',
        'is_bottle': true,
        'units_per_case': 24,
        'rate': 7.00,
        'label': '500ml Bottle (24 btls/box) — ₹7.00/btl (₹168/box)',
      },
      {
        'id': '4',
        'name': 'Shivnath 1 Litre Premium Mineral Bottle',
        'sku': 'SHV-1L',
        'is_bottle': true,
        'units_per_case': 12,
        'rate': 14.00,
        'label': '1 Litre Bottle (12 btls/box) — ₹14.00/btl (₹168/box)',
      },
      {
        'id': '5',
        'name': 'Shivnath 20 Litre Dispenser Jar',
        'sku': 'SHV-20L',
        'is_bottle': false,
        'units_per_case': 1,
        'rate': 40.00,
        'label': '20 Litre Water Jar — ₹40.00/jar',
      },
    ];

    Map<String, dynamic> selectedOption = productOptions[2]; // 500ml default
    final quantityController = TextEditingController(text: '5');
    final notesController = TextEditingController();
    bool isSubmitting = false;
    bool orderPlaced = false;
    int placedUnits = 0;
    String placedProduct = '';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogInnerContext, setDialogState) {
            final int enteredBoxesOrJars = int.tryParse(quantityController.text.trim()) ?? 0;
            final isBottle = selectedOption['is_bottle'] == true;
            final unitsPerCase = (selectedOption['units_per_case'] as int?) ?? 1;
            final double rate = (selectedOption['rate'] as num?)?.toDouble() ?? 20.0;
            final int requiredMoq = (selectedOption['min_order_quantity'] as int?) ?? 5;
            final bool meetsMoq = enteredBoxesOrJars >= requiredMoq;
            final int totalBottlesOrJars = isBottle ? (enteredBoxesOrJars * unitsPerCase) : enteredBoxesOrJars;
            final double subtotal = totalBottlesOrJars * rate;

            return AlertDialog(
              actionsOverflowDirection: VerticalDirection.down,
              actionsOverflowButtonSpacing: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF0284C7)),
                  SizedBox(width: 8),
                  Text('Place Plant Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedOption['sku'] as String,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Product',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: productOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt['sku'] as String,
                            child: Text(
                              opt['label'] as String,
                              style: const TextStyle(fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedOption = productOptions.firstWhere(
                              (opt) => opt['sku'] == value,
                              orElse: () => productOptions.first,
                            );
                          });
                        },
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isBottle ? 'Order Quantity (in Boxes / Cartons)' : 'Order Quantity (in Jars)',
                          hintText: 'Minimum 5 ${isBottle ? 'boxes' : 'jars'}',
                          border: const OutlineInputBorder(),
                          helperText: isBottle
                              ? '1 Box = $unitsPerCase bottles (Min 5 boxes = ${5 * unitsPerCase} bottles)'
                              : '1 Unit = 1 Water Jar (Min 5 jars)',
                          helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF0284C7)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),

                      const SizedBox(height: 12),

                      if (!meetsMoq)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Minimum order is $requiredMoq ${isBottle ? 'boxes (${requiredMoq * unitsPerCase} bottles)' : 'jars'}. Franchise protection requires economical batch deliveries.',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Units:', style: TextStyle(fontSize: 12, color: Color(0xFF166534))),
                                Text(
                                  isBottle
                                      ? '$enteredBoxesOrJars Boxes ($totalBottlesOrJars Bottles)'
                                      : '$enteredBoxesOrJars Jars',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Dealer Transfer Rate:', style: TextStyle(fontSize: 12, color: Color(0xFF166534))),
                                Text(
                                  isBottle ? '₹${rate.toStringAsFixed(2)} / bottle' : '₹${rate.toStringAsFixed(2)} / jar',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF14532D)),
                                ),
                              ],
                            ),
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Estimated Order Total:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                                Text(
                                  '₹${subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Notes (Optional)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: meetsMoq ? const Color(0xFF0284C7) : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: (!meetsMoq || isSubmitting)
                      ? null
                      : () async {
                          final count = int.tryParse(quantityController.text.trim()) ?? 0;
                          if (count < 5) return;

                          setDialogState(() => isSubmitting = true);

                          final user = await SessionService().getCurrentUser();
                          final franchiseName = user?.businessName.isNotEmpty == true
                              ? user!.businessName
                              : (user?.name.isNotEmpty == true ? user!.name : 'Franchise Partner');
                          final city = user?.city.isNotEmpty == true ? user!.city : 'Raipur';

                          final int totalUnits = isBottle ? (count * unitsPerCase) : count;
                          final double totalAmount = totalUnits * rate;
                          final prodId = int.tryParse(selectedOption['id']?.toString() ?? '1') ?? 1;

                          final res = await _orderRepository.createOrder({
                            'franchise': franchiseName,
                            'city': city,
                            'items': totalUnits,
                            'amount': totalAmount,
                            'order_source': 'FRANCHISE',
                            'product_id': prodId,
                            'order_items': [
                              {
                                'product_id': prodId,
                                'quantity': totalUnits,
                                'price': rate,
                              }
                            ],
                            'order_notes': notesController.text.trim(),
                            'status': 'Plant Approval',
                            'payment': 'Pending',
                            'payment_mode': 'PAY_ON_DELIVERY',
                          });

                          if (!dialogContext.mounted) return;

                          if (res['success'] == true) {
                            orderPlaced = true;
                            placedUnits = totalUnits;
                            placedProduct = selectedOption['name'] as String;
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } else {
                            setDialogState(() => isSubmitting = false);
                            final msg = res['message'] ?? 'Failed to place order';
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(msg.toString()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(meetsMoq ? 'Place Order (₹${subtotal.toStringAsFixed(0)})' : 'Min $requiredMoq Required'),
                ),
              ],
            );
          },
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      quantityController.dispose();
      notesController.dispose();
    });

    if (orderPlaced && mounted) {
      await _fetchOrders();
      if (!mounted) return;
      AppToast.success(
        context,
        'Order of $placedUnits units ($placedProduct) placed successfully!',
      );
    }
  }

  // =========================================================
  // DETAILS
  // =========================================================

  void _details(Map<String, dynamic> order) {
    final rawItems = order['items_list'];
    final List<Map<String, dynamic>> itemsList = rawItems is List
        ? List<Map<String, dynamic>>.from(rawItems)
        : [];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          title: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Order ${order['id']}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Order ID', '${order['id']}'),
                  _detailRow('Date', '${order['date']}'),
                  if ((order['customer_name'] ?? '').toString().isNotEmpty)
                    _detailRow('Customer', '${order['customer_name']}'),
                  if ((order['customer_phone'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 120,
                            child: Text(
                              'Phone',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${order['customer_phone']}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Call Customer',
                            icon: const Icon(Icons.call, size: 18, color: Color(0xFF0284C7)),
                            onPressed: () => ContactActionHelper.makePhoneCall(
                              dialogContext,
                              order['customer_phone']?.toString(),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Chat / SMS',
                            icon: const Icon(Icons.chat_outlined, size: 18, color: Color(0xFF16A34A)),
                            onPressed: () => ContactActionHelper.openMessagingChooser(
                              dialogContext,
                              phone: order['customer_phone']?.toString(),
                              contactName: order['customer_name']?.toString(),
                              defaultMessage: 'Hello ${order['customer_name'] ?? 'Customer'}, regarding your order #${order['id']}...',
                            ),
                          ),
                        ],
                      ),
                    ),
                  if ((order['delivery_address'] ?? '').toString().isNotEmpty)
                    _detailRow(
                      'Delivery Address',
                      '${order['delivery_address']}',
                    ),
                  if ((order['city'] ?? '').toString().isNotEmpty)
                    _detailRow('City', '${order['city']}'),
                  _detailRow('Status', '${order['status']}'),
                  _detailRow('Payment', '${order['payment']}'),
                  _detailRow('Paid Amount', '₹${_formatAmount(order['amount_paid'])}'),
                  _detailRow('Outstanding', '₹${_formatAmount(order['outstanding_amount'])}'),
                  const SizedBox(height: 12),
                  const Text(
                    'Ordered Products',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (itemsList.isEmpty)
                    _detailRow(
                      'Items Summary',
                      '${order['product']} (${order['qty']} items)',
                    )
                  else
                    ...itemsList.map((item) {
                      final name =
                          item['product_name'] ??
                          item['name'] ??
                          'Packaged Water';
                      final size = item['size'] ?? '';
                      final qty = item['quantity'] ?? 1;
                      final unitPrice =
                          item['unit_price'] ?? item['price'] ?? 0;
                      final totalPrice =
                          item['total_price'] ??
                          (double.tryParse(unitPrice.toString()) ?? 0) *
                              (int.tryParse(qty.toString()) ?? 1);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.water_drop_rounded,
                              size: 16,
                              color: Color(0xFF0284C7),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (size.toString().isNotEmpty)
                                    Text(
                                      'Size: $size | Qty: $qty',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '₹$totalPrice',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 10),
                  _detailRow(
                    'Total Amount',
                    '₹${_formatAmount(order['amount'])}',
                  ),
                  const SizedBox(height: 18),
                  _orderProgress(
                    '${order['status']}',
                    isPaid: order['payment_collected'] == true || order['payment_status'] == 'paid',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if ((double.tryParse(order['outstanding_amount']?.toString() ?? '0') ?? 0) > 0)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showCollectPaymentDialog(order);
                },
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: const Text('Collect Payment'),
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _showUpdateStatusDialog(order);
              },
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Update Status'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateStatusDialog(Map<String, dynamic> order) {
    final int? dbId = order['db_id'] as int?;
    if (dbId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot update status: missing order ID')),
      );
      return;
    }

    final double totalAmount = double.tryParse(order['amount']?.toString() ?? '0') ?? 0.0;
    final String paymentStatus = (order['payment_status'] ?? '').toString().toLowerCase();
    final bool isPaidInitial = order['payment_collected'] == true ||
        paymentStatus == 'paid' ||
        (order['payment']?.toString().toLowerCase() == 'paid');

    final double alreadyPaid = isPaidInitial
        ? totalAmount
        : (double.tryParse(order['amount_paid']?.toString() ?? '0') ?? 0.0);
    double maxOutstanding = isPaidInitial
        ? 0.0
        : (double.tryParse(order['outstanding_balance']?.toString() ?? '') ??
            double.tryParse(order['outstanding_amount']?.toString() ?? '') ??
            ((totalAmount - alreadyPaid) > 0 ? (totalAmount - alreadyPaid) : 0.0));

    final String rawStatus = order['raw_status']?.toString() ?? order['status']?.toString() ?? 'plant_approval';
    final String currentCanonical = _orderRepository.canonicalStatus(rawStatus);
    List<String> statusOptions = _orderRepository.getAllowedNextStatuses(currentCanonical);
    final bool isDelivered = currentCanonical == 'delivered';

    if (statusOptions.isEmpty) {
      if (isDelivered) {
        statusOptions = ['delivered'];
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Expanded(child: Text('Terminal Status')),
              ],
            ),
            content: Text(
              'Order #${order['id']} is currently in "${_orderRepository.getStatusLabel(currentCanonical)}".\n\n'
              'This order has reached a terminal state and cannot be transitioned to any other fulfillment stage.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    String selectedNewStatus = statusOptions.first;

    bool isOrderPaid = isPaidInitial || maxOutstanding <= 0.001;
    bool collectPayment = isOrderPaid;
    String paymentType = 'FULL'; // FULL, PARTIAL
    String paymentMode = 'CASH'; // CASH, UPI, BANK_TRANSFER, CHEQUE, OTHER
    final amountController = TextEditingController(text: maxOutstanding.toStringAsFixed(2));
    final refController = TextEditingController();
    final notesController = TextEditingController();
    bool isSubmitting = false;
    bool fetchedLiveBalance = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          if (!fetchedLiveBalance) {
            fetchedLiveBalance = true;
            _orderRepository.getOrderPayments(dbId).then((res) {
              if (res['success'] == true && res['data'] is Map) {
                final data = res['data'] as Map;
                final liveOutstanding = double.tryParse(data['outstanding_balance']?.toString() ?? '');
                final liveStatus = (data['payment_status'] ?? '').toString().toUpperCase();
                final liveCollected = data['payment_collected'] == true || liveStatus == 'PAID' || (liveOutstanding != null && liveOutstanding <= 0.001);

                if (ctx.mounted) {
                  setDlgState(() {
                    if (liveCollected) {
                      isOrderPaid = true;
                      collectPayment = true;
                      maxOutstanding = 0.0;
                      amountController.text = '0.00';
                    } else if (liveOutstanding != null) {
                      maxOutstanding = liveOutstanding;
                      if (paymentType == 'FULL' || amountController.text == totalAmount.toStringAsFixed(2) || amountController.text == '0.00') {
                        amountController.text = maxOutstanding.toStringAsFixed(2);
                      }
                    }
                  });
                }
              }
            });
          }
          final enteredAmount = double.tryParse(amountController.text) ?? 0.0;
          final remainingAfterPayment = (maxOutstanding - enteredAmount).clamp(0.0, maxOutstanding);

          return AlertDialog(
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.local_shipping_outlined, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Update Status (#${order['id']})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 480,
                maxHeight: MediaQuery.of(ctx).size.height * 0.72,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select the new fulfillment status for this customer order:',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 14),

                    // Fulfillment Status Dropdown
                    if (isDelivered)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Fulfillment Status: Delivered',
                                style: TextStyle(
                                  color: Color(0xFF166534),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: statusOptions.contains(selectedNewStatus)
                            ? selectedNewStatus
                            : statusOptions.first,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Fulfillment Status',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.local_shipping_outlined),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: statusOptions
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  _orderRepository.getStatusLabel(s),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() {
                              selectedNewStatus = val;
                              if (val == 'delivered' && maxOutstanding > 0 && !collectPayment) {
                                collectPayment = true;
                                amountController.text = maxOutstanding.toStringAsFixed(2);
                              }
                            });
                          }
                        },
                      ),

                    // Integrated Payment Collection Option
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isOrderPaid
                            ? const Color(0xFFF0FDF4)
                            : (collectPayment ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isOrderPaid
                              ? const Color(0xFF86EFAC)
                              : (collectPayment ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: isOrderPaid ? true : collectPayment,
                                  activeColor: const Color(0xFF16A34A),
                                  onChanged: isOrderPaid
                                      ? null
                                      : (val) {
                                          setDlgState(() {
                                            collectPayment = val ?? false;
                                            if (collectPayment) {
                                              amountController.text = maxOutstanding.toStringAsFixed(2);
                                            }
                                          });
                                        },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: isOrderPaid
                                      ? null
                                      : () {
                                          setDlgState(() {
                                            collectPayment = !collectPayment;
                                            if (collectPayment) {
                                              amountController.text = maxOutstanding.toStringAsFixed(2);
                                            }
                                          });
                                        },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            isOrderPaid ? 'Payment Collected' : 'Record Payment Collected',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (isOrderPaid) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'PAYMENT COLLECTED',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF166534),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        isOrderPaid
                                            ? 'Fully Collected (₹${totalAmount.toStringAsFixed(2)}) • Franchise Direct Collection'
                                            : 'Due: ₹${maxOutstanding.toStringAsFixed(2)} (Total: ₹${totalAmount.toStringAsFixed(2)})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isOrderPaid ? const Color(0xFF166534) : const Color(0xFF64748B),
                                          fontWeight: isOrderPaid ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (!isOrderPaid && collectPayment) ...[
                              const Divider(height: 18),

                              // Payment Type (Full vs Partial)
                              Row(
                                children: [
                                  Expanded(
                                    child: ChoiceChip(
                                      label: const Center(child: Text('FULL PAYMENT')),
                                      selected: paymentType == 'FULL',
                                      selectedColor: const Color(0xFFDCFCE7),
                                      labelStyle: TextStyle(
                                        color: paymentType == 'FULL' ? const Color(0xFF166534) : const Color(0xFF475569),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                      onSelected: (sel) {
                                        if (sel) {
                                          setDlgState(() {
                                            paymentType = 'FULL';
                                            amountController.text = maxOutstanding.toStringAsFixed(2);
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ChoiceChip(
                                      label: const Center(child: Text('PARTIAL')),
                                      selected: paymentType == 'PARTIAL',
                                      selectedColor: const Color(0xFFFEF3C7),
                                      labelStyle: TextStyle(
                                        color: paymentType == 'PARTIAL' ? const Color(0xFF92400E) : const Color(0xFF475569),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                      onSelected: (sel) {
                                        if (sel) {
                                          setDlgState(() {
                                            paymentType = 'PARTIAL';
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Payment Mode
                              DropdownButtonFormField<String>(
                                initialValue: paymentMode,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Payment Mode',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'CASH',
                                    child: Text('Cash', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'UPI',
                                    child: Text('UPI / Online QR', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'BANK_TRANSFER',
                                    child: Text('Bank Transfer (NEFT/RTGS)', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'CHEQUE',
                                    child: Text('Cheque', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'OTHER',
                                    child: Text('Other', overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDlgState(() => paymentMode = val);
                                },
                              ),
                              const SizedBox(height: 12),

                              // Amount Field
                              TextField(
                                controller: amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                readOnly: paymentType == 'FULL',
                                onChanged: (_) => setDlgState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Amount Collected (₹)',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  prefixText: '₹ ',
                                  helperText: paymentType == 'PARTIAL'
                                      ? 'Remaining Due: ₹${remainingAfterPayment.toStringAsFixed(2)}'
                                      : 'Full outstanding amount will be cleared.',
                                  helperStyle: TextStyle(
                                    color: remainingAfterPayment > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Reference / Txn ID
                              TextField(
                                controller: refController,
                                decoration: const InputDecoration(
                                  labelText: 'Reference ID / Cheque No. (Optional)',
                                  hintText: 'e.g. UPI-123456 or Cheque #',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Notes
                              TextField(
                                controller: notesController,
                                maxLines: 1,
                                decoration: const InputDecoration(
                                  labelText: 'Remarks / Notes (Optional)',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isOrderPaid || collectPayment) ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (isDelivered && isOrderPaid) {
                          Navigator.pop(ctx);
                          return;
                        }

                        double entered = 0.0;
                        if (!isOrderPaid && collectPayment) {
                          entered = double.tryParse(amountController.text) ?? 0.0;
                          if (paymentType == 'FULL' || entered > maxOutstanding) {
                            entered = maxOutstanding;
                          }
                          if (entered <= 0 && maxOutstanding > 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Payment amount must be greater than zero.')),
                            );
                            return;
                          }
                        }

                        setDlgState(() => isSubmitting = true);

                        // 1. Update order fulfillment status if transition is needed
                        if (selectedNewStatus != currentCanonical) {
                          if (selectedNewStatus.toLowerCase() == 'cancelled') {
                            final confirmed = await CancelOrderDialog.show(
                              context,
                              orderCode: (order['orderId'] ?? order['id']).toString(),
                            );
                            if (confirmed != true) {
                              setDlgState(() => isSubmitting = false);
                              return;
                            }
                          }

                          final statusRes = await _orderRepository.updateOrderStatus(
                            dbId,
                            selectedNewStatus,
                          );

                          if (!mounted) return;

                          if (statusRes['success'] != true) {
                            setDlgState(() => isSubmitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    statusRes['message']?.toString() ?? 'Failed to update order status',
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                            }
                            return;
                          }
                        }

                        // 2. If payment collection was selected and not yet paid, record the payment
                        if (!isOrderPaid && collectPayment && entered > 0) {
                          final paymentPayload = {
                            'payment_type': paymentType,
                            'amount': entered,
                            'payment_method': paymentMode,
                            'reference_number': refController.text.trim(),
                            'transaction_reference': refController.text.trim(),
                            'notes': notesController.text.trim(),
                          };

                          final payRes = await _orderRepository.recordOrderPayment(dbId, paymentPayload);
                          if (ctx.mounted) Navigator.pop(ctx);
                          Future.delayed(const Duration(milliseconds: 500), () {
                            amountController.dispose();
                            refController.dispose();
                            notesController.dispose();
                          });
                          if (!mounted) return;

                          order['raw_status'] = selectedNewStatus;
                          order['status'] = _orderRepository.getStatusLabel(selectedNewStatus);

                          if (payRes['success'] == true) {
                            final double remainingAfter = (maxOutstanding - entered).clamp(0.0, maxOutstanding);
                            final payData = payRes['data'] is Map ? payRes['data'] as Map : null;
                            final bool newPaid = (payData != null && payData['payment_collected'] == true) || remainingAfter <= 0.001;
                            final double newAmtPaid = payData != null && payData['amount_paid'] != null
                                ? (double.tryParse(payData['amount_paid'].toString()) ?? (totalAmount - remainingAfter))
                                : (totalAmount - remainingAfter);
                            final double newBalance = payData != null && payData['outstanding_balance'] != null
                                ? (double.tryParse(payData['outstanding_balance'].toString()) ?? remainingAfter)
                                : remainingAfter;
                            final bool newPartial = !newPaid && newAmtPaid > 0 && newBalance > 0;

                            setState(() {
                              order['payment_collected'] = newPaid;
                              order['payment_status'] = newPaid ? 'paid' : (newPartial ? 'partial' : 'pending');
                              order['payment'] = newPaid ? 'PAYMENT COLLECTED' : (newPartial ? 'PARTIALLY PAID' : 'PAYMENT PENDING');
                              order['amount_paid'] = newAmtPaid;
                              order['outstanding_amount'] = newBalance;
                              order['outstanding_balance'] = newBalance;
                              order['is_pending_verification'] = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Order #${order['id']} updated to ${_orderRepository.getStatusLabel(selectedNewStatus)} & collected ₹${entered.toStringAsFixed(2)} ($paymentMode)!',
                                ),
                                backgroundColor: const Color(0xFF16A34A),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Status updated to ${_orderRepository.getStatusLabel(selectedNewStatus)}, but payment recording failed: ${payRes['message'] ?? 'Unknown error'}',
                                ),
                                backgroundColor: Colors.orange.shade800,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                          _fetchOrders();
                        } else {
                          order['raw_status'] = selectedNewStatus;
                          order['status'] = _orderRepository.getStatusLabel(selectedNewStatus);

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Order #${order['id']} status updated to ${_orderRepository.getStatusLabel(selectedNewStatus)}'),
                              backgroundColor: const Color(0xFF16A34A),
                            ),
                          );
                          _fetchOrders();
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isDelivered
                        ? (isOrderPaid ? 'Close' : (collectPayment ? 'Record Payment' : 'OK'))
                        : (collectPayment ? 'Update & Record Payment' : 'Confirm Status')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCollectPaymentDialog(Map<String, dynamic> order) {
    final int? dbId = order['db_id'] as int?;
    if (dbId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot collect payment: missing order ID')),
      );
      return;
    }

    final double totalAmount = double.tryParse(order['amount']?.toString() ?? '0') ?? 0.0;
    final double alreadyPaid = double.tryParse(order['amount_paid']?.toString() ?? '0') ?? 0.0;
    double maxOutstanding = double.tryParse(order['outstanding_balance']?.toString() ?? '') ??
        double.tryParse(order['outstanding_amount']?.toString() ?? '') ??
        ((totalAmount - alreadyPaid) > 0 ? (totalAmount - alreadyPaid) : 0.0);

    String paymentType = 'FULL'; // FULL, PARTIAL
    String paymentMode = 'CASH'; // CASH, UPI, BANK_TRANSFER, CHEQUE, OTHER
    final amountController = TextEditingController(text: maxOutstanding.toStringAsFixed(2));
    final refController = TextEditingController();
    final notesController = TextEditingController();
    bool isSubmitting = false;
    bool fetchedLiveBalance = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          if (!fetchedLiveBalance) {
            fetchedLiveBalance = true;
            _orderRepository.getOrderPayments(dbId).then((res) {
              if (res['success'] == true && res['data'] is Map) {
                final data = res['data'] as Map;
                final liveOutstanding = double.tryParse(data['outstanding_balance']?.toString() ?? '');
                if (liveOutstanding != null && ctx.mounted) {
                  setDlgState(() {
                    maxOutstanding = liveOutstanding;
                    if (paymentType == 'FULL' || amountController.text == totalAmount.toStringAsFixed(2) || amountController.text == '0.00') {
                      amountController.text = maxOutstanding.toStringAsFixed(2);
                    }
                  });
                }
              }
            });
          }
          final enteredAmount = double.tryParse(amountController.text) ?? 0.0;
          final remainingAfterPayment = (maxOutstanding - enteredAmount).clamp(0.0, maxOutstanding);

          return AlertDialog(
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.payment_rounded, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Collect Payment (#${order['id']})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(ctx).size.width * 0.9,
                maxHeight: MediaQuery.of(ctx).size.height * 0.72,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Order:', style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
                              Text('₹${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Already Paid:', style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
                              Text('₹${alreadyPaid.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0284C7), fontSize: 13)),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Outstanding Due:', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF166534), fontSize: 13)),
                              Text('₹${maxOutstanding.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF166534), fontSize: 14)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payment Type: Full or Partial
                    const Text('Payment Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('FULL PAYMENT')),
                            selected: paymentType == 'FULL',
                            selectedColor: const Color(0xFFDCFCE7),
                            labelStyle: TextStyle(
                              color: paymentType == 'FULL' ? const Color(0xFF166534) : const Color(0xFF475569),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                            onSelected: (sel) {
                              if (sel) {
                                setDlgState(() {
                                  paymentType = 'FULL';
                                  amountController.text = maxOutstanding.toStringAsFixed(2);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('PARTIAL')),
                            selected: paymentType == 'PARTIAL',
                            selectedColor: const Color(0xFFFEF3C7),
                            labelStyle: TextStyle(
                              color: paymentType == 'PARTIAL' ? const Color(0xFF92400E) : const Color(0xFF475569),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                            onSelected: (sel) {
                              if (sel) {
                                setDlgState(() {
                                  paymentType = 'PARTIAL';
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Payment Mode Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: paymentMode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CASH',
                          child: Text('Cash', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'UPI',
                          child: Text('UPI / Online', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'BANK_TRANSFER',
                          child: Text('Bank Transfer (NEFT/RTGS)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'CHEQUE',
                          child: Text('Cheque', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'OTHER',
                          child: Text('Other', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => paymentMode = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Amount Field
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      readOnly: paymentType == 'FULL',
                      onChanged: (_) => setDlgState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Amount to Collect (₹)',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        prefixText: '₹ ',
                        helperText: paymentType == 'PARTIAL'
                            ? 'Remaining Due: ₹${remainingAfterPayment.toStringAsFixed(2)}'
                            : 'Full amount will clear outstanding balance.',
                        helperStyle: TextStyle(
                          color: remainingAfterPayment > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Reference / Txn ID
                    TextField(
                      controller: refController,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Reference / Cheque No.',
                        hintText: 'e.g. UPI-123456 or Cheque #',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Remarks / Notes',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        double entered = double.tryParse(amountController.text) ?? 0.0;
                        if (paymentType == 'FULL' || entered > maxOutstanding) {
                          entered = maxOutstanding;
                        }
                        if (entered <= 0 && maxOutstanding > 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Payment amount must be greater than zero.')),
                          );
                          return;
                        }

                        setDlgState(() => isSubmitting = true);
                        final payload = {
                          'payment_type': paymentType,
                          'amount': entered,
                          'payment_method': paymentMode,
                          'reference_number': refController.text.trim(),
                          'transaction_reference': refController.text.trim(),
                          'notes': notesController.text.trim(),
                        };

                        final res = await _orderRepository.recordOrderPayment(dbId, payload);
                        if (!mounted) return;

                        if (res['success'] == true) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          Future.delayed(const Duration(milliseconds: 500), () {
                            amountController.dispose();
                            refController.dispose();
                            notesController.dispose();
                          });
                          if (!mounted) return;

                          final double remainingAfter = (maxOutstanding - entered).clamp(0.0, maxOutstanding);
                          final payData = res['data'] is Map ? res['data'] as Map : null;
                          final bool newPaid = (payData != null && payData['payment_collected'] == true) || remainingAfter <= 0.001;
                          final double newAmtPaid = payData != null && payData['amount_paid'] != null
                              ? (double.tryParse(payData['amount_paid'].toString()) ?? (totalAmount - remainingAfter))
                              : (totalAmount - remainingAfter);
                          final double newBalance = payData != null && payData['outstanding_balance'] != null
                              ? (double.tryParse(payData['outstanding_balance'].toString()) ?? remainingAfter)
                              : remainingAfter;
                          final bool newPartial = !newPaid && newAmtPaid > 0 && newBalance > 0;

                          setState(() {
                            order['payment_collected'] = newPaid;
                            order['payment_status'] = newPaid ? 'paid' : (newPartial ? 'partial' : 'pending');
                            order['payment'] = newPaid ? 'PAYMENT COLLECTED' : (newPartial ? 'PARTIALLY PAID' : 'PAYMENT PENDING');
                            order['amount_paid'] = newAmtPaid;
                            order['outstanding_amount'] = newBalance;
                            order['outstanding_balance'] = newBalance;
                            order['is_pending_verification'] = false;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Payment of ₹$entered recorded successfully!'),
                              backgroundColor: const Color(0xFF16A34A),
                            ),
                          );
                          _fetchOrders();
                        } else {
                          setDlgState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(res['message']?.toString() ?? 'Failed to record payment'),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Record Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderProgress(String status, {bool isPaid = false}) {
    final steps = [
      'Order Placement',
      'Plant Approval',
      'Invoice Generation',
      'Dispatch',
      'Delivery',
      'Payment Collection',
    ];

    int activeStep = 0;

    if (status == 'Plant Approval') {
      activeStep = 1;
    } else if (status == 'Invoice Generated') {
      activeStep = 2;
    } else if (status == 'Dispatched') {
      activeStep = 3;
    } else if (status == 'Delivered') {
      activeStep = isPaid ? 5 : 4;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Progress',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 12),

        ...List.generate(steps.length, (index) {
          final done = index <= activeStep;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: done
                      ? const Color(0xFF0284C7)
                      : const Color(0xFFCBD5E1),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  steps[index],
                  style: TextStyle(
                    fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                    color: done
                        ? const Color(0xFF111827)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  Widget _orderIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0284C7)),
    );
  }

  Widget _statusBadge(String status) {
    return AppStatusBadge.order(status);
  }

  Widget _paymentBadge(String payment) {
    return AppStatusBadge.payment(payment);
  }

  String _formatAmount(dynamic amount) {
    final number = int.tryParse('$amount') ?? 0;

    return number.toString();
  }
}

// =========================================================
// STAT CARD
// =========================================================

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 105,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0284C7)),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// MOBILE STAT
// =========================================================

class _MobileStat extends StatelessWidget {
  final String title;
  final String value;

  const _MobileStat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _tableHeaderStyle = TextStyle(
  fontSize: 9,
  fontWeight: FontWeight.w700,
  color: Color(0xFF64748B),
  letterSpacing: 0.4,
);
