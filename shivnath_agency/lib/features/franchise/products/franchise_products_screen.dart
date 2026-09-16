import 'package:flutter/material.dart';

import '../../../core/services/OrderService.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/session_service.dart';
import '../../../models/product_model.dart';

class FranchiseProductsScreen extends StatefulWidget {
  const FranchiseProductsScreen({super.key});

  @override
  State<FranchiseProductsScreen> createState() =>
      _FranchiseProductsScreenState();
}

class _FranchiseProductsScreenState
    extends State<FranchiseProductsScreen> {
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
                ),
          body: Padding(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desktop) ...[
                  const Text(
                    'Products',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'View products and franchise pricing.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                    ),
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

                const SizedBox(height: 18),

                Expanded(
                  child: GridView.builder(
                    itemCount: products.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: desktop ? 4 : 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: desktop ? .9 : .58,
                    ),
                    itemBuilder: (context, index) {
                      final product = products[index];

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius:
                                      BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.local_drink_rounded,
                                  size: 54,
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
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              product.size,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Stock: ${product.stock}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '₹${product.price.toStringAsFixed(0)} / ${product.unit}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(height: 9),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _openOrderDialog(product),
                                icon: const Icon(
                                  Icons.add_shopping_cart,
                                  size: 18,
                                ),
                                label: const Text('Order'),
                              ),
                            ),
                          ],
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