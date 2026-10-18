import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/repositories/product_repository.dart';
import '../../../models/product_model.dart';
import '../cart/cart_provider.dart';
import '../cart/customer_cart_screen.dart';
import '../../../core/widgets/product_thumbnail.dart';
import 'product_detail_screen.dart';

/// Screen showing all products belonging to a specific category.
/// Navigated to when a customer taps a category card on the home screen.
class CategoryProductsScreen extends StatefulWidget {
  final int? categoryId;
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final ProductRepository _productRepository = ProductRepository();
  bool _loading = true;
  List<ProductModel> _products = [];
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _productRepository.getProducts(
        categoryId: widget.categoryId,
        category: widget.categoryId == null ? widget.categoryName : null,
        status: 'Active',
      );
      if (res['parsed_products'] is List<ProductModel>) {
        _products = List<ProductModel>.from(
          res['parsed_products'] as List<ProductModel>,
        );
      } else {
        _products = [];
      }

      // Fallback: If server returned empty, match from cached ProductRepository.cachedProducts
      if (_products.isEmpty && ProductRepository.cachedProducts.isNotEmpty) {
        final catLower = widget.categoryName.toLowerCase();
        _products = ProductRepository.cachedProducts.where((p) {
          final isBottle = catLower.contains('bottle');
          final isJar = catLower.contains('jar');
          if (isBottle) {
            return p.category.toLowerCase().contains('bottle') ||
                p.unit.toLowerCase().contains('bottle') ||
                p.name.toLowerCase().contains('bottle') ||
                (p.size.toLowerCase().contains('ml') &&
                    !p.size.toLowerCase().contains('20'));
          } else if (isJar) {
            return p.category.toLowerCase().contains('jar') ||
                p.unit.toLowerCase().contains('jar') ||
                p.name.toLowerCase().contains('jar') ||
                p.size.toLowerCase().contains('20');
          }
          return p.category.toLowerCase().contains(catLower) ||
              p.name.toLowerCase().contains(catLower);
        }).toList();
      }
    } catch (e) {
      _error = 'Failed to load products. Please try again.';
    }

    if (mounted) setState(() => _loading = false);
  }

  List<ProductModel> get _filtered {
    final q = _search.trim().toLowerCase();
    final activeOnly = _products.where(
      (p) => p.status.toLowerCase() == 'active' || p.status.isEmpty,
    );
    if (q.isEmpty) return activeOnly.toList();
    return activeOnly.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final cartCount = cart.totalItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.categoryName,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF111827),
              ),
            ),
            const Text(
              'Products',
              style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
        actions: [
          if (cartCount > 0)
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    color: Color(0xFF0284C7),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerCartScreen(),
                    ),
                  ),
                  tooltip: 'Cart',
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0284C7),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$cartCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            IconButton(
              icon: const Icon(
                Icons.shopping_cart_outlined,
                color: Color(0xFF9CA3AF),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerCartScreen()),
              ),
              tooltip: 'Cart',
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search in ${widget.categoryName}…',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB0B7C3),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0284C7)),
                ),
              ),
            ),
          ),

          // BODY
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                  )
                : _error != null
                ? _buildError()
                : _filtered.isEmpty
                ? _buildEmpty()
                : _buildGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final products = _filtered;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final crossCount = constraints.maxWidth >= 720
            ? 3
            : (constraints.maxWidth < 340 ? 1 : 2);
        final ratio = constraints.maxWidth >= 720
            ? 0.78
            : (crossCount == 1 ? 1.2 : 0.63);
        return RefreshIndicator(
          onRefresh: _fetchProducts,
          color: const Color(0xFF0284C7),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: ratio,
            ),
            itemCount: products.length,
            itemBuilder: (ctx, i) => _ProductCard(product: products[i]),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 52,
            color: Color(0xFFD1D5DB),
          ),
          const SizedBox(height: 14),
          Text(
            _search.isNotEmpty
                ? 'No products matching "$_search"'
                : 'No products in this category yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
          if (_search.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _search = ''),
              child: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF59E0B),
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchProducts,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
// PRODUCT CARD (overflow-safe, same style as ProductsScreen)
// ────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.getQuantity(product.id);
    final inCart = qty > 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // IMAGE
            Expanded(
              flex: 5,
              child: ProductThumbnail.fromProduct(
                product: product,
                fit: BoxFit.contain,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                padding: const EdgeInsets.all(8),
              ),
            ),

            // INFO
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    if (product.stock <= 0)
                      const Text(
                        'Out of Stock',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const Spacer(),
                    // ADD / QUANTITY CONTROL
                    inCart
                        ? _QuantityControl(product: product)
                        : SizedBox(
                            width: double.infinity,
                            height: 36,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: product.stock <= 0
                                    ? Colors.grey.shade400
                                    : const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: product.stock <= 0
                                  ? null
                                  : () {
                                      final error = context
                                          .read<CartProvider>()
                                          .addProduct(product);
                                      if (error != null) {
                                        ScaffoldMessenger.of(context)
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(
                                            SnackBar(
                                              content: Text(error),
                                              backgroundColor:
                                                  Colors.red.shade700,
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
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
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.white,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: const Color(
                                                0xFF16A34A,
                                              ),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
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
                                          ? Icons.remove_shopping_cart
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
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Image.asset(
      product.assetFallbackImage,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFFE0F2FE),
        child: const Center(
          child: Icon(
            Icons.water_drop_rounded,
            size: 36,
            color: Color(0xFF0284C7),
          ),
        ),
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final ProductModel product;
  const _QuantityControl({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.getQuantity(product.id);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SmallBtn(
          icon: Icons.remove_rounded,
          color: const Color(0xFFEF4444),
          onTap: () => cart.decrement(product.id),
        ),
        Text(
          '$qty',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: Color(0xFF111827),
          ),
        ),
        _SmallBtn(
          icon: Icons.add_rounded,
          color: const Color(0xFF0284C7),
          onTap: () => cart.add(product),
        ),
      ],
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SmallBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
