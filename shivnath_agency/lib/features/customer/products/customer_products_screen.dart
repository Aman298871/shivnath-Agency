import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/product_service.dart';
import '../../../models/product_model.dart';
import '../cart/cart_provider.dart';
import 'product_detail_screen.dart';

class CustomerProductsScreen extends StatefulWidget {
  const CustomerProductsScreen({super.key});

  @override
  State<CustomerProductsScreen> createState() =>
      _CustomerProductsScreenState();
}

class _CustomerProductsScreenState
    extends State<CustomerProductsScreen> {
  String search = '';
  String category = 'All';
  List<String> _categories = ['All'];
  bool _loadingCategories = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _fetchCategories();
  }

  Future<void> _fetchProducts() async {
    await ProductService().getProducts();
    if (mounted) setState(() {});
  }

  Future<void> _fetchCategories() async {
    setState(() => _loadingCategories = true);
    final res = await ProductService().getCategories(activeOnly: true);
    if (res['success'] == true && res['data'] is Map) {
      final list = res['data']['categories'];
      if (list is List) {
        final names = <String>['All'];
        for (var item in list) {
          if (item is Map && item['name'] != null) {
            final name = item['name'].toString();
            if (!names.contains(name)) names.add(name);
          }
        }
        if (mounted) {
          setState(() {
            _categories = names;
            _loadingCategories = false;
          });
          return;
        }
      }
    }
    if (mounted) setState(() => _loadingCategories = false);
  }

  @override
  Widget build(BuildContext context) {
    final products = ProductService.products.where((product) {
      final matchesSearch = product.name
          .toLowerCase()
          .contains(search.toLowerCase());

      final matchesCategory =
          category == 'All' || product.category.toLowerCase() == category.toLowerCase();

      return matchesSearch && matchesCategory;
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
            child: GridView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: products.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemBuilder: (context, index) {
                return _ProductCard(
                  product: products[index],
                  desktop: false,
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

                if (products.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(60),
                      child: Text(
                        'No products found',
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
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return _FilterChip(
            title: cat,
            selected: category == cat,
            onTap: () {
              setState(() {
                category = cat;
              });
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
                      Center(
                        child: Icon(
                          product.category ==
                                  'Water Jar'
                              ? Icons
                                  .water_drop_rounded
                              : Icons
                                  .local_drink_rounded,
                          size:
                              desktop ? 72 : 55,
                          color:
                              const Color(0xFF0284C7),
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
                child: ElevatedButton.icon(
                  style:
                      ElevatedButton.styleFrom(
                    minimumSize:
                        const Size(0, 42),
                    backgroundColor: product.stock <= 0 ? Colors.grey.shade400 : null,
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
                                  backgroundColor: Colors.red.shade700,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                          } else {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${product.name} added to cart',
                                  ),
                                  backgroundColor: const Color(0xFF0284C7),
                                  duration:
                                      const Duration(
                                    seconds: 1,
                                  ),
                                ),
                              );
                          }
                        },
                  icon: Icon(
                    product.stock <= 0 ? Icons.remove_shopping_cart : Icons.add_shopping_cart_rounded,
                    size: 17,
                  ),
                  label: Text(
                    product.stock <= 0 ? 'Out of Stock' : 'Add to Cart',
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