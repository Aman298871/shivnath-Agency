import '../services/franchise_service.dart';

class FranchiseRepository {
  final FranchiseService _franchiseService;

  FranchiseRepository({FranchiseService? franchiseService})
      : _franchiseService = franchiseService ?? FranchiseService();

  Future<Map<String, dynamic>> getFranchises() async {
    return await _franchiseService.getFranchises();
  }

  Future<Map<String, dynamic>> getPendingFranchises() async {
    return await _franchiseService.getPendingFranchises();
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    return await _franchiseService.getDashboardStats();
  }

  Future<Map<String, dynamic>> getFranchiseDetail(int franchiseId) async {
    return await _franchiseService.getFranchiseDetail(franchiseId);
  }

  Future<Map<String, dynamic>> createFranchise([
    Map<String, dynamic>? dataPositional,
    Map<String, dynamic>? unused,
  ]) async {
    final finalData = dataPositional ?? {};
    return await _franchiseService.createFranchise(data: finalData);
  }

  Future<Map<String, dynamic>> updateFranchise(
    int franchiseId,
    Map<String, dynamic> data,
  ) async {
    return await _franchiseService.updateFranchise(franchiseId: franchiseId, data: data);
  }

  Future<Map<String, dynamic>> rejectFranchise({
    required int franchiseId,
    required String reason,
  }) async {
    return await _franchiseService.rejectFranchise(
      franchiseId: franchiseId,
      reason: reason,
    );
  }

  Future<Map<String, dynamic>> deleteFranchise(int franchiseId) async {
    return await _franchiseService.deleteFranchise(franchiseId);
  }

  Future<Map<String, dynamic>> approveFranchise(int franchiseId, {String? overrideReason}) async {
    return await _franchiseService.approveFranchise(franchiseId, overrideReason: overrideReason);
  }

  Future<Map<String, dynamic>> verifyFranchiseFSSAI({
    required int franchiseId,
    required String action,
    String source = 'FoSCoS Portal Manual Review',
    String notes = '',
    String reason = '',
    String officialBusinessName = '',
    String officialReference = '',
    String? officialExpiryDate,
  }) async {
    return await _franchiseService.verifyFranchiseFSSAI(
      franchiseId: franchiseId,
      action: action,
      source: source,
      notes: notes,
      reason: reason,
      officialBusinessName: officialBusinessName,
      officialReference: officialReference,
      officialExpiryDate: officialExpiryDate,
    );
  }

  Future<Map<String, dynamic>> getFranchiseDocuments([int? dealerId]) async {
    return await _franchiseService.getFranchiseDocuments(dealerId);
  }

  Future<Map<String, dynamic>> uploadFranchiseDocument({
    required String documentType,
    required String documentNumber,
    required List<int> fileBytes,
    required String fileName,
    int? dealerId,
  }) async {
    return await _franchiseService.uploadFranchiseDocument(
      documentType: documentType,
      documentNumber: documentNumber,
      fileBytes: fileBytes,
      fileName: fileName,
      dealerId: dealerId,
    );
  }

  Future<Map<String, dynamic>> deleteFranchiseDocument(int docId, [int? dealerId]) async {
    return await _franchiseService.deleteFranchiseDocument(docId, dealerId);
  }

  Future<Map<String, dynamic>> verifyFranchiseDocument({
    required int docId,
    required String action,
    String rejectionReason = '',
  }) async {
    return await _franchiseService.verifyFranchiseDocument(
      docId: docId,
      action: action,
      rejectionReason: rejectionReason,
    );
  }
}
