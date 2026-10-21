import '../services/OrderService.dart';

class OrderRepository {
  final OrderService _orderService;

  OrderRepository({OrderService? orderService})
      : _orderService = orderService ?? OrderService();

  Future<Map<String, dynamic>> getOrders({
    String? search,
    String? status,
    String? orderSource,
  }) async {
    return await _orderService.getOrders(
      search: search,
      status: status,
      orderSource: orderSource,
    );
  }

  Future<Map<String, dynamic>> getOrder(int id) async {
    return await _orderService.getOrder(id);
  }

  Future<Map<String, dynamic>> getStats() async {
    return await _orderService.getStats();
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> data) async {
    return await _orderService.createOrder(data);
  }

  Future<Map<String, dynamic>> updateOrderStatus(int id, String status) async {
    return await _orderService.updateOrderStatus(id, status);
  }

  List<String> getAllowedNextStatuses(String? currentStatus) {
    return OrderService.getAllowedNextStatuses(currentStatus);
  }

  String getStatusLabel(String? status) {
    return OrderService.getStatusLabel(status);
  }

  String canonicalStatus(String? status) {
    return OrderService.canonicalStatus(status);
  }

  Future<Map<String, dynamic>> getWalletDetails() async {
    return await _orderService.getWalletDetails();
  }

  Future<Map<String, dynamic>> recordOrderPayment(int orderId, Map<String, dynamic> payload) async {
    return await _orderService.recordOrderPayment(orderId, payload);
  }

  Future<Map<String, dynamic>> getOrderPayments(int orderId) async {
    return await _orderService.getOrderPayments(orderId);
  }

  Future<Map<String, dynamic>> createRazorpayOrder({required double amount, int? orderId}) async {
    return await _orderService.createRazorpayOrder(amount: amount, orderId: orderId);
  }

  Future<Map<String, dynamic>> verifyRazorpayPayment({
    required int orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    return await _orderService.verifyRazorpayPayment(
      orderId: orderId,
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );
  }

  Future<Map<String, dynamic>> cancelRazorpayPayment({
    required int orderId,
    required String razorpayOrderId,
    String? reason,
  }) async {
    return await _orderService.cancelRazorpayPayment(
      orderId: orderId,
      razorpayOrderId: razorpayOrderId,
      reason: reason,
    );
  }

  Future<Map<String, dynamic>> getRazorpayStatus() async {
    return await _orderService.getRazorpayStatus();
  }

  Future<Map<String, dynamic>> getRedemptionProducts() async {
    return await _orderService.getRedemptionProducts();
  }

  Future<Map<String, dynamic>> redeemWalletPoints({
    required int productId,
    int quantity = 1,
    int? pointsToRedeem,
    dynamic deliveryAddress,
    String? notes,
  }) async {
    return await _orderService.redeemWalletPoints(
      productId: productId,
      quantity: quantity,
      pointsToRedeem: pointsToRedeem,
      deliveryAddress: deliveryAddress,
      notes: notes,
    );
  }

  Future<Map<String, dynamic>> getWalletSettings() async {
    return await _orderService.getWalletSettings();
  }

  Future<Map<String, dynamic>> updateWalletSettings(Map<String, dynamic> data) async {
    return await _orderService.updateWalletSettings(data);
  }

  Future<Map<String, dynamic>> initiateWalletRecharge({required double amount}) async {
    return await _orderService.initiateWalletRecharge(amount: amount);
  }

  Future<Map<String, dynamic>> verifyWalletRecharge({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    return await _orderService.verifyWalletRecharge(
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );
  }

  Future<Map<String, dynamic>> payOrderWithWallet({required int orderId}) async {
    return await _orderService.payOrderWithWallet(orderId: orderId);
  }

  Future<Map<String, dynamic>> getWalletTransactions() async {
    return await _orderService.getWalletTransactions();
  }

  Map<String, dynamic> mapOrder(Map<String, dynamic> raw) {
    return _orderService.mapOrder(raw);
  }
}
