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
      final List<dynamic> items =
          ordersResult['data']['orders'] ?? [];

      orders = items
          .map(
            (item) => _orderService.mapOrder(
              Map<String, dynamic>.from(item),
            ),
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
      stats = Map<String, dynamic>.from(
        statsResult['data']['stats'],
      );
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
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
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
          childAspectRatio: 1.1,
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
              children: [
                _search(),
                const SizedBox(height: 10),
                _filter(),
              ],
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
    return DropdownButtonFormField<String>(
      value: filter,
      decoration: const InputDecoration(labelText: 'Order Status'),
      items: const [
        'All',
        'Order Placement',
        'Plant Approval',
        'Invoice Generated',
        'Dispatch',
        'Delivered',
        'Payment Collection',
      ]
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e),
            ),
          )
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: header ? const Color(0xFFF8FAFC) : Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
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
          padding: const EdgeInsets.all(16),
          decoration: _orderCard(),
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
              _info('Payment', order['payment']),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton(
                  onPressed: () => _changeStatus(order),
                  child: const Text('Update Order Status'),
                ),
              ),
            ],
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
            width: 90,
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

  Future<void> _changeStatus(Map<String, dynamic> order) async {
    final statuses = [
      'Order Placement',
      'Plant Approval',
      'Invoice Generated',
      'Dispatch',
      'Delivered',
      'Payment Collection',
    ];

    String selected = order['status'];

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
                value: selected,
                decoration: const InputDecoration(labelText: 'Order Status'),
                items: statuses
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ),
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
                        result['message'] ??
                            'Unable to update order status.',
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
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