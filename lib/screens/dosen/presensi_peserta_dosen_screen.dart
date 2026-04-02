import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

class PresensiPesertaDosenScreen extends StatefulWidget {
  final String kdJdw;
  final String pertemuan;

  const PresensiPesertaDosenScreen({
    super.key,
    required this.kdJdw,
    required this.pertemuan,
  });

  @override
  State<PresensiPesertaDosenScreen> createState() =>
      _PresensiPesertaDosenScreenState();
}

class _PresensiPesertaDosenScreenState
    extends State<PresensiPesertaDosenScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  Map<String, dynamic> _rowInfo = {};
  List<_PesertaItem> _peserta = [];

  @override
  void initState() {
    super.initState();
    _loadPeserta();
  }

  @override
  void dispose() {
    for (final item in _peserta) {
      item.ketController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPeserta() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.fetchPresensiPeserta(
        widget.kdJdw,
        widget.pertemuan,
      );

      if (data == null || data['status'] == false) {
        setState(() {
          _errorMessage = (data?['pesan'] ?? 'Data tidak ditemukan').toString();
          _isLoading = false;
        });
        return;
      }

      final row = (data['row'] is Map<String, dynamic>)
          ? (data['row'] as Map<String, dynamic>)
          : <String, dynamic>{};

      final rawRows = data['rows'];
      final peserta = <_PesertaItem>[];
      if (rawRows is List) {
        for (final item in rawRows) {
          if (item is! Map) continue;
          final nim = (item['nim_kelas'] ?? '').toString();
          if (nim.isEmpty) continue;

          final hadirVal = (item['absen_presensi'] ?? 0).toString();
          peserta.add(
            _PesertaItem(
              nim: nim,
              nama: (item['nama_mahasiswa'] ?? '').toString(),
              noHp: (item['no_hp'] ?? '').toString(),
              pertemuan:
                  (item['absen_pertemuan'] ?? widget.pertemuan).toString(),
              hadir: hadirVal == '1',
              ket: (item['absen_ket'] ?? '').toString(),
            ),
          );
        }
      }

      setState(() {
        _rowInfo = row;
        _peserta = peserta;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _simpan() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final payload = _peserta
          .map(
            (e) => {
              'nim': e.nim,
              'hadir': e.hadir,
              'ket': e.ket,
            },
          )
          .toList();

      final result = await _apiService.simpanPresensiPeserta(
        kdJdw: widget.kdJdw,
        pertemuan: widget.pertemuan,
        peserta: payload,
      );

      if (!mounted) return;

      if (result == null || result['status'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (result?['pesan'] ?? 'Gagal menyimpan presensi').toString(),
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presensi berhasil disimpan')),
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

  void _toggleAll(bool value) {
    setState(() {
      for (final item in _peserta) {
        item.hadir = value;
      }
    });
  }

  Future<void> _kirimWa(_PesertaItem item) async {
    final mk = (_rowInfo['nm_matkul_jdw'] ?? 'Mata Kuliah').toString();
    final nomor = '62${item.noHp}';
    final pesan =
        'Halo, *${item.nama}*.\nPerkuliahan *$mk*, Pertemuan ke-*${item.pertemuan}* Anda belum Absen Kehadiran.';

    final uri = Uri.parse(
      'https://api.whatsapp.com/send?phone=$nomor&text=${Uri.encodeComponent(pesan)}',
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _tglId3(String tglDb) {
    if (tglDb.isEmpty) return '';
    final parts = tglDb.split('-');
    if (parts.length != 3) return tglDb;
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    final monthIndex = int.tryParse(parts[1]) ?? 0;
    if (monthIndex < 1 || monthIndex > 12) return tglDb;
    return '${parts[2]} ${months[monthIndex]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presensi Peserta'),
        backgroundColor: const Color(0xFF073163),
        foregroundColor: Colors.white,
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
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfo('Nama Matakuliah',
                                      '${_rowInfo['kd_matkul_jdw'] ?? ''} - ${_rowInfo['nm_matkul_jdw'] ?? ''}'),
                                  _buildInfo('Dosen',
                                      '${_rowInfo['dosen_nip'] ?? ''} - ${_rowInfo['dosen_nama'] ?? ''}'),
                                  _buildInfo('Pertemuan & Kelas',
                                      '${_rowInfo['rps_no_urut'] ?? ''}-${_rowInfo['rps_materi'] ?? ''} (${_rowInfo['nm_kelas_jdw'] ?? ''})'),
                                  _buildInfo('Jadwal & Ruang',
                                      '${_rowInfo['hari_jdw'] ?? ''}, ${_tglId3((_rowInfo['rps_tgl'] ?? '').toString())} @${_rowInfo['rps_ruang'] ?? ''}'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _peserta.isNotEmpty &&
                                        _peserta.every((e) => e.hadir),
                                    onChanged: (v) => _toggleAll(v ?? false),
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'Hadir Semua',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text('${_peserta.length} peserta'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_peserta.length, (index) {
                            final item = _peserta[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('${index + 1}. '),
                                        Expanded(
                                          child: Text(
                                            '${item.nim} - ${item.nama}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Checkbox(
                                          value: item.hadir,
                                          onChanged: (v) {
                                            setState(() {
                                              item.hadir = v ?? false;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    TextField(
                                      controller: item.ketController,
                                      onChanged: (v) => item.ket = v,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                        labelText: 'Catatan',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: item.noHp.isEmpty
                                            ? null
                                            : () => _kirimWa(item),
                                        icon: const Icon(Icons.message_rounded),
                                        label: const Text('Kirim WA'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _simpan,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                                _isSaving ? 'Menyimpan...' : 'Simpan Presensi'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PesertaItem {
  final String nim;
  final String nama;
  final String noHp;
  final String pertemuan;
  bool hadir;
  String ket;
  final TextEditingController ketController;

  _PesertaItem({
    required this.nim,
    required this.nama,
    required this.noHp,
    required this.pertemuan,
    required this.hadir,
    required this.ket,
  }) : ketController = TextEditingController(text: ket);
}
