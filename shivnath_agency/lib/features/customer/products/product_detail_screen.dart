import 'package:flutter/material.dart';

import '../../../models/product_model.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../../../core/widgets/moq_confirmation_dialog.dart';

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
              child: ProductThumbnail.fromProduct(
                product: product,
                fit: BoxFit.contain,
                borderRadius: BorderRadius.circular(16),
                backgroundColor: const Color(0xFFF0F9FF),
                padding: const EdgeInsets.all(16),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Minimum Order Quantity Policy',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.isJar
                              ? 'Minimum order: 5 water jars per delivery.'
                              : (product.isBottle
                                  ? 'Minimum order: 5 boxes (${product.unitsPerCase * 5} bottles). Sold in full cartons.'
                                  : 'Minimum order: ${product.minOrderQuantity} ${product.unit}.'),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                      MoqConfirmationDialog.handleAddToCart(context, product);
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