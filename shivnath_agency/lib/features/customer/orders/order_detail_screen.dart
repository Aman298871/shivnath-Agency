import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/repositories/app_repositories.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/product_thumbnail.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final String? amount;
  final String? status;
  final Map<String, dynamic>? initialOrder;
  final int? dbId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.amount,
    this.status,
    this.initialOrder,
    this.dbId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderRepository _orderRepository = OrderRepository();
  final AuthRepository _authRepository = AuthRepository();
  Map<String, dynamic>? _order;
  bool _loading = false;
  bool _updatingStatus = false;
  String? _error;
  String? _userRole;

  bool get _isAdminOrStaff {
    final r = (_userRole ?? '').toLowerCase();
    return r == 'admin' || r == 'super_admin' || r == 'staff' || r == 'franchise';
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    if (widget.initialOrder != null) {
      _order = Map<String, dynamic>.from(widget.initialOrder!);
    }
    _fetchLatestOrder();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = await _authRepository.getCachedUser();
      if (user != null && mounted) {
        setState(() {
          _userRole = user.role;
        });
      }
    } catch (_) {}
  }

  int? get _resolvedDbId {
    if (widget.dbId != null && widget.dbId! > 0) return widget.dbId;
    if (_order != null && _order!['id'] != null) {
      final parsed = int.tryParse(_order!['id'].toString());
      if (parsed != null && parsed > 0) return parsed;
    }
    final raw = widget.orderId.replaceAll('ORD-', '').replaceAll('#', '').trim();
    final parsed = int.tryParse(raw);
    return parsed;
  }

  Future<void> _fetchLatestOrder() async {
    int? id = _resolvedDbId;
    if (id == null || id <= 0) {
      try {
        final cleanWidgetId = widget.orderId.replaceAll('#', '').toLowerCase().trim();
        final searchRes = await _orderRepository.getOrders(search: cleanWidgetId);
        if (searchRes['success'] == true && searchRes['data'] != null) {
          final List ordersList = searchRes['data']['orders'] ?? (searchRes['data'] is List ? searchRes['data'] : []);
          for (final item in ordersList) {
            if (item is Map) {
              final mapped = _orderRepository.mapOrder(Map<String, dynamic>.from(item));
              final ordIdStr = (mapped['orderId'] ?? '').toString().replaceAll('#', '').toLowerCase().trim();
              final dbIdStr = (mapped['id'] ?? '').toString().trim();
              if (ordIdStr == cleanWidgetId || dbIdStr == cleanWidgetId) {
                id = mapped['id'] is int ? mapped['id'] as int : int.tryParse('${mapped['id']}');
                _order = mapped;
                break;
              }
            }
          }
        }
      } catch (_) {}
    }
    if (id == null || id <= 0) {
      if (_order == null && mounted) {
        setState(() {
          _loading = false;
          _error = 'Order "${widget.orderId}" could not be loaded. It may have been deleted, updated, or the server is unreachable.';
        });
      }
      return;
    }

    if (_order == null) {
      setState(() => _loading = true);
    }

    try {
      final res = await _orderRepository.getOrder(id);
      if (!mounted) return;

      if (res['success'] == true && res['data'] is Map) {
        final raw = res['data']['order'] ?? res['data'];
        if (raw is Map) {
          final mapped = _orderRepository.mapOrder(Map<String, dynamic>.from(raw));
          setState(() {
            _order = mapped;
            _loading = false;
            _error = null;
          });
          return;
        }
      }

      if (_order == null) {
        setState(() {
          _loading = false;
          _error = res['message']?.toString() ?? 'Unable to fetch order details.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_order == null) {
        setState(() {
          _loading = false;
          _error = 'Network error while loading order: $e';
        });
      }
    }
  }

  String _formatDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return DateFormat('dd MMM yyyy • hh:mm a').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderCode = _order?['orderId']?.toString() ??
        (widget.orderId.startsWith('#') ? widget.orderId : '#${widget.orderId}');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          orderCode,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh order status',
            onPressed: _fetchLatestOrder,
          ),
        ],
      ),
      body: _loading && _order == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _order == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: Color(0xFFEF4444)),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchLatestOrder,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Back to Dashboard'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchLatestOrder,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        children: [
                          _buildHeaderCard(),
                          if (_isAdminOrStaff) ...[
                            const SizedBox(height: 16),
                            _buildAdminActionsCard(),
                          ],
                          const SizedBox(height: 16),
                          _buildFulfillmentCard(),
                          const SizedBox(height: 16),
                          _buildDeliveryAddressCard(),
                          const SizedBox(height: 16),
                          _buildItemsCard(),
                          const SizedBox(height: 16),
                          _buildInvoiceCard(),
                          const SizedBox(height: 16),
                          _buildPriceSummaryCard(),
                          const SizedBox(height: 16),
                          _buildTimelineCard(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildAdminActionsCard() {
    final curStatus = (_order?['status'] ?? widget.status ?? 'Order Placement').toString();
    final lower = curStatus.toLowerCase();
    final dbId = _resolvedDbId;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFBAE6FD), width: 1.5),
      ),
      color: const Color(0xFFF0F9FF),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ADMIN ORDER OPERATIONS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0369A1),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Current Stage: $curStatus',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_updatingStatus)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFBAE6FD)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.published_with_changes_rounded, size: 18),
                  label: const Text(
                    'UPDATE STATUS / FULFILL',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  onPressed: (_updatingStatus || dbId == null) ? null : () => _showStatusUpdateDialog(dbId, curStatus),
                ),
                if (lower.contains('placement') || lower.contains('pending'))
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text(
                      'APPROVE ORDER',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    onPressed: (_updatingStatus || dbId == null) ? null : () => _performStatusUpdate(dbId, 'Plant Approval'),
                  ),
                if (lower.contains('approval') || lower.contains('prep'))
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: const Text(
                      'DISPATCH ORDER',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    onPressed: (_updatingStatus || dbId == null) ? null : () => _performStatusUpdate(dbId, 'Dispatch'),
                  ),
                if (lower.contains('dispatch'))
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: const Text(
                      'CONFIRM DELIVERED',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    onPressed: (_updatingStatus || dbId == null) ? null : () => _performStatusUpdate(dbId, 'Delivered'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performStatusUpdate(int id, String newStatus) async {
    setState(() => _updatingStatus = true);
    try {
      final res = await _orderRepository.updateOrderStatus(id, newStatus);
      if (!mounted) return;
      if (res['success'] == true) {
        AppToast.success(context, 'Order transitioned to $newStatus successfully!');
        await _fetchLatestOrder();
      } else {
        AppToast.error(context, res['message'] ?? 'Failed to update order status.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Network error updating status: $e');
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _showStatusUpdateDialog(int id, String currentStatus) async {
    final String currentCanonical = _orderRepository.canonicalStatus(currentStatus);
    final List<String> statuses = _orderRepository.getAllowedNextStatuses(currentCanonical);

    if (statuses.isEmpty) {
      if (!mounted) return;
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
            'This order is currently in "${_orderRepository.getStatusLabel(currentCanonical)}".\n\n'
            'It has reached a terminal state and cannot be transitioned to any other fulfillment stage.',
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

    String selected = statuses.first;

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String val = selected;
        return StatefulBuilder(
          builder: (context, setDlgState) => AlertDialog(
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Update Order Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select target lifecycle stage:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: statuses.contains(val) ? val : statuses.first,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(_orderRepository.getStatusLabel(s), style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                    onChanged: (nv) {
                      if (nv != null) setDlgState(() => val = nv);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, val),
                child: const Text('Apply Status'),
              ),
            ],
          ),
        );
      },
    );

    if (updated != null && updated.isNotEmpty && mounted) {
      await _performStatusUpdate(id, updated);
    }
  }

  Widget _buildHeaderCard() {
    final status = _order?['status']?.toString() ?? widget.status ?? 'Order Placement';
    final amount = _order?['amount'] != null
        ? '₹${_order!['amount']}'
        : (widget.amount ?? '₹0.00');
    final rawDate = _order?['raw']?['created_at'] ?? _order?['date'];
    final dateDisplay = _formatDateTime(rawDate).isNotEmpty
        ? _formatDateTime(rawDate)
        : (_order?['date']?.toString() ?? '');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF0284C7),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _order?['orderId']?.toString() ?? widget.orderId,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (dateDisplay.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                dateDisplay,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                AppStatusBadge.order(status),
              ],
            ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: BrandColors.redDark,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Payment Status',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    AppStatusBadge.payment(_order?['payment']?.toString() ?? 'Pending'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFulfillmentCard() {
    final fulfilling = _order?['fulfilling_entity'] as Map<String, dynamic>?;
    final orderSource = _order?['order_source']?.toString() ?? _order?['raw']?['order_source']?.toString() ?? '';
    final isWaterWallet = orderSource == 'WATER_WALLET' ||
        orderSource == 'WATER_WALLET_REDEMPTION' ||
        _order?['payment_mode'] == 'WALLET';
    final isFranchise = !isWaterWallet &&
        (_order?['order_source'] != 'DIRECT_COMPANY') &&
        (fulfilling?['type'] == 'FRANCHISE' ||
            (_order?['serving_franchise_name'] ?? '').toString().isNotEmpty);

    final title = isWaterWallet
        ? 'Shivnath Central Admin (Water Wallet)'
        : (isFranchise
            ? (fulfilling?['name'] ?? _order?['serving_franchise_name'] ?? _order?['franchise'] ?? 'Wholesale Dealer')
            : 'Shivnath Agency (Central Plant)');
    final subtitle = isWaterWallet
        ? 'Central Admin Direct Fulfillment — Paid via Water Wallet'
        : (isFranchise
            ? 'Wholesale Dealer Fulfilled'
            : 'Direct Company Fulfilled (Raipur Plant)');
    final phone = fulfilling?['phone']?.toString() ?? '';
    final territory = fulfilling?['territory']?.toString() ?? _order?['raw']?['territory']?.toString() ?? '';
    final address = fulfilling?['address']?.toString() ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFranchise ? Icons.storefront_rounded : Icons.factory_rounded,
                  color: isFranchise ? const Color(0xFF7C3AED) : const Color(0xFF0284C7),
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Fulfillment Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isFranchise ? const Color(0xFFF5F3FF) : const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFranchise ? const Color(0xFFDDD6FE) : const Color(0xFFBAE6FD),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isFranchise ? const Color(0xFF5B21B6) : const Color(0xFF0369A1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isFranchise ? const Color(0xFF7C3AED) : const Color(0xFF0284C7),
                    ),
                  ),
                  if (territory.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Territory / Zone: $territory',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'Contact: $phone',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.business_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryAddressCard() {
    final customerName = _order?['customer_name']?.toString() ??
        _order?['raw']?['customer_name']?.toString() ??
        'Valued Customer';
    final customerPhone = _order?['customer_phone']?.toString() ??
        _order?['raw']?['customer_phone']?.toString() ??
        '';
    final address = _order?['delivery_address']?.toString() ??
        _order?['raw']?['delivery_address']?.toString() ??
        '';
    final city = _order?['city']?.toString() ?? _order?['raw']?['city']?.toString() ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: Color(0xFF0284C7), size: 22),
                SizedBox(width: 8),
                Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              customerName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
            ),
            if (customerPhone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    customerPhone,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(
              address.isNotEmpty ? '$address, $city' : (city.isNotEmpty ? city : 'Standard Delivery Destination'),
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    final rawItems = _order?['items_list'] ?? _order?['raw']?['items'] ?? [];
    final List<Map<String, dynamic>> items = rawItems is List
        ? rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Products Ordered',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.water_drop_outlined, color: Color(0xFF0284C7)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_order?['items'] ?? 1} Items (${_order?['franchise'] ?? 'Packaged Water'})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '₹${_order?['amount'] ?? '0.00'}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                    ),
                  ],
                ),
              )
            else
              ...items.map((item) {
                final name = item['product_name'] ?? item['name'] ?? 'Packaged Water';
                final sku = item['sku'] ?? item['product_sku'] ?? '';
                final size = item['size'] ?? '';
                final qty = item['quantity'] ?? 1;
                final unitPrice = item['unit_price'] ?? item['price'] ?? 0;
                final totalPrice = item['total_price'] ??
                    ((double.tryParse(unitPrice.toString()) ?? 0) * (int.tryParse(qty.toString()) ?? 1));

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProductThumbnail.fromMap(
                        data: item,
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                        borderRadius: BorderRadius.circular(8),
                        padding: const EdgeInsets.all(4),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            if (sku.toString().isNotEmpty || size.toString().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                '${sku.toString().isNotEmpty ? 'SKU: $sku • ' : ''}${size.toString().isNotEmpty ? 'Size: $size' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '₹$unitPrice × $qty',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹$totalPrice',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceCard() {
    final invNumber = _order?['invoice_number']?.toString() ??
        _order?['raw']?['invoice_number']?.toString() ??
        '';
    final invStatus = _order?['invoice_status']?.toString() ??
        _order?['raw']?['invoice_status']?.toString() ??
        'UNPAID';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Tax Invoice',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                if (invNumber.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: invStatus == 'PAID'
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      invStatus,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: invStatus == 'PAID'
                            ? const Color(0xFF166534)
                            : const Color(0xFF92400E),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (invNumber.isNotEmpty) ...[
              Text(
                'Invoice No: $invNumber',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Official GST compliant invoice issued by Shivnath Agency / Serving Franchise.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF0284C7)),
                label: const Text('View Tax Breakdown', style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w700)),
                onPressed: _showInvoiceModal,
              ),
            ] else ...[
              const Text(
                'Invoice will be generated upon Plant Approval / Order Preparation.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showInvoiceModal() {
    final invNumber = _order?['invoice_number']?.toString() ?? '';
    final subtotal = _order?['invoice_subtotal'] ?? _order?['amount'] ?? 0.0;
    final tax = _order?['invoice_tax'] ?? 0.0;
    final grandTotal = _order?['invoice_grand_total'] ?? _order?['amount'] ?? 0.0;
    final customer = _order?['customer_name'] ?? 'Customer';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_rounded, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Text(
                      'Tax Invoice $invNumber',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _infoRow('Billed To', customer.toString()),
                _infoRow('Serving Plant/Dealer', _order?['franchise']?.toString() ?? 'Shivnath Agency'),
                _infoRow('Items Subtotal', '₹$subtotal'),
                _infoRow('CGST + SGST (18%)', '₹$tax'),
                _infoRow('Delivery Fee', 'FREE'),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Invoice Grand Total', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    Text('₹$grandTotal', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: BrandColors.redDark)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSummaryCard() {
    final subtotal = _order?['invoice_subtotal'] ?? _order?['amount'] ?? 0.0;
    final tax = _order?['invoice_tax'] ?? 0.0;
    final grandTotal = _order?['invoice_grand_total'] ?? _order?['amount'] ?? 0.0;
    final rawPm = _order?['payment_mode']?.toString() ?? '';
    final paymentMode = (rawPm.isNotEmpty && !rawPm.contains('Cash on Delivery'))
        ? rawPm
        : 'Online Payment (Razorpay)';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bill Summary',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),
            _priceRow('Item Subtotal', '₹$subtotal'),
            if (tax > 0) _priceRow('GST (CGST + SGST)', '₹$tax'),
            _priceRow('Delivery Charges', 'FREE', isHighlight: true),
            _priceRow('Discount Applied', '₹0.00'),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '₹$grandTotal',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: BrandColors.redDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.payment_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  'Payment Mode: $paymentMode',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    final rawHistory = _order?['status_history'] ?? _order?['raw']?['status_history'] ?? [];
    final List<Map<String, dynamic>> history = rawHistory is List
        ? rawHistory.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Lifecycle Timeline',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${history.length} stages',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (history.isEmpty) ...[
              _buildStaticTimelineFallback(),
            ] else ...[
              ...List.generate(history.length, (idx) {
                final h = history[idx];
                final title = h['display_title'] ?? h['new_status'] ?? 'Status Update';
                final notes = h['display_notes'] ?? h['notes'] ?? '';
                final role = h['performer_role'] ?? '';
                final timestamp = _formatDateTime(h['created_at']);
                final isLast = idx == history.length - 1;
                final isCancelled = (h['new_status'] ?? '').toString().toLowerCase().contains('cancel');

                return _TimelineRow(
                  title: title.toString(),
                  subtitle: notes.toString(),
                  timestamp: timestamp,
                  roleBadge: role.toString(),
                  isCancelled: isCancelled,
                  isLast: isLast,
                  isCompleted: true,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaticTimelineFallback() {
    final currentStatus = (_order?['status'] ?? widget.status ?? 'order_placement').toString().toLowerCase();

    final isDelivered = currentStatus.contains('deliver');
    final isDispatched = isDelivered || currentStatus.contains('dispatch');
    final isPreparing = isDispatched || currentStatus.contains('prepar') || currentStatus.contains('invoice');
    final isApproved = isPreparing || currentStatus.contains('plant') || currentStatus.contains('approv');
    final isCancelled = currentStatus.contains('cancel');

    if (isCancelled) {
      return const Column(
        children: [
          _TimelineRow(
            title: 'Order Placed',
            subtitle: 'Initial order placed by client',
            isCompleted: true,
            isLast: false,
          ),
          _TimelineRow(
            title: 'Order Cancelled',
            subtitle: 'This order has been cancelled',
            isCompleted: true,
            isCancelled: true,
            isLast: true,
          ),
        ],
      );
    }

    return Column(
      children: [
        const _TimelineRow(
          title: 'Order Placed',
          subtitle: 'Order received and logged in system',
          isCompleted: true,
          isLast: false,
        ),
        _TimelineRow(
          title: 'Plant / Admin Approval',
          subtitle: 'Production & distribution confirmed',
          isCompleted: isApproved,
          isLast: false,
        ),
        _TimelineRow(
          title: 'Bottling & Packaging',
          subtitle: 'Goods staged at fulfillment hub',
          isCompleted: isPreparing,
          isLast: false,
        ),
        _TimelineRow(
          title: 'Dispatched for Delivery',
          subtitle: 'Dispatched on delivery vehicle',
          isCompleted: isDispatched,
          isLast: false,
        ),
        _TimelineRow(
          title: 'Delivered',
          subtitle: 'Delivered successfully to customer',
          isCompleted: isDelivered,
          isLast: true,
        ),
      ],
    );
  }

  Widget _priceRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isHighlight ? const Color(0xFF10B981) : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timestamp;
  final String roleBadge;
  final bool isCompleted;
  final bool isCancelled;
  final bool isLast;

  const _TimelineRow({
    required this.title,
    required this.subtitle,
    this.timestamp = '',
    this.roleBadge = '',
    this.isCompleted = true,
    this.isCancelled = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isCancelled
        ? const Color(0xFFEF4444)
        : (isCompleted ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: dotColor,
              child: Icon(
                isCancelled
                    ? Icons.close_rounded
                    : (isCompleted ? Icons.check_rounded : Icons.circle),
                size: 13,
                color: Colors.white,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 52,
                color: isCompleted ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isCancelled
                              ? const Color(0xFFDC2626)
                              : (isCompleted ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    if (roleBadge.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          roleBadge,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                  ),
                ],
                if (timestamp.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timestamp,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}