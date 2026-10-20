import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/product_provider.dart';
import '../../../core/repositories/app_repositories.dart';
import '../../../core/widgets/ai_chatbot_modal.dart';
import '../../../models/product_model.dart';
import '../../../models/user_model.dart';
import '../cart/cart_provider.dart';
import '../cart/customer_cart_screen.dart';
import '../notifications/customer_notifications_screen.dart';
import '../products/category_products_screen.dart';
import '../products/product_detail_screen.dart';
import '../products/customer_products_screen.dart';
import '../orders/customer_orders_screen.dart';
import '../../../core/widgets/support_desk_modal.dart';
import '../../../core/widgets/product_thumbnail.dart';

class CustomerHomeScreen extends StatefulWidget {
  final VoidCallback? onOpenProducts;
  final VoidCallback? onOpenCart;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenProfile;

  const CustomerHomeScreen({
    super.key,
    this.onOpenProducts,
    this.onOpenCart,
    this.onOpenOrders,
    this.onOpenProfile,
  });

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  UserModel? _currentUser;
  String search = '';
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = await AuthRepository().getCachedUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }

    try {
      final notifRes = await AuthRepository().getCustomerNotifications();
      if (mounted && notifRes['success'] == true && notifRes['data'] is Map<String, dynamic>) {
        final list = notifRes['data']['notifications'] as List? ?? [];
        final unread = list.where((n) => n['is_read'] != true).length;
        setState(() {
          _unreadNotificationsCount = unread;
        });
      }
    } catch (_) {}
  }

  void _handleOpenProducts() {
    if (widget.onOpenProducts != null) {
      widget.onOpenProducts!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CustomerProductsScreen()),
      );
    }
  }

  void _handleOpenOrders() {
    if (widget.onOpenOrders != null) {
      widget.onOpenOrders!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CustomerOrdersScreen()),
      );
    }
  }


  void _handleOpenSupport() {
    SupportDeskModal.show(context);
  }

  void _showQualityDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Purity & Quality Standards',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Water Wala delivers certified, mineral-rich packaged drinking water following stringent 7-stage purification:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            _qualityStep('1', 'Multi-Grade Sand & Carbon Filtration'),
            _qualityStep('2', 'High-Pressure Reverse Osmosis (RO)'),
            _qualityStep('3', 'UV Disinfection & Sterilization'),
            _qualityStep('4', 'Ozonation for Maximum Purity & Freshness'),
            _qualityStep('5', 'Enriched with Essential Minerals (TDS 100-150)'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.health_and_safety_rounded,
                    color: Color(0xFF0284C7),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BIS & FSSAI certified 100% safe packaged drinking water.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleOpenProducts();
            },
            child: const Text('View Water Products'),
          ),
        ],
      ),
    );
  }

  Widget _qualityStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFF0284C7),
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showWalletDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFF0284C7),
              size: 24,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Customer Water Wallet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Text(
                    'Available Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '₹1,250.00',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Auto-applied on next water order checkout',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDCFCE7),
                child: Icon(Icons.add_card_rounded, color: Color(0xFF16A34A)),
              ),
              title: const Text(
                'Instant Cashback',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              subtitle: const Text(
                'Get 5% extra on recharges above ₹1,000',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleOpenProducts();
            },
            child: const Text('Order with Wallet'),
          ),
        ],
      ),
    );
  }

  void _showRewardsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.stars_rounded, color: Color(0xFF9333EA), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Shivnath Hydration Rewards',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD8B4FE)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.military_tech_rounded,
                    color: Color(0xFF9333EA),
                    size: 36,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Silver Member',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF6B21A8),
                          ),
                        ),
                        Text(
                          '320 Hydration Points available',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7E22CE),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '• Earn 1 point for every ₹10 spent on drinking water.\n• Redeem 100 points for ₹50 off on 20L water jars.\n• Free doorstep priority delivery on orders with Gold Tier.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleOpenProducts();
            },
            child: const Text('Earn More Points'),
          ),
        ],
      ),
    );
  }

  String get _userName {
    final name = _currentUser?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Valued Customer';
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
    final providerProducts = context.watch<ProductProvider>().products;
    final allProducts = providerProducts.isNotEmpty ? providerProducts : ProductRepository.cachedProducts;

    final filteredProducts = allProducts.where((product) {
      return product.name.toLowerCase().contains(search.toLowerCase().trim());
    }).toList();

    final products = search.trim().isEmpty
        ? allProducts.take(4).toList()
        : filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 28,
              width: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.water_drop_rounded,
                color: Color(0xFF0284C7),
                size: 26,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Water Wala',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    'Pure Water. Delivered.',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerNotificationsScreen(),
                ),
              );
              if (mounted) _loadInitialData();
            },
            icon: Badge(
              isLabelVisible: _unreadNotificationsCount > 0,
              label: Text('$_unreadNotificationsCount'),
              backgroundColor: const Color(0xFFEF4444),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        onPressed: () =>
            AiChatbotModal.show(context, mode: ChatbotMode.customer),
        icon: const Icon(Icons.smart_toy_rounded),
        label: const Text(
          'AI Assistant',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
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
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            search = '';
                          });

                          FocusScope.of(context).unfocus();
                        },
                        icon: const Icon(Icons.close_rounded),
                      )
                    : const Icon(Icons.tune_rounded),
              ),
            ),

            const SizedBox(height: 20),

            // MOBILE HERO
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleOpenProducts,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF06B6D4)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                Flexible(
                                  child: Text(
                                    'Fast Delivery',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
              ),
            ),

            const SizedBox(height: 20),

            // MOBILE QUICK STATUS CARDS
            Row(
              children: [
                Expanded(
                  child: _MobileQuickStatusCard(
                    title: 'My Orders',
                    subtitle: 'Track delivery',
                    icon: Icons.local_shipping_outlined,
                    iconColor: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFE0F2FE),
                    onTap: _handleOpenOrders,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MobileQuickStatusCard(
                    title: 'Water Wallet',
                    subtitle: '₹1,250.00',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFEF3C7),
                    onTap: _showWalletDialog,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MobileQuickStatusCard(
                    title: 'Rewards',
                    subtitle: '320 Pts (Silver)',
                    icon: Icons.stars_outlined,
                    iconColor: const Color(0xFF9333EA),
                    bgColor: const Color(0xFFF3E8FF),
                    onTap: _showRewardsDialog,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MobileQuickStatusCard(
                    title: 'Live Support',
                    subtitle: '24/7 Desk',
                    icon: Icons.support_agent_outlined,
                    iconColor: const Color(0xFF10B981),
                    bgColor: const Color(0xFFDCFCE7),
                    onTap: _handleOpenSupport,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const _SectionTitle(title: 'Categories'),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _MobileCategoryCard(
                    title: 'Water Bottles',
                    subtitle: '250 ML - 2 Litre',
                    icon: Icons.local_drink_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CategoryProductsScreen(
                            categoryName: 'Water Bottles',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MobileCategoryCard(
                    title: 'Water Jars',
                    subtitle: '5L & 20L',
                    icon: Icons.water_drop_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CategoryProductsScreen(
                            categoryName: 'Water Jars',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            Row(
              children: [
                Expanded(
                  child: _MobileBenefitCard(
                    icon: Icons.verified_outlined,
                    title: 'Quality',
                    subtitle: 'Pure Water',
                    onTap: _showQualityDialog,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MobileBenefitCard(
                    icon: Icons.local_shipping_outlined,
                    title: 'Delivery',
                    subtitle: 'Fast Service',
                    onTap: _handleOpenOrders,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MobileBenefitCard(
                    icon: Icons.support_agent_outlined,
                    title: 'Support',
                    subtitle: 'Easy Help',
                    onTap: _handleOpenSupport,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            _SectionTitle(
              title: search.isEmpty ? 'Popular Products' : 'Search Results',
            ),

            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (ctx, constraints) {
                final isVeryNarrow = constraints.maxWidth < 340;
                final crossCount = isVeryNarrow ? 1 : 2;
                final ratio = isVeryNarrow ? 1.25 : (constraints.maxWidth < 370 ? 0.54 : 0.58);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: ratio,
                  ),
                  itemBuilder: (context, index) {
                    return _ProductCard(product: products[index]);
                  },
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
    final providerProducts = context.watch<ProductProvider>().products;
    final allProducts = providerProducts.isNotEmpty ? providerProducts : ProductRepository.cachedProducts;
    final products = allProducts.take(4).toList();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // WELCOME
                Text(
                  'Welcome back, $_userName 👋',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Here’s what’s happening with your orders today.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),

                const SizedBox(height: 24),

                // STATS (Adaptive Row / 2x2 Grid based on available width)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final card1 = _DesktopStatCard(
                      title: 'Active Orders',
                      value: '2',
                      icon: Icons.local_shipping_outlined,
                      background: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      onTap: _handleOpenOrders,
                    );
                    final card2 = _DesktopStatCard(
                      title: 'Delivered',
                      value: '18',
                      icon: Icons.check_circle_outline,
                      background: const Color(0xFFDCFCE7),
                      iconColor: const Color(0xFF16A34A),
                      onTap: _handleOpenOrders,
                    );
                    final card3 = _DesktopStatCard(
                      title: 'Wallet Balance',
                      value: '₹1,250',
                      icon: Icons.account_balance_wallet_outlined,
                      background: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      onTap: _showWalletDialog,
                    );
                    final card4 = _DesktopStatCard(
                      title: 'Reward Points',
                      value: '320',
                      icon: Icons.stars_outlined,
                      background: const Color(0xFFF3E8FF),
                      iconColor: const Color(0xFF9333EA),
                      onTap: _showRewardsDialog,
                    );

                    if (constraints.maxWidth < 950) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: card1),
                              const SizedBox(width: 14),
                              Expanded(child: card2),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: card3),
                              const SizedBox(width: 14),
                              Expanded(child: card4),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: card1),
                        const SizedBox(width: 14),
                        Expanded(child: card2),
                        const SizedBox(width: 14),
                        Expanded(child: card3),
                        const SizedBox(width: 14),
                        Expanded(child: card4),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // HERO
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleOpenProducts,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 26,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF06B6D4)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pure Water. Better Life.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
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
                                      Icons.local_shipping_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                        'Fast doorstep delivery',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                              color: Colors.white.withValues(alpha: 0.15),
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
                  ),
                ),

                const SizedBox(height: 28),

                // QUICK ORDER
                const Text(
                  'Quick Order',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 14),

                LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < products.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: _DesktopQuickProduct(product: products[i]),
                          ),
                        ],
                      ],
                    );
                  },
                ),

                const SizedBox(height: 30),

                // BOTTOM TWO COLUMNS (Adaptive for Tablet / Desktop)
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 900) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RecentOrdersCard(onTap: _handleOpenOrders),
                          const SizedBox(height: 18),
                          _SupportCard(onTap: _handleOpenSupport),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _RecentOrdersCard(onTap: _handleOpenOrders),
                        ),
                        const SizedBox(width: 18),
                        Expanded(child: _SupportCard(onTap: _handleOpenSupport)),
                      ],
                    );
                  },
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

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    );
  }
}

