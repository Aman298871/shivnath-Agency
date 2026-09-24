import 'package:flutter/material.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/services/OrderService.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final OrderService _orderService = OrderService();

  List<Map<String, dynamic>> orders = [];

  Map<String, dynamic> stats = {
    'total_orders': 0,
    'approval_pending': 0,
    'in_dispatch': 0,
    'order_value': 0,
  };

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    final ordersResult = await _orderService.getOrders();
    final statsResult = await _orderService.getStats();

    if (!mounted) return;

    if (ordersResult['success'] == true) {
      final List<dynamic> items = ordersResult['data']['orders'] ?? [];

      orders = items
          .map(
            (item) => _orderService.mapOrder(Map<String, dynamic>.from(item)),
          )
          .toList();
    } else {
      AppToast.error(
        context,
        ordersResult['message'] ?? 'Failed to load orders.',
        title: 'Unable to Load',
      );
    }

    if (statsResult['success'] == true) {
      stats = Map<String, dynamic>.from(statsResult['data']['stats']);
    }

    setState(() {
      isLoading = false;
    });
  }

  String search = '';
  String filter = 'All';

  List<Map<String, dynamic>> get filtered {
    final q = search.toLowerCase();

    return orders.where((order) {
      final matches =
          q.isEmpty ||
          order['orderId'].toString().toLowerCase().contains(q) ||
          order['franchise'].toString().toLowerCase().contains(q) ||
          order['city'].toString().toLowerCase().contains(q);

      final status = filter == 'All' || order['status'] == filter;

      return matches && status;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Container(
          color: const Color(0xFFF5F7FB),
          width: double.infinity,
          height: double.infinity,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1350),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Orders',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Manage franchise orders, approval and dispatch',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 22),
                    _stats(desktop),
                    const SizedBox(height: 20),
                    _toolbar(desktop),
                    const SizedBox(height: 14),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      desktop ? _desktop() : _mobile(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stats(bool desktop) {
    final orderValue = (stats['order_value'] as num?) ?? 0;

    final data = [
      [
        'Total Orders',
        '${stats['total_orders'] ?? orders.length}',
        Icons.shopping_bag_outlined,
      ],
      [
        'Approval Pending',
        '${stats['approval_pending'] ?? 0}',
        Icons.schedule_outlined,
      ],
      [
        'In Dispatch',
        '${stats['in_dispatch'] ?? 0}',
        Icons.local_shipping_outlined,
      ],
      [
        'Order Value',
        '₹${orderValue.toStringAsFixed(0)}',
        Icons.currency_rupee,
      ],
    ];

    if (!desktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.25,
        ),
        itemBuilder: (_, i) => _OrderStat(
          title: data[i][0] as String,
          value: data[i][1] as String,
          icon: data[i][2] as IconData,
        ),
      );
    }

    return Row(
      children: List.generate(4, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 3 ? 0 : 14),
            child: _OrderStat(
              title: data[i][0] as String,
              value: data[i][1] as String,
              icon: data[i][2] as IconData,
            ),
          ),
        );
      }),
    );
  }

  Widget _toolbar(bool desktop) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _orderCard(),
      child: desktop
          ? Row(
              children: [
                Expanded(child: _search()),
                const SizedBox(width: 14),
                SizedBox(width: 220, child: _filter()),
              ],
            )
          : Column(
              children: [_search(), const SizedBox(height: 10), _filter()],
            ),
    );
  }

  Widget _search() {
    return TextField(
      onChanged: (v) => setState(() => search = v),
      decoration: const InputDecoration(
        hintText: 'Search order, franchise or city...',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }

  Widget _filter() {
    const filterOptions = [
      'All',
      'Order Placement',
      'Plant Approval',
      'Preparing',
      'Invoice Generated',
      'Dispatch',
      'Delivered',
      'Payment Collection',
      'Cancelled',
    ];
    final activeFilter = filterOptions.contains(filter) ? filter : 'All';

    return DropdownButtonFormField<String>(
      initialValue: activeFilter,
      decoration: const InputDecoration(labelText: 'Order Status'),
      items: filterOptions
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => filter = value);
      },
    );
  }

  Widget _desktop() {
    return Container(
      decoration: _orderCard(),
      child: Column(
        children: [
          _tableRow(null, true),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Text(
                'No orders found.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            )
          else
            ...filtered.map((order) => _tableRow(order, false)),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic>? order, bool header) {
    final cells = header
        ? ['ORDER', 'FRANCHISE', 'DATE', 'ITEMS', 'AMOUNT', 'STATUS', 'PAYMENT']
        : [
            order!['orderId'],
            '${order['franchise']}\n${order['city']}',
            order['date'],
            '${order['items']} Items',
            '₹${order['amount']}',
            order['status'],
            order['payment'],
          ];

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: header ? const Color(0xFFF8FAFC) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: List.generate(cells.length, (i) {
          if (!header && i == 5) {
            return Expanded(
              flex: 2,
              child: InkWell(
                onTap: () => _changeStatus(order!),
                child: _statusBadge(cells[i].toString()),
              ),
            );
          }

          return Expanded(
            flex: i == 1 || i == 5 ? 2 : 1,
            child: Text(
              cells[i].toString(),
              style: TextStyle(
                fontSize: header ? 9 : 11,
                fontWeight: header ? FontWeight.w700 : FontWeight.w500,
                color: header
                    ? const Color(0xFF64748B)
                    : const Color(0xFF1E293B),
              ),
            ),
          );
        }),
      ),
    );

    if (!header && order != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: () => _viewOrderDetails(order), child: row),
      );
    }
    return row;
  }

  Widget _mobile() {
    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(35),
        alignment: Alignment.center,
        child: const Text(
          'No orders found.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return Column(
      children: filtered.map((order) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: _orderCard(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _viewOrderDetails(order),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order['orderId'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _statusBadge(order['status']),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _info('Franchise', order['franchise']),
                    _info('City', order['city']),
                    _info('Date', order['date']),
                    _info('Items', '${order['items']}'),
                    _info('Amount', '₹${order['amount']}'),
                    if ((order['previous_outstanding'] ?? 0) > 0) ...[
                      _info('Prev. Outstanding', '₹${order['previous_outstanding']}'),
                      _info('Total Exposure', '₹${order['total_exposure']}'),
                    ],
                    _info('Payment', order['payment']),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _viewOrderDetails(order),
                            child: const Text('View Items'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _changeStatus(order),
                            child: const Text('Status'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Color(0xFF0284C7),
          fontWeight: FontWeight.w700,
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _info(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewOrderDetails(Map<String, dynamic> order) async {
    final rawItems = order['items_list'];
    final List<Map<String, dynamic>> itemsList = rawItems is List
        ? List<Map<String, dynamic>>.from(rawItems)
        : [];

    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF0284C7),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Order ${order['orderId']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _statusBadge(order['status'].toString()),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _info('Date', order['date']),
                        if ((order['customer_name'] ?? '')
                            .toString()
                            .isNotEmpty)
                          _info('Customer', order['customer_name']),
                        _info('Franchise', order['franchise']),
                        if ((order['delivery_address'] ?? '')
                            .toString()
                            .isNotEmpty)
                          _info('Delivery Address', order['delivery_address']),
                        _info('City', order['city']),
                        if ((order['duration_choice'] ?? '')
                            .toString()
                            .isNotEmpty)
                          _info('Plan Duration', order['duration_choice']),
                        _info('Payment', order['payment']),
                        if ((order['order_source'] ?? '').toString().isNotEmpty)
                          _info(
                            'Order Source',
                            order['order_source'] == 'DIRECT_COMPANY'
                                ? 'Direct Company (Plant Fulfilled)'
                                : 'Franchise Fulfilled',
                          ),
                        const SizedBox(height: 14),
                        const Text(
                          'Ordered Products',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (itemsList.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.water_drop_outlined,
                                  color: Color(0xFF0284C7),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${order['items']} Items (${order['franchise']})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹${order['amount']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
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
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.water_drop_rounded,
                                      size: 18,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (size.toString().isNotEmpty)
                                          Text(
                                            'Size: $size | Qty: $qty',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹$totalPrice',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                      Text(
                                        '₹$unitPrice each',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Current Order Amount',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '₹${order['amount']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                              if ((order['previous_outstanding'] ?? 0) > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Previous Outstanding', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                                    Text('₹${order['previous_outstanding']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFDC2626))),
                                  ],
                                ),
                                const Divider(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Exposure / Due', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF991B1B))),
                                    Text('₹${order['total_exposure']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF991B1B))),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Shivnath Central Manufacturing & Production Allocation
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.precision_manufacturing_rounded,
                                    size: 18,
                                    color: Color(0xFF0284C7),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Shivnath Factory Production\n & Pending Stock',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if ((order['client_name'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                _info('Client Name', order['client_name']),
                              if ((order['label_requirement'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                _info('Label Spec', order['label_requirement']),
                              if ((order['printing_requirement'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                _info(
                                  'Printing Spec',
                                  order['printing_requirement'],
                                ),
                              if ((order['branding_requirement'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                _info(
                                  'Branding Spec',
                                  order['branding_requirement'],
                                ),
                              if (order['custom_shelf_life_days'] != null)
                                _info(
                                  'Shelf Life',
                                  '${order['custom_shelf_life_days']} Days (Configured)',
                                ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'PRODUCED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${order['total_produced_units'] ?? 0} units',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DELIVERED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${order['total_delivered_units'] ?? 0} units',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'PENDING IN STOCK',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${order['total_pending_stock_units'] ?? 0} units',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Lifecycle & Status History',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final rawHistory = order['status_history'];
                            final List history = rawHistory is List
                                ? rawHistory
                                : [];
                            if (history.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No status transitions recorded yet.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: history.map<Widget>((h) {
                                final oldS = h['old_status'] ?? '-';
                                final newS = h['new_status'] ?? '-';
                                final byUser = h['changed_by_name'] ?? 'System';
                                final changedAt =
                                    h['created_at']?.toString() ?? '';
                                final notes = h['notes']?.toString() ?? '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.history_rounded,
                                        size: 16,
                                        color: Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$oldS → $newS',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'By: $byUser ${changedAt.isNotEmpty ? '• ${changedAt.substring(0, changedAt.length > 19 ? 19 : changedAt.length).replaceAll('T', ' ')}' : ''}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                            if (notes.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                notes,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
                        _changeStatus(order);
                      },
                      icon: const Icon(
                        Icons.published_with_changes_rounded,
                        size: 18,
                      ),
                      label: const Text('Update Status'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeStatus(Map<String, dynamic> order) async {
    const statuses = [
      'Order Placement',
      'Plant Approval',
      'Preparing',
      'Invoice Generated',
      'Dispatch',
      'Delivered',
      'Payment Collection',
      'Cancelled',
    ];

    String rawStatus = order['status']?.toString() ?? 'Order Placement';
    final lowerStatus = rawStatus.toLowerCase();
    String selected = 'Order Placement';
    if (lowerStatus.contains('plant') && lowerStatus.contains('approval')) {
      selected = 'Plant Approval';
    } else if (lowerStatus.contains('prep')) {
      selected = 'Preparing';
    } else if (lowerStatus.contains('invoice')) {
      selected = 'Invoice Generated';
    } else if (lowerStatus.contains('dispatch')) {
      selected = 'Dispatch';
    } else if (lowerStatus.contains('deliver')) {
      selected = 'Delivered';
    } else if (lowerStatus.contains('payment')) {
      selected = 'Payment Collection';
    } else if (lowerStatus.contains('cancel')) {
      selected = 'Cancelled';
    } else if (statuses.contains(rawStatus)) {
      selected = rawStatus;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, update) => AlertDialog(
            title: Text('Update ${order['orderId']}'),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: DropdownButtonFormField<String>(
                initialValue: statuses.contains(selected)
                    ? selected
                    : statuses.first,
                decoration: const InputDecoration(labelText: 'Order Status'),
                items: statuses
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) update(() => selected = value);
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              SizedBox(
                width: 100,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    maximumSize: const Size(100, 44),
                  ),
                  onPressed: () async {
                    final result = await _orderService.updateOrderStatus(
                      order['id'] as int,
                      selected,
                    );

                    if (result['success'] == true) {
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }

                      await _loadData();

                      if (!mounted) return;

                      AppToast.success(
                        context,
                        '${order['orderId']} status changed to $selected.',
                        title: 'Order Status Updated',
                      );
                    } else {
                      AppToast.error(
                        context,
                        result['message'] ?? 'Unable to update order status.',
                        title: 'Update Failed',
                      );
                    }
                  },
                  child: const Text('Update'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _OrderStat({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _orderCard(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0284C7), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _orderCard() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: const Color(0xFFE5E7EB)),
);
