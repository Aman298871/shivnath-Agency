import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/OrderService.dart';

class CustomerWalletScreen extends StatefulWidget {
  const CustomerWalletScreen({super.key});

  @override
  State<CustomerWalletScreen> createState() => _CustomerWalletScreenState();
}

class _CustomerWalletScreenState extends State<CustomerWalletScreen> {
  final OrderService _orderService = OrderService();

  bool _isLoading = true;
  double _walletBalance = 150.0; // Welcome promotional credit
  int _rewardPoints = 0;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    // Load or initialize wallet balance
    if (!prefs.containsKey('customer_water_wallet_balance')) {
      await prefs.setDouble('customer_water_wallet_balance', 150.0);
    }
    final balance = prefs.getDouble('customer_water_wallet_balance') ?? 150.0;

    // Load customer order transactions
    List<Map<String, dynamic>> txList = [];
    int points = 0;

    try {
      final res = await _orderService.getOrders();
      if (res['success'] == true && res['data'] is Map) {
        final rawOrders = res['data']['orders'];
        if (rawOrders is List) {
          for (final item in rawOrders) {
            final map = Map<String, dynamic>.from(item as Map);
            final amount = double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0;
            final date = (map['created_at'] ?? '').toString();
            final orderCode = map['order_code'] ?? 'ORD-${map['id']}';
            final status = (map['status'] ?? '').toString();

            if (status.toLowerCase() != 'cancelled') {
              points += (amount / 10).floor();
            }

            txList.add({
              'id': map['id'],
              'title': 'Water Order #$orderCode',
              'subtitle': '${map['items_count'] ?? 1} item(s) • Status: ${status.replaceAll('_', ' ').toUpperCase()}',
              'amount': amount,
              'is_credit': false,
              'date': date.isNotEmpty ? date.substring(0, date.length > 10 ? 10 : date.length) : 'Recent',
            });
          }
        }
      }
    } catch (_) {}

    // Add wallet recharge history if any
    final rechargeHistory = prefs.getStringList('customer_recharges_list') ?? [];
    for (final r in rechargeHistory) {
      final parts = r.split('|');
      if (parts.length >= 2) {
        txList.insert(0, {
          'id': 'recharge_${parts[0]}',
          'title': 'Wallet Top-up',
          'subtitle': 'Online UPI / Card Recharge',
          'amount': double.tryParse(parts[1]) ?? 100.0,
          'is_credit': true,
          'date': parts[0],
        });
      }
    }

    if (mounted) {
      setState(() {
        _walletBalance = balance;
        _rewardPoints = points > 0 ? points : 120; // Baseline points
        _transactions = txList;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRecharge(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final newBalance = _walletBalance + amount;
    await prefs.setDouble('customer_water_wallet_balance', newBalance);

    final rechargeHistory = prefs.getStringList('customer_recharges_list') ?? [];
    final today = DateTime.now().toIso8601String().substring(0, 10);
    rechargeHistory.add('$today|$amount');
    await prefs.setStringList('customer_recharges_list', rechargeHistory);

    if (mounted) {
      setState(() {
        _walletBalance = newBalance;
      });
      _loadWalletData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('₹${amount.toStringAsFixed(0)} added to Water Wallet successfully! 🎉'),
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddMoneyDialog() {
    double selectedAmount = 250.0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.add_card_rounded, color: Color(0xFF0284C7)),
                SizedBox(width: 10),
                Text('Add Money to Wallet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prepay for uninterrupted 20L water jar deliveries without cash or daily payment hassle.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 18),
                const Text('Select Recharge Amount:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [100.0, 250.0, 500.0, 1000.0].map((amt) {
                    final isSel = selectedAmount == amt;
                    return ChoiceChip(
                      label: Text('₹${amt.toStringAsFixed(0)}'),
                      selected: isSel,
                      selectedColor: const Color(0xFFE0F2FE),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isSel ? const Color(0xFF0284C7) : const Color(0xFF334155),
                      ),
                      onSelected: (_) => setDialogState(() => selectedAmount = amt),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total to Pay:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('₹${selectedAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0284C7))),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Confirm Recharge'),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _handleRecharge(selectedAmount);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _redeemPoints() async {
    if (_rewardPoints < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need at least 100 Hydration Points to redeem ₹50 cash discount.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final newBalance = _walletBalance + 50.0;
    await prefs.setDouble('customer_water_wallet_balance', newBalance);

    if (mounted) {
      setState(() {
        _walletBalance = newBalance;
        _rewardPoints -= 100;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 100 Points redeemed! ₹50 credited to your Water Wallet.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Water Wallet',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadWalletData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWalletData,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  // 1. Water Wallet Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Available Wallet Balance',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.verified_user_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Active',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${_walletBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0284C7),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 20),
                                label: const Text(
                                  'Add Money',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                onPressed: _showAddMoneyDialog,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white, width: 1.5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.stars_rounded, size: 18),
                                label: Text(
                                  '$_rewardPoints Pts',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                onPressed: _redeemPoints,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 2. Hydration Rewards Badge Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD8B4FE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.military_tech_rounded, color: Color(0xFF9333EA), size: 38),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hydration Rewards Member',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF6B21A8)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_rewardPoints Points Available • Earn 1 point per ₹10 spent',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF7E22CE)),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _redeemPoints,
                          child: const Text('Redeem', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF9333EA))),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 3. How it Works Explainer Card
                  ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    backgroundColor: Colors.white,
                    collapsedBackgroundColor: Colors.white,
                    leading: const Icon(Icons.help_outline_rounded, color: Color(0xFF0284C7)),
                    title: const Text(
                      'What is Water Wallet & Rewards?',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              '💧 What is the Water Wallet?',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'The Water Wallet allows you to prepay for recurring drinking water jar deliveries. When your daily or weekly 20L jars arrive, the amount is automatically settled without needing cash or completing online OTP payments every time.',
                              style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF475569)),
                            ),
                            SizedBox(height: 10),
                            Text(
                              '⭐ What are Hydration Rewards?',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Every time you order drinking water, you earn 1 reward point for every ₹10 spent. You can redeem 100 points for an instant ₹50 cashback credit directly added into your Water Wallet.',
                              style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // 4. Recent Transactions
                  const Text(
                    'Transaction History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_transactions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            const Text(
                              'No transactions yet',
                              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Recharge your wallet or place water orders to see activity.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._transactions.map((tx) {
                      final isCredit = tx['is_credit'] == true;
                      final amt = tx['amount'] as double? ?? 0.0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: isCredit ? const Color(0xFFDCFCE7) : const Color(0xFFE0F2FE),
                            child: Icon(
                              isCredit ? Icons.arrow_downward_rounded : Icons.shopping_bag_outlined,
                              color: isCredit ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                              size: 18,
                            ),
                          ),
                          title: Text(
                            tx['title']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${tx['subtitle'] ?? ''} • ${tx['date'] ?? ''}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          trailing: Text(
                            '${isCredit ? "+" : "-"}₹${amt.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: isCredit ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}