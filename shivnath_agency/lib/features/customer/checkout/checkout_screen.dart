import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String paymentMethod = 'COD';
  bool _isSubmitting = false;

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
    _loadCustomerAndFranchises();
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
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    customDaysController.dispose();
    super.dispose();
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.shopping_bag_outlined, color: Color(0xFF0284C7)),
              SizedBox(width: 10),
              Text('Confirm Order'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to place this order?',
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
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Payment: ${paymentMethod == 'COD' ? 'Cash on Delivery (COD)' : 'Online Payment'}',
              ),
            ],
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
              child: const Text('Confirm & Place Order'),
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

    String selectedFranchiseName = 'Shivnath Agency (Direct Company Fulfillment)';
    if (!isDirect && selectedFranchiseId != null) {
      final match = eligibleFranchises.firstWhere(
        (f) => f['id'] == selectedFranchiseId,
        orElse: () => {},
      );
      selectedFranchiseName = match['business_name']?.toString() ??
          match['name']?.toString() ??
          'Shivnath Franchise';
    }

    try {
      final res = await OrderService().createOrder({
        'franchise': isDirect
            ? 'Shivnath Agency (Direct Company Fulfillment)'
            : selectedFranchiseName,
        'city': addressController.text.trim(),
        'customer_name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'delivery_address': addressController.text.trim(),
        'items': totalItems,
        'amount': amount,
        'status': 'Order Placement',
        'payment': paymentMethod == 'COD' ? 'Pending' : 'Paid',
        'duration_choice': durationChoice,
        'duration_days': durationDays,
        'order_source': finalOrderSource,
        'serving_franchise_id': ?finalServingFranchiseId,
        'order_items': orderItems,
      });

      if (!mounted) return;

      if (res['success'] == true) {
        cart.clearCart();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => OrderSuccessScreen(amount: amount)),
        );
      } else {
        setState(() => _isSubmitting = false);
        final msg =
            res['message'] ?? 'Unable to place order. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server unavailable. Please try again.'),
          backgroundColor: Colors.red,
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
                      Text(
                        'Checking fulfillment availability...',
                        style: TextStyle(fontSize: 12),
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
                  title: 'Order Directly from Shivnath Agency',
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
                              'Shivnath Agency',
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
                        'No franchise is currently assigned to your territory. Your order will be fulfilled directly by Shivnath Agency central dispatch.',
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
                              'Shivnath Agency',
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
                        'No delivery territory selected. Your order will be handled directly by Shivnath Agency (you can complete your territory in Profile anytime).',
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
              const Text(
                'Payment Method',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _PaymentTile(
                title: 'Cash on Delivery',
                subtitle: 'Pay when your order arrives',
                icon: Icons.payments_outlined,
                value: 'COD',
                groupValue: paymentMethod,
                onChanged: (value) {
                  setState(() => paymentMethod = value);
                },
              ),
              const SizedBox(height: 10),
              _PaymentTile(
                title: 'Online Payment',
                subtitle: 'UPI / Card / Net Banking',
                icon: Icons.account_balance_wallet_outlined,
                value: 'ONLINE',
                groupValue: paymentMethod,
                onChanged: (value) {
                  setState(() => paymentMethod = value);
                },
              ),
              const SizedBox(height: 28),
              const Text(
                'Order Summary',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SummaryRow(title: 'Items', value: '${cart.itemCount}'),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        title: 'Subtotal',
                        value: '₹${cart.subtotal.toStringAsFixed(0)}',
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        title: 'Delivery',
                        value: cart.deliveryCharge == 0
                            ? 'FREE'
                            : '₹${cart.deliveryCharge.toStringAsFixed(0)}',
                      ),
                      const Divider(height: 25),
                      _SummaryRow(
                        title: 'Current Order',
                        value: '₹${cart.totalAmount.toStringAsFixed(0)}',
                      ),
                      if (_previousOutstanding > 0) ...[
                        const SizedBox(height: 10),
                        _SummaryRow(
                          title: 'Previous Outstanding',
                          value: '₹${_previousOutstanding.toStringAsFixed(0)}',
                          bold: true,
                        ),
                        const Divider(height: 20),
                        _SummaryRow(
                          title: 'Total Exposure / Due',
                          value: '₹${(cart.totalAmount + _previousOutstanding).toStringAsFixed(0)}',
                          bold: true,
                        ),
                      ] else ...[
                        const Divider(height: 25),
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
                    : const Text('Place Order'),
              ),
            ],
          ),
        ),
      ),
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
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE0F2FE) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0284C7)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
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
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFF0284C7) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final bool bold;

  const _SummaryRow({
    required this.title,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 17 : 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
