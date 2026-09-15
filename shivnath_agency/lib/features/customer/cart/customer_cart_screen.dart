import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../checkout/checkout_screen.dart';
import 'cart_provider.dart';

class CustomerCartScreen extends StatelessWidget {
  const CustomerCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart =
        context.watch<CartProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            constraints.maxWidth >= 800;

        if (desktop) {
          return _desktop(context, cart);
        }

        return _mobile(context, cart);
      },
    );
  }

  Widget _mobile(
    BuildContext context,
    CartProvider cart,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Cart',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: cart.items.isEmpty
          ? const _EmptyCart()
          : _mobileCartContent(
              context,
              cart,
            ),
    );
  }

  Widget _desktop(
    BuildContext context,
    CartProvider cart,
  ) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1200,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Cart',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  cart.items.isEmpty
                      ? 'Your cart is currently empty.'
                      : '${cart.itemCount} items ready for checkout.',
                  style: const TextStyle(
                    color:
                        Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 24),

                if (cart.items.isEmpty)
                  const SizedBox(
                    height: 450,
                    child: _EmptyCart(),
                  )
                else
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          children:
                              cart.items.map(
                            (item) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                child:
                                    _DesktopCartItem(
                                  item: item,
                                  cart: cart,
                                ),
                              );
                            },
                          ).toList(),
                        ),
                      ),

                      const SizedBox(
                        width: 22,
                      ),

                      SizedBox(
                        width: 350,
                        child:
                            _DesktopSummary(
                          cart: cart,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileCartContent(
    BuildContext context,
    CartProvider cart,
  ) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding:
                const EdgeInsets.all(16),
            itemCount: cart.items.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: 12),
            itemBuilder:
                (context, index) {
              final item =
                  cart.items[index];

              return _DesktopCartItem(
                item: item,
                cart: cart,
              );
            },
          ),
        ),

        Container(
          padding:
              const EdgeInsets.all(18),
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _PriceRow(
                  title: 'Subtotal',
                  value:
                      '₹${cart.subtotal.toStringAsFixed(0)}',
                ),
                const SizedBox(height: 8),
                _PriceRow(
                  title: 'Delivery',
                  value:
                      cart.deliveryCharge ==
                              0
                          ? 'FREE'
                          : '₹${cart.deliveryCharge.toStringAsFixed(0)}',
                ),
                const Divider(
                  height: 24,
                ),
                _PriceRow(
                  title: 'Total',
                  value:
                      '₹${cart.totalAmount.toStringAsFixed(0)}',
                  bold: true,
                ),
                const SizedBox(
                  height: 16,
                ),
                ElevatedButton(
                  onPressed: () {
                    _checkout(context);
                  },
                  child: const Text(
                    'Proceed to Checkout',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _checkout(
    BuildContext context,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CheckoutScreen(),
      ),
    );
  }
}

class _DesktopCartItem
    extends StatelessWidget {
  final CartItem item;
  final CartProvider cart;

  const _DesktopCartItem({
    required this.item,
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFE0F2FE),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_drink_rounded,
              size: 45,
              color:
                  Color(0xFF0284C7),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '₹${item.product.price.toStringAsFixed(0)} / ${item.product.unit}',
                  style: const TextStyle(
                    color:
                        Color(0xFF0284C7),
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    _QtyButton(
                      icon:
                          Icons.remove,
                      onTap: () {
                        cart.decreaseQuantity(
                          item.product.id,
                        );
                      },
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      child: Text(
                        '${item.quantity}',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      onTap: () {
                        cart.increaseQuantity(
                          item.product.id,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () {
                  cart.removeProduct(
                    item.product.id,
                  );
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
              ),

              Text(
                '₹${item.total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopSummary
    extends StatelessWidget {
  final CartProvider cart;

  const _DesktopSummary({
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 22),

          _PriceRow(
            title: 'Subtotal',
            value:
                '₹${cart.subtotal.toStringAsFixed(0)}',
          ),

          const SizedBox(height: 14),

          _PriceRow(
            title: 'Delivery',
            value:
                cart.deliveryCharge == 0
                    ? 'FREE'
                    : '₹${cart.deliveryCharge.toStringAsFixed(0)}',
          ),

          const Divider(height: 32),

          _PriceRow(
            title: 'Total',
            value:
                '₹${cart.totalAmount.toStringAsFixed(0)}',
            bold: true,
          ),

          const SizedBox(height: 22),

          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const CheckoutScreen(),
                ),
              );
            },
            child: const Text(
              'Proceed to Checkout',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart
    extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 75,
            color:
                Color(0xFFCBD5E1),
          ),
          SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Add some water products to continue',
            style: TextStyle(
              color:
                  Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton
    extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color:
              const Color(0xFFF1F5F9),
          borderRadius:
              BorderRadius.circular(8),
        ),
        child:
            Icon(icon, size: 17),
      ),
    );
  }
}

class _PriceRow
    extends StatelessWidget {
  final String title;
  final String value;
  final bool bold;

  const _PriceRow({
    required this.title,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: bold
                ? const Color(
                    0xFF0F172A,
                  )
                : const Color(
                    0xFF64748B,
                  ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold
                ? FontWeight.w800
                : FontWeight.w600,
            fontSize:
                bold ? 19 : 14,
          ),
        ),
      ],
    );
  }
}