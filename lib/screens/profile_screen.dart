import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/api_service.dart';
import '../models/profile_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  
  final _hpController = TextEditingController();
  final _gmailController = TextEditingController();
  
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isSavingPassword = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  
  ProfileData? _profileData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _apiService.fetchProfile();
      setState(() {
        _profileData = profile;
        _hpController.text = profile.phone;
        _gmailController.text = profile.email;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat profil: $e';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_hpController.text.isEmpty || _gmailController.text.isEmpty) {
      _showSnackBar('HP dan Email tidak boleh kosong', isError: true);
      return;
    }

    setState(() => _isSavingProfile = true);

    try {
      final result = await _apiService.updateProfile(
        phone: _hpController.text,
        email: _gmailController.text,
      );

      setState(() => _isSavingProfile = false);

      if (result['success']) {
        _showSnackBar('Profil berhasil diperbarui');
        await _loadProfile();
      } else {
        _showSnackBar(result['message'] ?? 'Gagal memperbarui profil', isError: true);
      }
    } catch (e) {
      setState(() => _isSavingProfile = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _changePassword() async {
    if (_oldPasswordController.text.isEmpty) {
      _showSnackBar('Password lama tidak boleh kosong', isError: true);
      return;
    }
    if (_newPasswordController.text.isEmpty) {
      _showSnackBar('Password baru tidak boleh kosong', isError: true);
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('Password baru tidak cocok', isError: true);
      return;
    }

    setState(() => _isSavingPassword = true);

    try {
      final result = await _apiService.changePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      setState(() => _isSavingPassword = false);

      if (result['success']) {
        _showSnackBar('Password berhasil diubah');
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        _showSnackBar(result['message'] ?? 'Gagal mengubah password', isError: true);
      }
    } catch (e) {
      setState(() => _isSavingPassword = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hpController.dispose();
    _gmailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 40,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF073163),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 0, bottom: 15),
              title: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Profil',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF073163), Color(0xFF1756a5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(
                    child: SpinKitFadingCircle(
                      color: Color(0xFF073163),
                      size: 50.0,
                    ),
                  ),
                )
              : _errorMessage != null
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red,
                                size: 64,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Gagal memuat profil',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: _loadProfile,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Coba Lagi'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF073163),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
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
                  : SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _isLoading ? Container() : _buildProfileContent(),
                        ]),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return _isLoading
          ? const Center(
              child: SpinKitFadingCircle(
                color: Color(0xFF073163),
                size: 50.0,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProfile,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF073163),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: _profileData?.photoUrl != null && _profileData!.photoUrl!.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      _profileData!.photoUrl!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(Icons.person, size: 50, color: Color(0xFF073163));
                                      },
                                    ),
                                  )
                                : const Icon(Icons.person, size: 50, color: Color(0xFF073163)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _profileData?.name ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Username: ${_profileData?.username ?? ''}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildInfoChip(
                                icon: Icons.school,
                                label: _profileData?.userType ?? 'Mahasiswa',
                              ),
                              const SizedBox(width: 8),
                              _buildInfoChip(
                                icon: Icons.access_time,
                                label: _profileData?.lastVisit ?? '',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF073163),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF073163),
                        tabs: const [
                          Tab(text: 'Profil'),
                          Tab(text: 'Ubah Password'),
                        ],
                      ),
                    ),
                    
                    SizedBox(
                      height: 500,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildProfileTab(),
                          _buildPasswordTab(),
                        ],
                      ),
                    ),
                  ],
                );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _hpController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Nomor HP',
              prefixIcon: const Icon(Icons.phone),
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
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _gmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Gmail',
              prefixIcon: const Icon(Icons.email),
              hintText: 'nama@gmail.com',
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
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSavingProfile ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF073163),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isSavingProfile
                  ? const SpinKitThreeBounce(
                      color: Colors.white,
                      size: 20,
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save),
                        SizedBox(width: 8),
                        Text(
                          'Simpan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _oldPasswordController,
            obscureText: _obscureOldPassword,
            decoration: InputDecoration(
              labelText: 'Password Lama',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureOldPassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _obscureOldPassword = !_obscureOldPassword);
                },
              ),
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
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            decoration: InputDecoration(
              labelText: 'Password Baru',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _obscureNewPassword = !_obscureNewPassword);
                },
              ),
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
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Ulangi Password Baru',
              prefixIcon: const Icon(Icons.lock_reset),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
              ),
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
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSavingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF073163),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isSavingPassword
                  ? const SpinKitThreeBounce(
                      color: Colors.white,
                      size: 20,
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save),
                        SizedBox(width: 8),
                        Text(
                          'Simpan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
