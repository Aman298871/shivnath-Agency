import '../services/InventoryService.dart';
import '../services/stock_service.dart';

class InventoryRepository {
  final InventoryService _inventoryService;
  final StockService _stockService;

  InventoryRepository({
    InventoryService? inventoryService,
    StockService? stockService,
  })  : _inventoryService = inventoryService ?? InventoryService(),
        _stockService = stockService ?? StockService();

  Future<Map<String, dynamic>> getItems({
    String? search,
    String? type,
  }) async {
    return await _inventoryService.getItems(search: search, type: type);
  }

  Future<Map<String, dynamic>> getItem(int id) async {
    final res = await _inventoryService.getItems();
    if (res['success'] == true && res['data'] is List) {
      final list = res['data'] as List;
      final match = list.firstWhere(
        (e) => e is Map && (e['id'] == id || e['id']?.toString() == id.toString()),
        orElse: () => null,
      );
      if (match != null) {
        return {'success': true, 'data': match};
      }
    }
    return {'success': false, 'message': 'Item not found'};
  }

  Future<Map<String, dynamic>> createItem(Map<String, dynamic> data) async {
    return await _inventoryService.createItem(data);
  }

  Future<Map<String, dynamic>> updateItem(int id, Map<String, dynamic> data) async {
    return await _inventoryService.updateItem(id, data);
  }

  Future<Map<String, dynamic>> deleteItem(int id) async {
    return await _inventoryService.deleteItem(id);
  }

  Future<Map<String, dynamic>> getStockRequests({String? status}) async {
    return await _inventoryService.getStockRequests(status: status);
  }

  Future<Map<String, dynamic>> createStockRequest({
    required int itemId,
    required String type,
    required int quantity,
    String reason = '',
  }) async {
    return await _inventoryService.createStockRequest(
      itemId: itemId,
      type: type,
      quantity: quantity,
      reason: reason,
    );
  }

  Future<Map<String, dynamic>> approveStockRequest(int id) async {
    return await _inventoryService.approveStockRequest(id);
  }

  Future<Map<String, dynamic>> rejectStockRequest(int id, {required String reason}) async {
    return await _inventoryService.rejectStockRequest(id, reason: reason);
  }

  Map<String, dynamic> mapItem(Map<String, dynamic> item) {
    return _inventoryService.mapItem(item);
  }

  Map<String, dynamic> mapStockRequest(Map<String, dynamic> item) {
    return _inventoryService.mapStockRequest(item);
  }

  Future<Map<String, dynamic>> getRawMaterials() async {
    return await _inventoryService.getRawMaterials();
  }

  Future<Map<String, dynamic>> getDealerStockRequests({String? status}) async {
    return await _inventoryService.getDealerStockRequests(status: status);
  }

  Future<Map<String, dynamic>> createDealerStockRequest(Map<String, dynamic> data) async {
    return await _inventoryService.createDealerStockRequest(data);
  }

  Future<Map<String, dynamic>> approveDealerStockRequest(int id, {String? notes}) async {
    return await _inventoryService.dispatchDealerStockRequest(id, {'notes': notes ?? ''});
  }

  Future<Map<String, dynamic>> rejectDealerStockRequest(int id, {String? reason}) async {
    return await _inventoryService.rejectStockRequest(id, reason: reason ?? '');
  }

  Future<Map<String, dynamic>> fulfillDealerStockRequest(int id, Map<String, dynamic> payload) async {
    return await _inventoryService.fulfillSingleStockRequest(id);
  }

  Future<Map<String, dynamic>> fulfillAllStockRequests({bool autoReceive = true}) async {
    return await _inventoryService.fulfillAllStockRequests(autoReceive: autoReceive);
  }

  Future<Map<String, dynamic>> dispatchDealerStockRequest(int id, Map<String, dynamic> data) async {
    return await _inventoryService.dispatchDealerStockRequest(id, data);
  }

  Future<Map<String, dynamic>> receiveDealerStockRequest(int id, Map<String, dynamic> data) async {
    return await _inventoryService.receiveDealerStockRequest(id, data);
  }

