import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/dosen_detail_model.dart';
import '../services/api_service.dart';

class DosenDetailScreen extends StatefulWidget {
  final String kode;
  final String? nidn;

  const DosenDetailScreen({super.key, required this.kode, this.nidn});

  @override
  State<DosenDetailScreen> createState() => _DosenDetailScreenState();
}

class _DosenDetailScreenState extends State<DosenDetailScreen> {
  final ApiService _apiService = ApiService();
  DosenDetail? _dosenDetail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDosenDetail();
  }

  Future<void> _loadDosenDetail() async {
    try {
      final detail = await _apiService.getDosenDetail(widget.kode, nidn: widget.nidn);
      setState(() {
        _dosenDetail = detail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    String phone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (!phone.startsWith('62')) {
      if (phone.startsWith('0')) {
        phone = '62${phone.substring(1)}';
      } else {
        phone = '62$phone';
      }
    }

    final url = Uri.parse('https://wa.me/$phone');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka WhatsApp'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    'Detail Dosen',
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
          SliverToBoxAdapter(
            child: SingleChildScrollView(
        child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Gagal memuat data',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _loadDosenDetail,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Coba Lagi'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF073163),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF073163),
                                  const Color(0xFF073163).withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_dosenDetail!.nidn.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'NIDN: ${_dosenDetail!.nidn}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Text(
                                  _dosenDetail!.nama,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _buildHeaderChip(Icons.school, _dosenDetail!.prodi),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        _dosenDetail!.photoUrl != null
                                          ? CircleAvatar(
                                              radius: 40,
                                              backgroundColor: Colors.grey[300],
                                              child: ClipOval(
                                                child: Image.network(
                                                  _dosenDetail!.photoUrl!,
                                                  width: 80,
                                                  height: 80,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return const Icon(Icons.person, size: 40, color: Color(0xFF073163));
                                                  },
                                                ),
                                              ),
                                            )
                                          : Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF073163).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.person,
                                                color: Color(0xFF073163),
                                                size: 40,
                                              ),
                                            ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Dosen',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _dosenDetail!.nama,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (_dosenDetail!.ponsel != null && _dosenDetail!.ponsel!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  _dosenDetail!.ponsel!,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (_dosenDetail!.ponsel != null && _dosenDetail!.statusWa == 'Aktif') ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _launchWhatsApp(_dosenDetail!.ponsel!),
                                      icon: const Icon(Icons.chat, size: 20),
                                      label: const Text('Hubungi via WhatsApp'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF25D366),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),

                                GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.4,
                                  children: [
                                    _buildInfoCard(
                                      icon: Icons.school_rounded,
                                      title: 'Fakultas',
                                      value: _dosenDetail!.fakultas.isNotEmpty ? _dosenDetail!.fakultas : '-',
                                      color: Colors.blue,
                                    ),
                                    _buildInfoCard(
                                      icon: Icons.work_rounded,
                                      title: 'Jabatan',
                                      value: _dosenDetail!.jabatanFungsional.isNotEmpty ? _dosenDetail!.jabatanFungsional : '-',
                                      color: Colors.purple,
                                    ),
                                    _buildInfoCard(
                                      icon: Icons.badge_rounded,
                                      title: 'Status',
                                      value: _dosenDetail!.statusIkatanKerja.isNotEmpty ? _dosenDetail!.statusIkatanKerja : '-',
                                      color: Colors.orange,
                                    ),
                                    _buildInfoCard(
                                      icon: Icons.person_rounded,
                                      title: 'Jenis Kelamin',
                                      value: _dosenDetail!.jenisKelamin.isNotEmpty ? _dosenDetail!.jenisKelamin : '-',
                                      color: Colors.teal,
                                    ),
                                    _buildInfoCard(
                                      icon: Icons.school,
                                      title: 'Pendidikan',
                                      value: _dosenDetail!.pendidikanTerakhir.isNotEmpty ? _dosenDetail!.pendidikanTerakhir : '-',
                                      color: Colors.green,
                                    ),
                                  ],
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
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

}
