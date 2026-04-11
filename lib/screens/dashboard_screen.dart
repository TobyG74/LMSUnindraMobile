import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/user_role_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'login_role_selector_screen.dart';
import 'jadwal_screen.dart';
import 'dosen/presensi_dosen_screen.dart';
import 'dosen/nilai_dosen_screen.dart';
import 'dosen/laporan_dosen_screen.dart';
import 'mahasiswa/presensi_mahasiswa_screen.dart';
import 'profile_screen.dart';
import 'matakuliah_screen.dart';
import 'mahasiswa_search_screen.dart';
import 'dosen_search_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  String? _userName;
  String? _userPhotoUrl;
  bool _isLoadingUserData = true;
  bool _animateCards = false;
  int _newMeetingCount = 0;
  Set<String> _newMeetingLinks = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkForUpdates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _animateCards = true;
        });
      }
    });
  }

  Future<void> _checkForUpdates() async {
    await Future.delayed(const Duration(seconds: 2));

    final updateService = UpdateService();

    final shouldCheck = await updateService.shouldCheckUpdate();
    if (!shouldCheck) return;

    final updateInfo = await updateService.checkForUpdate();
    if (updateInfo != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: !updateInfo.updateRequired,
        builder: (context) => UpdateDialog(updateInfo: updateInfo),
      );
    }
  }

  Future<void> _loadUserData() async {
    try {
      final html = await _apiService.fetchDashboardPage();
      final document = html_parser.parse(html);

      final userHeader = document.querySelector('li.user-header');
      if (userHeader != null) {
        final pTag = userHeader.querySelector('p');
        if (pTag != null) {
          _userName = pTag.text.trim();
        }

        final imgTag = userHeader.querySelector('img.img-circle');
        if (imgTag != null) {
          _userPhotoUrl = imgTag.attributes['src'];
        }
      }

      // Count new (unread) pertemuan — only relevant for mahasiswa.
      try {
        final role =
            Provider.of<AuthService>(context, listen: false).currentUserRole;
        if (role == UserRole.mahasiswa) {
          final allLinks = document
              .querySelectorAll('a[href*="pertemuan/pke/"]')
              .map((a) {
                final href = a.attributes['href'] ?? '';
                final m = RegExp(r'pertemuan/pke/(.+)$').firstMatch(href);
                return m?.group(1) ?? '';
              })
              .where((s) => s.isNotEmpty)
              .toSet();

          final prefs = await SharedPreferences.getInstance();
          final opened =
              (prefs.getStringList('opened_pertemuan') ?? []).toSet();
          final newLinks = allLinks.difference(opened);
          _newMeetingCount = newLinks.length;
          _newMeetingLinks = newLinks;
        }
      } catch (_) {
        // Non-critical — ignore errors in new-meeting count.
      }

      setState(() {
        _isLoadingUserData = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  void _showAboutDialog(BuildContext context) {
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

  static Widget _buildAboutCard({
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

  static Widget _buildAboutItem({
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

  static Widget _buildLinkButton(
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

  Widget _buildNewMeetingBanner(
      BuildContext context, int count, bool isDark) {
    final bgColor =
        isDark ? const Color(0xFF0F2033) : const Color(0xFFEEF5FF);
    final borderColor =
        isDark ? const Color(0xFF1E3A5F) : const Color(0xFFBDD5F8);
    final textColor =
        isDark ? const Color(0xFF90C2FF) : const Color(0xFF0A52A8);
    final subtitleColor =
        isDark ? const Color(0xFF6A9FCF) : const Color(0xFF4070B0);

    return GestureDetector(
      onTap: () async {
        // Mark all current new pertemuan as seen so banner disappears
        final prefs = await SharedPreferences.getInstance();
        final opened = (prefs.getStringList('opened_pertemuan') ?? []).toSet();
        opened.addAll(_newMeetingLinks);
        await prefs.setStringList('opened_pertemuan', opened.toList());
        if (mounted) {
          setState(() {
            _newMeetingCount = 0;
            _newMeetingLinks = {};
          });
        }
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const JadwalScreen(),
            ),
          );
        }
      },
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        offset: _animateCards ? Offset.zero : const Offset(0, -0.1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
          opacity: _animateCards ? 1 : 0,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    size: 20,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count Pertemuan Baru Tersedia',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ketuk untuk melihat mata kuliah',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: subtitleColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthService>().currentUserRole;
    final isDosen = role == UserRole.dosen;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF0E1320) : const Color(0xFFF2F6FC);
    final sectionTitleColor =
        isDark ? const Color(0xFFE6EEF8) : const Color(0xFF0A2A57);

    final now = DateTime.now();
    final weekDays = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final formattedDate =
        '${weekDays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF0A2A57),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0A2A57),
                      const Color(0xFF0F4A96),
                      Colors.lightBlue.shade600,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -80,
                      right: -50,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.14),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -90,
                      left: -70,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                    ),
                    _isLoadingUserData
                        ? const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          )
                        : SafeArea(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 62, 20, 18),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              blurRadius: 10,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: _userPhotoUrl != null &&
                                                _userPhotoUrl!.isNotEmpty &&
                                                _userPhotoUrl!
                                                    .startsWith('http')
                                            ? CircleAvatar(
                                                radius: 32,
                                                backgroundColor: Colors.white,
                                                child: ClipOval(
                                                  child: Image.network(
                                                    _userPhotoUrl!,
                                                    width: 64,
                                                    height: 64,
                                                    fit: BoxFit.cover,
                                                    loadingBuilder: (context,
                                                        child,
                                                        loadingProgress) {
                                                      if (loadingProgress ==
                                                          null) {
                                                        return child;
                                                      }
                                                      return const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                      Color>(
                                                                  Color(
                                                                      0xFF0A2A57)),
                                                        ),
                                                      );
                                                    },
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return const Icon(
                                                        Icons.person,
                                                        size: 38,
                                                        color:
                                                            Color(0xFF0A2A57),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              )
                                            : const CircleAvatar(
                                                radius: 32,
                                                backgroundColor: Colors.white,
                                                child: Icon(
                                                  Icons.person,
                                                  size: 36,
                                                  color: Color(0xFF0A2A57),
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Selamat datang kembali',
                                              style: TextStyle(
                                                fontSize: 13,
                                                letterSpacing: 0.2,
                                                color: Colors.white
                                                    .withOpacity(0.92),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              (_userName?.isNotEmpty ?? false)
                                                  ? _userName!
                                                  : (isDosen
                                                      ? 'Dosen'
                                                      : 'Mahasiswa'),
                                              style: const TextStyle(
                                                fontSize: 21,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                height: 1.1,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.25),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            formattedDate,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white),
                onPressed: () => _showAboutDialog(context),
                tooltip: 'Tentang',
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async {
                  final authService =
                      Provider.of<AuthService>(context, listen: false);
                  await authService.logout();

                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const LoginRoleSelectorScreen(),
                      ),
                    );
                  }
                },
                tooltip: 'Keluar',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if (!isDosen && _newMeetingCount > 0) ...[
                    _buildNewMeetingBanner(
                        context, _newMeetingCount, isDark),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: sectionTitleColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Akses Cepat',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: sectionTitleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.45,
                    children: isDosen
                        ? _buildDosenMenuCards(context)
                        : _buildMahasiswaMenuCards(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    final duration = Duration(milliseconds: 380 + (index * 80));
    final accentColor = gradient.colors.first;
    final cardBackground = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF152035)
        : Colors.white;

    return AnimatedSlide(
      duration: duration,
      curve: Curves.easeOutCubic,
      offset: _animateCards ? Offset.zero : const Offset(0, 0.12),
      child: AnimatedOpacity(
        duration: duration,
        curve: Curves.easeOut,
        opacity: _animateCards ? 1 : 0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                color: cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accentColor.withOpacity(0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMahasiswaMenuCards(BuildContext context) {
    return [
      _buildMenuCard(
        context,
        index: 0,
        icon: Icons.book_rounded,
        title: 'Mata Kuliah',
        subtitle: 'Lihat daftar kelas',
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const MataKuliahScreen(),
            ),
          );
        },
      ),
      _buildMenuCard(
        context,
        index: 1,
        icon: Icons.calendar_month_rounded,
        title: 'Jadwal',
        subtitle: 'Agenda perkuliahan',
        gradient: const LinearGradient(
          colors: [Color(0xFF009688), Color(0xFF00796B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const JadwalScreen(),
            ),
          );
        },
      ),
      _buildMenuCard(
        context,
        index: 2,
        icon: Icons.how_to_reg_rounded,
        title: 'Presensi',
        subtitle: 'Cek kehadiran',
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFF57C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PresensiMahasiswaScreen(),
            ),
          );
        },
      ),
      _buildMenuCard(
        context,
        index: 3,
        icon: Icons.person_rounded,
        title: 'Profil',
        subtitle: 'Informasi akun',
        gradient: const LinearGradient(
          colors: [Color(0xFF455A64), Color(0xFF263238)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ProfileScreen(),
            ),
          );
        },
      ),
      _buildMenuCard(
        context,
        index: 4,
        icon: Icons.search_rounded,
        title: 'Cari Mhs',
        subtitle: 'Database PDDIKTI',
        gradient: const LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const MahasiswaSearchScreen(),
            ),
          );
        },
      ),
      _buildMenuCard(
        context,
        index: 5,
        icon: Icons.person_search_rounded,
        title: 'Cari Dosen',
        subtitle: 'SIMPEG UNINDRA',
        gradient: const LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const DosenSearchScreen(),
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _buildDosenMenuCards(BuildContext context) {
    return [
      _buildMenuCard(
        context,
        index: 0,
        icon: Icons.book_rounded,
        title: 'Mata Kuliah',
        subtitle: 'Daftar kelas ajar',
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const MataKuliahScreen(),
            ),
          );
        },
      ),
      _buildMenuCard(
        context,
        index: 1,
        icon: Icons.grading_rounded,
        title: 'Nilai',
        subtitle: 'Penilaian per kelas',
        gradient: const LinearGradient(
          colors: [Color(0xFF5E35B1), Color(0xFF4527A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const NilaiDosenScreen(),
            ),
          );
        },
      ),
      _buildMenuCard(
        context,
        index: 2,
        icon: Icons.how_to_reg_rounded,
        title: 'Presensi',
        subtitle: 'Input kehadiran kelas',
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFF57C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PresensiDosenScreen(
                headerTitle: 'Presensi Dosen',
                headerIcon: Icons.how_to_reg_rounded,
              ),
            ),
          );
        },
      ),
      _buildMenuCard(
        context,
        index: 3,
        icon: Icons.fact_check_rounded,
        title: 'Laporan Kuliah',
        subtitle: 'Realisasi pertemuan',
        gradient: const LinearGradient(
          colors: [Color(0xFF8E24AA), Color(0xFF6A1B9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const LaporanDosenScreen(),
            ),
          );
        },
      ),
      _buildMenuCard(
        context,
        index: 4,
        icon: Icons.calendar_month_rounded,
        title: 'Jadwal',
        subtitle: 'Agenda mengajar',
        gradient: const LinearGradient(
          colors: [Color(0xFF009688), Color(0xFF00796B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const JadwalScreen(),
            ),
          );
        },
      ),
      _buildMenuCard(
        context,
        index: 5,
        icon: Icons.person_rounded,
        title: 'Profil',
        subtitle: 'Informasi akun',
        gradient: const LinearGradient(
          colors: [Color(0xFF455A64), Color(0xFF263238)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ProfileScreen(),
            ),
          );
        },
      ),
      _buildMenuCard(
        context,
        index: 6,
        icon: Icons.search_rounded,
        title: 'Cari Mhs',
        subtitle: 'Database PDDIKTI',
        gradient: const LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const MahasiswaSearchScreen(),
            ),
          );
        },
      ),
      _buildMenuCard(
        context,
        index: 7,
        icon: Icons.person_search_rounded,
        title: 'Cari Dosen',
        subtitle: 'SIMPEG UNINDRA',
        gradient: const LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const DosenSearchScreen(),
            ),
          );
        },
      ),
    ];
  }
}