  Future<Map<String, dynamic>> createRawMaterial(Map<String, dynamic> data) async {
    return await _inventoryService.createRawMaterial(data);
  }

  Future<Map<String, dynamic>> deleteProductBOMItem(int productId, int itemId) async {
    return await _inventoryService.deleteProductBOMItem(productId, itemId);
  }

  Future<Map<String, dynamic>> recordInvoicePayment({
    required int invoiceId,
    required double amount,
    String paymentMethod = 'UPI',
    String referenceNumber = '',
    String notes = '',
  }) async {
    return await _inventoryService.recordInvoicePayment(
      invoiceId: invoiceId,
      amount: amount,
      paymentMethod: paymentMethod,
      referenceNumber: referenceNumber,
      notes: notes,
    );
  }

  Future<Map<String, dynamic>> getDealerBatches({int? dealerId}) async {
    return await _inventoryService.getDealerBatches(dealerId: dealerId);
  }

  Future<Map<String, dynamic>> getFranchiseRawMaterials() async {
    return await _inventoryService.getFranchiseRawMaterials();
  }

  Future<Map<String, dynamic>> getFranchiseTransactions() async {
    return await _inventoryService.getFranchiseTransactions();
  }

  Future<Map<String, dynamic>> getFranchiseProductionLogs() async {
    return await _inventoryService.getFranchiseProductionLogs();
  }

  Future<Map<String, dynamic>> createFranchiseProductionLog(Map<String, dynamic> data) async {
    return await _inventoryService.createFranchiseProductionLog(data);
  }

  Future<Map<String, dynamic>> getInvoices({String? status, String? search, String? invoiceType}) async {
    return await _inventoryService.getInvoices(status: status, invoiceType: invoiceType ?? search);
  }

  Future<Map<String, dynamic>> recordPayment(int invoiceId, Map<String, dynamic> payload) async {
    return await _inventoryService.recordPayment(invoiceId, payload);
  }

  Future<Map<String, dynamic>> verifyInvoicePayment({required int invoiceId, String notes = ''}) async {
    return await _inventoryService.verifyInvoicePayment(invoiceId: invoiceId, notes: notes);
  }

  Future<Map<String, dynamic>> rejectInvoicePayment({required int invoiceId, String reason = ''}) async {
    return await _inventoryService.rejectInvoicePayment(invoiceId: invoiceId, reason: reason);
  }

  Future<Map<String, dynamic>> getPendingPayments() async {
    return await _inventoryService.getPendingPayments();
  }

  Future<Map<String, dynamic>> verifyPaymentByTxnId({required int txnId, String notes = ''}) async {
    return await _inventoryService.verifyPaymentByTxnId(txnId: txnId, notes: notes);
  }

  Future<Map<String, dynamic>> rejectPaymentByTxnId({required int txnId, String reason = ''}) async {
    return await _inventoryService.rejectPaymentByTxnId(txnId: txnId, reason: reason);
  }

  Future<Map<String, dynamic>> getPendingStockExpiryAlerts() async {
    return await _inventoryService.getPendingStockExpiryAlerts();
  }

  Future<Map<String, dynamic>> getDealerCreditProfile(int dealerId) async {
    return await _inventoryService.getDealerCreditProfile(dealerId);
  }

  Future<Map<String, dynamic>> getDealerAgingReport(int dealerId) async {
    return await _inventoryService.getDealerAgingReport(dealerId);
  }

  Future<Map<String, dynamic>> actionPendingStockExpiryAlert({
    required int alertId,
    required String action,
    int? snoozeDays,
    String? notes,
  }) async {
    return await _inventoryService.actionPendingStockExpiryAlert(
      alertId: alertId,
      action: action,
      snoozeDays: snoozeDays,
      notes: notes,
    );
  }

  Future<Map<String, dynamic>> getProductBOM(int productId) async {
    return await _inventoryService.getProductBOM(productId);
  }

