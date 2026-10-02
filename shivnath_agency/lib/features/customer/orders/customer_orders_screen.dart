
import 'package:flutter/material.dart';

import '../../../core/services/OrderService.dart';
import '../../../core/widgets/app_components.dart';
import 'order_detail_screen.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  final OrderService _orderService = OrderService();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _orderService.getOrders();
    if (!mounted) return;

    if (res['success'] == true && res['data'] is Map) {
      final rawOrders = res['data']['orders'];
      if (rawOrders is List) {
        final mapped = rawOrders.whereType<Map>().map((item) {
          return _orderService.mapOrder(Map<String, dynamic>.from(item));
        }).toList();

        setState(() {
          _orders = mapped;
          _isLoading = false;
        });
        return;
      }
    }

    setState(() {
      _orders = [];
      _isLoading = false;
      if (res['success'] != true && res['message'] != null) {
        _errorMessage = res['message'].toString();
      }
    });
  }

  List<Map<String, dynamic>> get orders => _orders;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final desktop =
            constraints.maxWidth >= 800;

        if (desktop) {
          return _desktop(context);
        }

        return _mobile(context);
      },
    );
  }

  Widget _mobile(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage ?? 'No orders placed yet',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _errorMessage != null
                            ? 'Pull to refresh or tap the refresh icon to retry.'
                            : 'Browse products and place your first water order.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: _orderList(context),
                ),
    );
  }

  Widget _desktop(
    BuildContext context,
  ) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1200,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Orders',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Track and manage all your orders.',
                  style: TextStyle(
                    color:
                        Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 24),

                Builder(
                  builder: (context) {
                    final total = _orders.length;
                    final processing = _orders.where((o) {
                      final s = (o['status'] ?? '').toString().toLowerCase();
                      return s.contains('prepar') || s.contains('approv') || s.contains('placement');
                    }).length;
                    final dispatched = _orders.where((o) => (o['status'] ?? '').toString().toLowerCase().contains('dispatch')).length;
                    final delivered = _orders.where((o) => (o['status'] ?? '').toString().toLowerCase().contains('deliver')).length;

                    return Row(
                      children: [
                        Expanded(
                          child: _OrderStat(
                            title: 'Total Orders',
                            value: '$total',
                            icon: Icons.receipt_long_outlined,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _OrderStat(
                            title: 'Processing',
                            value: '$processing',
                            icon: Icons.schedule_outlined,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _OrderStat(
                            title: 'Dispatched',
                            value: '$dispatched',
                            icon: Icons.local_shipping_outlined,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _OrderStat(
                            title: 'Delivered',
                            value: '$delivered',
                            icon: Icons.check_circle_outline,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 22),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: orders.map((order) {
                      return _DesktopOrderRow(
                        order: order,
                        onTap: () => _openOrder(context, order),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _orderList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(18),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        final orderCode = order['orderId']?.toString() ?? 'ORD-${order['id']}';
        final displayCode = orderCode.startsWith('#') ? orderCode : '#$orderCode';
        final amount = '₹${order['amount']}';
        final status = order['status']?.toString() ?? 'Pending';
        final date = order['date']?.toString() ?? '';
        final franchise = order['franchise']?.toString() ?? '';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(15),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE0F2FE),
              child: Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF0284C7),
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    displayCode,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  amount,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          date,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppStatusBadge.order(status),
                    ],
                  ),
                  if (franchise.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Fulfilled by: $franchise',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            onTap: () => _openOrder(context, order),
          ),
        );
      },
    );
  }

  void _openOrder(
    BuildContext context,
    Map<String, dynamic> order,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderId: order['orderId']?.toString() ?? 'ORD-${order['id']}',
          amount: '₹${order['amount']}',
          status: order['status']?.toString(),
          initialOrder: order,
          dbId: order['id'] is int ? order['id'] as int : int.tryParse(order['id']?.toString() ?? ''),
        ),
      ),
    );
  }
}

class _OrderStat
    extends StatelessWidget {
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
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFE0F2FE),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color:
                  const Color(0xFF0284C7),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 10,
                    color:
                        Color(0xFF64748B),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style:
                        const TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w800,
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

class _DesktopOrderRow extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _DesktopOrderRow({
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final orderCode = order['orderId']?.toString() ?? 'ORD-${order['id']}';
    final displayCode = orderCode.startsWith('#') ? orderCode : '#$orderCode';
    final amount = '₹${order['amount']}';
    final status = order['status']?.toString() ?? 'Pending';
    final date = order['date']?.toString() ?? '';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF1F5F9)),
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFE0F2FE),
              child: Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Text(
                displayCode,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Text(
                date,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppStatusBadge.order(status),
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                amount,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),

            const SizedBox(
              width: 18,
            ),

            const Icon(
              Icons
                  .chevron_right_rounded,
            ),
          ],
        ),
      ),
    );
  }
}