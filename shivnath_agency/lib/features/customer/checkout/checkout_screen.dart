import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/OrderService.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/session_service.dart';
import '../cart/cart_provider.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final String paymentMethod = 'RAZORPAY';
  bool _isSubmitting = false;

  late Razorpay _razorpay;
  Map<String, dynamic>? _gatewayStatus;
  bool _isLoadingGatewayStatus = true;
  int? _pendingOrderDbId;
  Map<String, dynamic>? _pendingOrderObj;
  String? _pendingRzpOrderId;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final customDaysController = TextEditingController(text: '45');

  final formKey = GlobalKey<FormState>();

  String selectedDurationChoice = '1 Month';
  int selectedDurationDays = 30;
  bool isCustomDuration = false;

  List<Map<String, dynamic>> eligibleFranchises = [];
  int? selectedFranchiseId;
  String? userZoneName;
  bool isLoadingFranchises = true;
  bool isFallbackFranchise = false;
  String? fallbackMessage;
  String matchLevel = 'exact';
  Map<String, dynamic>? supportContact;
  String orderSource = 'FRANCHISE'; // 'FRANCHISE' or 'DIRECT_COMPANY'
  bool hasCustomerTerritory = false;
  double _previousOutstanding = 0.0;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadCustomerAndFranchises();
    _checkGatewayStatus();
  }

  Future<void> _checkGatewayStatus() async {
    setState(() => _isLoadingGatewayStatus = true);
    final status = await OrderService().getRazorpayStatus();
    if (!mounted) return;

    final Map<String, dynamic> normalized = Map<String, dynamic>.from(status);
    if (status['data'] is Map<String, dynamic>) {
      normalized.addAll(Map<String, dynamic>.from(status['data'] as Map));
    }

    setState(() {
      _gatewayStatus = normalized;
      _isLoadingGatewayStatus = false;
    });
  }

  Future<void> _loadCustomerAndFranchises() async {
    String? district;
    int? zoneId;
    bool hasTerritory = false;

    // Instant local autofill from SessionService and SharedPreferences
    final localUser = await SessionService().getUser();
    if (localUser != null) {
      if (localUser.name.isNotEmpty && nameController.text.isEmpty) {
        nameController.text = localUser.name;
      }
      if (localUser.phone.isNotEmpty && phoneController.text.isEmpty) {
        phoneController.text = localUser.phone;
      }
      if (localUser.city.isNotEmpty) {
        district = localUser.city;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddr = prefs.getString('customer_delivery_address');
      if (savedAddr != null &&
          savedAddr.isNotEmpty &&
          addressController.text.isEmpty) {
        addressController.text = savedAddr;
      }
    } catch (_) {}

    final userRes = await AuthService().getCurrentUser();
    if (userRes['success'] == true && userRes['data'] is Map<String, dynamic>) {
      final data = userRes['data'] as Map<String, dynamic>;
      if (data['name'] != null && data['name'].toString().isNotEmpty) {
        nameController.text = data['name'].toString();
      }
      if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
        phoneController.text = data['phone'].toString();
      }
      if (data['address'] != null && data['address'].toString().isNotEmpty) {
        addressController.text = data['address'].toString();
      }

      final terrInfo = data['territory_info'] as Map<String, dynamic>?;
      final terr = data['territory'] as Map<String, dynamic>?;

      // Fetch any existing customer previous outstanding
      try {
        final ordRes = await OrderService().getOrders();
        if (ordRes['success'] == true && ordRes['data'] != null && ordRes['data']['orders'] is List) {
          final ordList = List<Map<String, dynamic>>.from(ordRes['data']['orders']);
          if (ordList.isNotEmpty && ordList.first['previous_outstanding'] != null) {
            _previousOutstanding = double.tryParse(ordList.first['previous_outstanding'].toString()) ?? 0.0;
          }
        }
      } catch (_) {}

      if (terrInfo != null && terrInfo['is_assigned'] == true) {
        hasTerritory = true;
        district = terrInfo['district']?.toString();
        userZoneName = terrInfo['territory']?.toString();
        zoneId = terrInfo['zone_id'] as int?;
      } else if (terr != null &&
          (terr['zone_id'] != null || terr['district'] != null)) {
        hasTerritory = true;
        userZoneName =
            terr['zone_name']?.toString() ?? data['zone_name']?.toString();
        zoneId = (terr['zone_id'] as int?) ?? (data['zone_id'] as int?);
        district = terr['district']?.toString() ?? data['district']?.toString();
      } else if (data['zone_id'] != null ||
          (data['district'] != null &&
              data['district'].toString().isNotEmpty)) {
        hasTerritory = true;
        zoneId = data['zone_id'] as int?;
        district = data['district']?.toString();
        userZoneName = data['zone_name']?.toString();
      }
    }

    Map<String, dynamic> fRes = {
      'success': true,
      'data': {'franchises': []},
    };
    if (district != null && district.isNotEmpty) {
      fRes = await AuthService().getEligibleFranchises(
        district: district,
        zoneId: zoneId,
      );
    }

    if (mounted) {
      List<Map<String, dynamic>> franchises = [];
      bool isFallback = false;
      String? fallbackMsg;
      String mLevel = 'exact';
      Map<String, dynamic>? supContact;

      if (fRes['success'] == true && fRes['data'] != null) {
        final data = fRes['data'];
        if (data is Map<String, dynamic>) {
          if (data['franchises'] is List) {
            franchises = List<Map<String, dynamic>>.from(data['franchises']);
          }
          isFallback = data['is_fallback'] == true;
          fallbackMsg = data['fallback_message']?.toString();
          mLevel =
              data['match_level']?.toString() ??
              (franchises.isNotEmpty ? 'exact' : 'none');
          if (data['support_contact'] is Map) {
            supContact = Map<String, dynamic>.from(data['support_contact']);
          }
        }
      }
      setState(() {
        hasCustomerTerritory = hasTerritory;
        eligibleFranchises = franchises;
        isFallbackFranchise = isFallback;
        fallbackMessage = fallbackMsg;
        matchLevel = mLevel;
        supportContact = supContact;
        isLoadingFranchises = false;
        if (franchises.isNotEmpty) {
          selectedFranchiseId = franchises.first['id'] as int?;
          orderSource = 'FRANCHISE';
        } else {
          selectedFranchiseId = null;
          orderSource = 'DIRECT_COMPANY';
        }
      });
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    customDaysController.dispose();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final orderDbId = _pendingOrderDbId;
    if (orderDbId == null) return;
    setState(() => _isSubmitting = true);

    try {
      final orderService = OrderService();
      final verifyRes = await orderService.verifyRazorpayPayment(
        orderId: orderDbId,
        razorpayOrderId: response.orderId ?? _pendingRzpOrderId ?? '',
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      if (!mounted) return;

      if (verifyRes['success'] == true) {
        final cart = Provider.of<CartProvider>(context, listen: false);
        cart.clearCart();

        final rawVerifyData = (verifyRes['data'] is Map)
            ? Map<String, dynamic>.from(verifyRes['data'] as Map)
            : verifyRes;
        final isTestMode = rawVerifyData['is_test_mode'] == true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isTestMode
                    ? '[TEST MODE] Razorpay sandbox payment verified successfully.'
                    : 'Payment verified successfully. Order confirmed!',
              ),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 4),
            ),
          );
        }

        final Map<String, dynamic> verifiedOrder =
            (verifyRes['data'] is Map && verifyRes['data']['order'] is Map)
                ? Map<String, dynamic>.from(verifyRes['data']['order'] as Map)
                : (_pendingOrderObj ?? {'id': orderDbId});

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(
              amount: (verifiedOrder['amount'] is num)
                  ? (verifiedOrder['amount'] as num).toDouble()
                  : 0.0,
              orderData: verifiedOrder,
            ),
          ),
        );
      } else {
        setState(() => _isSubmitting = false);
        final errorMsg = verifyRes['message']?.toString() ?? 'Payment verification failed.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment verification error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handlePaymentError(PaymentFailureResponse response) async {
    setState(() => _isSubmitting = false);
    final orderDbId = _pendingOrderDbId;
    final rzpOrderId = _pendingRzpOrderId;

    if (orderDbId != null) {
      await OrderService().cancelRazorpayPayment(
        orderId: orderDbId,
        razorpayOrderId: rzpOrderId,
        reason: '${response.code}: ${response.message}',
      );
    }

    if (!mounted) return;
    final isUserCancel = response.code == Razorpay.PAYMENT_CANCELLED;
    final message = isUserCancel
        ? 'Payment cancelled. Your cart and order have been preserved.'
        : 'Payment failed (${response.message ?? 'Unknown reason'}). Your cart has been preserved.';

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
        content: Text('Redirecting to wallet: ${response.walletName}...'),
        backgroundColor: const Color(0xFF0284C7),
      ),
    );
  }

  DateTime get _calculatedEndDate {
    final days = isCustomDuration
        ? (int.tryParse(customDaysController.text.trim()) ?? 30)
        : selectedDurationDays;
    return DateTime.now().add(Duration(days: days));
  }

  String _formatDate(DateTime d) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  Future<void> placeOrder() async {
    if (_isSubmitting) return;

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your cart is empty.')));
      return;
    }

    // Check gateway status: if unavailable, show diagnostic modal
    final isGatewayAvail = _gatewayStatus != null &&
        (_gatewayStatus!['available'] == true ||
            (_gatewayStatus!['data'] is Map && _gatewayStatus!['data']['available'] == true));
    if (!isGatewayAvail) {
      final diag = (_gatewayStatus?['diagnostics'] is Map)
          ? _gatewayStatus!['diagnostics'] as Map<String, dynamic>
          : (_gatewayStatus?['data'] is Map && _gatewayStatus!['data']['diagnostics'] is Map)
              ? _gatewayStatus!['data']['diagnostics'] as Map<String, dynamic>
              : null;
      final msg = diag?['message']?.toString() ??
          _gatewayStatus?['message']?.toString() ??
          'Payment Gateway Unavailable: Razorpay API credentials are not configured on the production server. Mock payment mode is strictly prohibited in production.';
      final isProd = _gatewayStatus?['is_production'] == true ||
          (_gatewayStatus?['data'] is Map && _gatewayStatus!['data']['is_production'] == true);

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text('Payment Gateway Unavailable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg, style: const TextStyle(fontSize: 13, height: 1.4)),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Environment: ${_gatewayStatus!['environment'] ?? (isProd ? 'PRODUCTION' : 'TEST')}\n'
                  'Error Code: ${diag?['error_code'] ?? 'GATEWAY_CREDENTIALS_MISSING'}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _checkGatewayStatus();
              },
              child: const Text('Re-check Status'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
      return;
    }

    final isDirect =
        orderSource == 'DIRECT_COMPANY' ||
        eligibleFranchises.isEmpty ||
        selectedFranchiseId == null;
    final finalOrderSource = isDirect ? 'DIRECT_COMPANY' : 'FRANCHISE';
    final finalServingFranchiseId = isDirect ? null : selectedFranchiseId;

    final amount = cart.totalAmount;
    final totalItems = cart.itemCount;

    final durationDays = isCustomDuration
        ? (int.tryParse(customDaysController.text.trim()) ?? 30)
        : selectedDurationDays;
    final durationChoice = isCustomDuration
        ? '$durationDays Days (Custom)'
        : selectedDurationChoice;

    // Explicit confirmation dialog to prevent accidental order placement on back/exit
    final shouldPlace = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.payment_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 10),
              Expanded(
                child: Text('Confirm Order & Pay'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ready to complete your order via Razorpay?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text('Total Items: $totalItems'),
              const SizedBox(height: 4),
              Text(
                'Payable Amount: ₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0284C7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _gatewayStatus?['is_test_mode'] == true
                          ? 'Razorpay Sandbox (Test Mode) Checkout'
                          : '100% Secure Razorpay Online Payment',
                      style: const TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Pay Now & Place Order'),
            ),
          ],
        );
      },
    );

    if (shouldPlace != true) return;

    final orderItems = cart.items.map((it) {
      final pid = int.tryParse(it.id) ?? 1;
      return {'product_id': pid, 'quantity': it.quantity, 'price': it.price};
    }).toList();

    setState(() => _isSubmitting = true);

    String selectedFranchiseName = 'Water Wala (Direct Fulfillment)';
    if (!isDirect && selectedFranchiseId != null) {
      final match = eligibleFranchises.firstWhere(
        (f) => f['id'] == selectedFranchiseId,
        orElse: () => {},
      );
      selectedFranchiseName = match['business_name']?.toString() ??
          match['name']?.toString() ??
          'Water Wala Authorized Franchise';
    }

    try {
      final orderService = OrderService();
      // Step 1: Create Order with pending payment
      final res = await orderService.createOrder({
        'franchise': isDirect
            ? 'Water Wala (Direct Fulfillment)'
            : selectedFranchiseName,
        'city': addressController.text.trim(),
        'customer_name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'delivery_address': addressController.text.trim(),
        'items': totalItems,
        'amount': amount,
        'status': 'order_placement',
        'payment': 'pending',
        'payment_mode': 'RAZORPAY',
        'duration_choice': durationChoice,
        'duration_days': durationDays,
        'order_source': finalOrderSource,
        'serving_franchise_id': finalServingFranchiseId,
        'order_items': orderItems,
      });

      if (!mounted) return;

      if (res['success'] == true) {
        final dynamic rawData = res['data'];
        final Map<String, dynamic> orderObj = (rawData is Map && rawData['order'] is Map)
            ? Map<String, dynamic>.from(rawData['order'] as Map)
            : (rawData is Map ? Map<String, dynamic>.from(rawData) : <String, dynamic>{});
        final int orderDbId = int.tryParse(orderObj['id']?.toString() ?? res['id']?.toString() ?? '0') ?? 0;

        // Step 2: Initialize Razorpay online order with server-validated amount
        final rzpOrderRes = await orderService.createRazorpayOrder(
          orderId: orderDbId > 0 ? orderDbId : null,
          amount: amount,
        );

        if (rzpOrderRes['success'] != true) {
          if (!mounted) return;
          setState(() => _isSubmitting = false);
          final errorMsg = rzpOrderRes['message']?.toString() ?? 'Unable to initialize payment.';
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

        _pendingOrderDbId = orderDbId;
        _pendingOrderObj = orderObj;
        _pendingRzpOrderId = rzpOrderId;

        // Step 3: Open Genuine Razorpay Checkout
        final localUser = await SessionService().getUser();
        final options = {
          'key': keyId.isNotEmpty ? keyId : AppConstants.razorpayKeyId,
          'amount': amountInPaise,
          'name': 'Shivnath Agency - WATER WALA',
          'order_id': rzpOrderId,
          'description': 'Order #${orderObj['order_code'] ?? orderDbId}',
          'timeout': 300,
          'prefill': {
            'contact': phoneController.text.trim().isNotEmpty
                ? phoneController.text.trim()
                : (localUser?.phone != null && localUser!.phone.trim().isNotEmpty
                    ? localUser.phone.trim()
                    : '9876543210'),
            'email': (localUser?.email != null && localUser!.email.trim().isNotEmpty)
                ? localUser.email.trim()
                : 'customer@shivnath.com',
          },
          'notes': {
            'order_id': orderDbId.toString(),
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
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error launching Razorpay checkout: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } else {
        setState(() => _isSubmitting = false);
        final msg = res['message'] ?? 'Unable to place order. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error during order initialization: $e'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Checkout',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text(
                'Delivery Address',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  if (value == null || value.length < 10) {
                    return 'Enter valid mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Delivery Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter delivery address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Stock Supply Duration',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select the planned duration for this water stock. Expected cycle end date will be calculated automatically.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('1 Month (~30 Days)'),
                    selected: !isCustomDuration && selectedDurationDays == 30,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          isCustomDuration = false;
                          selectedDurationDays = 30;
                          selectedDurationChoice = '1 Month';
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('2 Months (~60 Days)'),
                    selected: !isCustomDuration && selectedDurationDays == 60,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          isCustomDuration = false;
                          selectedDurationDays = 60;
                          selectedDurationChoice = '2 Months';
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('3 Months (~90 Days)'),
                    selected: !isCustomDuration && selectedDurationDays == 90,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          isCustomDuration = false;
                          selectedDurationDays = 90;
                          selectedDurationChoice = '3 Months';
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Custom Duration'),
                    selected: isCustomDuration,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          isCustomDuration = true;
                        });
                      }
                    },
                  ),
                ],
              ),
              if (isCustomDuration) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: customDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Custom Duration (Days)',
                    prefixIcon: Icon(Icons.date_range_outlined),
                    suffixText: 'Days',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF0284C7),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '📅 Stock cycle ends on ${_formatDate(_calculatedEndDate)}. You will receive a low-stock reminder 7 days prior.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0369A1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Order Fulfillment',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (userZoneName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        userZoneName!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0284C7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (isLoadingFranchises)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Checking fulfillment availability...',
                          style: TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else if (eligibleFranchises.isNotEmpty) ...[
                const Text(
                  'Choose how you would like your order to be fulfilled:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                _PaymentTile(
                  title: 'Order from Franchise',
                  subtitle:
                      'Delivered by authorized local franchise in your zone',
                  icon: Icons.storefront_outlined,
                  value: 'FRANCHISE',
                  groupValue: orderSource,
                  onChanged: (val) {
                    setState(() => orderSource = val);
                  },
                ),
                if (orderSource == 'FRANCHISE') ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: selectedFranchiseId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.location_city_outlined),
                      labelText: 'Select Serving Franchise',
                    ),
                    items: eligibleFranchises.map((f) {
                      final name =
                          f['business_name']?.toString() ?? 'Franchise';
                      final isPrimary = f['is_primary'] == true;
                      final coverage = f['service_coverage']?.toString();
                      final label = (coverage != null && coverage.isNotEmpty)
                          ? '$name ($coverage)'
                          : (isPrimary ? '$name (Primary Franchise)' : name);

                      return DropdownMenuItem<int>(
                        value: f['id'] as int?,
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontWeight: isPrimary
                                ? FontWeight.w700
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => selectedFranchiseId = val);
                    },
                  ),
                ],
                const SizedBox(height: 10),
                _PaymentTile(
                  title: 'Order Directly from Water Wala',
                  subtitle: 'Central company fulfillment & dispatch',
                  icon: Icons.business_outlined,
                  value: 'DIRECT_COMPANY',
                  groupValue: orderSource,
                  onChanged: (val) {
                    setState(() => orderSource = val);
                  },
                ),
              ] else if (hasCustomerTerritory) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            color: Color(0xFF0284C7),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Direct Company Fulfillment',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Water Wala',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No franchise is currently assigned to your territory. Your order will be fulfilled directly by Water Wala central dispatch.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF075985),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            color: Color(0xFF334155),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Direct Company Fulfillment',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF475569),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Water Wala',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No delivery territory selected. Your order will be handled directly by Water Wala (you can complete your territory in Profile anytime).',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Payment Method',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.lock_rounded, size: 14, color: Color(0xFF16A34A)),
                      SizedBox(width: 4),
                      Text(
                        '100% Secure',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoadingGatewayStatus) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Checking payment gateway status...',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_gatewayStatus != null &&
                  (_gatewayStatus!['available'] == true ||
                      (_gatewayStatus!['data'] is Map && _gatewayStatus!['data']['available'] == true))) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF86EFAC),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF16A34A), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Online Payment — Razorpay',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xFF14532D),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                if (_gatewayStatus!['is_test_mode'] == true ||
                                    (_gatewayStatus!['data'] is Map && _gatewayStatus!['data']['is_test_mode'] == true)) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF08A),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFEAB308)),
                                    ),
                                    child: const Text(
                                      'SANDBOX TEST',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF854D0E),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.radio_button_checked,
                            color: Color(0xFF16A34A),
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'UPI (GPay, PhonePe, Paytm), Debit/Credit Cards, Net Banking & Wallets',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF166534),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: (((_gatewayStatus!['supported_methods'] ?? (_gatewayStatus!['data'] is Map ? _gatewayStatus!['data']['supported_methods'] : null)) as List?)?.map((m) => _payBadge(m.toString())).toList()) ?? [
                          _payBadge('UPI'),
                          _payBadge('Cards'),
                          _payBadge('Net Banking'),
                          _payBadge('Wallets'),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 22),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Payment Gateway Unavailable',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _checkGatewayStatus,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, size: 12, color: Color(0xFF991B1B)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Retry',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (_gatewayStatus?['diagnostics'] is Map
                                ? (_gatewayStatus!['diagnostics'] as Map)['message']?.toString()
                                : null) ??
                            _gatewayStatus?['message']?.toString() ??
                            'Razorpay API credentials are not configured on the production server. Mock payment mode is strictly prohibited in production.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB91C1C),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFEE2E2)),
                        ),
                        child: Text(
                          'Environment: ${_gatewayStatus?['environment'] ?? 'PRODUCTION'}  |  Code: ${(_gatewayStatus?['diagnostics'] is Map ? (_gatewayStatus!['diagnostics'] as Map)['error_code'] : null) ?? 'GATEWAY_CREDENTIALS_MISSING'}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7F1D1D),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ordered Items',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cart.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = cart.items[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item.image.isNotEmpty
                                ? Image.network(
                                    item.image,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Image.asset(
                                      item.assetFallbackImage,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    item.assetFallbackImage,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${item.unitPrice.toStringAsFixed(0)} × ${item.quantity}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${item.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Order Summary',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SummaryRow(
                        title: 'Items Subtotal (${cart.itemCount} items)',
                        value: '₹${cart.subtotal.toStringAsFixed(0)}',
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        title: 'Delivery Charges',
                        value: cart.deliveryCharge == 0
                            ? 'FREE'
                            : '₹${cart.deliveryCharge.toStringAsFixed(0)}',
                        color: cart.deliveryCharge == 0 ? const Color(0xFF16A34A) : null,
                      ),
                      const Divider(height: 24),
                      _SummaryRow(
                        title: 'Current Order Total',
                        value: '₹${cart.totalAmount.toStringAsFixed(0)}',
                        bold: true,
                      ),
                      if (_previousOutstanding > 0) ...[
                        const SizedBox(height: 10),
                        _SummaryRow(
                          title: 'Previous Outstanding',
                          value: '₹${_previousOutstanding.toStringAsFixed(0)}',
                          bold: true,
                          color: const Color(0xFFDC2626),
                        ),
                        const Divider(height: 20),
                        _SummaryRow(
                          title: 'Total Amount Due',
                          value: '₹${(cart.totalAmount + _previousOutstanding).toStringAsFixed(0)}',
                          bold: true,
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        const _SummaryRow(
                          title: 'GST / Taxes',
                          value: 'Included',
                          color: Color(0xFF64748B),
                        ),
                        const Divider(height: 24),
                        _SummaryRow(
                          title: 'Payable Amount',
                          value: '₹${cart.totalAmount.toStringAsFixed(0)}',
                          bold: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : placeOrder,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'PLACE ORDER / PAY NOW (₹${cart.totalAmount.toStringAsFixed(0)})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _payBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF166534),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final bool bold;
  final Color? color;

  const _SummaryRow({
    required this.title,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: color ?? (bold ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: color ?? (bold ? const Color(0xFF0284C7) : const Color(0xFF0F172A)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _PaymentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: selected ? const Color(0xFF166534) : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              activeColor: const Color(0xFF16A34A),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