  Future<Map<String, dynamic>> addProductBOMItem(int productId, Map<String, dynamic> data) async {
    return await _inventoryService.addProductBOMItem(productId, data);
  }

  Future<Map<String, dynamic>> updateProductPricing(int productId, Map<String, dynamic> data) async {
    return await _inventoryService.updateProductPricing(productId, data);
  }

  Future<Map<String, dynamic>> updateProductStockThreshold(int productId, Map<String, dynamic> data) async {
    return await _inventoryService.updateProductStockThreshold(productId, data);
  }

  Future<Map<String, dynamic>> getProductionBatches() async {
    return await _inventoryService.getProductionBatches();
  }

  Future<Map<String, dynamic>> createProductionBatch(Map<String, dynamic> data) async {
    return await _inventoryService.createProductionBatch(data);
  }

  Future<Map<String, dynamic>> recordBatchCollection({
    required int batchId,
    required int quantityCollected,
    String? clientName,
    String? notes,
    String? paymentStatus,
    String? paymentMethod,
    String? referenceNumber,
    double? amountDue,
    double? amountPaid,
    String? deliveryStatus,
  }) async {
    return await _inventoryService.recordBatchCollection(
      batchId: batchId,
      quantityCollected: quantityCollected,
      clientName: clientName,
      notes: notes,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      referenceNumber: referenceNumber,
      amountDue: amountDue,
      amountPaid: amountPaid,
      deliveryStatus: deliveryStatus,
    );
  }

  Future<Map<String, dynamic>> getStockRequestFulfillment(int requestId) async {
    return await _inventoryService.getStockRequestFulfillment(requestId);
  }

  Future<Map<String, dynamic>> fulfillSingleStockRequest(int requestId) async {
    return await _inventoryService.fulfillSingleStockRequest(requestId);
  }

  Future<Map<String, dynamic>> updateDealerCreditProfile({
    required int dealerId,
    required double creditLimit,
    int? paymentTermsDays,
    String? creditStatus,
    String? notes,
  }) async {
    return await _inventoryService.updateDealerCreditProfile(
      dealerId: dealerId,
      creditLimit: creditLimit,
      paymentTermsDays: paymentTermsDays,
      creditStatus: creditStatus,
      notes: notes,
    );
  }

  Future<Map<String, dynamic>> getDailyBusinessReports({
    String? startDate,
    String? endDate,
    String? period,
    String? productSku,
    dynamic orderId,
    dynamic franchiseId,
    dynamic customerId,
  }) async {
    return await _inventoryService.getDailyBusinessReports(
      startDate: startDate,
      endDate: endDate,
      period: period,
      productSku: productSku,
      orderId: orderId,
      franchiseId: franchiseId,
      customerId: customerId,
    );
  }

  Future<Map<String, dynamic>> getInventoryLedger({Map<String, String>? filters}) async {
    return await _inventoryService.getInventoryLedger(filters: filters);
  }

  Future<Map<String, dynamic>> adjustBatch({
    required int batchId,
    required String adjustmentType,
    required int quantity,
    required String reason,
  }) async {
    return await _inventoryService.adjustBatch(
      batchId: batchId,
      adjustmentType: adjustmentType,
      quantity: quantity,
      reason: reason,
    );
  }

  Future<Map<String, dynamic>> getBatchHistory(int batchId) async {
    return await _inventoryService.getBatchHistory(batchId);
  }

  // =========================================================
  // STOCK CYCLES & METRICS
  // =========================================================
  Future<Map<String, dynamic>> getCustomerStock() async {
    return await _stockService.getCustomerStock();
  }

  Future<Map<String, dynamic>> getFranchiseCustomerStocks({
    String? filter,
    String? search,
  }) async {
    return await _stockService.getFranchiseCustomerStocks(
      filter: filter,
      search: search,
    );
  }

  Future<Map<String, dynamic>> getAdminStocks({
    String? filter,
    String? search,
  }) async {
    return await _stockService.getAdminStocks(
      filter: filter,
      search: search,
    );
  }
}
