import '../services/customer_service.dart';

class CustomerRepository {
  final CustomerService _customerService;

  CustomerRepository({CustomerService? customerService})
      : _customerService = customerService ?? CustomerService();

  Future<Map<String, dynamic>> getCustomers({
    String? search,
    String? status,
    String? zone,
    String? franchise,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    return await _customerService.getCustomers(
      search: search,
      status: status,
      zone: zone,
      franchise: franchise,
      dateFrom: dateFrom,
      dateTo: dateTo,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<Map<String, dynamic>> getCustomerDetail(
    int customerId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    return await _customerService.getCustomerDetail(
      customerId,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<Map<String, dynamic>> getAdminDashboardStats() async {
    return await _customerService.getAdminDashboardStats();
  }
}
