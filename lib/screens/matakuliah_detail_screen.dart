import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MataKuliahDetailScreen extends StatelessWidget {
  final String namaMataKuliah;
  final String kodeMataKuliah;
  final String kelas;
  final String semester;
  final String sks;
  final String dosenPengampu;
  final String? nomorHpDosen;
  final String? fotoDosen;
  final String? ruang;
  final String? waktu;

  const MataKuliahDetailScreen({
    super.key,
    required this.namaMataKuliah,
    required this.kodeMataKuliah,
    required this.kelas,
    required this.semester,
    required this.sks,
    required this.dosenPengampu,
    this.nomorHpDosen,
    this.fotoDosen,
    this.ruang,
    this.waktu,
  });

  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleaned.startsWith('08')) {
      cleaned = '62${cleaned.substring(1)}';
    }
    else if (cleaned.startsWith('+62')) {
      cleaned = cleaned.substring(1);
    }
    else if (cleaned.startsWith('8') && !cleaned.startsWith('62')) {
      cleaned = '62$cleaned';
    }
    
    return cleaned;
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    if (nomorHpDosen == null || nomorHpDosen!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor HP dosen tidak tersedia'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final formattedNumber = _formatPhoneNumber(nomorHpDosen!);
      final whatsappUrl = 'https://wa.me/$formattedNumber';
      final uri = Uri.parse(whatsappUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka WhatsApp'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
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
      appBar: AppBar(
        title: const Text('Detail Mata Kuliah'),
        backgroundColor: const Color(0xFF073163),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      kodeMataKuliah,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    namaMataKuliah,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildHeaderChip(Icons.class_, kelas),
                      if (ruang != null && ruang!.isNotEmpty) ...[  
                        const SizedBox(width: 8),
                        _buildHeaderChip(Icons.room, ruang!),
                      ],
                      if (waktu != null && waktu!.isNotEmpty) ...[  
                        const SizedBox(width: 8),
                        _buildHeaderChip(Icons.schedule, waktu!),
                      ],
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              fotoDosen != null && fotoDosen!.isNotEmpty
                                ? CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.grey[300],
                                    child: ClipOval(
                                      child: Image.network(
                                        fotoDosen!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(Icons.person, size: 28, color: Color(0xFF073163));
                                        },
                                      ),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF073163).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Color(0xFF073163),
                                      size: 28,
                                    ),
                                  ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Dosen Pengampu',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dosenPengampu,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (nomorHpDosen != null && nomorHpDosen!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        nomorHpDosen!,
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
                          if (nomorHpDosen != null && nomorHpDosen!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _openWhatsApp(context),
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
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _buildInfoCard(
                        icon: Icons.meeting_room,
                        title: 'Kelas',
                        value: kelas,
                        color: Colors.blue,
                      ),
                      if (ruang != null && ruang!.isNotEmpty)
                        _buildInfoCard(
                          icon: Icons.room,
                          title: 'Ruang Kelas',
                          value: ruang!,
                          color: Colors.green,
                        )
                      else
                        _buildInfoCard(
                          icon: Icons.room,
                          title: 'Ruang Kelas',
                          value: '-',
                          color: Colors.green,
                        ),
                      if (waktu != null && waktu!.isNotEmpty)
                        _buildInfoCard(
                          icon: Icons.schedule,
                          title: 'Waktu',
                          value: waktu!,
                          color: Colors.orange,
                        )
                      else
                        _buildInfoCard(
                          icon: Icons.schedule,
                          title: 'Waktu',
                          value: '-',
                          color: Colors.orange,
                        ),
                      _buildInfoCard(
                        icon: Icons.code,
                        title: 'Kode MK',
                        value: kodeMataKuliah,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
