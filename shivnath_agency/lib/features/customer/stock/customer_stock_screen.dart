import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/stock_service.dart';
import '../products/customer_products_screen.dart';

class CustomerStockScreen extends StatefulWidget {
  const CustomerStockScreen({super.key});

  @override
  State<CustomerStockScreen> createState() => _CustomerStockScreenState();
}

class _CustomerStockScreenState extends State<CustomerStockScreen> {
  final StockService _stockService = StockService();
  final AuthService _authService = AuthService();

  bool _isSyncing = false;
  List<Map<String, dynamic>> _activeStocks = [];
  List<Map<String, dynamic>> _stockHistory = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initStockData();
  }

  Future<void> _initStockData() async {
    // 1. Instant local load (paint UI in < 10ms)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRaw = prefs.getString('cached_customer_stocks');
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        final decoded = jsonDecode(cachedRaw);
        if (decoded is Map<String, dynamic> && mounted) {
          setState(() {
            _activeStocks = List<Map<String, dynamic>>.from(
              decoded['active_stocks'] ?? [],
            );
            _stockHistory = List<Map<String, dynamic>>.from(
              decoded['stock_history'] ?? [],
            );
          });
        }
      }
    } catch (_) {}

    // 2. Background network refresh
    _fetchStocks();
  }

  Future<void> _fetchStocks() async {
    if (mounted) setState(() => _isSyncing = true);

    try {
      final res = await _stockService.getCustomerStock();
      if (!mounted) return;

      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final data = res['data'] as Map<String, dynamic>;
        final active = List<Map<String, dynamic>>.from(
          data['active_stocks'] ?? [],
        );
        final history = List<Map<String, dynamic>>.from(
          data['stock_history'] ?? [],
        );

        setState(() {
          _activeStocks = active;
          _stockHistory = history;
          _isSyncing = false;
          _errorMessage = null;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'cached_customer_stocks',
          jsonEncode({
            'active_stocks': active,
            'stock_history': history,
          }),
        );
      } else {
        setState(() {
          _isSyncing = false;
          if (_activeStocks.isEmpty) {
            _errorMessage = res['message'] ?? 'Unable to connect to water server';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _callFranchise(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available for this franchise'),
        ),
      );
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not dial $phone')));
    }
  }

  Future<void> _handleHoldResume(Map<String, dynamic> stock) async {
    final status = stock['service_status'] ?? 'active';
    final isHold = status == 'hold';
    final action = isHold ? 'resume' : 'hold';
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isHold ? 'Resume Water Service' : 'Pause Water Service (Hold)',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHold
                  ? 'Reactivate daily water deliveries. Your remaining stock cycle days will resume from today.'
                  : 'Going on vacation or renovation? Pause your service and freeze remaining days safely.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: isHold ? 'Notes (Optional)' : 'Reason for Hold *',
                hintText: isHold
                    ? 'e.g. Back from trip'
                    : 'e.g. Out of station for 10 days',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isHold
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isHold ? 'Resume Now' : 'Confirm Pause'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = await _authService.updateServiceStatus(
      action: action,
      reason: reasonController.text.trim(),
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['data']?['message']?.toString() ?? 'Service status updated.',
          ),
          backgroundColor: isHold
              ? const Color(0xFF16A34A)
              : const Color(0xFF0284C7),
        ),
      );
      _fetchStocks();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ?? 'Failed to update service status',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Color _getStatusColor(String status, bool isLowStock) {
    if (status == 'hold') return const Color(0xFF9333EA);
    if (status == 'expired') return const Color(0xFFDC2626);
    if (isLowStock) return const Color(0xFFD97706);
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Water Stock',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchStocks,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStocks,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isSyncing)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Color(0xFFE2E8F0),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                  ),
                ),
              ),
            if (_errorMessage != null && _activeStocks.isEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_sync_outlined,
                      color: Color(0xFF0284C7),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _fetchStocks,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            _buildHeaderSummary(),
                  const SizedBox(height: 16),
                  const Text(
                    'Active Stock Cycles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_activeStocks.isEmpty)
                    _buildEmptyActiveCard()
                  else
                    ..._activeStocks.map(_buildActiveStockCard),
                  const SizedBox(height: 24),
                  const Text(
                    'Stock & Refill History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_stockHistory.isEmpty)
                    _buildEmptyHistoryCard()
                  else
                    ..._stockHistory.map(_buildHistoryStockCard),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderSummary() {
    final activeCount = _activeStocks.length;
    final lowStockCount = _activeStocks
        .where((s) => s['is_low_stock'] == true)
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pure Drinking Water Stock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lowStockCount > 0
                      ? '⚠️ $lowStockCount stock cycle(s) running low on days!'
                      : activeCount > 0
                      ? 'All active water delivery cycles running normally.'
                      : 'No active stock cycle found. Place an order to start!',
                  style: TextStyle(
                    color: lowStockCount > 0
                        ? const Color(0xFFFEF08A)
                        : Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: lowStockCount > 0
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStockCard(Map<String, dynamic> stock) {
    final productName = stock['product_name'] ?? 'Pure Mineral Water';
    final variantSize = stock['variant_size'] ?? '';
    final quantity = stock['quantity'] ?? 1;
    final orderNumber = stock['order_number'] ?? 'N/A';
    final durationChoice = stock['duration_choice'] ?? '';
    final durationDays = stock['duration_days'] ?? 30;
    final startDate = stock['start_date'] ?? '';
    final expectedEndDate = stock['expected_end_date'] ?? '';
    final daysRemaining = stock['days_remaining'] ?? 0;
    final isLowStock = stock['is_low_stock'] == true;
    final status = stock['service_status'] ?? 'active';
    final servingFranchise =
        stock['serving_franchise'] as Map<String, dynamic>?;
    final registeredFranchise =
        stock['registered_franchise'] as Map<String, dynamic>?;
    final territory = stock['territory'] as Map<String, dynamic>?;

    final progress = (durationDays > 0)
        ? (daysRemaining / durationDays).clamp(0.0, 1.0)
        : 0.0;
    final statusColor = _getStatusColor(status, isLowStock);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLowStock ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
          width: isLowStock ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠️ Low Stock Banner
          if (isLowStock && status != 'hold')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Low Stock Alert! $daysRemaining day(s) remaining.',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerProductsScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Refill Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Product Name + Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (variantSize.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Size: $variantSize  •  Qty: $quantity',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        status == 'hold'
                            ? 'PAUSED / ON HOLD'
                            : isLowStock
                            ? 'LOW STOCK'
                            : status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Order link tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.receipt_outlined,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Order $orderNumber',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Countdown and duration
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Stock Duration',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                durationChoice.isNotEmpty
                                    ? durationChoice.toUpperCase()
                                    : '$durationDays Days',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Remaining Days',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '$daysRemaining Days',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Started: $startDate',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            'Finishes: $expectedEndDate',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Serving & Territory Details
                if (servingFranchise != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Serving Franchise: ${servingFranchise['business_name'] ?? servingFranchise['name'] ?? 'Shivnath Partner'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (servingFranchise['phone'] != null)
                        InkWell(
                          onTap: () => _callFranchise(
                            servingFranchise['phone']?.toString(),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 12,
                                  color: Color(0xFF0284C7),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Call',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF0284C7),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                if (registeredFranchise != null &&
                    registeredFranchise['id'] != servingFranchise?['id']) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Registered Franchise: ${registeredFranchise['business_name'] ?? registeredFranchise['name'] ?? 'Shivnath Franchise'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                if (territory != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Territory: ${territory['zone'] ?? ''}, ${territory['district'] ?? ''} (${territory['pincode'] ?? ''})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                const Divider(height: 1),
                const SizedBox(height: 10),

                // Actions: Pause/Resume + Refill
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: status == 'hold'
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFE11D48),
                          side: BorderSide(
                            color: status == 'hold'
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFE11D48),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _handleHoldResume(stock),
                        icon: Icon(
                          status == 'hold'
                              ? Icons.play_arrow_rounded
                              : Icons.pause_circle_outline_rounded,
                          size: 18,
                        ),
                        label: Text(
                          status == 'hold' ? 'Resume Service' : 'Pause Service',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomerProductsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.autorenew_rounded, size: 18),
                        label: const Text('Refill Stock'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryStockCard(Map<String, dynamic> stock) {
    final productName = stock['product_name'] ?? 'Pure Mineral Water';
    final variantSize = stock['variant_size'] ?? '';
    final quantity = stock['quantity'] ?? 1;
    final orderNumber = stock['order_number'] ?? 'N/A';
    final durationChoice = stock['duration_choice'] ?? '';
    final durationDays = stock['duration_days'] ?? 30;
    final startDate = stock['start_date'] ?? '';
    final expectedEndDate = stock['expected_end_date'] ?? '';
    final servingFranchise =
        stock['serving_franchise'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Order $orderNumber  •  $quantity unit(s) ($variantSize)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Duration: ${durationChoice.isNotEmpty ? durationChoice : "$durationDays Days"} ($startDate to $expectedEndDate)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                if (servingFranchise != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Served by: ${servingFranchise['business_name'] ?? servingFranchise['name'] ?? 'Franchise'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'COMPLETED',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActiveCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.water_drop_outlined,
              size: 42,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 8),
            const Text(
              'No Active Stock Cycle',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'You currently do not have an active pure water supply cycle.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerProductsScreen(),
                  ),
                );
              },
              child: const Text('Order Water Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Text(
          'No past stock cycles recorded yet.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}
