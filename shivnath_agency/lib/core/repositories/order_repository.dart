import '../services/OrderService.dart';

class OrderRepository {
  final OrderService _orderService;

  OrderRepository({OrderService? orderService})
      : _orderService = orderService ?? OrderService();

  Future<Map<String, dynamic>> getOrders({
    String? search,
    String? status,
  }) async {
    return await _orderService.getOrders(
      search: search,
      status: status,
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

  Map<String, dynamic> mapOrder(Map<String, dynamic> raw) {
    return _orderService.mapOrder(raw);
  }
}
