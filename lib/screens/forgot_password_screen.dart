 import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:typed_data';
import '../services/api_service.dart';
import '../services/captcha_service.dart';
import '../models/login_model.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _captchaController = TextEditingController();
  
  final ApiService _apiService = ApiService();
  final CaptchaService _captchaService = CaptchaService();
  
  bool _isLoading = false;
  bool _isLoadingCaptcha = false;
  bool _autoSolvingCaptcha = false;
  
  Uint8List? _captchaImageBytes;
  LoginFormData? _formData;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _formData = await _apiService.fetchLoginPage();
      
      await _loadCaptcha();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data: $e';
      });
    }
  }

  Future<void> _loadCaptcha() async {
    setState(() {
      _isLoadingCaptcha = true;
      _captchaController.clear();
    });

    try {
      final captchaBytes = await _apiService.fetchCaptchaImage();
      setState(() {
        _captchaImageBytes = captchaBytes;
        _isLoadingCaptcha = false;
      });
      
      await _autoSolveCaptcha();
    } catch (e) {
      setState(() {
        _isLoadingCaptcha = false;
        _errorMessage = 'Gagal memuat captcha: $e';
      });
    }
  }

  Future<void> _autoSolveCaptcha() async {
    if (_captchaImageBytes == null) return;

    setState(() {
      _autoSolvingCaptcha = true;
    });

    try {
      final result = await _captchaService.solveCaptcha(_captchaImageBytes!);
      setState(() {
        _captchaController.text = result;
        _autoSolvingCaptcha = false;
      });
    } catch (e) {
      setState(() {
        _autoSolvingCaptcha = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_formData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data form belum siap, silakan refresh'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await _apiService.submitForgotPassword(
        email: _emailController.text,
        captcha: _captchaController.text,
        csrfToken: _formData!.csrfToken,
        hiddenField: _formData!.hiddenFieldValue,
      );

      setState(() {
        _isLoading = false;
      });

      if (response['success']) {
        setState(() {
          _successMessage = response['message'] ?? 'Link reset password telah dikirim ke email Anda';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_successMessage!),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        _emailController.clear();
        _captchaController.clear();
        
        await _loadCaptcha();
      } else {
        // Langsung reload captcha kalo error
        await _loadCaptcha();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Langsung reload captcha kalo error
      await _loadCaptcha();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _captchaController.dispose();
    _captchaService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF073163)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading && _formData == null
            ? const Center(
                child: SpinKitFadingCircle(
                  color: Color(0xFF073163),
                  size: 50.0,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFF073163).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.lock_reset,
                                size: 60,
                                color: Color(0xFF073163),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Reset Password',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF073163),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Masukkan email Gmail Anda untuk\nmenerima link reset password',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Gmail',
                          prefixIcon: const Icon(Icons.email),
                          hintText: 'contoh@gmail.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF073163), width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email tidak boleh kosong';
                          }
                          if (!value.contains('@gmail.com')) {
                            return 'Harus menggunakan email Gmail';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      const SizedBox(height: 16),
                      
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF073163),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SpinKitThreeBounce(
                                  color: Colors.white,
                                  size: 20,
                                )
                              : const Text(
                                  'Kirim Link Reset',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Kembali ke Login',
                            style: TextStyle(
                              color: Color(0xFF073163),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
