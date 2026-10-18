import 'package:flutter/material.dart';

import '../../../core/repositories/inventory_repository.dart';
import '../../../core/repositories/product_repository.dart';
import '../../../core/utils/app_toast.dart';
import '../../../models/product_model.dart';
import '../../customer/products/product_detail_screen.dart';
import '../../../core/widgets/product_thumbnail.dart';

class FranchiseProductsScreen extends StatefulWidget {
  const FranchiseProductsScreen({super.key});

  @override
  State<FranchiseProductsScreen> createState() =>
      _FranchiseProductsScreenState();
}

class _FranchiseProductsScreenState
    extends State<FranchiseProductsScreen> {
  final ProductRepository _productRepository = ProductRepository();
  String search = '';
  int? selectedCategoryId;
  String selectedCategoryName = 'All';
  List<Map<String, dynamic>> _categoryItems = [
    {'id': null, 'name': 'All', 'full_path': 'All'}
  ];
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _fetchCategories();
  }

  Future<void> _fetchProducts() async {
    if (mounted) setState(() => _loadingProducts = true);
    await _productRepository.getProducts(
      status: 'Active',
      categoryId: selectedCategoryId,
      category: selectedCategoryId == null && selectedCategoryName != 'All' ? selectedCategoryName : null,
    );
    if (mounted) setState(() => _loadingProducts = false);
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await _productRepository.getCategories(activeOnly: true);
      if (res['success'] == true && res['data'] is Map) {
        final list = res['data']['categories'];
        if (list is List) {
          final items = <Map<String, dynamic>>[
            {'id': null, 'name': 'All', 'full_path': 'All'}
          ];
          void extract(List<dynamic> nodes) {
            for (var item in nodes) {
              if (item is Map) {
                final map = Map<String, dynamic>.from(item);
                items.add({
                  'id': map['id'],
                  'name': map['name'] ?? '',
                  'full_path': map['full_path'] ?? map['name'] ?? '',
                });
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
            return;
          }
        }
      }
    } catch (_) {
    }
  }

  Future<void> _openOrderDialog(ProductModel product) async {
    final statusLower = product.status.trim().toLowerCase();
    final skuUpper = product.sku.trim().toUpperCase();
    if (statusLower == 'inactive' || skuUpper == 'BOTTEL1' || skuUpper.isEmpty) {
      AppToast.warning(context, 'This item is not an active catalog product and cannot be ordered.');
      return;
    }

    final int? orderedQty = await showDialog<int>(
      context: context,
      builder: (dialogCtx) => _StockRequestDialog(product: product),
    );

    if (orderedQty != null && orderedQty > 0 && mounted) {
      AppToast.success(
        context,
        'Stock request of $orderedQty x ${product.name} submitted successfully to Central Plant!',
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final products = ProductRepository.cachedProducts.where((product) {
      final statusLower = product.status.trim().toLowerCase();
      if (statusLower.isNotEmpty && statusLower != 'active') return false;
      final skuUpper = product.sku.trim().toUpperCase();
      if (skuUpper == 'BOTTEL1') return false;

      final query = search.trim().toLowerCase();
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: desktop
              ? null
              : AppBar(
                  title: const Text('Company Catalog'),
                  actions: [
                    IconButton(
                      tooltip: 'Refresh Products',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () => _fetchProducts(),
                    ),
                  ],
                ),
          body: Padding(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desktop) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Company Catalog',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Official company products and wholesale dealer pricing. Select products to request stock.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _fetchProducts(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh Catalog'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                TextField(
                  onChanged: (value) {
                    setState(() => search = value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categoryItems.length,
                    itemBuilder: (context, index) {
                      final cat = _categoryItems[index];
                      final catId = cat['id'] as int?;
                      final isSelected = selectedCategoryId == catId;
                      final title = cat['name']?.toString() ?? 'All';

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(title),
                          selected: isSelected,
                          selectedColor: const Color(0xFFE0F2FE),
                          checkmarkColor: const Color(0xFF0284C7),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF334155),
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          onSelected: (_) async {
                            setState(() {
                              selectedCategoryId = catId;
                              selectedCategoryName = title;
                            });
                            await _fetchProducts();
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                Expanded(
                  child: _loadingProducts
                      ? const Center(child: CircularProgressIndicator())
                      : products.isEmpty
                          ? const Center(
                              child: Text(
                                'No products found',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final isSmall = constraints.maxWidth < 340;
                                final crossAxisCount = desktop
                                    ? 4
                                    : (constraints.maxWidth > 700 ? 3 : (isSmall ? 1 : 2));
                                final childAspectRatio = desktop
                                    ? .82
                                    : (isSmall
                                        ? 1.25
                                        : (constraints.maxWidth < 380 ? .54 : .58));
                                return GridView.builder(
                                  itemCount: products.length,
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: childAspectRatio,
                                  ),
                              itemBuilder: (context, index) {
                                final product = products[index];

                                return Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
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
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: ProductThumbnail.fromProduct(
                                              product: product,
                                              width: double.infinity,
                                              fit: BoxFit.contain,
                                              borderRadius: BorderRadius.circular(12),
                                              padding: const EdgeInsets.all(6),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            product.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            product.size,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: product.stock > 0 ? const Color(0xFF22C55E) : Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Stock: ${product.stock}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: product.stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '₹${product.price.toStringAsFixed(0)} / ${product.unit}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: Color(0xFF0284C7),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 36,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                backgroundColor: const Color(0xFF0284C7),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              onPressed: () => _openOrderDialog(product),
                                              icon: const Icon(Icons.add_shopping_cart, size: 15),
                                              label: const Text('Request Stock', style: TextStyle(fontSize: 12)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StockRequestDialog extends StatefulWidget {
  final ProductModel product;

  const _StockRequestDialog({required this.product});

  @override
  State<_StockRequestDialog> createState() => _StockRequestDialogState();
}

class _StockRequestDialogState extends State<_StockRequestDialog> {
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;
  int _quantity = 10;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '10');
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalAmount => _quantity * widget.product.price;

  Future<void> _submit() async {
    if (_quantity <= 0 || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final res = await InventoryRepository().createDealerStockRequest({
        'items': [
          {
            'product_id': widget.product.id,
            'sku': widget.product.sku,
            'product_sku': widget.product.sku,
            'quantity': _quantity,
            'requested_quantity': _quantity,
          }
        ],
        'notes': _notesController.text.trim(),
      });

      if (!mounted) return;

      if (res['success'] == true) {
        Navigator.pop(context, _quantity);
      } else {
        setState(() => _isSubmitting = false);
        final msg = res['message'] ?? 'Unable to submit stock request.';
        AppToast.error(context, msg.toString());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppToast.error(context, 'Error submitting stock request: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_shopping_cart, color: Color(0xFF0284C7), size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Stock Request (Dealer)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_drink_rounded, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          Text(
                            '₹${widget.product.price.toStringAsFixed(0)} / ${widget.product.unit}',
                            style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [10, 25, 50, 100, 500].map((preset) {
                  final isSelected = _quantity == preset;
                  return ChoiceChip(
                    label: Text('$preset'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _quantity = preset;
                          _quantityController.text = preset.toString();
                        });
                      }
                    },
                    selectedColor: const Color(0xFF0284C7),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity (Units / Boxes)',
                  prefixIcon: Icon(Icons.format_list_numbered_rounded),
                ),
                onChanged: (val) {
                  setState(() {
                    _quantity = int.tryParse(val) ?? 0;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Delivery Notes (Optional)',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Total Estimated Cost:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '₹${_totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Stock request will be sent to company admin for review and dispatch.',
                style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSubmitting || _quantity <= 0 ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit Stock Request'),
            ),
          ],
        ),
      ],
    );
  }
}