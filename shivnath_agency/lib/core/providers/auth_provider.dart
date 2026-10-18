import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthProvider({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository();

  UserModel? _currentUser;
  String? _token;
  String? _role;
  bool _isLoading = false;
  String? _errorMessage;
  bool _initialized = false;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  String? get role => _role ?? _currentUser?.role;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty && _currentUser != null;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    _isLoading = true;
    notifyListeners();

    try {
      _token = await _authRepository.getAccessToken();
      _currentUser = await _authRepository.getCachedUser();
      _role = await _authRepository.getCachedRole();

      if (_token != null && _token!.isNotEmpty) {
        // Refresh profile in background
        final res = await _authRepository.getCurrentUser();
        if (res['success'] == true && res['data'] is Map<String, dynamic>) {
          _currentUser = UserModel.fromJson(res['data'] as Map<String, dynamic>);
          await _authRepository.saveSession(
            token: _token!,
            user: _currentUser!,
            role: _role ?? _currentUser!.role,
          );
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] Init error: $e');
    } finally {
      _isLoading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String role,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _authRepository.login(
        email: email,
        password: password,
        role: role,
      );

      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final data = res['data'] as Map<String, dynamic>;
        _token = data['access']?.toString() ?? data['token']?.toString();
        _role = role;

        if (data['user'] is Map<String, dynamic>) {
          _currentUser = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        } else {
          _currentUser = UserModel(
            id: data['id']?.toString() ?? '0',
            name: data['name']?.toString() ?? email.split('@').first,
            email: email,
            phone: data['phone']?.toString() ?? '',
            role: role,
          );
        }

        if (_token != null && _currentUser != null) {
          await _authRepository.saveSession(
            token: _token!,
            user: _currentUser!,
            role: role,
          );
        }

        _isLoading = false;
        notifyListeners();
        return {'success': true, 'data': data};
      } else {
        _errorMessage = res['message']?.toString() ?? 'Login failed. Please check your credentials.';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'message': _errorMessage};
      }
    } catch (e) {
      _errorMessage = 'An error occurred during login. Please try again.';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    }
  }

  Future<Map<String, dynamic>> registerCustomer(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _authRepository.registerCustomer(
        name: data['name']?.toString() ?? '',
        phone: data['phone']?.toString() ?? '',
        email: data['email']?.toString() ?? '',
        password: data['password']?.toString() ?? '',
        confirmPassword: data['confirmPassword']?.toString() ?? data['password']?.toString() ?? '',
        city: data['city']?.toString() ?? '',
        district: data['district']?.toString() ?? '',
        zoneId: data['zoneId'] is int
            ? data['zoneId'] as int
            : int.tryParse(data['zoneId']?.toString() ?? '0') ?? 0,
        franchiseId: data['franchiseId'] is int
            ? data['franchiseId'] as int
            : int.tryParse(data['franchiseId']?.toString() ?? ''),
        address: data['address']?.toString() ?? '',
      );
      _isLoading = false;
      if (res['success'] != true) {
        _errorMessage = res['message']?.toString();
      }
      notifyListeners();
      return res;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Registration error: $e';
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    }
  }

  Future<Map<String, dynamic>> registerFranchise(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _authRepository.registerFranchise(
        ownerName: data['ownerName']?.toString() ?? '',
        businessName: data['businessName']?.toString() ?? '',
        phone: data['phone']?.toString() ?? '',
        email: data['email']?.toString() ?? '',
        password: data['password']?.toString() ?? '',
        confirmPassword: data['confirmPassword']?.toString() ?? data['password']?.toString() ?? '',
        city: data['city']?.toString() ?? '',
        address: data['address']?.toString() ?? '',
        territory: data['territory']?.toString() ?? '',
        fssaiNumber: data['fssaiNumber']?.toString() ?? '',
        documentFilePath: data['documentFilePath']?.toString() ?? '',
        fssaiBusinessName: data['fssaiBusinessName']?.toString() ?? '',
        fssaiPremisesAddress: data['fssaiPremisesAddress']?.toString() ?? '',
        fssaiState: data['fssaiState']?.toString() ?? '',
        fssaiDistrict: data['fssaiDistrict']?.toString() ?? '',
        fssaiExpiryDate: data['fssaiExpiryDate']?.toString() ?? '',
        documentType: data['documentType']?.toString() ?? 'FSSAI_CERTIFICATE',
        gstNumber: data['gstNumber']?.toString() ?? '',
        panNumber: data['panNumber']?.toString() ?? '',
        aadhaarNumber: data['aadhaarNumber']?.toString() ?? '',
      );
      _isLoading = false;
      if (res['success'] != true) {
        _errorMessage = res['message']?.toString();
      }
      notifyListeners();
      return res;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Franchise registration error: $e';
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authRepository.clearSession();
      _currentUser = null;
      _token = null;
      _role = null;
      _errorMessage = null;
    } catch (e) {
      debugPrint('[AuthProvider] Logout error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> refreshUser() async {
    try {
      final res = await _authRepository.getCurrentUser();
      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        _currentUser = UserModel.fromJson(res['data'] as Map<String, dynamic>);
        if (_token != null && _currentUser != null) {
          await _authRepository.saveSession(
            token: _token!,
            user: _currentUser!,
            role: _role ?? _currentUser!.role,
          );
        }
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[AuthProvider] Refresh user error: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _authRepository.updateProfile(data);
      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        _currentUser = UserModel.fromJson(res['data'] as Map<String, dynamic>);
        if (_token != null && _currentUser != null) {
          await _authRepository.saveSession(
            token: _token!,
            user: _currentUser!,
            role: _role ?? _currentUser!.role,
          );
        }
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'data': res['data']};
      } else {
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'message': res['message']};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Profile update error: $e'};
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      _isLoading = false;
      notifyListeners();
      return res;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Password change error: $e'};
    }
  }
}
