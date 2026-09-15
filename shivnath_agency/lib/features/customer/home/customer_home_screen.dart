import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/product_service.dart';
import '../../../core/widgets/ai_chatbot_modal.dart';
import '../../../models/product_model.dart';
import '../cart/cart_provider.dart';
import '../notifications/customer_notifications_screen.dart';
import '../products/product_detail_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() =>
      _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String search = '';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    await ProductService().getProducts();
    if (mounted) setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          return _buildDesktopHome();
        }

        return _buildMobileHome();
      },
    );
  }

  // =========================================================
  // MOBILE VIEW
  // =========================================================

  Widget _buildMobileHome() {
    final allProducts = ProductService.products;

    final filteredProducts = allProducts.where((product) {
      return product.name.toLowerCase().contains(
            search.toLowerCase().trim(),
          );
    }).toList();

    final products = search.trim().isEmpty
        ? allProducts.take(4).toList()
        : filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shivnath Agency',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Pure Water. Delivered.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const CustomerNotificationsScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        onPressed: () => AiChatbotModal.show(context),
        icon: const Icon(Icons.smart_toy_rounded),
        label: const Text('AI Assistant', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          18,
          10,
          18,
          100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (value) {
                setState(() {
                  search = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search water products...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                ),
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            search = '';
                          });

                          FocusScope.of(context)
                              .unfocus();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      )
                    : const Icon(
                        Icons.tune_rounded,
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // MOBILE HERO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0284C7),
                    Color(0xFF06B6D4),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pure Water,\nHealthy Life',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 9),
                        Text(
                          'Fresh packaged drinking water delivered directly to you.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Fast Delivery',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.water_drop_rounded,
                    size: 85,
                    color: Colors.white,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            const _SectionTitle(
              title: 'Categories',
            ),

            const SizedBox(height: 12),

            const Row(
              children: [
                Expanded(
                  child: _MobileCategoryCard(
                    title: 'Water Bottles',
                    subtitle: '250 ML - 2 Litre',
                    icon: Icons.local_drink_outlined,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _MobileCategoryCard(
                    title: 'Water Jars',
                    subtitle: '5L & 20L',
                    icon: Icons.water_drop_outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            const Row(
              children: [
                Expanded(
                  child: _MobileBenefitCard(
                    icon: Icons.verified_outlined,
                    title: 'Quality',
                    subtitle: 'Pure Water',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _MobileBenefitCard(
                    icon: Icons.local_shipping_outlined,
                    title: 'Delivery',
                    subtitle: 'Fast Service',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _MobileBenefitCard(
                    icon: Icons.support_agent_outlined,
                    title: 'Support',
                    subtitle: 'Easy Help',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            _SectionTitle(
              title: search.isEmpty
                  ? 'Popular Products'
                  : 'Search Results',
            ),

            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemBuilder: (context, index) {
                return _ProductCard(
                  product: products[index],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DESKTOP VIEW
  // =========================================================

  Widget _buildDesktopHome() {
    final products = ProductService.products.take(4).toList();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1180,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // WELCOME
                const Text(
                  'Welcome back, Demo Customer 👋',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Here’s what’s happening with your orders today.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 24),

                // STATS
                const Row(
                  children: [
                    Expanded(
                      child: _DesktopStatCard(
                        title: 'Active Orders',
                        value: '2',
                        icon: Icons.local_shipping_outlined,
                        background:
                            Color(0xFFE0F2FE),
                        iconColor:
                            Color(0xFF0284C7),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: _DesktopStatCard(
                        title: 'Delivered',
                        value: '18',
                        icon: Icons.check_circle_outline,
                        background:
                            Color(0xFFDCFCE7),
                        iconColor:
                            Color(0xFF16A34A),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: _DesktopStatCard(
                        title: 'Wallet Balance',
                        value: '₹1,250',
                        icon:
                            Icons.account_balance_wallet_outlined,
                        background:
                            Color(0xFFFEF3C7),
                        iconColor:
                            Color(0xFFD97706),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: _DesktopStatCard(
                        title: 'Reward Points',
                        value: '320',
                        icon: Icons.stars_outlined,
                        background:
                            Color(0xFFF3E8FF),
                        iconColor:
                            Color(0xFF9333EA),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // HERO
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 26,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0284C7),
                        Color(0xFF06B6D4),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pure Water. Better Life.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Order fresh packaged drinking water for your home, office or event.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  Icons
                                      .local_shipping_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Fast doorstep delivery',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.water_drop_rounded,
                          size: 76,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // QUICK ORDER
                const Text(
                  'Quick Order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: products.map((product) {
                    return Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.only(right: 12),
                        child: _DesktopQuickProduct(
                          product: product,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 30),

                // BOTTOM TWO COLUMNS
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _RecentOrdersCard(),
                    ),
                    const SizedBox(width: 18),
                    const Expanded(
                      child: _SupportCard(),
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
}

// =========================================================
// COMMON
// =========================================================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// =========================================================
// MOBILE CARDS
// =========================================================

class _MobileCategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _MobileCategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0284C7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileBenefitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MobileBenefitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF0284C7),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// DESKTOP STAT CARD
// =========================================================

class _DesktopStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color background;
  final Color iconColor;

  const _DesktopStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.background,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================
// DESKTOP QUICK PRODUCT
// =========================================================

class _DesktopQuickProduct extends StatelessWidget {
  final ProductModel product;

  const _DesktopQuickProduct({
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            height: 90,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_drink_rounded,
              size: 45,
              color: Color(0xFF0284C7),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            '₹${product.price.toStringAsFixed(0)} / ${product.unit}',
            style: const TextStyle(
              color: Color(0xFF0284C7),
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context
                    .read<CartProvider>()
                    .addProduct(product);

                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        '${product.name} added to cart',
                      ),
                    ),
                  );
              },
              icon: const Icon(
                Icons.add_shopping_cart,
                size: 17,
              ),
              label: const Text(
                'Add',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// RECENT ORDERS
// =========================================================

class _RecentOrdersCard extends StatelessWidget {
  _RecentOrdersCard();

  final List<Map<String, String>> orders = const [
    {
      'id': '#ORD1002',
      'date': '05 Sep 2026',
      'amount': '₹550',
      'status': 'Dispatched',
    },
    {
      'id': '#ORD1001',
      'date': '04 Sep 2026',
      'amount': '₹430',
      'status': 'Delivered',
    },
    {
      'id': '#ORD0998',
      'date': '01 Sep 2026',
      'amount': '₹850',
      'status': 'Delivered',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Orders',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 18),

          ...orders.map(
            (order) => Container(
              margin: const EdgeInsets.only(
                bottom: 10,
              ),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor:
                        Color(0xFFE0F2FE),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF0284C7),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['id']!,
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        Text(
                          order['date']!,
                          style: const TextStyle(
                            fontSize: 10,
                            color:
                                Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      Text(
                        order['amount']!,
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order['status']!,
                        style: const TextStyle(
                          fontSize: 10,
                          color:
                              Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// SUPPORT
// =========================================================

class _SupportCard extends StatelessWidget {
  const _SupportCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFFE0F2FE),
            child: Icon(
              Icons.support_agent_rounded,
              color: Color(0xFF0284C7),
            ),
          ),

          SizedBox(height: 16),

          Text(
            'Need Help?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          SizedBox(height: 7),

          Text(
            'Our support team is available to assist you with orders, delivery and payments.',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Color(0xFF64748B),
            ),
          ),

          SizedBox(height: 18),

          Row(
            children: [
              Icon(
                Icons.phone_outlined,
                size: 17,
                color: Color(0xFF0284C7),
              ),
              SizedBox(width: 8),
              Text(
                'Contact Support',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0284C7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================
// PRODUCT CARD
// =========================================================

class _ProductCard extends StatelessWidget {
  final ProductModel product;

  const _ProductCard({
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(
                product: product,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_drink_rounded,
                    size: 55,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                '₹${product.price.toStringAsFixed(0)} / ${product.unit}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0284C7),
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 9),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                  ),
                  onPressed: () {
                    context
                        .read<CartProvider>()
                        .addProduct(product);
                  },
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}