import 'package:flutter/material.dart';

import '../../../core/services/OrderService.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/app_toast.dart';
import '../../../models/product_model.dart';
import '../../customer/products/product_detail_screen.dart';

class FranchiseProductsScreen extends StatefulWidget {
  const FranchiseProductsScreen({super.key});

  @override
  State<FranchiseProductsScreen> createState() =>
      _FranchiseProductsScreenState();
}

class _FranchiseProductsScreenState
    extends State<FranchiseProductsScreen> {
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
    await ProductService().getProducts(
      categoryId: selectedCategoryId,
      category: selectedCategoryId == null && selectedCategoryName != 'All' ? selectedCategoryName : null,
    );
    if (mounted) setState(() => _loadingProducts = false);
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await ProductService().getCategories(activeOnly: true);
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
    final quantityController = TextEditingController(text: '10');
    final notesController = TextEditingController();
    int quantity = 10;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final totalAmount = quantity * product.price;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0284C7)),
                  const SizedBox(width: 8),
                  const Text('Place Plant Order', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
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
                                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  Text('₹${product.price.toStringAsFixed(0)} / ${product.unit}', style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w700, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity (Units / Boxes)',
                          prefixIcon: Icon(Icons.format_list_numbered_rounded),
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            quantity = int.tryParse(val) ?? 0;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
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
                            const Text('Total Estimated Cost:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0369A1))),
                            Text('₹${totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Order will be sent to the bottling plant for approval.',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting || quantity <= 0
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);
                          final user = await SessionService().getCurrentUser();
                          final franchiseName = user?.businessName.isNotEmpty == true
                              ? user!.businessName
                              : (user?.name.isNotEmpty == true ? user!.name : 'Franchise Partner');
                          final city = user?.city.isNotEmpty == true ? user!.city : 'Raipur';

                          final res = await OrderService().createOrder({
                            'franchise': franchiseName,
                            'city': city,
                            'items': quantity,
                            'amount': totalAmount,
                            'status': 'Plant Approval',
                            'payment': 'Pending',
                          });

                          if (!dialogContext.mounted) return;

                          if (res['success'] == true) {
                            Navigator.pop(dialogContext);
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text('Order of $quantity x ${product.name} placed successfully!'),
                                    backgroundColor: const Color(0xFF0284C7),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                            }
                          } else {
                            setDialogState(() => isSubmitting = false);
                            final msg = res['message'] ?? 'Unable to place order.';
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirm Order'),
                ),
              ],
            );
          },
        );
      },
    );

    quantityController.dispose();
    notesController.dispose();
  }

  Future<void> _openProductFormDialog({ProductModel? product}) async {
    final bool editing = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final skuController = TextEditingController(text: 'SKU-${DateTime.now().millisecondsSinceEpoch % 10000}');
    final sizeController = TextEditingController(text: product?.size ?? '20 Litre');
    final priceController = TextEditingController(text: product != null ? product.price.toStringAsFixed(0) : '35');
    final unitController = TextEditingController(text: product?.unit ?? 'Jar');
    final stockController = TextEditingController(text: product?.stock.toString() ?? '50');
    final descController = TextEditingController(text: product?.description ?? '');
    int? catId = product?.categoryRefId;
    String status = 'Active';
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(editing ? Icons.edit_note_rounded : Icons.add_box_rounded, color: const Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Text(editing ? 'Edit Product' : 'Add Product', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.9),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: skuController,
                          decoration: const InputDecoration(labelText: 'SKU *', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: sizeController,
                          decoration: const InputDecoration(labelText: 'Size / Volume *', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: catId,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: _categoryItems.map((c) => DropdownMenuItem<int?>(
                      value: c['id'] as int?,
                      child: Text(c['name']?.toString() ?? 'All', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (val) => setDlgState(() => catId = val),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Price (₹) *', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: unitController,
                          decoration: const InputDecoration(labelText: 'Unit (Jar/Bottle) *', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stock Qty', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: status,
                          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                            DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => status = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
              onPressed: isSaving ? null : () async {
                final name = nameController.text.trim();
                final sku = skuController.text.trim();
                final size = sizeController.text.trim();
                final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                final unit = unitController.text.trim().isEmpty ? 'Jar' : unitController.text.trim();
                final stock = int.tryParse(stockController.text.trim()) ?? 0;
                final desc = descController.text.trim();

                if (name.isEmpty) {
                  AppToast.error(ctx, 'Please enter product name');
                  return;
                }

                setDlgState(() => isSaving = true);
                final Map<String, dynamic> payload = {
                  'name': name,
                  'sku': sku.isEmpty ? 'SKU-${name.substring(0, 2).toUpperCase()}' : sku,
                  'size': size.isEmpty ? '20 Litre' : size,
                  'price': price,
                  'unit': unit,
                  'stock': stock,
                  'description': desc,
                  'status': status,
                };
                if (catId != null) {
                  payload['category_ref_id'] = catId;
                }

                final prodIdInt = int.tryParse(product?.id ?? '') ?? 0;
                Map<String, dynamic> res;
                if (editing && prodIdInt > 0) {
                  res = await ProductService().updateProduct(prodIdInt, payload);
                } else {
                  res = await ProductService().createProduct(payload);
                }

                if (!dialogCtx.mounted) return;
                setDlgState(() => isSaving = false);

                if (res['success'] == true) {
                  Navigator.pop(dialogCtx);
                  await _fetchProducts();
                  if (mounted) {
                    AppToast.success(context, editing ? 'Product updated successfully!' : 'Product added successfully!');
                  }
                } else {
                  AppToast.error(dialogCtx, res['message'] ?? 'Failed to save product');
                }
              },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(editing ? 'Save Changes' : 'Create Product'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    skuController.dispose();
    sizeController.dispose();
    priceController.dispose();
    unitController.dispose();
    stockController.dispose();
    descController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ProductService.products.where((product) {
      return product.name
          .toLowerCase()
          .contains(search.toLowerCase());
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: desktop
              ? null
              : AppBar(
                  title: const Text('Products'),
                  actions: [
                    IconButton(
                      tooltip: 'Add Product',
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => _openProductFormDialog(),
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
                            'Products',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'View products and franchise pricing.',
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
                        onPressed: () => _openProductFormDialog(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Product'),
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
                          : GridView.builder(
                              itemCount: products.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: desktop ? 4 : 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: desktop ? .82 : .52,
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
                                            child: Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE0F2FE),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Stack(
                                                children: [
                                                  Center(
                                                    child: Icon(
                                                      product.category == 'Water Jar'
                                                          ? Icons.water_drop_rounded
                                                          : Icons.local_drink_rounded,
                                                      size: desktop ? 60 : 48,
                                                      color: const Color(0xFF0284C7),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 4,
                                                    right: 4,
                                                    child: InkWell(
                                                      onTap: () => _openProductFormDialog(product: product),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          shape: BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withOpacity(0.08),
                                                              blurRadius: 4,
                                                            ),
                                                          ],
                                                        ),
                                                        child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF0284C7)),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
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
                                              label: const Text('Order', style: TextStyle(fontSize: 12)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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