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

  double get price {
    if (product is ProductModel) return (product as ProductModel).price;
    if (product is Map) {
      return double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
    }
    return 0.0;
  }

  String get size {
    if (product is ProductModel) return (product as ProductModel).size;
    if (product is Map) return product['size']?.toString() ?? product['unit']?.toString() ?? '';
    return '';
  }

  int get stock {
    if (product is ProductModel) return (product as ProductModel).stock;
    if (product is Map) {
      return int.tryParse(product['stock']?.toString() ?? '0') ?? 0;
    }
    return 999;
  }

  double get total => price * quantity;
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

  double get deliveryCharge => subtotal >= 500 ? 0 : 30;

  double get totalAmount => subtotal + deliveryCharge;

  /// Adds a product to the cart with stock validation.
  /// Returns null on success, or an error message if stock limit is exceeded.
  String? addProduct(dynamic product, {int qty = 1}) {
    String prodId = '';
    int availableStock = 999;

    if (product is ProductModel) {
      prodId = product.id;
      availableStock = product.stock;
    } else if (product is Map) {
      prodId = product['id']?.toString() ?? '';
      availableStock = int.tryParse(product['stock']?.toString() ?? '999') ?? 999;
    }

    if (availableStock <= 0) {
      return "This product is currently out of stock.";
    }

    final index = _items.indexWhere((item) => item.id == prodId);

    if (index >= 0) {
      if (_items[index].quantity + qty > availableStock) {
        return "Only $availableStock units are currently available.";
      }
      _items[index].quantity += qty;
    } else {
      if (qty > availableStock) {
        return "Only $availableStock units are currently available.";
      }
      _items.add(CartItem(product: product, quantity: qty));
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
      if (item.quantity >= item.stock) {
        return "Only ${item.stock} units are currently available.";
      }
      item.quantity++;
      notifyListeners();
      return null;
    }
    return "Item not found in cart.";
  }

  void decreaseQuantity(String id) {
    final index = _items.indexWhere((item) => item.id == id);

    if (index < 0) return;

    if (_items[index].quantity > 1) {
      _items[index].quantity--;
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