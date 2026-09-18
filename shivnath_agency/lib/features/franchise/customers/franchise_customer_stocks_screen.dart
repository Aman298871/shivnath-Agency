import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/stock_service.dart';
import '../../../core/services/whatsapp_service.dart';

class FranchiseCustomerStocksScreen extends StatefulWidget {
  const FranchiseCustomerStocksScreen({super.key});

  @override
  State<FranchiseCustomerStocksScreen> createState() => _FranchiseCustomerStocksScreenState();
}

class _FranchiseCustomerStocksScreenState extends State<FranchiseCustomerStocksScreen> {
  final StockService _stockService = StockService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, low_stock, on_hold, expired
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _stocks = [];
  Map<String, dynamic> _counts = {
    'total': 0,
    'low_stock': 0,
    'on_hold': 0,
    'expired': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchCustomerStocks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomerStocks() async {
    setState(() => _isLoading = true);

    final res = await _stockService.getFranchiseCustomerStocks(
      filter: _selectedFilter,
      search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
    );

    if (!mounted) return;

    if (res['success'] == true && res['data'] is Map<String, dynamic>) {
      final data = res['data'] as Map<String, dynamic>;
      final list = data['customer_stocks'] as List? ?? [];
      final counts = data['counts'] as Map<String, dynamic>? ?? {};

      setState(() {
        _stocks = List<Map<String, dynamic>>.from(list);
        _counts = counts;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not dial $phone')),
      );
    }
  }

  Future<void> _chatCustomerWhatsApp(String? phone, String name, String product, int daysRemaining) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }
    final message = daysRemaining <= 7
        ? 'Namaste $name ji,\nThis is regarding your pure water delivery ($product). Your stock has $daysRemaining day(s) remaining. Would you like us to schedule your refill delivery?'
        : 'Namaste $name ji,\nThis is your pure water delivery franchise partner regarding your current supply cycle.';

    await WhatsAppService.openWhatsApp(
      phone: phone,
      message: message,
    );
  }

  Future<void> _handleServiceStatusChange({
    required int customerId,
    required String currentStatus,
  }) async {
    final isHold = currentStatus == 'hold';
    final action = isHold ? 'resume' : 'hold';
    final title = isHold ? 'Resume Water Delivery' : 'Put Water Service on Hold';
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHold
                  ? 'Reactivate water deliveries for this customer. Preserved days will resume from today.'
                  : 'Specify reason for pausing water delivery. The remaining duration countdown will freeze safely.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: isHold ? 'Notes / Reason (Optional)' : 'Reason for Hold *',
                hintText: isHold ? 'e.g. Customer requested restart' : 'e.g. Customer out of station',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isHold ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isHold ? 'Resume Delivery' : 'Confirm Hold'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = await _authService.updateServiceStatus(
      action: action,
      reason: reasonController.text.trim(),
      customerId: customerId,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['data']?['message']?.toString() ?? 'Service status updated.'),
          backgroundColor: isHold ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
        ),
      );
      _fetchCustomerStocks();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Failed to update service status'),
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
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Customer Stock Cycles', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCustomerStocks,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter tabs & counts
          _buildFilterChips(),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by customer, mobile, product...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _fetchCustomerStocks();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              onSubmitted: (val) {
                setState(() => _searchQuery = val);
                _fetchCustomerStocks();
              },
            ),
          ),

          // Main list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
                : _stocks.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchCustomerStocks,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _stocks.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
                          itemBuilder: (context, idx) {
                            return _buildStockCard(_stocks[idx]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('all', 'All Stocks', _counts['total'] ?? 0),
            const SizedBox(width: 8),
            _filterChip('low_stock', '⚠️ Low Stock', _counts['low_stock'] ?? 0, alertColor: const Color(0xFFD97706)),
            const SizedBox(width: 8),
            _filterChip('on_hold', 'On Hold', _counts['on_hold'] ?? 0, alertColor: const Color(0xFF9333EA)),
            const SizedBox(width: 8),
            _filterChip('expired', 'Expired', _counts['expired'] ?? 0, alertColor: const Color(0xFFDC2626)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label, int count, {Color? alertColor}) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
              color: isSelected
                  ? Colors.white
                  : (alertColor != null && count > 0 ? alertColor : const Color(0xFF475569)),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.25) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
      selectedColor: alertColor ?? const Color(0xFF0284C7),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedFilter = key);
          _fetchCustomerStocks();
        }
      },
    );
  }

  Widget _buildStockCard(Map<String, dynamic> stock) {
    final customer = stock['customer'] as Map<String, dynamic>? ?? {};
    final custName = customer['name']?.toString() ?? 'Valued Customer';
    final custPhone = customer['phone']?.toString() ?? '';
    final custCode = customer['customer_code']?.toString() ?? 'CUST-${customer['id']}';
    final custAddress = customer['address']?.toString() ?? '';
    final customerId = customer['id'] as int? ?? 0;

    final productName = stock['product_name'] ?? 'Pure Drinking Water';
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
    final territory = stock['territory'] as Map<String, dynamic>?;

    final statusColor = _getStatusColor(status, isLowStock);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLowStock && status != 'hold' ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB),
          width: isLowStock && status != 'hold' ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top strip for low-stock alert
          if (isLowStock && status != 'hold')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Refill Alert: Only $daysRemaining day(s) remaining for $custName!',
                      style: const TextStyle(color: Color(0xFFB45309), fontSize: 12, fontWeight: FontWeight.w700),
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
                // Header: Customer Info + Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFE0F2FE),
                      child: Text(
                        custName.isNotEmpty ? custName[0].toUpperCase() : 'C',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(custName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            '$custCode  •  $custPhone',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        status == 'hold'
                            ? 'ON HOLD'
                            : isLowStock
                                ? '$daysRemaining DAYS LEFT'
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

                // Product details box
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  productName,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                                ),
                                if (variantSize.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Size: $variantSize  •  Qty: $quantity',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Remaining', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              Text(
                                '$daysRemaining Days',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: statusColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order: $orderNumber', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text(
                            durationChoice.isNotEmpty ? durationChoice.toUpperCase() : '$durationDays Days Plan',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Started: $startDate', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          Text('Finishes: $expectedEndDate', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Territory / Address
                if (custAddress.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.home_outlined, size: 15, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            custAddress,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (territory != null)
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Zone: ${territory['zone'] ?? ''}, ${territory['district'] ?? ''} (${territory['pincode'] ?? ''})',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),

                const Divider(height: 1),
                const SizedBox(height: 10),

                // Action buttons: Call, WhatsApp, Hold/Resume
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0284C7),
                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => _makePhoneCall(custPhone),
                        icon: const Icon(Icons.phone, size: 15),
                        label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => _chatCustomerWhatsApp(custPhone, custName, productName, daysRemaining),
                        icon: const Icon(Icons.chat_outlined, size: 15),
                        label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: status == 'hold' ? 'Resume delivery' : 'Put on hold',
                      style: IconButton.styleFrom(
                        backgroundColor: status == 'hold' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        foregroundColor: status == 'hold' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: customerId > 0
                          ? () => _handleServiceStatusChange(customerId: customerId, currentStatus: status)
                          : null,
                      icon: Icon(
                        status == 'hold' ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        size: 18,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.water_drop_outlined, size: 56, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              _selectedFilter == 'low_stock'
                  ? 'No customers currently running low on stock'
                  : _selectedFilter == 'on_hold'
                      ? 'No customer services currently on hold'
                      : _selectedFilter == 'expired'
                          ? 'No expired customer stock cycles'
                          : 'No customer stock cycles found',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Stock cycles for customers served by your franchise will appear here.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
