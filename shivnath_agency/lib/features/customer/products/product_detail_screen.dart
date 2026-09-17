import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/product_model.dart';
import '../cart/cart_provider.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.local_drink,
              size: 120,
              color: Color(0xFF0284C7),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            product.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '${product.size} • ${product.category}',
            style: const TextStyle(
              color: Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            '₹${product.price.toStringAsFixed(0)} / ${product.unit}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0284C7),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            product.description,
            style: const TextStyle(
              height: 1.6,
              color: Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: product.stock > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                product.stock > 0
                    ? 'Available Stock: ${product.stock} units'
                    : 'Currently Out of Stock',
                style: TextStyle(
                  color: product.stock > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          ElevatedButton.icon(
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
                          ),
                        );
                    } else {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text('${product.name} added to cart'),
                            backgroundColor: const Color(0xFF0284C7),
                          ),
                        );
                    }
                  },
            icon: const Icon(Icons.shopping_cart_outlined),
            label: Text(product.stock > 0 ? 'Add to Cart' : 'Out of Stock'),
          ),
        ],
      ),
    );
  }
}