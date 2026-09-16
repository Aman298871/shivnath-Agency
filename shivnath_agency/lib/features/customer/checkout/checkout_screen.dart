import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/OrderService.dart';
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

  final nameController =
      TextEditingController(text: 'Demo Customer');

  final phoneController =
      TextEditingController(text: '9876543210');

  final addressController =
      TextEditingController(text: 'Raipur, Chhattisgarh');

  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> placeOrder() async {
    if (_isSubmitting) return;

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty.')),
      );
      return;
    }

    final amount = cart.totalAmount;
    final totalItems = cart.itemCount;

    setState(() => _isSubmitting = true);

    try {
      final res = await OrderService().createOrder({
        'franchise': nameController.text.trim(),
        'city': addressController.text.trim(),
        'items': totalItems,
        'amount': amount,
        'status': 'Order Placement',
        'payment': paymentMethod == 'COD' ? 'Pending' : 'Paid',
      });

      if (!mounted) return;

      if (res['success'] == true) {
        cart.clearCart();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(
              amount: amount,
            ),
          ),
        );
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

    return Scaffold(
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
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
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
            const SizedBox(height: 28),
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
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
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SummaryRow(
                      title: 'Items',
                      value: '${cart.itemCount}',
                    ),
                    const SizedBox(height: 10),
                    _SummaryRow(
                      title: 'Subtotal',
                      value:
                          '₹${cart.subtotal.toStringAsFixed(0)}',
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
                      title: 'Payable Amount',
                      value:
                          '₹${cart.totalAmount.toStringAsFixed(0)}',
                      bold: true,
                    ),
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
          color: selected
              ? const Color(0xFFE0F2FE)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF0284C7)
                : const Color(0xFFE2E8F0),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
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
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected
                  ? const Color(0xFF0284C7)
                  : Colors.grey,
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
            fontWeight:
                bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}