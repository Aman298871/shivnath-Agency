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

          Text(
            'Available Stock: ${product.stock}',
            style: const TextStyle(
              color: Color(0xFF16A34A),
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 30),

          ElevatedButton.icon(
            onPressed: () {
              context.read<CartProvider>().addProduct(product);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Added to cart'),
                ),
              );
            },
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }
}