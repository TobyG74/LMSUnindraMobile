import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:typed_data';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/captcha_service.dart';
import '../models/login_model.dart';
import '../models/user_role_model.dart';
import 'dashboard_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final UserRole userRole;

  const LoginScreen({super.key, required this.userRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();

  final ApiService _apiService = ApiService();
  final CaptchaService _captchaService = CaptchaService();

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isFirstLoad = true;

  Uint8List? _captchaImageBytes;
  LoginFormData? _loginFormData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeLogin();
  }

  Future<void> _initializeLogin() async {
    final savedCredentials =
        await _apiService.loadSavedCredentials(widget.userRole);
    if (savedCredentials != null) {
      setState(() {
        _usernameController.text = savedCredentials['username']!;
        // Hanya isi password jika ada (remember me = true)
        if (savedCredentials.containsKey('password')) {
          _passwordController.text = savedCredentials['password']!;
          _rememberMe = true;
        } else {
          // Username tersimpan tapi tidak ada password (setelah logout)
          _passwordController.clear();
          _rememberMe = false;
        }
      });
    }

    await _loadLoginData();
  }

  Future<void> _loadLoginData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _loginFormData = await _apiService.fetchLoginPage();

      await _loadCaptcha();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data login: $e';
      });
    }
  }

  Future<void> _loadCaptcha() async {
    setState(() {
      _captchaController.clear();
    });

    try {
      final captchaBytes = await _apiService.fetchCaptchaImage();
      setState(() {
        _captchaImageBytes = captchaBytes;
      });

      await _autoSolveCaptcha();
    } catch (e) {}
  }

  Future<void> _autoSolveCaptcha() async {
    if (_captchaImageBytes == null) return;

    try {
      final result = await _captchaService.solveCaptcha(_captchaImageBytes!);
      setState(() {
        _captchaController.text = result;
      });

      // Auto-login hanya jika remember me aktif dan ada username + password
      if (_isFirstLoad &&
          mounted &&
          result != '0' &&
          _rememberMe &&
          _usernameController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          _isFirstLoad = false;
          await _handleLogin();
        }
      }
    } catch (e) {}
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    if (_loginFormData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data login belum siap, silakan refresh'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final loginRequest = LoginRequest(
      csrfToken: _loginFormData!.csrfToken,
      hiddenField: _loginFormData!.hiddenFieldValue,
      username: _usernameController.text,
      password: _passwordController.text,
      captcha: _captchaController.text,
      userRole: widget.userRole,
      rememberMe: _rememberMe,
    );

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.login(loginRequest);

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const DashboardScreen(),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Username atau password salah'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        await _loadCaptcha();
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    _captchaService.dispose();
    super.dispose();
  }

  void _showAboutDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1A2436) : const Color(0xFFF8FAFD);
    final borderColor =
        isDark ? const Color(0xFF2A3853) : const Color(0xFFE0E8F3);
    final subtitleColor =
        isDark ? const Color(0xFFB9C6DA) : const Color(0xFF5A6B85);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE7CC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.info_outline, color: Color(0xFFD97706)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tentang Aplikasi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3D1A7)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Aplikasi Unofficial',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aplikasi ini merupakan aplikasi tidak resmi (unofficial) yang dibuat untuk memudahkan akses ke LMS UNINDRA.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildAboutCard(
                color: cardColor,
                borderColor: borderColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dibuat oleh',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Tobi Saputra', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildLinkButton(
                          context,
                          icon: FontAwesomeIcons.github,
                          label: 'GitHub',
                          url: 'https://github.com/TobyG74',
                        ),
                        const SizedBox(width: 8),
                        _buildLinkButton(
                          context,
                          icon: FontAwesomeIcons.instagram,
                          label: 'Instagram',
                          url: 'https://instagram.com/ini.tobz',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildAboutCard(
                color: cardColor,
                borderColor: borderColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Terima kasih kepada',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildAboutItem(
                      icon: Icons.bug_report_rounded,
                      title: 'Tester',
                      titleColor: subtitleColor,
                    ),
                    const SizedBox(height: 6),
                    const Text('• Rahmad Supandi',
                        style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 6),
                    _buildLinkButton(
                      context,
                      icon: FontAwesomeIcons.instagram,
                      label: 'Instagram',
                      url: 'https://instagram.com/siorxplane',
                      compact: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildAboutCard(
                color: cardColor,
                borderColor: borderColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAboutItem(
                      icon: Icons.code_rounded,
                      title: 'Kontributor Fitur',
                      titleColor: subtitleColor,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Ahmad Dandi Subhani',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fitur Cari Dosen (Data & API)',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildLinkButton(
                          context,
                          icon: FontAwesomeIcons.github,
                          label: 'GitHub',
                          url: 'https://github.com/dandiedutech',
                          compact: true,
                        ),
                        const SizedBox(width: 8),
                        _buildLinkButton(
                          context,
                          icon: FontAwesomeIcons.instagram,
                          label: 'Instagram',
                          url: 'https://instagram.com/dandisubhani_',
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard({
    required Widget child,
    required Color color,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _buildAboutItem({
    required IconData icon,
    required String title,
    required Color titleColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: titleColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: titleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String url,
    bool compact = false,
  }) {
    return InkWell(
      onTap: () async {
        try {
          final uri = Uri.parse(url);
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tidak dapat membuka link: $url'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Tooltip(
          message: label,
          child:
              Icon(icon, color: Colors.blue.shade700, size: compact ? 18 : 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryTextColor = Color(0xFF111827);
    const Color secondaryTextColor = Color(0xFF4B5563);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF073163),
        iconTheme: const IconThemeData(color: Color(0xFF073163)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF073163)),
            onPressed: _isLoading ? null : _loadLoginData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF073163)),
            onPressed: _showAboutDialog,
            tooltip: 'Tentang Aplikasi',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading && _loginFormData == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SpinKitFadingCircle(
                      color: Color(0xFF073163),
                      size: 50.0,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Memuat halaman login...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : _errorMessage != null && _loginFormData == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Gagal Memuat',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadLoginData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF073163),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 40),
                          Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/icon.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'LMS UNINDRA',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF073163),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Login ${widget.userRole.displayName}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF1756A5),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Learning Management System',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style:
                                          TextStyle(color: Colors.red.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(color: primaryTextColor),
                            cursorColor: Color(0xFF073163),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle:
                                  const TextStyle(color: secondaryTextColor),
                              floatingLabelStyle:
                                  const TextStyle(color: Color(0xFF073163)),
                              prefixIcon: const Icon(
                                Icons.person,
                                color: secondaryTextColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF073163), width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Username tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: primaryTextColor),
                            cursorColor: Color(0xFF073163),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle:
                                  const TextStyle(color: secondaryTextColor),
                              floatingLabelStyle:
                                  const TextStyle(color: Color(0xFF073163)),
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: secondaryTextColor,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: secondaryTextColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF073163), width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                                activeColor: const Color(0xFF073163),
                                checkColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFF6B7280),
                                  width: 1.3,
                                ),
                              ),
                              const Text(
                                'Remember me',
                                style: TextStyle(color: primaryTextColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
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
                                      'Log In',
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
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Lupa Password?',
                                style: TextStyle(
                                  color: Color(0xFF073163),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            '© ${DateTime.now().year} LMS UNINDRA',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
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
