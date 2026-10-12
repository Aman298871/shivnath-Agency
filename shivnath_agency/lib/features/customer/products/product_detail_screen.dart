import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/product_model.dart';
import '../cart/cart_provider.dart';
import '../cart/customer_cart_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  final ProductModel product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 240,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: product.image.isNotEmpty
                    ? Image.network(
                        product.image,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Image.asset(
                          product.assetFallbackImage,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Image.asset(
                        product.assetFallbackImage,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              product.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              product.category,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Text(
              '₹${product.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  product.stock > 0 ? Icons.check_circle : Icons.cancel,
                  color: product.stock > 0 ? Colors.green : Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  product.stock > 0 ? 'In Stock (${product.stock})' : 'Out of Stock',
                  style: TextStyle(
                    color: product.stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              product.description.isEmpty
                  ? 'No description available for this product.'
                  : product.description,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: product.stock <= 0 ? Colors.grey.shade400 : null,
              ),
              onPressed: product.stock <= 0
                  ? null
                  : () {
                      final error = context.read<CartProvider>().addProduct(product);
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
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Text(product.stock > 0 ? 'Add to Cart' : 'Out of Stock'),
            ),
          ],
        ),
      ),
    );
  }
}