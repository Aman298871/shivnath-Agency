import 'package:flutter/material.dart';

import '../../../core/services/OrderService.dart';
import '../../../core/services/session_service.dart';

class FranchiseOrdersScreen extends StatefulWidget {
  const FranchiseOrdersScreen({super.key});

  @override
  State<FranchiseOrdersScreen> createState() =>
      _FranchiseOrdersScreenState();
}

class _FranchiseOrdersScreenState
    extends State<FranchiseOrdersScreen> {
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
          final mappedItem = OrderService().mapOrder(Map<String, dynamic>.from(item));
          final rawDbId = item['id'] is int
              ? item['id'] as int
              : (int.tryParse(item['id']?.toString() ?? '') ??
                  (mappedItem['id'] is int ? mappedItem['id'] as int : null));
          final rawId = mappedItem['orderId']?.toString();
          final fallbackId = rawDbId != null ? 'ORD-${1000 + rawDbId}' : '';
          final orderCode = (rawId != null && rawId.isNotEmpty) ? rawId : fallbackId;
          return {
            'db_id': rawDbId,
            'id': orderCode,
            'date': mappedItem['date']?.toString() ?? '',
            'product': mappedItem['franchise']?.toString().isNotEmpty == true ? mappedItem['franchise']!.toString() : 'Packaged Water',
            'qty': mappedItem['items'] ?? 1,
            'amount': mappedItem['amount'] ?? 0,
            'status': mappedItem['status']?.toString() ?? 'Plant Approval',
            'payment': mappedItem['payment']?.toString() ?? 'Pending',
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
      final id =
          (order['id'] ?? '').toString().toLowerCase();

      final product =
          (order['product'] ?? '').toString().toLowerCase();

      final status =
          (order['status'] ?? '').toString();

      final matchesSearch =
          query.isEmpty ||
          id.contains(query) ||
          product.contains(query);

      final matchesStatus =
          selectedStatus == 'All' ||
          status == selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;

        return desktop
            ? _buildDesktop()
            : _buildMobile();
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
            constraints: const BoxConstraints(
              maxWidth: 1250,
            ),
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
                        value: '${orders.where((o) => o['status'] == 'Plant Approval').length}',
                        subtitle: 'Waiting for plant',
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StatCard(
                        title: 'Dispatched',
                        value: '${orders.where((o) => o['status'] == 'Dispatched').length}',
                        subtitle: 'In transit',
                        icon: Icons.local_shipping_outlined,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StatCard(
                        title: 'Delivered',
                        value: '${orders.where((o) => o['status'] == 'Delivered').length}',
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
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 20),

        IconButton(
          tooltip: 'Refresh Orders',
          onPressed: _fetchOrders,
          icon: const Icon(
            Icons.refresh_rounded,
            color: Color(0xFF0284C7),
          ),
        ),

        const SizedBox(width: 10),

        SizedBox(
          width: 180,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _newOrder,
            icon: const Icon(
              Icons.add_rounded,
              size: 18,
            ),
            label: const Text(
              'Place New Order',
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 44),
              maximumSize: const Size(180, 44),
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
              ),
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
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
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
                  hintText:
                      'Search order ID or product...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          Container(
            width: 210,
            height: 44,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedStatus,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'All',
                    child: Text('All Status'),
                  ),
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
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          _tableHeader(),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 55,
              ),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (filteredOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 55,
              ),
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
            ...filteredOrders.map(
              (order) => _desktopOrderRow(order),
            ),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(width: 55),

          Expanded(
            flex: 2,
            child: Text(
              'ORDER',
              style: _tableHeaderStyle,
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              'PRODUCT',
              style: _tableHeaderStyle,
            ),
          ),

          Expanded(
            child: Text(
              'QTY',
              style: _tableHeaderStyle,
            ),
          ),

          Expanded(
            child: Text(
              'AMOUNT',
              style: _tableHeaderStyle,
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              'STATUS',
              style: _tableHeaderStyle,
            ),
          ),

          Expanded(
            child: Text(
              'PAYMENT',
              style: _tableHeaderStyle,
            ),
          ),

          SizedBox(width: 55),
        ],
      ),
    );
  }

  Widget _desktopOrderRow(
    Map<String, dynamic> order,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 55,
            child: _orderIcon(),
          ),

          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child: Text(
              '${order['qty']}',
              style: const TextStyle(
                fontSize: 11,
              ),
            ),
          ),

          Expanded(
            child: Text(
              '₹${_formatAmount(order['amount'])}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _statusBadge(
                '${order['status']}',
              ),
            ),
          ),

          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _paymentBadge(
                '${order['payment']}',
              ),
            ),
          ),

          SizedBox(
            width: 80,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 18,
                  ),
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
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _newOrder,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'New Order',
        ),
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
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
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
                      value: '${orders.where((o) => o['status'] == 'Plant Approval').length}',
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
                      value: '${orders.where((o) => o['status'] == 'Dispatched').length}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MobileStat(
                      title: 'Delivered',
                      value: '${orders.where((o) => o['status'] == 'Delivered').length}',
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
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
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
                ...filteredOrders.map(
                  (order) => _mobileOrderCard(order),
                ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileOrderCard(
    Map<String, dynamic> order,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: InkWell(
        onTap: () {
          _details(order);
        },
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _orderIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order['id']}',
                        style: const TextStyle(
                          color:
                              Color(0xFF0284C7),
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${order['date']}',
                        style: const TextStyle(
                          fontSize: 10,
                          color:
                              Color(0xFF94A3B8),
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order['qty']} Qty',
                    style: const TextStyle(
                      color:
                          Color(0xFF64748B),
                    ),
                  ),
                ),
                Text(
                  '₹${_formatAmount(order['amount'])}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
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
                      _statusBadge(
                        '${order['status']}',
                      ),
                      _paymentBadge(
                        '${order['payment']}',
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Update', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showUpdateStatusDialog(order),
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

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Place New Order',
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                    DropdownButtonFormField<String>(
                      value: selectedProduct,
                      decoration:
                          const InputDecoration(
                        labelText: 'Product',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value:
                              '250ml Water Bottle',
                          child: Text(
                            '250ml Water Bottle',
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                              '500ml Water Bottle',
                          child: Text(
                            '500ml Water Bottle',
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                              '1 Litre Water Bottle',
                          child: Text(
                            '1 Litre Water Bottle',
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                              '2 Litre Water Bottle',
                          child: Text(
                            '2 Litre Water Bottle',
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                              '5 Litre Water Jar',
                          child: Text(
                            '5 Litre Water Jar',
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                              '20 Litre Water Jar',
                          child: Text(
                            '20 Litre Water Jar',
                          ),
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
                      controller:
                          quantityController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        labelText: 'Quantity',
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller:
                          notesController,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Delivery Notes',
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        color: const Color(
                          0xFFE0F2FE,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                      ),
                      child: const Text(
                        'Order will be sent for Plant Approval after placement.',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              Color(0xFF0284C7),
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
                    style:
                        TextButton.styleFrom(
                      minimumSize:
                          const Size(
                        0,
                        44,
                      ),
                      maximumSize:
                          const Size(
                        90,
                        44,
                      ),
                    ),
                    onPressed: isSubmitting ? null : () {
                      Navigator.pop(
                        dialogContext,
                      );
                    },
                    child:
                        const Text('Cancel'),
                  ),
                ),

                SizedBox(
                  width: 130,
                  height: 44,
                  child: ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      minimumSize:
                          const Size(
                        0,
                        44,
                      ),
                      maximumSize:
                          const Size(
                        130,
                        44,
                      ),
                    ),
                    onPressed: isSubmitting ? null : () async {
                      final quantity =
                          int.tryParse(
                                quantityController
                                    .text,
                              ) ??
                              0;

                      if (quantity <= 0) {
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      final user = await SessionService().getCurrentUser();
                      final franchiseName = user?.businessName.isNotEmpty == true
                          ? user!.businessName
                          : (user?.name.isNotEmpty == true ? user!.name : 'Franchise Partner');
                      final city = user?.city.isNotEmpty == true ? user!.city : 'Raipur';
                      final double totalAmount = (quantity * 20).toDouble();

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
                        Navigator.pop(dialogContext);
                        await _fetchOrders();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Order of $quantity x $selectedProduct placed successfully!'),
                              backgroundColor: const Color(0xFF0284C7),
                            ),
                          );
                        }
                      } else {
                        setDialogState(() => isSubmitting = false);
                        final msg = res['message'] ?? 'Failed to place order';
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Place Order',
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    quantityController.dispose();
    notesController.dispose();
  }

  // =========================================================
  // DETAILS
  // =========================================================

  void _details(
    Map<String, dynamic> order,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Order Details',
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _detailRow(
                    'Order ID',
                    '${order['id']}',
                  ),
                  _detailRow(
                    'Date',
                    '${order['date']}',
                  ),
                  _detailRow(
                    'Product',
                    '${order['product']}',
                  ),
                  _detailRow(
                    'Quantity',
                    '${order['qty']}',
                  ),
                  _detailRow(
                    'Amount',
                    '₹${_formatAmount(order['amount'])}',
                  ),
                  _detailRow(
                    'Status',
                    '${order['status']}',
                  ),
                  _detailRow(
                    'Payment',
                    '${order['payment']}',
                  ),

                  const SizedBox(height: 18),

                  _orderProgress(
                    '${order['status']}',
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
                style:
                    TextButton.styleFrom(
                  minimumSize:
                      const Size(
                    0,
                    44,
                  ),
                  maximumSize:
                      const Size(
                    90,
                    44,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
                child:
                    const Text('Close'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showUpdateStatusDialog(order);
                },
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Update Status'),
              ),
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

    String selectedNewStatus = order['status']?.toString() ?? 'Plant Approval';
    const statusOptions = [
      'Order Placement',
      'Plant Approval',
      'Invoice Generated',
      'Dispatched',
      'Delivered',
      'Cancelled',
    ];

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Update Order Status (#${order['id']})', style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select the new fulfillment status for this order:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: statusOptions.contains(selectedNewStatus) ? selectedNewStatus : statusOptions.first,
                decoration: const InputDecoration(
                  labelText: 'Fulfillment Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
                items: statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) {
                  if (val != null) setDlgState(() => selectedNewStatus = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await OrderService().updateOrderStatus(dbId, selectedNewStatus);
                if (!mounted) return;
                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Order #${order['id']} status updated to $selectedNewStatus'),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                  _fetchOrders();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'Failed to update order status'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              },
              child: const Text('Confirm Status'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(
                color:
                    Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderProgress(
    String status,
  ) {
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
    } else if (status ==
        'Invoice Generated') {
      activeStep = 2;
    } else if (status ==
        'Dispatched') {
      activeStep = 3;
    } else if (status ==
        'Delivered') {
      activeStep = 4;
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Progress',
          style: TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        ...List.generate(
          steps.length,
          (index) {
            final done =
                index <= activeStep;

            return Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 8,
              ),
              child: Row(
                children: [
                  Icon(
                    done
                        ? Icons
                            .check_circle_rounded
                        : Icons
                            .radio_button_unchecked,
                    color: done
                        ? const Color(
                            0xFF0284C7,
                          )
                        : const Color(
                            0xFFCBD5E1,
                          ),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    steps[index],
                    style: TextStyle(
                      fontWeight: done
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: done
                          ? const Color(
                              0xFF111827,
                            )
                          : const Color(
                              0xFF94A3B8,
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
        color:
            const Color(0xFFE0F2FE),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        color:
            Color(0xFF0284C7),
      ),
    );
  }

  Widget _statusBadge(
    String status,
  ) {
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
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }

  Widget _paymentBadge(
    String payment,
  ) {
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
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        payment,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }

  String _formatAmount(
    dynamic amount,
  ) {
    final number =
        int.tryParse('$amount') ?? 0;

    return number.toString();
  }
}

// =========================================================
// STAT CARD
// =========================================================

class _StatCard
    extends StatelessWidget {
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
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: 105,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color:
                  const Color(
                0xFFE0F2FE,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              color:
                  const Color(
                0xFF0284C7,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color:
                        Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color:
                        Color(0xFF94A3B8),
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

// =========================================================
// MOBILE STAT
// =========================================================

class _MobileStat
    extends StatelessWidget {
  final String title;
  final String value;

  const _MobileStat({
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color:
                  Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle
    _tableHeaderStyle =
    TextStyle(
  fontSize: 9,
  fontWeight:
      FontWeight.w700,
  color:
      Color(0xFF64748B),
  letterSpacing: 0.4,
);