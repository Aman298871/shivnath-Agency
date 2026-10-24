import 'package:flutter/material.dart';
import '../../../models/product_model.dart';

class CartItem {
  final dynamic product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  String get id {
    if (product is ProductModel) return (product as ProductModel).id;
    if (product is Map) return product['id']?.toString() ?? '';
    return product.toString();
  }

  String get name {
    if (product is ProductModel) return (product as ProductModel).name;
    if (product is Map) return product['name']?.toString() ?? '';
    return 'Product';
  }

  String get productName => name;

  double get price {
    if (product is ProductModel) return (product as ProductModel).price;
    if (product is Map) {
      return double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
    }
    return 0.0;
  }

  double get unitPrice => price;

  String get size {
    if (product is ProductModel) return (product as ProductModel).size;
    if (product is Map) return product['size']?.toString() ?? product['unit']?.toString() ?? '';
    return '';
  }

  String get sku {
    if (product is ProductModel) return (product as ProductModel).sku;
    if (product is Map) return product['sku']?.toString() ?? '';
    return '';
  }

  String get image {
    if (product is ProductModel) return (product as ProductModel).image;
    if (product is Map) return product['image']?.toString() ?? '';
    return '';
  }

  String get assetFallbackImage {
    if (product is ProductModel) return (product as ProductModel).assetFallbackImage;
    final s = sku.toUpperCase();
    final sz = size.toLowerCase();
    final nm = name.toLowerCase();

    if (s.contains('SHV-200') || sz.contains('200') || nm.contains('200')) {
      return 'assets/images/products/shv_200.jpg';
    }
    if (s.contains('SHV-250') || sz.contains('250') || nm.contains('250')) {
      return 'assets/images/products/shv_250.jpg';
    }
    if (s.contains('SHV-500') || sz.contains('500') || nm.contains('500')) {
      return 'assets/images/products/shv_500.jpg';
    }
    if (s.contains('SHV-1L') || sz.contains('1l') || sz.contains('1 l') || sz.contains('1000') || nm.contains('1 litre') || nm.contains('1l')) {
      return 'assets/images/products/shv_1l.jpg';
    }
    if (s.contains('SHV-20L') || sz.contains('20l') || sz.contains('20 l') || sz.contains('20000') || nm.contains('20 litre') || nm.contains('20l') || nm.contains('jar')) {
      return 'assets/images/products/shv_20l.jpg';
    }
    return 'assets/images/products/shv_500.jpg';
  }

  int get stock {
    if (product is ProductModel) return (product as ProductModel).stock;
    if (product is Map) {
      return int.tryParse(product['stock']?.toString() ?? '0') ?? 0;
    }
    return 999;
  }

  bool get isJar {
    if (product is ProductModel) return (product as ProductModel).isJar;
    final s = sku.toUpperCase();
    final sz = size.toLowerCase();
    final nm = name.toLowerCase();
    return s.contains('SHV-20L') ||
        s.contains('JAR') ||
        sz.contains('20l') ||
        sz.contains('20 l') ||
        sz.contains('20000') ||
        nm.contains('20 litre') ||
        nm.contains('20l') ||
        nm.contains('jar');
  }

  bool get isBottle {
    if (isJar) return false;
    if (product is ProductModel) return (product as ProductModel).isBottle;
    final s = sku.toUpperCase();
    final sz = size.toLowerCase();
    final nm = name.toLowerCase();
    return s.contains('BOT') ||
        s.contains('SHV-') ||
        sz.contains('ml') ||
        sz.contains('1l') ||
        sz.contains('2l') ||
        nm.contains('bottle') ||
        nm.contains('box') ||
        nm.contains('carton');
  }

  int get unitsPerCase {
    if (product is ProductModel) {
      final upc = (product as ProductModel).unitsPerCase;
      if (upc > 0) return upc;
    }
    if (isJar) return 1;
    final s = sku.toUpperCase();
    final sz = size.toLowerCase();
    final nm = name.toLowerCase();
    if (s.contains('1L') || sz.contains('1l') || sz.contains('1 l') || nm.contains('1 litre') || nm.contains('1l')) {
      return 12;
    }
    if (s.contains('2L') || sz.contains('2l') || sz.contains('2 l') || nm.contains('2 litre')) {
      return 9;
    }
    return 24;
  }

  int get stepQuantity {
    if (isBottle) return unitsPerCase;
    return 1;
  }

  int get boxCount {
    if (isBottle) return (quantity / unitsPerCase).floor();
    return quantity;
  }

  int get minOrderBoxes => 5;

  int get minOrderQuantity {
    if (product is ProductModel) return (product as ProductModel).minOrderQuantity;
    if (isJar) return 5;
    if (isBottle) return 5 * unitsPerCase;
    return 1;
  }

  String get moqUnitLabel {
    if (product is ProductModel) return (product as ProductModel).moqUnitLabel;
    if (isJar) return 'jars';
    if (isBottle) return 'boxes ($unitsPerCase bottles/box)';
    return 'units';
  }

  bool get meetsMoq {
    if (isJar) return quantity >= 5;
    if (isBottle) return quantity >= (5 * unitsPerCase) && (quantity % unitsPerCase == 0);
    return quantity >= 1;
  }

