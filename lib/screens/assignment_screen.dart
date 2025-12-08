import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

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
  bool _isLoading = true;
  bool _isUploading = false;
  
  Map<String, dynamic>? _assignmentData;
  File? _selectedFile;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    _loadAssignmentDetail();
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

  bool _isDeadlinePassed() {
    if (_assignmentData == null) return false;
    final remaining = (_assignmentData!['remaining'] ?? '').toString().toLowerCase();
    
    // Cek berbagai kemungkinan indikator deadline lewat
    if (remaining.isEmpty || remaining == '-') return true;
    
    // Cek kata kunci bahwa deadline sudah lewat
    if (remaining.contains('lewat') || 
        remaining.contains('tutup') ||
        remaining.contains('telah') ||
        remaining.contains('berakhir') ||
        remaining.contains('habis') ||
        remaining.contains('expired') ||
        remaining.contains('melewati')) {
      return true;
    }
    
    // Cek jika ada angka negatif (misalnya "-5 hari")
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
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF073163),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignmentData == null
              ? const Center(child: Text('Data assignment tidak ditemukan'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.assignment, color: Colors.blue.shade700, size: 28),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Informasi Tugas',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow('Status Submit', _assignmentData!['status'] ?? '-'),
                              const Divider(height: 24),
                              _buildInfoRow('Akhir Submit', _assignmentData!['deadline'] ?? '-'),
                              const Divider(height: 24),
                              _buildInfoRow('Sisa Waktu', _assignmentData!['remaining'] ?? '-'),
                              const Divider(height: 24),
                              _buildInfoRow('File Upload', _assignmentData!['file_uploaded'] ?? '-'),
                              if (_assignmentData!['upload_time'] != null && _assignmentData!['upload_time'] != '-') ...[
                                const Divider(height: 24),
                                _buildInfoRow('Waktu Upload', _assignmentData!['upload_time'] ?? '-'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
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
                                  Icon(Icons.upload_file, color: Colors.orange.shade700, size: 28),
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
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green.shade700),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _selectedFileName!,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: _isDeadlinePassed() ? null : () {
                                          setState(() {
                                            _selectedFile = null;
                                            _selectedFileName = null;
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
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning, color: Colors.red.shade700),
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
                                  onPressed: _isUploading || _isDeadlinePassed() ? null : _pickFile,
                                  icon: const Icon(Icons.folder_open),
                                  label: const Text('Pilih File'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Upload button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isUploading || _selectedFile == null || _isDeadlinePassed()
                                      ? null
                                      : _uploadFile,
                                  icon: _isUploading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.cloud_upload),
                                  label: Text(_isUploading ? 'Mengupload...' : 'Upload File'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
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
