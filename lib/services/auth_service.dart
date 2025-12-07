import 'package:flutter/material.dart';
import 'api_service.dart';
import '../models/login_model.dart';

class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;
  
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  Future<Map<String, String>?> loadSavedCredentials() async {
    return await _apiService.loadSavedCredentials();
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
    notifyListeners();
  }
}
