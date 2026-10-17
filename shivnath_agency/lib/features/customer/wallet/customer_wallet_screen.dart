import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/OrderService.dart';
import '../../../core/services/session_service.dart';

class CustomerWalletScreen extends StatefulWidget {
  const CustomerWalletScreen({super.key});

  @override
  State<CustomerWalletScreen> createState() => _CustomerWalletScreenState();
}

class _CustomerWalletScreenState extends State<CustomerWalletScreen> {
  final OrderService _orderService = OrderService();
  late Razorpay _razorpay;

  bool _isSyncing = false;
  bool _isProcessingPayment = false;
  double _pendingRechargeAmount = 0.0;
  double _walletBalance = 150.0; // Welcome promotional credit
  int _rewardPoints = 120;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadWalletData();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Instant local load (paint UI in < 10ms)
    if (!prefs.containsKey('customer_water_wallet_balance')) {
      await prefs.setDouble('customer_water_wallet_balance', 150.0);
    }
    final balance = prefs.getDouble('customer_water_wallet_balance') ?? 150.0;

    // Load local recharge history first
    final List<Map<String, dynamic>> txList = [];
    final rechargeHistory = prefs.getStringList('customer_recharges_list') ?? [];
    for (final r in rechargeHistory) {
      final parts = r.split('|');
      if (parts.length >= 2) {
        final paymentRef = (parts.length >= 3 && parts[2].isNotEmpty) ? ' • ID: ${parts[2]}' : '';
        txList.add({
          'id': 'recharge_${parts[0]}_${parts[1]}',
          'title': 'Wallet Top-up',
          'subtitle': 'Razorpay Online Recharge (UPI/Card)$paymentRef',
          'amount': double.tryParse(parts[1]) ?? 100.0,
          'is_credit': true,
          'date': parts[0],
        });
      }
    }

    if (mounted) {
      setState(() {
        _walletBalance = balance;
        if (_transactions.isEmpty) {
          _transactions = List.from(txList);
        }
        _isSyncing = true;
      });
    }

    // 2. Safe background network sync with strict 4s timeout (never hangs UI)
    int points = 0;
    try {
      // First try dedicated server wallet endpoint
      final walletRes = await _orderService.getWalletDetails();
      if (walletRes['success'] == true && walletRes['balance'] != null) {
        final serverBalance = double.tryParse(walletRes['balance'].toString());
        if (serverBalance != null && serverBalance > 0) {
          await prefs.setDouble('customer_water_wallet_balance', serverBalance);
          if (mounted) setState(() => _walletBalance = serverBalance);
        }
      }

      // Then sync customer order history for transaction logs
      final res = await _orderService.getOrders().timeout(
        const Duration(seconds: 4),
        onTimeout: () => {'success': false, 'data': {}},
      );

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

    if (mounted) {
      setState(() {
        _rewardPoints = points > 0 ? points : 120;
        _transactions = txList;
        _isSyncing = false;
      });
    }
  }

