import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/stock_service.dart';
import '../../models/user_model.dart';

class AuthRepository {
  final AuthService _authService;
  final SessionService _sessionService;
  final StockService _stockService;

  AuthRepository({
    AuthService? authService,
    SessionService? sessionService,
    StockService? stockService,
  })  : _authService = authService ?? AuthService(),
        _sessionService = sessionService ?? SessionService(),
        _stockService = stockService ?? StockService();

  Future<String?> getAccessToken() => _sessionService.getAccessToken();

  Future<UserModel?> getCachedUser() => _sessionService.getUser();
  Future<UserModel?> getSessionUser() => _sessionService.getUser();

  Future<String?> getCachedRole() => _sessionService.getRole();

  Future<void> saveSession({
    required String token,
    required UserModel user,
    required String role,
  }) async {
    await _sessionService.saveToken(token);
    await _sessionService.saveUser(user);
    await _sessionService.saveRole(role);
  }

  Future<void> saveUser(UserModel user) => _sessionService.saveUser(user);
  Future<void> clearSession() => _sessionService.clearSession();
  Future<void> logout() => _sessionService.logout();

  Future<Map<String, dynamic>> deleteAccount({
    required String password,
    String? reason,
  }) async {
    return await _authService.deleteAccount(
      password: password,
      reason: reason,
    );
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String role,
  }) async {
    return await _authService.login(
      email: email,
      password: password,
      role: role,
    );
  }

  Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String confirmPassword,
    required String city,
    required String district,
    required int zoneId,
    int? franchiseId,
    String address = '',
  }) async {
    return await _authService.registerCustomer(
      name: name,
      phone: phone,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      city: city,
      district: district,
      zoneId: zoneId,
      franchiseId: franchiseId,
      address: address,
    );
  }

  Future<Map<String, dynamic>> getTerritories({String? district}) async {
    return await _authService.getTerritories(district: district ?? '');
  }

  Future<Map<String, dynamic>> getTerritoryMaster() async {
    return await _authService.getTerritoryMaster();
  }

  Future<Map<String, dynamic>> getEligibleFranchises({
    int? territoryId,
    int? zoneId,
    String? district,
    String? city,
  }) async {
    return await _authService.getEligibleFranchises(
      territoryId: territoryId,
      zoneId: zoneId,
      district: district,
      city: city,
    );
  }

  Future<Map<String, dynamic>> getDistricts() async {
    return await _authService.getDistricts();
  }

  Future<Map<String, dynamic>> registerFranchise({
    required String ownerName,
    required String businessName,
    required String phone,
    required String email,
    required String password,
    required String confirmPassword,
    required String city,
    required String address,
    required String territory,
    required String fssaiNumber,
    required String documentFilePath,
    String fssaiBusinessName = '',
    String fssaiPremisesAddress = '',
    String fssaiState = '',
    String fssaiDistrict = '',
    String fssaiExpiryDate = '',
    String documentType = 'FSSAI_CERTIFICATE',
    String gstNumber = '',
    String panNumber = '',
    String aadhaarNumber = '',
  }) async {
    return await _authService.registerFranchise(
      ownerName: ownerName,
      businessName: businessName,
      phone: phone,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      city: city,
      address: address,
      territory: territory,
      fssaiNumber: fssaiNumber,
      documentFilePath: documentFilePath,
      fssaiBusinessName: fssaiBusinessName,
      fssaiPremisesAddress: fssaiPremisesAddress,
      fssaiState: fssaiState,
      fssaiDistrict: fssaiDistrict,
      fssaiExpiryDate: fssaiExpiryDate,
      documentType: documentType,
      gstNumber: gstNumber,
      panNumber: panNumber,
      aadhaarNumber: aadhaarNumber,
    );
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    return await _authService.getCurrentUser();
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return await _authService.updateProfile(data);
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    return await _authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }

  Future<Map<String, dynamic>> sendPasswordResetOtp(String email) async {
    return await _authService.forgotPassword(emailOrPhone: email);
  }

  Future<Map<String, dynamic>> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    return await _authService.resetPassword(
      emailOrPhone: email,
      token: otp,
      newPassword: newPassword,
      confirmPassword: newPassword,
    );
  }

  Future<Map<String, dynamic>> updateServiceStatus({
    required String action,
    String reason = '',
    int? customerId,
  }) async {
    return await _authService.updateServiceStatus(
      action: action,
      reason: reason,
      customerId: customerId,
    );
  }

  Future<Map<String, dynamic>> getFranchiseNotifications() async {
    return await _authService.getFranchiseNotifications();
  }

  Future<Map<String, dynamic>> markFranchiseNotificationsAsRead({int? id}) async {
    return await _authService.markFranchiseNotificationsAsRead(id: id);
  }

  Future<Map<String, dynamic>> getFranchiseCustomers({
    String? search,
    String? status,
  }) async {
    return await _authService.getFranchiseCustomers(
      search: (search != null && search.isNotEmpty) ? search : null,
    );
  }

  Future<Map<String, dynamic>> getUsers({String? role, String? search}) async {
    return await _authService.getUsers(role: role, search: search);
  }

  Future<Map<String, dynamic>> adminResetPassword({
    required int userId,
    required String verificationReason,
  }) async {
    return await _authService.adminResetPassword(
      userId: userId,
      verificationReason: verificationReason,
    );
  }

  Future<Map<String, dynamic>> getSuperAdminAdmins() async {
    return await _authService.getSuperAdminAdmins();
  }

  Future<Map<String, dynamic>> createSuperAdminAdmin(Map<String, dynamic> data) async {
    return await _authService.createSuperAdminAdmin(data);
  }

  Future<Map<String, dynamic>> updateSuperAdminAdmin(int id, Map<String, dynamic> data) async {
    return await _authService.updateSuperAdminAdmin(id, data);
  }

  Future<Map<String, dynamic>> resetSuperAdminAdminPassword(int id, String password) async {
    return await _authService.resetSuperAdminAdminPassword(id, password);
  }

  Future<Map<String, dynamic>> toggleSuperAdminAdminActive(int id, bool active) async {
    return await _authService.toggleSuperAdminAdminActive(id, active);
  }

  Future<Map<String, dynamic>> getAdminNotifications() async {
    return await _authService.getAdminNotifications();
  }

  Future<Map<String, dynamic>> markNotificationsAsRead({int? id}) async {
    return await _authService.markNotificationsAsRead(id: id);
  }

  Future<Map<String, dynamic>> getSuperAdminAdminPerformance({
    String dateFilter = 'today',
    String? startDate,
    String? endDate,
  }) async {
    return await _authService.getSuperAdminAdminPerformance(
      dateFilter: dateFilter,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // =========================================================
  // CUSTOMER / FRANCHISE / ADMIN STOCK CYCLES
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

  // =========================================================
  // CUSTOMER NOTIFICATIONS
  // =========================================================
  Future<Map<String, dynamic>> getCustomerNotifications() async {
    return await _stockService.getCustomerNotifications();
  }

  Future<Map<String, dynamic>> markCustomerNotificationsAsRead({int? id}) async {
    return await _stockService.markCustomerNotificationsAsRead(id: id);
  }

  Future<int> getUnreadNotificationCount() async {
    return await _stockService.getUnreadNotificationCount();
  }
}
