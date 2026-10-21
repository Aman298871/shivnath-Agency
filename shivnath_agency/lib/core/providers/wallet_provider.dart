import 'package:flutter/foundation.dart';
import '../repositories/order_repository.dart';

class WalletProvider extends ChangeNotifier {
  final OrderRepository _orderRepository;

  WalletProvider({OrderRepository? orderRepository})
      : _orderRepository = orderRepository ?? OrderRepository();

  double _balance = 0.0;
  int _rewardPoints = 0;
  double _pointsValueInInr = 0.0;
  Map<String, dynamic>? _conversionRule;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  double get balance => _balance;
  int get rewardPoints => _rewardPoints;
  double get pointsValueInInr => _pointsValueInInr;
  Map<String, dynamic>? get conversionRule => _conversionRule;
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

        final pts = res['reward_points'];
        if (pts is num) {
          _rewardPoints = pts.toInt();
        } else if (pts is String) {
          _rewardPoints = int.tryParse(pts) ?? 0;
        }

        final ptsVal = res['points_value_in_inr'];
        if (ptsVal is num) {
          _pointsValueInInr = ptsVal.toDouble();
        } else if (ptsVal is String) {
          _pointsValueInInr = double.tryParse(ptsVal) ?? 0.0;
        }

        if (res['conversion_rule'] is Map) {
          _conversionRule = Map<String, dynamic>.from(res['conversion_rule']);
        }

        final data = res['data'];
        final txList = (data is Map && data['recent_transactions'] is List)
            ? data['recent_transactions']
            : (data is Map && data['transactions'] is List ? data['transactions'] : null);

        if (txList is List) {
          _transactions = txList
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

  void updatePoints(int newPoints) {
    _rewardPoints = newPoints;
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

  Future<Map<String, dynamic>> redeemPointsForProduct({
    required int productId,
    int quantity = 1,
    int? pointsToRedeem,
    dynamic deliveryAddress,
    String? notes,
  }) async {
    final res = await _orderRepository.redeemWalletPoints(
      productId: productId,
      quantity: quantity,
      pointsToRedeem: pointsToRedeem,
      deliveryAddress: deliveryAddress,
      notes: notes,
    );

    if (res['success'] == true) {
      // Refresh wallet state to sync points and balance
      await loadWallet(forceRefresh: true);
    }

    return res;
  }

  Future<void> refresh() async {
    await loadWallet(forceRefresh: true);
  }
}