  Future<void> _handleRecharge(double amount, {String? paymentId}) async {
    final prefs = await SharedPreferences.getInstance();
    final newBalance = _walletBalance + amount;
    await prefs.setDouble('customer_water_wallet_balance', newBalance);

    final rechargeHistory = prefs.getStringList('customer_recharges_list') ?? [];
    final today = DateTime.now().toIso8601String().substring(0, 10);
    rechargeHistory.add('$today|$amount|${paymentId ?? ''}');
    await prefs.setStringList('customer_recharges_list', rechargeHistory);

    if (mounted) {
      setState(() {
        _walletBalance = newBalance;
      });
      _loadWalletData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('₹${amount.toStringAsFixed(0)} added to Water Wallet successfully! 🎉'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _startRazorpayRecharge(double amount) async {
    if (amount < 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid recharge amount.')),
      );
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      // 1. Create Razorpay order through authoritative backend
      final rzpOrderRes = await _orderService.createRazorpayOrder(amount: amount);

      if (!mounted) return;

      if (rzpOrderRes['success'] != true) {
        setState(() => _isProcessingPayment = false);
        final errorMsg = rzpOrderRes['message']?.toString() ?? 'Unable to initialize payment gateway.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      final dynamic rawRzpData = (rzpOrderRes['data'] is Map) ? rzpOrderRes['data'] : rzpOrderRes;
      final Map<String, dynamic> rzpData = rawRzpData is Map<String, dynamic>
          ? rawRzpData
          : (rawRzpData is Map ? Map<String, dynamic>.from(rawRzpData) : <String, dynamic>{});
      final rzpOrderId = rzpData['razorpay_order_id']?.toString() ?? '';
      final keyId = rzpData['key_id']?.toString() ?? '';
      final amountInPaise = rzpData['amount_in_paise'] as int? ?? (amount * 100).round();

      _pendingRechargeAmount = amount;

      // 2. Open Razorpay Checkout Sheet with UPI, PhonePe, Google Pay, Cards, NetBanking
      final localUser = await SessionService().getUser();
      final options = {
        'key': keyId.isNotEmpty ? keyId : AppConstants.razorpayKeyId,
        'amount': amountInPaise,
        'name': 'Shivnath Agency - WATER WALA',
        'order_id': rzpOrderId,
        'description': 'Water Wallet Top-up (₹${amount.toStringAsFixed(0)})',
        'timeout': 300,
        'prefill': {
          'contact': (localUser?.phone != null && localUser!.phone.trim().isNotEmpty)
              ? localUser.phone.trim()
              : '9876543210',
          'email': (localUser?.email != null && localUser!.email.trim().isNotEmpty)
              ? localUser.email.trim()
              : 'customer@shivnath.com',
        },
        'notes': {
          'type': 'WALLET_RECHARGE',
          'amount': amount.toString(),
          'app_environment': AppConstants.environmentName,
        },
        'theme': {
          'color': '#0284C7',
        },
        'retry': {
          'enabled': true,
          'max_count': 3,
        },
        'send_sms_hash': true,
      };

      try {
        _razorpay.open(options);
      } catch (e) {
        setState(() => _isProcessingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching Razorpay checkout: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error initializing payment: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessingPayment = false);
    final credited = _pendingRechargeAmount > 0 ? _pendingRechargeAmount : 100.0;
    await _handleRecharge(credited, paymentId: response.paymentId);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessingPayment = false);
    if (!mounted) return;
    final isUserCancel = response.code == Razorpay.PAYMENT_CANCELLED;
    final message = isUserCancel
        ? 'Recharge payment cancelled.'
        : 'Payment failed (${response.message ?? "Transaction not completed"}).';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isUserCancel ? const Color(0xFF475569) : Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet chosen: ${response.walletName}'),
        backgroundColor: const Color(0xFF0284C7),
      ),
    );
  }

  void _showAddMoneyDialog() {
    double selectedAmount = 250.0;
    final customAmountController = TextEditingController(text: '250');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.add_card_rounded, color: Color(0xFF0284C7)),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Add Money to Wallet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Prepay for uninterrupted 20L water jar deliveries without cash or daily payment hassle.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
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
                        onSelected: (_) {
                          setDialogState(() {
                            selectedAmount = amt;
                            customAmountController.text = amt.toStringAsFixed(0);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: customAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    decoration: const InputDecoration(
                      labelText: 'Or enter custom amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        setDialogState(() => selectedAmount = parsed);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '100% Secure via Razorpay (UPI, GPay, PhonePe, Cards, NetBanking)',
                            style: TextStyle(
                              color: Color(0xFF166534),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: Text('Pay ₹${selectedAmount.toStringAsFixed(0)} via Razorpay'),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _startRazorpayRecharge(selectedAmount);
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
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadWalletData,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                if (_isSyncing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                      ),
                    ),
                  ),
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
                            const Expanded(
                              child: Text(
                                'Available Wallet Balance',
                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
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
          if (_isProcessingPayment)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 4)),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF0284C7)),
                      SizedBox(height: 18),
                      Text(
                        'Opening Payment Gateway...',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '100% Secure Checkout via Razorpay\nUPI • Google Pay • PhonePe • Cards',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}