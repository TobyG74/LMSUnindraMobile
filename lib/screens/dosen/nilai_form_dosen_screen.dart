import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class NilaiFormDosenScreen extends StatefulWidget {
  final String formUrl;
  final String? title;

  const NilaiFormDosenScreen({
    super.key,
    required this.formUrl,
    this.title,
  });

  @override
  State<NilaiFormDosenScreen> createState() => _NilaiFormDosenScreenState();
}

class _NilaiFormDosenScreenState extends State<NilaiFormDosenScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  final Map<String, String> _classInfo = {};
  String _jenisLabel = 'Nilai';
  String _kdJdw = '';
  String _jenis = '';
  List<_NilaiEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final item in _entries) {
      item.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.fetchNilaiFormData(widget.formUrl);
      if (data == null) {
        setState(() {
          _errorMessage =
              'Form nilai tidak ditemukan. Silakan refresh halaman Nilai Kelas lalu coba lagi.';
          _isLoading = false;
        });
        return;
      }

      for (final item in _entries) {
        item.controller.dispose();
      }

      final classInfo = <String, String>{};
      final classInfoRaw = data['class_info'];
      if (classInfoRaw is Map) {
        classInfoRaw.forEach((key, value) {
          classInfo[key.toString()] = value.toString();
        });
      }

      final rows = <_NilaiEntry>[];
      final rowRaw = data['rows'];
      if (rowRaw is List) {
        for (final item in rowRaw) {
          if (item is! Map) continue;
          final nim = (item['nim'] ?? '').toString();
          if (nim.isEmpty) continue;

          rows.add(
            _NilaiEntry(
              nim: nim,
              nama: (item['nama'] ?? '').toString(),
              controller: TextEditingController(
                text: (item['nilai'] ?? '').toString(),
              ),
            ),
          );
        }
      }

      setState(() {
        _classInfo
          ..clear()
          ..addAll(classInfo);
        _entries = rows;
        _kdJdw = (data['h_kd_jdw'] ?? '').toString();
        _jenis = (data['h_jenis'] ?? '').toString();
        _jenisLabel = (data['jenis_label'] ?? 'Nilai').toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_kdJdw.isEmpty || _jenis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data form tidak lengkap.')),
      );
      return;
    }

    for (final item in _entries) {
      final raw = item.controller.text.trim();
      if (raw.isEmpty) continue;
      final value = int.tryParse(raw);
      if (value == null || value < 0 || value > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nilai ${item.nama} harus 0-100.')),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await _apiService.submitNilaiForm(
        kdJdw: _kdJdw,
        jenis: _jenis,
        entries: _entries
            .map(
              (e) => {
                'nim': e.nim,
                'nilai': e.controller.text.trim(),
              },
            )
            .toList(),
      );

      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan nilai.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Form Nilai'),
        backgroundColor: const Color(0xFF073163),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF073163), Color(0xFF1756A5)],
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
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_errorMessage!, textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  children: [
                    if (_classInfo.isNotEmpty)
                      Card(
                        margin: const EdgeInsets.all(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Form Nilai $_jenisLabel',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._classInfo.entries.map(
                                (e) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text('${e.key}: ${e.value}'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: _entries.isEmpty
                          ? const Center(
                              child: Text('Data mahasiswa tidak ditemukan.'),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _entries.length,
                              itemBuilder: (context, index) {
                                final item = _entries[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.nama,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item.nim,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 90,
                                          child: TextField(
                                            controller: item.controller,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              hintText: '0-100',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      bottomNavigationBar: _isLoading || _errorMessage != null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Nilai'),
              ),
            ),
    );
  }
}

class _NilaiEntry {
  final String nim;
  final String nama;
  final TextEditingController controller;

  _NilaiEntry({
    required this.nim,
    required this.nama,
    required this.controller,
  });
}
