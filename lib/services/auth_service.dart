import 'package:flutter/material.dart';
import 'api_service.dart';
import '../models/login_model.dart';
import '../models/user_role_model.dart';

class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;
  UserRole? _currentUserRole;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;
  UserRole? get currentUserRole => _currentUserRole;

  Future<Map<String, String>?> loadSavedCredentials(UserRole role) async {
    return await _apiService.loadSavedCredentials(role);
  }

  Future<Map<String, dynamic>> login(LoginRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.login(request);

      if (result['success']) {
        _isAuthenticated = true;
        _errorMessage = null;
        _currentUserRole = request.userRole;
      } else {
        _isAuthenticated = false;
        _errorMessage = result['message'];
      }

      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Terjadi kesalahan: $e';
      notifyListeners();

      return {
        'success': false,
        'message': _errorMessage,
      };
    }
  }

  Future<void> logout() async {
    await _apiService.clearSavedCredentials();
    _isAuthenticated = false;
    _currentUserRole = null;
    notifyListeners();
  }
}
