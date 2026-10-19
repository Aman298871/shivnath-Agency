import 'package:flutter/material.dart';

import '../../../core/repositories/app_repositories.dart';
import 'franchise_customer_stocks_screen.dart';

class FranchiseCustomersScreen extends StatefulWidget {
  const FranchiseCustomersScreen({super.key});

  @override
  State<FranchiseCustomersScreen> createState() => _FranchiseCustomersScreenState();
}

class _FranchiseCustomersScreenState extends State<FranchiseCustomersScreen> {
  final AuthRepository _authRepository = AuthRepository();
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    final res = await _authRepository.getFranchiseCustomers(
      search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
    );

    if (mounted) {
      List<Map<String, dynamic>> list = [];
      if (res['success'] == true && res['data'] != null && res['data']['customers'] is List) {
        list = List<Map<String, dynamic>>.from(res['data']['customers']);
      }
      setState(() {
        _customers = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleServiceStatusChange({
    required int customerId,
    required String currentStatus,
  }) async {
    final isHold = currentStatus == 'hold';
    final action = isHold ? 'resume' : 'hold';
    final title = isHold ? 'Resume Water Service' : 'Put Water Service on Hold';
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isHold
                    ? 'Are you sure you want to resume daily water delivery for this customer? Remaining duration will reactivate.'
                    : 'Specify reason for pausing water delivery. The remaining duration countdown will freeze safely.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: isHold ? 'Notes / Reason (Optional)' : 'Reason for Hold *',
                  hintText: isHold ? 'e.g. Customer requested restart' : 'e.g. Vacation / Premises Renovation',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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

    final res = await _authRepository.updateServiceStatus(
      action: action,
      reason: reasonController.text.trim(),
      customerId: customerId,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['data']?['message']?.toString() ?? 'Service status updated successfully.'),
          backgroundColor: isHold ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
        ),
      );
      _fetchCustomers();
    } else {
      final msg = res['message'] ?? 'Failed to update service status';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showCustomerDetails(Map<String, dynamic> c) {
    final name = c['name']?.toString() ?? 'Customer';
    final code = c['customer_code']?.toString() ?? 'CUST-${c['id']}';
    final phone = c['phone']?.toString() ?? '';
    final email = c['email']?.toString() ?? '';
    final address = c['address']?.toString() ?? '';
    final district = c['district']?.toString() ?? '';
    final zoneName = c['zone_name']?.toString() ?? '';
    final pincode = c['pincode']?.toString() ?? '';
    final orderCount = c['order_count'] ?? 0;
    final stockCycle = c['stock_cycle'] as Map<String, dynamic>?;
    final holdHistory = c['hold_history'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFE0F2FE),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'C',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF0284C7)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(code, style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w700, fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            if (zoneName.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(zoneName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 10),
              const Text('Contact & Location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 10),
              _detailRow(Icons.phone_outlined, 'Mobile', phone.isNotEmpty ? phone : 'Not provided'),
              _detailRow(Icons.email_outlined, 'Email', email.isNotEmpty ? email : 'Not provided'),
              _detailRow(Icons.location_on_outlined, 'Area', '$district - $pincode'),
              if (address.isNotEmpty) _detailRow(Icons.home_outlined, 'Address', address),
              _detailRow(Icons.shopping_bag_outlined, 'Orders', '$orderCount orders placed'),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),
              const Text('Active Supply Stock Cycle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 10),
              if (stockCycle != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: stockCycle['status'] == 'active' ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: stockCycle['status'] == 'active' ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Status: ${stockCycle['status'].toString().toUpperCase()}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: stockCycle['status'] == 'active' ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                          ),
                          Text(
                            '${stockCycle['days_remaining']} Days Left',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Duration: ${stockCycle['duration_choice'] ?? 'Standard'}', style: const TextStyle(fontSize: 12)),
                      Text('Expected End Date: ${stockCycle['expected_end_date'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ] else ...[
                const Text('No active stock cycle currently running.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
              if (holdHistory.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),
                const Text('Service Hold / Resume Audit Log', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                ...holdHistory.take(4).map((h) {
                  final action = (h['action'] ?? '').toString().toUpperCase();
                  final actorName = h['actor_name'] ?? 'User';
                  final remaining = h['remaining_days'] ?? 0;
                  final reason = h['reason'] ?? '';
                  final date = (h['created_at'] ?? '').toString().split('T').first;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          action == 'HOLD' ? Icons.pause_circle_outline : Icons.play_circle_outline,
                          size: 16,
                          color: action == 'HOLD' ? Colors.orange : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$action by $actorName ($date)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              if (reason.isNotEmpty)
                                Text('Reason: $reason', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              Text('Remaining days: $remaining', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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

  Widget _detailRow(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0284C7)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          Expanded(child: Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('My Customers', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.water_drop_outlined),
            tooltip: 'Customer Stock Cycles',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FranchiseCustomerStocksScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCustomers,
          ),
        ],
      ),
      body: Column(
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FranchiseCustomerStocksScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Track customer supply countdowns & low stock alerts',
                      style: TextStyle(color: Color(0xFF0369A1), fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF0284C7), size: 12),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customer by name, mobile, or code...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _fetchCustomers();
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
                _fetchCustomers();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
                : _customers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_outline, size: 60, color: Color(0xFFCBD5E1)),
                              const SizedBox(height: 12),
                              const Text(
                                'No customers found in your territory',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Customers registered in or assigned to your zone will appear here.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _customers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final c = _customers[idx];
                          final name = c['name']?.toString() ?? 'Customer';
                          final code = c['customer_code']?.toString() ?? 'CUST-${c['id']}';
                          final phone = c['phone']?.toString() ?? '';
                          final zoneName = c['zone_name']?.toString() ?? '';
                          final stockCycle = c['stock_cycle'] as Map<String, dynamic>?;
                          final cycleStatus = stockCycle?['status']?.toString() ?? 'none';
                          final daysRemaining = stockCycle?['days_remaining'] ?? 0;
                          final customerId = c['id'] as int;

                          return InkWell(
                            onTap: () => _showCustomerDetails(c),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: const Color(0xFFE0F2FE),
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$code  •  $phone',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (cycleStatus == 'active')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDF4),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF86EFAC)),
                                          ),
                                          child: Text(
                                            'Active ($daysRemaining d)',
                                            style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700, fontSize: 11),
                                          ),
                                        )
                                      else if (cycleStatus == 'hold')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFFBEB),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFFDE68A)),
                                          ),
                                          child: Text(
                                            'On Hold ($daysRemaining d)',
                                            style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700, fontSize: 11),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            zoneName.isNotEmpty ? zoneName : 'Default Territory',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                          ),
                                        ],
                                      ),
                                      if (cycleStatus == 'active' || cycleStatus == 'hold')
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: cycleStatus == 'active' ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                            side: BorderSide(
                                              color: cycleStatus == 'active' ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _handleServiceStatusChange(
                                            customerId: customerId,
                                            currentStatus: cycleStatus,
                                          ),
                                          icon: Icon(
                                            cycleStatus == 'active' ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                            size: 14,
                                          ),
                                          label: Text(
                                            cycleStatus == 'active' ? 'Hold' : 'Resume',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                    ],
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
}