// =========================================================
// MOBILE CARDS
// =========================================================

class _MobileQuickStatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback? onTap;

  const _MobileQuickStatusCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileCategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _MobileCategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF0284C7)),
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
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBenefitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MobileBenefitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF0284C7)),
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
                style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
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
  final VoidCallback? onTap;

  const _DesktopStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.background,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// DESKTOP QUICK PRODUCT
// =========================================================

class _DesktopQuickProduct extends StatelessWidget {
  final ProductModel product;

  const _DesktopQuickProduct({required this.product});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductThumbnail.fromProduct(
                product: product,
                height: 90,
                width: double.infinity,
                fit: BoxFit.contain,
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.all(6),
              ),

              const SizedBox(height: 12),

              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
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
                    context.read<CartProvider>().addProduct(product);

                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${product.name} added to cart',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF0284C7),
                          duration: const Duration(seconds: 4),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          action: SnackBarAction(
                            label: 'GO TO CART',
                            textColor: const Color(0xFFFEF08A),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CustomerCartScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                  },
                  icon: const Icon(Icons.add_shopping_cart, size: 17),
                  label: const Text('Add'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// RECENT ORDERS
// =========================================================

class _RecentOrdersCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _RecentOrdersCard({this.onTap});

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
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Orders',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              if (onTap != null)
                TextButton(onPressed: onTap, child: const Text('View All')),
            ],
          ),

          const SizedBox(height: 18),

          ...orders.map(
            (order) => Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2FE),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF0284C7),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order['id']!,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            order['date']!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          order['amount']!,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order['status']!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
  final VoidCallback? onTap;

  const _SupportCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: Color(0xFFE0F2FE),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: Color(0xFF0284C7),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Need Help?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 7),

              const Text(
                'Our AI support and customer care team are available to assist you with orders, deliveries and payments.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 18),

              const Row(
                children: [
                  Icon(
                    Icons.smart_toy_rounded,
                    size: 17,
                    color: Color(0xFF0284C7),
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Chat with Support',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// PRODUCT CARD
// =========================================================

class _ProductCard extends StatelessWidget {
  final ProductModel product;

  const _ProductCard({required this.product});

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
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ProductThumbnail.fromProduct(
                  product: product,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  borderRadius: BorderRadius.circular(14),
                  padding: const EdgeInsets.all(8),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: product.stock <= 0
                        ? Colors.grey.shade400
                        : const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: product.stock <= 0
                      ? null
                      : () {
                          final error = context.read<CartProvider>().addProduct(
                            product,
                          );
                          if (error != null) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  backgroundColor: Colors.red.shade700,
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                          } else {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${product.name} added to cart',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF0284C7),
                                  duration: const Duration(seconds: 4),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  action: SnackBarAction(
                                    label: 'GO TO CART',
                                    textColor: const Color(0xFFFEF08A),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const CustomerCartScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                          }
                        },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          product.stock <= 0
                              ? Icons.remove_shopping_cart_outlined
                              : Icons.add_shopping_cart_rounded,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          product.stock <= 0 ? 'Out of Stock' : 'Add to Cart',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ],
                    ),
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
