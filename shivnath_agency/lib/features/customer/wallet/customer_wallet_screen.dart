import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/repositories/app_repositories.dart';

class CustomerWalletScreen extends StatefulWidget {
  const CustomerWalletScreen({super.key});

  @override
  State<CustomerWalletScreen> createState() => _CustomerWalletScreenState();
}

class _CustomerWalletScreenState extends State<CustomerWalletScreen> {
  final OrderRepository _orderRepository = OrderRepository();
  final AuthRepository _authRepository = AuthRepository();
  late Razorpay _razorpay;

  bool _isSyncing = false;
  bool _isProcessingPayment = false;
  double _pendingRechargeAmount = 0.0;
  String? _pendingRzpOrderId;
  double _walletBalance = 0.0;
  int _rewardPoints = 0;
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

    // 1. Instant local load (paint UI quickly)
    final cachedBalance = prefs.getDouble('customer_water_wallet_balance') ?? 0.0;

    if (mounted) {
      setState(() {
        _walletBalance = cachedBalance;
        _isSyncing = true;
      });
    }

    // 2. Authoritative backend sync for wallet balance, reward points, and ledger
    try {
      final walletRes = await _orderRepository.getWalletDetails();
      if (walletRes['success'] == true) {
        final serverBalance = double.tryParse(walletRes['balance']?.toString() ?? '0') ?? 0.0;
        final serverPoints = int.tryParse(walletRes['reward_points']?.toString() ?? '0') ?? 0;
        await prefs.setDouble('customer_water_wallet_balance', serverBalance);
        if (mounted) {
          setState(() {
            _walletBalance = serverBalance;
            _rewardPoints = serverPoints;
          });
        }
      }

      // Fetch official ledger audit trail
      final txRes = await _orderRepository.getWalletTransactions();
      final List<Map<String, dynamic>> txList = [];

      if (txRes['success'] == true && txRes['data'] is List) {
        final rawTx = txRes['data'] as List;
        for (final item in rawTx) {
          if (item is Map) {
            final tx = Map<String, dynamic>.from(item);
            final type = (tx['transaction_type'] ?? '').toString();
            final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
            final points = int.tryParse(tx['points']?.toString() ?? '0') ?? 0;
            final date = (tx['created_at'] ?? '').toString();
            final status = (tx['status'] ?? 'COMPLETED').toString().toUpperCase();
            final orderId = tx['order'];
            final ref = tx['payment_reference']?.toString() ?? '';

            bool isCredit = true;
            String title = 'Wallet Transaction';
            String subtitle = tx['description']?.toString() ?? '';

            if (type == 'RECHARGE') {
              title = 'Wallet Top-up';
              isCredit = true;
              subtitle = 'Razorpay Online Recharge${ref.isNotEmpty ? " • Ref: $ref" : ""}';
            } else if (type == 'ORDER_DEBIT') {
              title = 'Order Payment ${orderId != null ? "#$orderId" : ""}';
              isCredit = false;
              subtitle = 'Water Wala Order • Central Admin Fulfilled';
            } else if (type == 'ORDER_REFUND') {
              title = 'Refund for Order ${orderId != null ? "#$orderId" : ""}';
              isCredit = true;
              subtitle = 'Order Cancellation Reversal';
            } else if (type == 'POINTS_REDEEMED') {
              title = 'Hydration Reward Redeemed';
              isCredit = false;
              subtitle = 'Redeemed $points Points for Product';
            } else if (type == 'POINTS_EARNED') {
              title = 'Reward Points Earned';
              isCredit = true;
              subtitle = '+$points Points from Order #${orderId ?? ""}';
            }

            final formattedDate = date.length >= 10 ? date.substring(0, 10) : 'Recent';

            txList.add({
              'id': tx['id'] ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
              'title': title,
              'subtitle': subtitle,
              'amount': amount,
              'points': points,
              'is_credit': isCredit,
              'status': status,
              'type': type,
              'date': formattedDate,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _transactions = txList;
          _isSyncing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSyncing = false);
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
      // 1. Create Razorpay recharge order through authoritative backend endpoint
      final rzpOrderRes = await _orderRepository.initiateWalletRecharge(amount: amount);

      if (!mounted) return;

      if (rzpOrderRes['success'] != true) {
        setState(() => _isProcessingPayment = false);
        final errorMsg = rzpOrderRes['message']?.toString() ?? 'Unable to initialize wallet recharge.';
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
      _pendingRzpOrderId = rzpOrderId;

      // 2. Open Razorpay Checkout Sheet with UPI, PhonePe, Google Pay, Cards, NetBanking
      final localUser = await _authRepository.getCachedUser();
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
        if (!mounted) return;
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
    setState(() => _isProcessingPayment = true);

    final rzpOrderId = response.orderId ?? _pendingRzpOrderId ?? '';
    final rzpPaymentId = response.paymentId ?? '';
    final rzpSignature = response.signature ?? '';

    if (rzpOrderId.isEmpty || rzpPaymentId.isEmpty) {
      setState(() => _isProcessingPayment = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment verification failed: Missing transaction identifiers from gateway.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final verifyRes = await _orderRepository.verifyWalletRecharge(
        razorpayOrderId: rzpOrderId,
        razorpayPaymentId: rzpPaymentId,
        razorpaySignature: rzpSignature,
      );

      if (!mounted) return;
      setState(() => _isProcessingPayment = false);

      if (verifyRes['success'] == true) {
        final newBal = (verifyRes['new_balance'] as num?)?.toDouble() ??
            (verifyRes['balance'] as num?)?.toDouble();
        if (newBal != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('customer_water_wallet_balance', newBal);
          setState(() => _walletBalance = newBal);
        }
        await _loadWalletData();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '₹${(_pendingRechargeAmount > 0 ? _pendingRechargeAmount : (verifyRes['amount'] ?? 100)).toStringAsFixed(0)} added to Water Wallet successfully! 🎉',
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(verifyRes['message']?.toString() ?? 'Recharge verification failed. Wallet not credited.'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error verifying payment with server: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RedemptionCatalogSheet(
        currentPoints: _rewardPoints,
        onRedeemed: () {
          _loadWalletData();
        },
      ),
    );
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
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
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                (amt > 0)
                                    ? '${isCredit ? "+" : "-"}₹${amt.toStringAsFixed(2)}'
                                    : (tx['points'] != null && (tx['points'] as int) > 0
                                        ? '${isCredit ? "+" : "-"}${tx['points']} pts'
                                        : '₹0.00'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: isCredit ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                                ),
                              ),
                              if (tx['status'] != null && tx['status'] != 'COMPLETED') ...[
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: tx['status'] == 'FAILED' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    tx['status'].toString(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: tx['status'] == 'FAILED' ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
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
                        'Processing Wallet Transaction...',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '100% Secure Checkout via Razorpay\nVerifying cryptographic payment signature with server...',
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

class _RedemptionCatalogSheet extends StatefulWidget {
  final int currentPoints;
  final VoidCallback onRedeemed;

  const _RedemptionCatalogSheet({
    required this.currentPoints,
    required this.onRedeemed,
  });

  @override
  State<_RedemptionCatalogSheet> createState() => _RedemptionCatalogSheetState();
}

class _RedemptionCatalogSheetState extends State<_RedemptionCatalogSheet> {
  final OrderRepository _orderRepository = OrderRepository();
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  String? _error;
  int? _redeemingProductId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await _orderRepository.getRedemptionProducts();
    if (!mounted) return;

    if (res['success'] == true && res['data'] is List) {
      setState(() {
        _products = List<Map<String, dynamic>>.from(res['data']);
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = res['message']?.toString() ?? 'Unable to load eligible redemption products.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRedeem(Map<String, dynamic> product) async {
    final prodId = product['id'] as int? ?? int.tryParse(product['id']?.toString() ?? '0') ?? 0;
    final pointsReq = product['points_required'] as int? ?? int.tryParse(product['points_required']?.toString() ?? '0') ?? 0;
    final prodName = product['name']?.toString() ?? 'Product';

    if (widget.currentPoints < pointsReq) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You need $pointsReq points for $prodName. You currently have ${widget.currentPoints} points.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Point Redemption', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Redeem $pointsReq Hydration Points for 1 unit of $prodName?'),
            const SizedBox(height: 10),
            const Text(
              'This order will be placed directly with Shivnath Central Admin for fulfillment.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Redeem & Place Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _redeemingProductId = prodId);

    final res = await _orderRepository.redeemWalletPoints(
      productId: prodId,
      quantity: 1,
      notes: 'Redeemed via Water Wallet screen',
    );

    if (!mounted) return;
    setState(() => _redeemingProductId = null);

    if (res['success'] == true) {
      widget.onRedeemed();
      Navigator.pop(context);

      final dynamic rawOrder = res['data'] is Map ? res['data']['order'] : null;
      final orderData = rawOrder is Map ? rawOrder : (res['data'] is Map ? res['data'] : {});
      final orderCode = orderData['order_code'] ?? 'ORD-${orderData['id'] ?? ''}';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Expanded(child: Text('Redemption Confirmed!')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your order #$orderCode has been sent directly to Central Admin.'),
              const SizedBox(height: 8),
              Text('Points debited: $pointsReq pts', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Text('Serving: Shivnath Central Admin (Water Wallet)', style: TextStyle(fontSize: 12, color: Color(0xFF0284C7))),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Failed to redeem product.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.stars_rounded, color: Color(0xFF9333EA), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Hydration Rewards Catalog',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD8B4FE)),
                ),
                child: Text(
                  '${widget.currentPoints} Pts',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7E22CE),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Redeem your reward points for free drinking water products. Orders are fulfilled directly by Central Admin.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Divider(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
                            const SizedBox(height: 10),
                            OutlinedButton(onPressed: _loadProducts, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _products.isEmpty
                        ? const Center(child: Text('No redemption products currently eligible.'))
                        : ListView.separated(
                            itemCount: _products.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (ctx, idx) {
                              final p = _products[idx];
                              final ptsReq = p['points_required'] as int? ?? int.tryParse(p['points_required']?.toString() ?? '0') ?? 0;
                              final canRedeem = widget.currentPoints >= ptsReq;
                              final isRedeemingThis = _redeemingProductId == p['id'];

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['name']?.toString() ?? 'Product',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$ptsReq Points',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF9333EA),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: canRedeem ? const Color(0xFF9333EA) : Colors.grey.shade300,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: (canRedeem && !isRedeemingThis) ? () => _handleRedeem(p) : null,
                                      child: isRedeemingThis
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : Text(canRedeem ? 'Redeem' : 'Need ${ptsReq - widget.currentPoints} more'),
                                    ),
                                  ],
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