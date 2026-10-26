import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/product_provider.dart';
import '../../../core/repositories/product_repository.dart';
import '../../../models/product_model.dart';
import '../cart/cart_provider.dart';
import '../cart/customer_cart_screen.dart';
import '../../../core/widgets/product_thumbnail.dart';
import 'product_detail_screen.dart';
import '../../../core/widgets/moq_confirmation_dialog.dart';

class CustomerProductsScreen extends StatefulWidget {
  const CustomerProductsScreen({super.key});

  @override
  State<CustomerProductsScreen> createState() =>
      _CustomerProductsScreenState();
}

class _CustomerProductsScreenState
    extends State<CustomerProductsScreen> {
  final ProductRepository _productRepository = ProductRepository();
  String search = '';
  int? selectedCategoryId;
  String selectedCategoryName = 'All';
  List<Map<String, dynamic>> _categoryItems = [
    {'id': null, 'name': 'All', 'full_path': 'All'}
  ];
  List<ProductModel> _loadedProducts = [];
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProducts();
      _fetchCategories();
    });
  }

  Future<void> _fetchProducts() async {
    if (mounted) setState(() => _loadingProducts = true);
    try {
      final productProvider = context.read<ProductProvider>();
      await productProvider.loadProducts(
        categoryId: selectedCategoryId,
        category: selectedCategoryName != 'All' ? selectedCategoryName : null,
        forceRefresh: true,
      );
      if (mounted) {
        var list = productProvider.products;
        if (list.isEmpty && ProductRepository.cachedProducts.isNotEmpty && selectedCategoryName != 'All') {
          final catLower = selectedCategoryName.toLowerCase();
          final isBottle = catLower.contains('bottle');
          final isJar = catLower.contains('jar');
          list = ProductRepository.cachedProducts.where((p) {
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
        setState(() {
          _loadedProducts = list;
          _loadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await _productRepository.getCategories(activeOnly: true, hasActiveProducts: true);
      final raw = res['data'] ?? res;
      final dynamic list = (raw is Map) ? (raw['categories'] ?? raw['data']) : (raw is List ? raw : null);
      if (res['success'] == true && list is List) {
        final items = <Map<String, dynamic>>[
          {'id': null, 'name': 'All', 'full_path': 'All'}
        ];
        final seenIds = <dynamic>{null};
        void extract(List<dynamic> nodes) {
          for (var item in nodes) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final id = map['id'];
              final pCount = (map['product_count'] is int)
                  ? map['product_count'] as int
                  : int.tryParse('${map['product_count'] ?? ''}') ?? 1;

              // Only include categories that have at least one active product
              if (!seenIds.contains(id) && pCount > 0) {
                seenIds.add(id);
                items.add({
                  'id': id,
                  'name': map['name'] ?? '',
                  'full_path': map['full_path'] ?? map['name'] ?? '',
                  'product_count': pCount,
                });
              }
              final children = map['children'] ?? map['subcategories'];
              if (children is List && children.isNotEmpty) {
                extract(children);
              }
            }
          }
        }
        extract(list);
        if (mounted) {
          setState(() {
            _categoryItems = items;
          });
        }
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _loadedProducts.where((product) {
      final matchesSearch = search.trim().isEmpty ||
          product.name.toLowerCase().contains(search.toLowerCase());
      return matchesSearch;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          return _desktop(products);
        }

        return _mobile(products);
      },
    );
  }

  // =====================================================
  // MOBILE
  // =====================================================

  Widget _mobile(List<ProductModel> products) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Products',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, _) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: 'Go to Cart',
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerCartScreen(),
                      ),
                    );
                  },
                ),
                if (cart.itemCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '${cart.itemCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.itemCount == 0) return const SizedBox.shrink();

          return SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'} in cart',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '₹${cart.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: const Text(
                      'GO TO CART',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerCartScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              8,
              18,
              10,
            ),
            child: _searchField(),
          ),

          _filters(),

          Expanded(
            child: _loadingProducts
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 12),
                              Text(
                                selectedCategoryName != 'All'
                                    ? 'No products available under "$selectedCategoryName"'
                                    : 'No products currently available',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (selectedCategoryName != 'All' || search.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      selectedCategoryId = null;
                                      selectedCategoryName = 'All';
                                      search = '';
                                    });
                                    _fetchProducts();
                                  },
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('View All Available Products'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0284C7),
                                    side: const BorderSide(color: Color(0xFF0284C7)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (ctx, constraints) {
                          final crossCount = constraints.maxWidth >= 720
                              ? 3
                              : (constraints.maxWidth < 340 ? 1 : 2);
                          final ratio = constraints.maxWidth >= 720
                              ? 0.78
                              : (crossCount == 1
                                  ? 1.25
                                  : (constraints.maxWidth < 370 ? 0.58 : 0.62));
                          return GridView.builder(
                            padding: const EdgeInsets.all(18),
                            itemCount: products.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: ratio,
                            ),
                            itemBuilder: (context, index) {
                              return _ProductCard(
                                product: products[index],
                                desktop: false,
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // DESKTOP
  // =====================================================

  Widget _desktop(List<ProductModel> products) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1250,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Products',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Browse and order our premium drinking water products.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 24),

                _searchField(),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _filters(),
                    ),

                    const SizedBox(width: 16),

                    Container(
                      height: 44,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(11),
                        border: Border.all(
                          color:
                              const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.sort_rounded,
                            size: 18,
                            color:
                                Color(0xFF64748B),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sort: Popular',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                if (_loadingProducts)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(60),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (products.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(60),
                      child: Text(
                        'No products found',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      childAspectRatio: .72,
                    ),
                    itemBuilder: (context, index) {
                      return _ProductCard(
                        product: products[index],
                        desktop: true,
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

  Widget _searchField() {
    return TextField(
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
                },
                icon: const Icon(
                  Icons.close_rounded,
                ),
              )
            : const Icon(
                Icons.tune_rounded,
              ),
      ),
    );
  }

  Widget _filters() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categoryItems.length,
        itemBuilder: (context, index) {
          final cat = _categoryItems[index];
          final catId = cat['id'] as int?;
          final isSelected = selectedCategoryId == catId;
          final title = cat['name']?.toString() ?? 'All';

          return _FilterChip(
            title: title,
            selected: isSelected,
            onTap: () async {
              setState(() {
                selectedCategoryId = catId;
                selectedCategoryName = title;
              });
              await _fetchProducts();
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: selected
            ? const Icon(
                Icons.check_rounded,
                size: 15,
              )
            : null,
        label: Text(title),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool desktop;

  const _ProductCard({
    required this.product,
    required this.desktop,
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
              builder: (_) =>
                  ProductDetailScreen(
                product: product,
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(
            desktop ? 14 : 11,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFE0F2FE),
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ProductThumbnail.fromProduct(
                          product: product,
                          fit: BoxFit.contain,
                          borderRadius: BorderRadius.circular(14),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),

                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(
                              20,
                            ),
                          ),
                          child: Text(
                            product.size,
                            style:
                                const TextStyle(
                              fontSize: 9,
                              fontWeight:
                                  FontWeight.w700,
                              color:
                                  Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                product.name,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize:
                      desktop ? 14 : 12,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(height: 5),

              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        const BoxDecoration(
                      color:
                          Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${product.stock} in stock',
                    style:
                        const TextStyle(
                      fontSize: 10,
                      color:
                          Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 7),

              Text(
                '₹${product.price.toStringAsFixed(0)} / ${product.unit}',
                style: TextStyle(
                  fontSize:
                      desktop ? 16 : 13,
                  color:
                      const Color(0xFF0284C7),
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 11),

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
                          MoqConfirmationDialog.handleAddToCart(context, product);
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
    );
  }
}