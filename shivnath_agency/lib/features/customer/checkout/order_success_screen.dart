import 'package:flutter/material.dart';
import '../orders/order_detail_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final double amount;
  final Map<String, dynamic>? orderData;

  const OrderSuccessScreen({
    super.key,
    required this.amount,
    this.orderData,
  });

  @override
  Widget build(BuildContext context) {
    final orderId = orderData?['id']?.toString() ??
        orderData?['order_id']?.toString() ??
        '';
    final orderCode = orderData?['orderId']?.toString() ??
        orderData?['order_id']?.toString() ??
        (orderId.isNotEmpty ? 'ORD-${1000 + (int.tryParse(orderId) ?? 0)}' : 'ORD-SUCCESS');
    final deliveryAddress = orderData?['delivery_address']?.toString() ??
        orderData?['city']?.toString() ??
        'Saved Delivery Address';
    final isWaterWallet = orderData?['order_source'] == 'WATER_WALLET' ||
        orderData?['payment_mode'] == 'WALLET';
    final isRedemption = orderData?['order_source'] == 'WATER_WALLET_REDEMPTION';
    final isFranchise = orderData?['order_source'] == 'FRANCHISE' ||
        (orderData?['serving_franchise_id'] != null && !isWaterWallet && !isRedemption);

    final fulfillmentSource = (isWaterWallet || isRedemption)
        ? 'Shivnath Central Admin (Water Wallet)'
        : (orderData?['order_source'] == 'DIRECT_COMPANY'
            ? 'Shivnath Central Plant (Direct Company)'
            : (orderData?['franchise']?.toString() ?? 'Franchise Partner Fulfillment'));

    final paymentModeText = isWaterWallet
        ? 'Water Wallet (Prepaid)'
        : (isRedemption
            ? 'Reward Points Redemption'
            : (isFranchise
                ? 'Pay on Delivery (Franchise Collection)'
                : 'Razorpay Online Payment'));

    final rawItems = orderData?['items_list'] ?? orderData?['items'] ?? [];
    final List<dynamic> itemsList = rawItems is List ? rawItems : [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Order Confirmation',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 52,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Order Placed Successfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your payment has been verified and your order is confirmed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Order Details Card
                  Card(
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Order Number',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    orderCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 14,
                                      color: Color(0xFF16A34A),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Paid & Verified',
                                      style: TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _infoRow('Amount Paid', '₹${amount.toStringAsFixed(0)}', isBoldValue: true),
                          const SizedBox(height: 8),
                          _infoRow('Payment Mode', paymentModeText),
                          const SizedBox(height: 8),
                          _infoRow('Fulfillment', fulfillmentSource),
                          const SizedBox(height: 8),
                          _infoRow('Delivery Address', deliveryAddress),
                          if (itemsList.isNotEmpty) ...[
                            const Divider(height: 24),
                            const Text(
                              'Ordered Items',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...itemsList.take(3).map((item) {
                              final name = item is Map
                                  ? (item['product_name'] ?? item['name'] ?? 'Product')
                                  : 'Item';
                              final qty = item is Map ? (item['quantity'] ?? 1) : 1;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '• $name',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      'Qty: $qty',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (itemsList.length > 3)
                              Text(
                                '+ ${itemsList.length - 3} more items',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF0284C7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(
                              orderId: orderCode,
                              dbId: int.tryParse(orderId),
                              initialOrder: orderData,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_rounded, size: 20),
                      label: const Text(
                        'VIEW ORDER DETAILS',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.popUntil(
                          context,
                          (route) => route.isFirst,
                        );
                      },
                      child: const Text(
                        'CONTINUE SHOPPING',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBoldValue = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF1E293B),
              fontWeight: isBoldValue ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}