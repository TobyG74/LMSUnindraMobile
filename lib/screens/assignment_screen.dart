import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class AssignmentScreen extends StatefulWidget {
  final String encryptedUrl;
  final String title;

  const AssignmentScreen({
    super.key,
    required this.encryptedUrl,
    required this.title,
  });

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;
  bool _isUploading = false;
  bool _hasReminder1Hour = false;
  bool _hasReminder30Min = false;

  Map<String, dynamic>? _assignmentData;
  File? _selectedFile;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    _loadAssignmentDetail();
    _loadReminderStatus();
  }

  Future<void> _loadReminderStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final key1h = 'reminder_1h_${widget.encryptedUrl}';
    final key30m = 'reminder_30m_${widget.encryptedUrl}';
    setState(() {
      _hasReminder1Hour = prefs.getBool(key1h) ?? false;
      _hasReminder30Min = prefs.getBool(key30m) ?? false;
    });
  }

  DateTime? _parseDeadline(String? deadlineStr) {
    if (deadlineStr == null || deadlineStr.isEmpty || deadlineStr == '-') {
      return null;
    }

    try {
      final str = deadlineStr.trim();

      // Map bulan (nama Indonesia penuh + singkatan Inggris) ke angka
      const months = {
        // Indonesia
        'Januari': 1,
        'Februari': 2,
        'Maret': 3,
        'April': 4,
        'Mei': 5,
        'Juni': 6,
        'Juli': 7,
        'Agustus': 8,
        'September': 9,
        'Oktober': 10,
        'November': 11,
        'Desember': 12,
        // Inggris singkat (dari LMS)
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12,
      };

      // Cari pola tanggal: "20 Januari 2026"
      final dateRegex = RegExp(r'(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})');
      final dateMatch = dateRegex.firstMatch(str);
      if (dateMatch == null) return null;

      final day = int.tryParse(dateMatch.group(1)!);
      final monthName = dateMatch.group(2)!;
      final year = int.tryParse(dateMatch.group(3)!);

      if (day == null || year == null) return null;

      final month = months[monthName];
      if (month == null) return null;

      // Cari pola waktu: "23:59" atau "23.59" setelah tanggal
      final afterDate = str.substring(dateMatch.end);
      final timeRegex = RegExp(r'(\d{1,2})[:\.](\d{2})');
      final timeMatch = timeRegex.firstMatch(afterDate);

      if (timeMatch == null) return null;

      final hour = int.tryParse(timeMatch.group(1)!);
      final minute = int.tryParse(timeMatch.group(2)!);

      if (hour == null || minute == null) return null;

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  Future<void> _scheduleReminder(int minutesBefore) async {
    final deadline = _parseDeadline(_assignmentData?['deadline']);
    if (deadline == null) {
      _showSnackBar('Format deadline tidak valid');
      return;
    }

    final now = DateTime.now();
    final reminderTime = deadline.subtract(Duration(minutes: minutesBefore));

    if (reminderTime.isBefore(now)) {
      _showSnackBar('Waktu pengingat sudah terlewat');
      return;
    }

    final hasPermission = await _notificationService.requestPermission();
    if (!hasPermission) {
      _showSnackBar('Izin notifikasi ditolak');
      return;
    }

    final notificationId = '${widget.encryptedUrl}_${minutesBefore}'.hashCode;

    await _notificationService.scheduleAssignmentReminder(
      id: notificationId,
      title: 'Pengingat Tugas: ${widget.title}',
      body: minutesBefore == 60
          ? 'Tugas akan berakhir 1 jam lagi!'
          : 'Tugas akan berakhir 30 menit lagi!',
      scheduledTime: reminderTime,
    );

    // Save reminder status
    final prefs = await SharedPreferences.getInstance();
    final key = minutesBefore == 60
        ? 'reminder_1h_${widget.encryptedUrl}'
        : 'reminder_30m_${widget.encryptedUrl}';
    await prefs.setBool(key, true);

    setState(() {
      if (minutesBefore == 60) {
        _hasReminder1Hour = true;
      } else {
        _hasReminder30Min = true;
      }
    });

    final timeStr = minutesBefore == 60 ? '1 jam' : '30 menit';
    _showSnackBar('Pengingat $timeStr sebelum deadline berhasil diatur');
  }

  Future<void> _cancelReminder(int minutesBefore) async {
    final notificationId = '${widget.encryptedUrl}_${minutesBefore}'.hashCode;
    await _notificationService.cancelNotification(notificationId);

    // Remove from preferences
    final prefs = await SharedPreferences.getInstance();
    final key = minutesBefore == 60
        ? 'reminder_1h_${widget.encryptedUrl}'
        : 'reminder_30m_${widget.encryptedUrl}';
    await prefs.remove(key);

    setState(() {
      if (minutesBefore == 60) {
        _hasReminder1Hour = false;
      } else {
        _hasReminder30Min = false;
      }
    });

    final timeStr = minutesBefore == 60 ? '1 jam' : '30 menit';
    _showSnackBar('Pengingat $timeStr dibatalkan');
  }

  Future<void> _loadAssignmentDetail() async {
    setState(() => _isLoading = true);

    try {
      final data = await _apiService.fetchAssignmentDetail(widget.encryptedUrl);
      setState(() {
        _assignmentData = data;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e');
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _selectedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      _showSnackBar('Error memilih file: $e');
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) {
      _showSnackBar('Pilih file terlebih dahulu');
      return;
    }

    if (_assignmentData == null || _assignmentData!['tokens'] == null) {
      _showSnackBar('Data assignment tidak lengkap');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final tokens = _assignmentData!['tokens'] as Map<String, dynamic>;
      final result = await _apiService.uploadAssignment(
        tokens: tokens,
        filePath: _selectedFile!.path,
        fileName: _selectedFileName!,
      );

      if (mounted) {
        _showSnackBar(result ?? 'File berhasil diupload');
        // Reload data setelah upload
        await _loadAssignmentDetail();
        setState(() {
          _selectedFile = null;
          _selectedFileName = null;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error upload: $e');
      }
    }

    setState(() => _isUploading = false);
  }

  Future<void> _downloadAssignmentFile() async {
    if (_assignmentData == null ||
        _assignmentData!['assignment_file_param'] == null) {
      _showSnackBar('File tugas tidak tersedia');
      return;
    }

    try {
      final fileParam = _assignmentData!['assignment_file_param'];
      final url =
          Uri.parse('${ApiService.baseUrl}/member_tugas/lihat_pdf/$fileParam');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Tidak dapat membuka file');
      }
    } catch (e) {
      _showSnackBar('Error membuka file: $e');
    }
  }

  bool _isDeadlinePassed() {
    if (_assignmentData == null) return false;
    final remaining =
        (_assignmentData!['remaining'] ?? '').toString().toLowerCase();

    if (remaining.isEmpty || remaining == '-') return true;

    if (remaining.contains('lewat') ||
        remaining.contains('tutup') ||
        remaining.contains('telah') ||
        remaining.contains('berakhir') ||
        remaining.contains('habis') ||
        remaining.contains('expired') ||
        remaining.contains('melewati')) {
      return true;
    }

    if (remaining.contains('-') && RegExp(r'-\s*\d').hasMatch(remaining)) {
      return true;
    }

    return false;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_rounded,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  child: Center(child: CircularProgressIndicator()),
                )
              : _assignmentData == null
                  ? const SliverFillRemaining(
                      child: Center(
                          child: Text('Data assignment tidak ditemukan')),
                    )
                  : SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Detail Tugas Section
                            if (_assignmentData!['assignment_title'] != null ||
                                _assignmentData!['description'] != null ||
                                _assignmentData!['assignment_file_name'] !=
                                    null) ...[
                              Card(
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.description,
                                              color: Colors.blue.shade700,
                                              size: 28),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Text(
                                              'Detail Tugas',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Judul Tugas
                                      if (_assignmentData![
                                              'assignment_title'] !=
                                          null) ...[
                                        const SizedBox(height: 16),
                                        Text(
                                          _assignmentData!['assignment_title'],
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],

                                      // Deskripsi
                                      if (_assignmentData!['description'] !=
                                          null) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          _assignmentData!['description'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],

                                      // File Tugas
                                      if (_assignmentData![
                                              'assignment_file_name'] !=
                                          null) ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.blue.shade200),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.picture_as_pdf,
                                                  color: Colors.red.shade700,
                                                  size: 32),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'File Tugas',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black54,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _assignmentData![
                                                          'assignment_file_name'],
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton.icon(
                                                onPressed:
                                                    _downloadAssignmentFile,
                                                icon: const Icon(Icons.download,
                                                    size: 18),
                                                label: const Text('Buka'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 10),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Status Submit Section
                            Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.assignment,
                                            color: Colors.green.shade700,
                                            size: 28),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Status Submit',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildInfoRow('Status Submit',
                                        _assignmentData!['status'] ?? '-'),
                                    const Divider(height: 24),
                                    _buildInfoRow('Akhir Submit',
                                        _assignmentData!['deadline'] ?? '-'),
                                    const Divider(height: 24),
                                    _buildInfoRow('Sisa Waktu',
                                        _assignmentData!['remaining'] ?? '-'),
                                    const Divider(height: 24),
                                    _buildInfoRow(
                                        'File Upload',
                                        _assignmentData!['file_uploaded'] ??
                                            '-'),
                                    if (_assignmentData!['upload_time'] !=
                                            null &&
                                        _assignmentData!['upload_time'] !=
                                            '-') ...[
                                      const Divider(height: 24),
                                      _buildInfoRow(
                                          'Waktu Upload',
                                          _assignmentData!['upload_time'] ??
                                              '-'),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Reminder Section
                            if (!_isDeadlinePassed()) ...[
                              Card(
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.notifications_active,
                                              color: Colors.purple.shade700,
                                              size: 28),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Pengingat Deadline',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Atur pengingat untuk deadline tugas ini:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Tombol Ingatkan 1 Jam
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _hasReminder1Hour
                                              ? () => _cancelReminder(60)
                                              : () => _scheduleReminder(60),
                                          icon: Icon(_hasReminder1Hour
                                              ? Icons.notifications_off
                                              : Icons.notifications),
                                          label: Text(_hasReminder1Hour
                                              ? 'Batalkan Pengingat 1 Jam'
                                              : 'Ingatkan Saya 1 Jam Sebelumnya'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _hasReminder1Hour
                                                ? Colors.grey
                                                : Colors.purple,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Tombol Ingatkan 30 Menit
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _hasReminder30Min
                                              ? () => _cancelReminder(30)
                                              : () => _scheduleReminder(30),
                                          icon: Icon(_hasReminder30Min
                                              ? Icons.notifications_off
                                              : Icons.notifications),
                                          label: Text(_hasReminder30Min
                                              ? 'Batalkan Pengingat 30 Menit'
                                              : 'Ingatkan Saya 30 Menit Sebelumnya'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _hasReminder30Min
                                                ? Colors.grey
                                                : Colors.deepPurple,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Upload Section
                            Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.upload_file,
                                            color: Colors.orange.shade700,
                                            size: 28),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Upload File',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // File selected info
                                    if (_selectedFileName != null) ...[
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.green.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.check_circle,
                                                color: Colors.green.shade700),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _selectedFileName!,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close),
                                              onPressed: _isDeadlinePassed()
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        _selectedFile = null;
                                                        _selectedFileName =
                                                            null;
                                                      });
                                                    },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // Warning pas deadline udah lewat
                                    if (_isDeadlinePassed()) ...[
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.red.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.warning,
                                                color: Colors.red.shade700),
                                            const SizedBox(width: 12),
                                            const Expanded(
                                              child: Text(
                                                'Waktu pengumpulan telah berakhir',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // Pick file button
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed:
                                            _isUploading || _isDeadlinePassed()
                                                ? null
                                                : _pickFile,
                                        icon: const Icon(Icons.folder_open),
                                        label: const Text('Pilih File'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Upload button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _isUploading ||
                                                _selectedFile == null ||
                                                _isDeadlinePassed()
                                            ? null
                                            : _uploadFile,
                                        icon: _isUploading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(Icons.cloud_upload),
                                        label: Text(_isUploading
                                            ? 'Mengupload...'
                                            : 'Upload File'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                        ),
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
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const Text(': '),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
