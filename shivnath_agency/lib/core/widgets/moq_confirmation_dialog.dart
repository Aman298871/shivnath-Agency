import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../features/customer/cart/cart_provider.dart';

class MoqConfirmationDialog extends StatelessWidget {
  final bool isJar;
  final String productName;
  final int minQty;

  const MoqConfirmationDialog({
    super.key,
    required this.isJar,
    required this.productName,
    this.minQty = 5,
  });

  static Future<bool> show(
    BuildContext context, {
    required bool isJar,
    required String productName,
    int minQty = 5,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MoqConfirmationDialog(
        isJar: isJar,
        productName: productName,
        minQty: minQty,
      ),
    );
    return result ?? false;
  }

  /// Centralized entry-point for adding a product to cart with transparent MOQ confirmation
  static Future<bool> handleAddToCart(
    BuildContext context,
    dynamic product, {
    int? requestedQty,
  }) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final String prodId = (product is ProductModel)
        ? product.id
        : (product['id']?.toString() ?? '');
    final currentQty = cart.getQuantity(prodId);

    bool isJar = false;
    bool isBottle = false;
    String name = '';
    int unitsPerCase = 24;

    if (product is ProductModel) {
      isJar = product.isJar;
      isBottle = product.isBottle;
      name = product.name;
      unitsPerCase = product.unitsPerCase;
    } else if (product is Map) {
      final s = (product['sku'] ?? '').toString().toUpperCase();
      final sz = (product['size'] ?? product['unit'] ?? '').toString().toLowerCase();
      final nm = (product['name'] ?? '').toString().toLowerCase();
      name = product['name']?.toString() ?? 'Product';
      if (s.contains('20L') || sz.contains('20l') || nm.contains('jar')) {
        isJar = true;
      } else {
        isBottle = true;
        unitsPerCase = (sz.contains('1l') || nm.contains('1l')) ? 12 : 24;
      }
    }

    // If item is already in cart, MOQ is already satisfied: add incremental quantity
    if (currentQty > 0) {
      final toAdd = requestedQty ?? (isBottle ? unitsPerCase : 1);
      final error = cart.addProduct(product, qty: toAdd);
      if (error != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }
      return true;
    }

    // Item is not yet in cart:
    // If requested quantity is already >= 5 units (jars or boxes), add directly
    final minUnits = isJar ? 5 : (5 * unitsPerCase);
    if (requestedQty != null && requestedQty >= minUnits) {
      final error = cart.addProduct(product, qty: requestedQty);
      if (error != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }
      return true;
    }

    // Quantity < MOQ: pop transparent confirmation dialog
    if (!context.mounted) return false;
    final confirmed = await show(
      context,
      isJar: isJar,
      productName: name,
      minQty: 5,
    );

    if (confirmed && context.mounted) {
      final error = cart.addProduct(product, qty: minUnits);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
      final unitLabel = isJar ? '5 jars' : '5 boxes';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$unitLabel of $name added to cart',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0284C7),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = isJar ? 'jars' : 'boxes';
    final actionLabel = 'Add $minQty $unitLabel';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
              ),
              child: Icon(
                isJar ? Icons.water_drop_rounded : Icons.inventory_2_rounded,
                color: const Color(0xFF0284C7),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Minimum Order Quantity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isJar
                  ? 'Minimum order quantity for 20L Water Jars is $minQty jars.\n\nWould you like to add $minQty jars to your cart?'
                  : 'Minimum order quantity for $productName is $minQty boxes.\n\nWould you like to add $minQty boxes to your cart?',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
