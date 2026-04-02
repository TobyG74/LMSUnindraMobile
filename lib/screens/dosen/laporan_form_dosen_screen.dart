import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class LaporanFormDosenScreen extends StatefulWidget {
  final String editKode;

  const LaporanFormDosenScreen({
    super.key,
    required this.editKode,
  });

  @override
  State<LaporanFormDosenScreen> createState() => _LaporanFormDosenScreenState();
}

class _LaporanFormDosenScreenState extends State<LaporanFormDosenScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  String _actionUrl = '/rps/realisasi_rps_proses';
  final Map<String, String> _hidden = {};

  final TextEditingController _pertemuanCtrl = TextEditingController();
  final TextEditingController _materiCtrl = TextEditingController();
  final TextEditingController _realisasiMateriCtrl = TextEditingController();
  final TextEditingController _tglCtrl = TextEditingController();
  final TextEditingController _realisasiTglCtrl = TextEditingController();
  final TextEditingController _waktuCtrl = TextEditingController();
  final TextEditingController _realisasiWaktuCtrl = TextEditingController();

  List<String> _ruangOptions = [];
  String _ruangRps = '';
  String _ruangRealisasi = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pertemuanCtrl.dispose();
    _materiCtrl.dispose();
    _realisasiMateriCtrl.dispose();
    _tglCtrl.dispose();
    _realisasiTglCtrl.dispose();
    _waktuCtrl.dispose();
    _realisasiWaktuCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.fetchRpsEditFormData(widget.editKode);
      if (data == null) {
        setState(() {
          _errorMessage = 'Form ubah laporan tidak ditemukan.';
          _isLoading = false;
        });
        return;
      }

      String readField(String name) => (data['fields']?[name] ?? '').toString();

      _actionUrl = (data['action'] ?? '/rps/realisasi_rps_proses').toString();

      _hidden
        ..clear()
        ..addAll({
          'aksi': readField('aksi'),
          'h_real_kd_jdw': readField('h_real_kd_jdw'),
          'h_real_dosen_nip': readField('h_real_dosen_nip'),
          'h_real_dosen_nama': readField('h_real_dosen_nama'),
        });

      _pertemuanCtrl.text = readField('real_pertemuan');
      _materiCtrl.text = readField('real_materi');
      _realisasiMateriCtrl.text = readField('realisasi_materi');
      _tglCtrl.text = readField('real_rps_tgl');
      _realisasiTglCtrl.text = readField('realisasi_rps_tgl');
      _waktuCtrl.text = readField('real_rps_wkt');
      _realisasiWaktuCtrl.text = readField('realisasi_rps_wkt');

      _ruangOptions =
          List<String>.from(data['ruangan_options'] ?? const <String>[]);
      _ruangRps = readField('rps_ruangan');
      _ruangRealisasi = readField('realisasi_ruangan');

      if (_ruangRps.isNotEmpty && !_ruangOptions.contains(_ruangRps)) {
        _ruangOptions = [..._ruangOptions, _ruangRps];
      }
      if (_ruangRealisasi.isNotEmpty &&
          !_ruangOptions.contains(_ruangRealisasi)) {
        _ruangOptions = [..._ruangOptions, _ruangRealisasi];
      }

      setState(() {
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

    if (_realisasiMateriCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Realisasi materi wajib diisi.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final payload = <String, String>{
        ..._hidden,
        'real_pertemuan': _pertemuanCtrl.text.trim(),
        'real_materi': _materiCtrl.text.trim(),
        'realisasi_materi': _realisasiMateriCtrl.text.trim(),
        'real_rps_tgl': _tglCtrl.text.trim(),
        'realisasi_rps_tgl': _realisasiTglCtrl.text.trim(),
        'real_rps_wkt': _waktuCtrl.text.trim(),
        'realisasi_rps_wkt': _realisasiWaktuCtrl.text.trim(),
        'rps_ruangan': _ruangRps,
        'realisasi_ruangan': _ruangRealisasi,
        'btn_simpan': 'Simpan',
      };

      final ok = await _apiService.submitRpsEditForm(
        actionUrl: _actionUrl,
        fields: payload,
      );

      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan realisasi laporan.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Realisasi perkuliahan berhasil disimpan.')),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }

  DateTime _parseDateOrNow(String value) {
    final raw = value.trim();
    if (raw.isNotEmpty) {
      try {
        final parts = raw.split('-');
        if (parts.length == 3) {
          final year = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final day = int.tryParse(parts[2]);
          if (year != null && month != null && day != null) {
            return DateTime(year, month, day);
          }
        }
      } catch (_) {
        // Ignore parse error and fallback to today.
      }
    }
    return DateTime.now();
  }

  String _toYyyyMmDd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  TimeOfDay _parseTimeOrNow(String value) {
    final parts = value.trim().split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return TimeOfDay.now();
  }

  String _toHhMm(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseDateOrNow(controller.text),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      controller.text = _toYyyyMmDd(picked);
    });
  }

  Future<void> _pickTimeRange(TextEditingController controller) async {
    final current = controller.text.trim();
    final currentParts = current.split('-');
    final startInitial = _parseTimeOrNow(
      currentParts.isNotEmpty ? currentParts.first : '',
    );
    final endInitial = _parseTimeOrNow(
      currentParts.length > 1 ? currentParts[1] : '',
    );

    final start = await showTimePicker(
      context: context,
      initialTime: startInitial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (start == null) return;

    if (!mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: endInitial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (end == null) return;

    setState(() {
      controller.text = '${_toHhMm(start)}-${_toHhMm(end)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubah Laporan Perkuliahan'),
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
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: _pertemuanCtrl,
                      readOnly: true,
                      decoration: _inputDecoration('Pertemuan ke'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _materiCtrl,
                      maxLines: 2,
                      decoration: _inputDecoration('Materi'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _realisasiMateriCtrl,
                            maxLines: 2,
                            decoration: _inputDecoration('Realisasi Materi'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Copy dari Materi',
                          onPressed: () {
                            setState(() {
                              _realisasiMateriCtrl.text = _materiCtrl.text;
                            });
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tglCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(_tglCtrl),
                      decoration: _inputDecoration('Tanggal (yyyy-mm-dd)')
                          .copyWith(
                        suffixIcon: const Icon(Icons.calendar_today_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _realisasiTglCtrl,
                            readOnly: true,
                            onTap: () => _pickDate(_realisasiTglCtrl),
                            decoration:
                                _inputDecoration('Realisasi Tanggal').copyWith(
                              suffixIcon:
                                  const Icon(Icons.calendar_today_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Copy dari Tanggal',
                          onPressed: () {
                            setState(() {
                              _realisasiTglCtrl.text = _tglCtrl.text;
                            });
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _waktuCtrl,
                      readOnly: true,
                      onTap: () => _pickTimeRange(_waktuCtrl),
                      decoration: _inputDecoration('Waktu (07:00-08:40)')
                          .copyWith(
                        suffixIcon: const Icon(Icons.access_time_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _realisasiWaktuCtrl,
                            readOnly: true,
                            onTap: () => _pickTimeRange(_realisasiWaktuCtrl),
                            decoration:
                                _inputDecoration('Realisasi Waktu').copyWith(
                              suffixIcon:
                                  const Icon(Icons.access_time_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Copy dari Waktu',
                          onPressed: () {
                            setState(() {
                              _realisasiWaktuCtrl.text = _waktuCtrl.text;
                            });
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _ruangRps.isEmpty ? null : _ruangRps,
                      decoration: _inputDecoration('Ruang Kelas'),
                      items: _ruangOptions
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _ruangRps = v ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _ruangRealisasi.isEmpty
                                ? null
                                : _ruangRealisasi,
                            decoration:
                                _inputDecoration('Realisasi Ruang Kelas'),
                            items: _ruangOptions
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _ruangRealisasi = v ?? '';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Copy dari Ruang Kelas',
                          onPressed: () {
                            setState(() {
                              _ruangRealisasi = _ruangRps;
                            });
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
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
                label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
              ),
            ),
    );
  }
}
