import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/product_service.dart';
import '../../../models/product_model.dart';
import '../cart/cart_provider.dart';
import '../cart/customer_cart_screen.dart';
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
      await ProductService().getProducts(
        categoryId: widget.categoryId,
        category: widget.categoryId == null ? widget.categoryName : null,
      );
      _products = ProductService.products.toList();
    } catch (e) {
      _error = 'Failed to load products. Please try again.';
    }

    if (mounted) setState(() => _loading = false);
  }

  List<ProductModel> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products.where((p) => p.name.toLowerCase().contains(q)).toList();
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
                  icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF0284C7)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomerCartScreen()),
                  ),
                  tooltip: 'Cart',
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        cartCount > 9 ? '9+' : '$cartCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF9CA3AF)),
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
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB0B7C3)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF9CA3AF)),
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
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
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
        final isWide = constraints.maxWidth >= 600;
        final crossCount = isWide ? 3 : 2;
        return RefreshIndicator(
          onRefresh: _fetchProducts,
          color: const Color(0xFF0284C7),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: isWide ? 0.80 : 0.62,
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
          const Icon(Icons.inventory_2_outlined, size: 52, color: Color(0xFFD1D5DB)),
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
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 44),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
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
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // IMAGE
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: product.image != null && product.image!.isNotEmpty
                    ? Image.network(
                        product.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
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
                      '₹${product.sellingPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    if (product.stock <= 0)
                      const Text(
                        'Out of Stock',
                        style: TextStyle(fontSize: 10, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                      ),
                    const Spacer(),
                    // ADD / QUANTITY CONTROL
                    inCart
                        ? _QuantityControl(product: product)
                        : SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: ElevatedButton(
                              onPressed: product.stock > 0
                                  ? () => context.read<CartProvider>().add(product)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                              child: const Text('Add'),
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
    return Container(
      color: const Color(0xFFE0F2FE),
      child: const Center(
        child: Icon(Icons.water_drop_rounded, size: 36, color: Color(0xFF0284C7)),
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
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF111827)),
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
  const _SmallBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
