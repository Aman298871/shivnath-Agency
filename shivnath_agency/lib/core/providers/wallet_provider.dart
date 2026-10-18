import 'package:flutter/foundation.dart';
import '../repositories/order_repository.dart';

class WalletProvider extends ChangeNotifier {
  final OrderRepository _orderRepository;

  WalletProvider({OrderRepository? orderRepository})
      : _orderRepository = orderRepository ?? OrderRepository();

  double _balance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  double get balance => _balance;
  List<Map<String, dynamic>> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadWallet({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _orderRepository.getWalletDetails();
      if (res['success'] == true) {
        final bal = res['balance'];
        if (bal is num) {
          _balance = bal.toDouble();
        } else if (bal is String) {
          _balance = double.tryParse(bal) ?? 0.0;
        }

        final data = res['data'];
        if (data is Map && data['transactions'] is List) {
          _transactions = (data['transactions'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } else {
        _errorMessage = res['message']?.toString();
      }
    } catch (e) {
      _errorMessage = 'Error loading wallet: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateBalance(double newBalance) {
    _balance = newBalance;
    notifyListeners();
  }

  void addCredit(double amount) {
    _balance += amount;
    notifyListeners();
  }

  void deductDebit(double amount) {
    if (_balance >= amount) {
      _balance -= amount;
    } else {
      _balance = 0.0;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadWallet(forceRefresh: true);
  }
}
