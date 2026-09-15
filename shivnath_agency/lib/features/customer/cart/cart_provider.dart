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

  double get total => price * quantity;
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount =>
      _items.fold(0, (total, item) => total + item.quantity);

  double get subtotal =>
      _items.fold(0, (total, item) => total + item.total);

  double get deliveryCharge => subtotal >= 500 ? 0 : 30;

  double get totalAmount => subtotal + deliveryCharge;

  void addProduct(dynamic product) {
    String prodId = '';
    if (product is ProductModel) {
      prodId = product.id;
    } else if (product is Map) {
      prodId = product['id']?.toString() ?? '';
    }

    final index = _items.indexWhere((item) => item.id == prodId);

    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }

    notifyListeners();
  }

  void increaseQuantity(String id) {
    final index = _items.indexWhere((item) => item.id == id);

    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
    }
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