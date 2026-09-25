import 'package:flutter/material.dart';

import '../../../core/services/OrderService.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/contact_action_helper.dart';

class FranchiseOrdersScreen extends StatefulWidget {
  const FranchiseOrdersScreen({super.key});

  @override
  State<FranchiseOrdersScreen> createState() => _FranchiseOrdersScreenState();
}

class _FranchiseOrdersScreenState extends State<FranchiseOrdersScreen> {
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
    final res = await OrderService().getOrders();
    if (!mounted) return;

    if (res['success'] == true && res['data'] is Map) {
      final rawOrders = res['data']['orders'];
      if (rawOrders is List) {
        final mapped = rawOrders.whereType<Map>().map((item) {
          final mappedItem = OrderService().mapOrder(
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
                    .map((e) => Map<String, dynamic>.from(e as Map))
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

          final double totalAmt = double.tryParse(mappedItem['amount']?.toString() ?? '0') ?? 0.0;
          final double amtPaid = double.tryParse(item['amount_paid']?.toString() ?? mappedItem['amount_paid']?.toString() ?? '0') ?? 0.0;
          final double outstandingAmt = double.tryParse(item['outstanding_amount']?.toString() ?? mappedItem['outstanding_amount']?.toString() ?? '${(totalAmt - amtPaid).clamp(0.0, totalAmt)}') ?? (totalAmt - amtPaid).clamp(0.0, totalAmt);

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
            'amount_paid': amtPaid,
            'outstanding_amount': outstandingAmt,
            'status': mappedItem['status']?.toString() ?? 'Plant Approval',
            'payment': mappedItem['payment']?.toString() ?? 'Pending',
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
                            '${orders.where((o) => o['status'] == 'Plant Approval').length}',
                        subtitle: 'Waiting for plant',
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StatCard(
                        title: 'Dispatched',
                        value:
                            '${orders.where((o) => o['status'] == 'Dispatched').length}',
                        subtitle: 'In transit',
                        icon: Icons.local_shipping_outlined,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StatCard(
                        title: 'Delivered',
                        value:
                            '${orders.where((o) => o['status'] == 'Delivered').length}',
                        subtitle: 'Completed',
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

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
                  DropdownMenuItem(value: 'All', child: Text('All Status')),
                  DropdownMenuItem(
                    value: 'Plant Approval',
                    child: Text('Plant Approval'),
                  ),
                  DropdownMenuItem(
                    value: 'Invoice Generated',
                    child: Text('Invoice Generated'),
                  ),
                  DropdownMenuItem(
                    value: 'Dispatched',
                    child: Text('Dispatched'),
                  ),
                  DropdownMenuItem(
                    value: 'Delivered',
                    child: Text('Delivered'),
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
                          '${orders.where((o) => o['status'] == 'Plant Approval').length}',
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
                          '${orders.where((o) => o['status'] == 'Dispatched').length}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MobileStat(
                      title: 'Delivered',
                      value:
                          '${orders.where((o) => o['status'] == 'Delivered').length}',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

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

            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _statusBadge('${order['status']}'),
                      _paymentBadge('${order['payment']}'),
                    ],
                  ),
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
    String selectedProduct = '500ml Water Bottle';

    final quantityController = TextEditingController(text: '10');
    final notesController = TextEditingController();
    bool isSubmitting = false;
    bool orderPlaced = false;
    int placedQuantity = 0;
    String placedProduct = '';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogInnerContext, setDialogState) {
            return AlertDialog(
              title: const Text('Place New Order'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedProduct,
                        decoration: const InputDecoration(labelText: 'Product'),
                        items: const [
                          DropdownMenuItem(
                            value: '250ml Water Bottle',
                            child: Text('250ml Water Bottle'),
                          ),
                          DropdownMenuItem(
                            value: '500ml Water Bottle',
                            child: Text('500ml Water Bottle'),
                          ),
                          DropdownMenuItem(
                            value: '1 Litre Water Bottle',
                            child: Text('1 Litre Water Bottle'),
                          ),
                          DropdownMenuItem(
                            value: '2 Litre Water Bottle',
                            child: Text('2 Litre Water Bottle'),
                          ),
                          DropdownMenuItem(
                            value: '5 Litre Water Jar',
                            child: Text('5 Litre Water Jar'),
                          ),
                          DropdownMenuItem(
                            value: '20 Litre Water Jar',
                            child: Text('20 Litre Water Jar'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            selectedProduct = value;
                          });
                        },
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Notes',
                        ),
                      ),

                      const SizedBox(height: 14),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Order will be sent for Plant Approval after placement.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                SizedBox(
                  width: 90,
                  height: 44,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      maximumSize: const Size(90, 44),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                          },
                    child: const Text('Cancel'),
                  ),
                ),

                SizedBox(
                  width: 130,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      maximumSize: const Size(130, 44),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final quantity =
                                int.tryParse(quantityController.text) ?? 0;

                            if (quantity <= 0) {
                              return;
                            }

                            setDialogState(() => isSubmitting = true);

                            final user = await SessionService()
                                .getCurrentUser();
                            final franchiseName =
                                user?.businessName.isNotEmpty == true
                                ? user!.businessName
                                : (user?.name.isNotEmpty == true
                                      ? user!.name
                                      : 'Franchise Partner');
                            final city = user?.city.isNotEmpty == true
                                ? user!.city
                                : 'Raipur';
                            final double totalAmount = (quantity * 20)
                                .toDouble();

                            final res = await OrderService().createOrder({
                              'franchise': franchiseName,
                              'city': city,
                              'items': quantity,
                              'amount': totalAmount,
                              'status': 'Plant Approval',
                              'payment': 'Pending',
                            });

                            if (!dialogContext.mounted) return;

                            if (res['success'] == true) {
                              orderPlaced = true;
                              placedQuantity = quantity;
                              placedProduct = selectedProduct;
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            } else {
                              setDialogState(() => isSubmitting = false);
                              final msg =
                                  res['message'] ?? 'Failed to place order';
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Place Order'),
                  ),
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
        'Order of $placedQuantity x $placedProduct placed successfully!',
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
              maxHeight: 650,
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
                  _orderProgress('${order['status']}'),
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
    final double alreadyPaid = double.tryParse(order['amount_paid']?.toString() ?? '0') ?? 0.0;
    double maxOutstanding = double.tryParse(order['outstanding_balance']?.toString() ?? '') ??
        double.tryParse(order['outstanding_amount']?.toString() ?? '') ??
        ((totalAmount - alreadyPaid) > 0 ? (totalAmount - alreadyPaid) : 0.0);

    String rawStatus = order['status']?.toString() ?? 'Plant Approval';
    String selectedNewStatus = 'Plant Approval';
    final lower = rawStatus.toLowerCase();
    if ((lower.contains('plant') && lower.contains('approval')) ||
        lower.contains('admin approved') ||
        lower == 'plant_approval') {
      selectedNewStatus = 'Plant Approval';
    } else if (lower.contains('dispatch')) {
      selectedNewStatus = 'Dispatched';
    } else if (rawStatus.toLowerCase().contains('invoice')) {
      selectedNewStatus = 'Invoice Generated';
    } else if (rawStatus.toLowerCase().contains('deliver')) {
      selectedNewStatus = 'Delivered';
    } else if (rawStatus.toLowerCase().contains('cancel')) {
      selectedNewStatus = 'Cancelled';
    } else if (rawStatus.toLowerCase().contains('placement')) {
      selectedNewStatus = 'Order Placement';
    }

    const statusOptions = [
      'Order Placement',
      'Plant Approval',
      'Invoice Generated',
      'Dispatched',
      'Delivered',
      'Cancelled',
    ];

    bool collectPayment = false;
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
            OrderService().getOrderPayments(dbId).then((res) {
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.local_shipping_outlined, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
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
                    DropdownButtonFormField<String>(
                      initialValue: statusOptions.contains(selectedNewStatus)
                          ? selectedNewStatus
                          : statusOptions.first,
                      decoration: const InputDecoration(
                        labelText: 'Fulfillment Status',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: statusOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() {
                            selectedNewStatus = val;
                            if (val.toLowerCase() == 'delivered' && maxOutstanding > 0 && !collectPayment) {
                              collectPayment = true;
                              amountController.text = maxOutstanding.toStringAsFixed(2);
                            }
                          });
                        }
                      },
                    ),

                    if (maxOutstanding <= 0) ...[
                      Container(
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Payment Status: Fully Paid (₹${totalAmount.toStringAsFixed(2)})',
                                style: const TextStyle(
                                  color: Color(0xFF166534),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Integrated Payment Collection Option
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: collectPayment ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: collectPayment ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
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
                                    value: collectPayment,
                                    activeColor: const Color(0xFF16A34A),
                                    onChanged: (val) {
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
                                    onTap: () {
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
                                        const Text(
                                          'Record Payment Collected',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          'Due: ₹${maxOutstanding.toStringAsFixed(2)} (Total: ₹${totalAmount.toStringAsFixed(2)})',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (collectPayment) ...[
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
                                decoration: const InputDecoration(
                                  labelText: 'Payment Mode',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                                  DropdownMenuItem(value: 'UPI', child: Text('UPI / Online QR')),
                                  DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT/RTGS)')),
                                  DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
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
                  backgroundColor: collectPayment ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        double entered = 0.0;
                        if (collectPayment) {
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

                        // 1. Update order fulfillment status
                        final statusRes = await OrderService().updateOrderStatus(
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

                        // 2. If payment collection was selected, record the payment
                        if (collectPayment && entered > 0) {
                          final paymentPayload = {
                            'payment_type': paymentType,
                            'amount': entered,
                            'payment_method': paymentMode,
                            'reference_number': refController.text.trim(),
                            'transaction_reference': refController.text.trim(),
                            'notes': notesController.text.trim(),
                          };

                          final payRes = await OrderService().recordOrderPayment(dbId, paymentPayload);
                          if (ctx.mounted) Navigator.pop(ctx);
                          Future.delayed(const Duration(milliseconds: 500), () {
                            amountController.dispose();
                            refController.dispose();
                            notesController.dispose();
                          });
                          if (!mounted) return;

                          if (payRes['success'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Order #${order['id']} updated to $selectedNewStatus & collected ₹${entered.toStringAsFixed(2)} ($paymentMode)!',
                                ),
                                backgroundColor: const Color(0xFF16A34A),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Status updated to $selectedNewStatus, but payment recording failed: ${payRes['message'] ?? 'Unknown error'}',
                                ),
                                backgroundColor: Colors.orange.shade800,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                          _fetchOrders();
                        } else {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Order #${order['id']} status updated to $selectedNewStatus'),
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
                    : Text(collectPayment ? 'Update & Record Payment' : 'Confirm Status'),
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
            OrderService().getOrderPayments(dbId).then((res) {
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
                maxHeight: 520,
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
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                        DropdownMenuItem(value: 'UPI', child: Text('UPI / Online')),
                        DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT/RTGS)')),
                        DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
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

                        final res = await OrderService().recordOrderPayment(dbId, payload);
                        if (!mounted) return;

                        if (res['success'] == true) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          Future.delayed(const Duration(milliseconds: 500), () {
                            amountController.dispose();
                            refController.dispose();
                            notesController.dispose();
                          });
                          if (!mounted) return;
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

  Widget _orderProgress(String status) {
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
      activeStep = 4;
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
    Color bg;
    Color fg;

    switch (status) {
      case 'Delivered':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        break;

      case 'Dispatched':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        break;

      case 'Invoice Generated':
        bg = const Color(0xFFF5F3FF);
        fg = const Color(0xFF7C3AED);
        break;

      default:
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFEA580C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _paymentBadge(String payment) {
    Color bg;
    Color fg;

    if (payment == 'Paid') {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF059669);
    } else if (payment == 'Partial') {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFFEA580C);
    } else {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        payment,
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
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