  double get total => price * quantity;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'product_name': name,
      'price': price,
      'size': size,
      'sku': sku,
      'image': image,
      'image_url': image,
      'assetFallbackImage': assetFallbackImage,
      'stock': stock,
      'quantity': quantity,
      'units_per_case': unitsPerCase,
      'min_order_quantity': minOrderQuantity,
      'moq_unit_label': moqUnitLabel,
      'meets_moq': meetsMoq,
    };
  }
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount =>
      _items.fold(0, (total, item) => total + item.quantity);

  int get totalItems => itemCount;

  int getQuantity(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    return index >= 0 ? _items[index].quantity : 0;
  }

  void add(dynamic product) {
    addProduct(product);
  }

  void decrement(String id) {
    decreaseQuantity(id);
  }

  double get subtotal =>
      _items.fold(0, (total, item) => total + item.total);

  double _customDeliveryCharge = 0.0;
  bool _hasCustomDeliveryCharge = false;

  void setDeliveryCharge(double charge) {
    _customDeliveryCharge = charge;
    _hasCustomDeliveryCharge = true;
    notifyListeners();
  }

  void resetDeliveryCharge() {
    _customDeliveryCharge = 0.0;
    _hasCustomDeliveryCharge = false;
    notifyListeners();
  }

  double get deliveryCharge => _hasCustomDeliveryCharge ? _customDeliveryCharge : 0.0;

  double get totalAmount => subtotal == 0 ? 0 : (subtotal + deliveryCharge);

  /// Validates that all items in cart satisfy their business MOQ.
  /// Returns null if valid, or an error message explaining the shortfall.
  String? validateCartMoq() {
    for (final item in _items) {
      if (item.isJar && item.quantity < 5) {
        return 'Minimum order requirement for "${item.name}" is 5 water jars. Current quantity is ${item.quantity}.';
      }
      if (item.isBottle) {
        final minUnits = 5 * item.unitsPerCase;
        if (item.quantity < minUnits) {
          final boxes = (item.quantity / item.unitsPerCase).toStringAsFixed(1);
          return 'Minimum order requirement for "${item.name}" is 5 boxes ($minUnits bottles). Current quantity is $boxes boxes (${item.quantity} bottles).';
        }
        if (item.quantity % item.unitsPerCase != 0) {
          return '"${item.name}" must be ordered in full boxes (${item.unitsPerCase} bottles per box). Current quantity: ${item.quantity} bottles.';
        }
      }
    }
    return null;
  }

  /// Adds a product to the cart with stock and MOQ validation.
  /// If adding a new item and qty is not specified, defaults to the product MOQ.
  /// Returns null on success, or an error message if stock limit is exceeded.
  String? addProduct(dynamic product, {int? qty}) {
    String prodId = '';
    int availableStock = 999;
    int moq = 1;
    int upc = 1;

    if (product is ProductModel) {
      prodId = product.id;
      availableStock = product.stock;
      moq = product.minOrderQuantity;
      upc = product.unitsPerCase;
    } else if (product is Map) {
      prodId = product['id']?.toString() ?? '';
      availableStock = int.tryParse(product['stock']?.toString() ?? '999') ?? 999;
      final s = (product['sku'] ?? '').toString().toUpperCase();
      final sz = (product['size'] ?? product['unit'] ?? '').toString().toLowerCase();
      final nm = (product['name'] ?? '').toString().toLowerCase();
      if (s.contains('20L') || sz.contains('20l') || nm.contains('jar')) {
        moq = 5;
        upc = 1;
      } else if (s.contains('BOT') || sz.contains('ml') || sz.contains('1l')) {
        upc = (sz.contains('1l') || nm.contains('1l')) ? 12 : 24;
        moq = 5 * upc;
      }
    }

    if (availableStock <= 0) {
      return "This product is currently out of stock.";
    }

    final effectiveQty = qty ?? moq;

    final index = _items.indexWhere((item) => item.id == prodId);

    if (index >= 0) {
      final step = _items[index].stepQuantity;
      final toAdd = qty ?? step;
      if (_items[index].quantity + toAdd > availableStock) {
        return "Only $availableStock units are currently available.";
      }
      _items[index].quantity += toAdd;
    } else {
      if (effectiveQty > availableStock) {
        return "Only $availableStock units are currently available.";
      }
      _items.add(CartItem(product: product, quantity: effectiveQty));
    }

    notifyListeners();
    return null;
  }

  /// Increases the quantity of a cart item with stock validation.
  /// Returns null on success, or an error message if stock limit is exceeded.
  String? increaseQuantity(String id) {
    final index = _items.indexWhere((item) => item.id == id);

    if (index >= 0) {
      final item = _items[index];
      final step = item.stepQuantity;
      if (item.quantity + step > item.stock) {
        return "Only ${item.stock} units are currently available.";
      }
      item.quantity += step;
      notifyListeners();
      return null;
    }
    return "Item not found in cart.";
  }

  /// Decreases the quantity of a cart item.
  /// If current quantity is at or below MOQ, removing decrements the entire line item
  /// to prevent leaving the cart in an invalid MOQ state (1-4 units).
  void decreaseQuantity(String id) {
    final index = _items.indexWhere((item) => item.id == id);

    if (index < 0) return;

    final item = _items[index];
    final step = item.stepQuantity;
    if (item.quantity - step >= item.minOrderQuantity) {
      item.quantity -= step;
    } else {
      _items.removeAt(index);
    }

    notifyListeners();
  }

  void removeProduct(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}