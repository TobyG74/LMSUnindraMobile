import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';

enum LessonFormType {
  uploadFile,
  forum,
  chat,
  quiz,
  audio,
  video,
  htmlPage,
  urlEksternal,
  peerAssessment,
  tugasAssignment,
  tugasKolaborasi,
  youtube,
  zoomMeeting,
  autodraw,
  canva,
}

class TambahLessonFormScreen extends StatefulWidget {
  final LessonFormType type;
  final String url;

  const TambahLessonFormScreen({
    super.key,
    required this.type,
    required this.url,
  });

  @override
  State<TambahLessonFormScreen> createState() => _TambahLessonFormScreenState();
}

class _TambahLessonFormScreenState extends State<TambahLessonFormScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, String> _formMeta = {};

  File? _selectedFile;
  String? _selectedFileName;
  String? _selectedTugasUntuk;
  String? _selectedPeerTask;
  String? _selectedMakPerKelompok;
  List<_OptionItem> _tugasUntukOptions = [];
  List<_OptionItem> _peerTaskOptions = [];
  List<_OptionItem> _makPerKelompokOptions = [];

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _urlController.dispose();
    _startDateController.dispose();
    _startTimeController.dispose();
    _endDateController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  bool get _isTugasType {
    return widget.type == LessonFormType.tugasAssignment ||
        widget.type == LessonFormType.tugasKolaborasi;
  }

  bool get _isUrlType {
    return widget.type == LessonFormType.urlEksternal ||
        widget.type == LessonFormType.zoomMeeting ||
        widget.type == LessonFormType.autodraw ||
        widget.type == LessonFormType.canva;
  }

  bool get _isSingleUrlType {
    return widget.type == LessonFormType.youtube;
  }

  Future<void> _loadForm() async {
    setState(() => _isLoading = true);

    Map<String, String>? formMeta;
    switch (widget.type) {
      case LessonFormType.uploadFile:
        formMeta = await _apiService.fetchUploadFileForm(widget.url);
        break;
      case LessonFormType.forum:
        formMeta = await _apiService.fetchTambahForumForm(widget.url);
        break;
      case LessonFormType.chat:
        formMeta = await _apiService.fetchTambahChatForm(widget.url);
        break;
      case LessonFormType.quiz:
        formMeta = await _apiService.fetchTambahQuizForm(widget.url);
        break;
      case LessonFormType.audio:
        formMeta = await _apiService.fetchUploadAudioForm(widget.url);
        break;
      case LessonFormType.video:
        formMeta = await _apiService.fetchUploadVideoForm(widget.url);
        break;
      case LessonFormType.htmlPage:
        formMeta = await _apiService.fetchTambahPageForm(widget.url);
        break;
      case LessonFormType.urlEksternal:
        formMeta = await _apiService.fetchTambahUrlEksternalForm(widget.url);
        break;
      case LessonFormType.peerAssessment:
        formMeta = await _apiService.fetchTambahPeerAssessmentForm(widget.url);
        break;
      case LessonFormType.tugasAssignment:
        formMeta = await _apiService.fetchTambahTugasAssignmentForm(widget.url);
        break;
      case LessonFormType.tugasKolaborasi:
        formMeta = await _apiService.fetchTambahTugasKolaborasiForm(widget.url);
        break;
      case LessonFormType.youtube:
        formMeta = await _apiService.fetchTambahYoutubeForm(widget.url);
        break;
      case LessonFormType.zoomMeeting:
        formMeta = await _apiService.fetchTambahZoomMeetingForm(widget.url);
        break;
      case LessonFormType.autodraw:
        formMeta = await _apiService.fetchTambahAutodrawForm(widget.url);
        break;
      case LessonFormType.canva:
        formMeta = await _apiService.fetchTambahCanvaForm(widget.url);
        break;
    }

    if (!mounted) return;

    if (formMeta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat form lesson')),
      );
      Navigator.pop(context);
      return;
    }

    final resolvedFormMeta = formMeta;

    setState(() {
      _formMeta = resolvedFormMeta;
      _initDynamicFields(resolvedFormMeta);
      _isLoading = false;
    });
  }

  void _initDynamicFields(Map<String, String> formMeta) {
    _startDateController.text =
        formMeta['tgl_mulai_tugas'] ?? formMeta['tgl_mulai_peer'] ?? '';
    _startTimeController.text =
        formMeta['jam_mulai_tugas'] ?? formMeta['jam_mulai_peer'] ?? '';
    _endDateController.text =
        formMeta['tgl_akhir_tugas'] ?? formMeta['tgl_akhir_peer'] ?? '';
    _endTimeController.text =
        formMeta['jam_akhir_tugas'] ?? formMeta['jam_akhir_peer'] ?? '';

    if (widget.type == LessonFormType.tugasAssignment ||
        widget.type == LessonFormType.tugasKolaborasi) {
      _tugasUntukOptions =
          _parseOptions(formMeta['tugas_untuk_options_json'] ?? '[]');
      if (_tugasUntukOptions.isNotEmpty) {
        _selectedTugasUntuk = _tugasUntukOptions.first.value;
      }
    }

    if (widget.type == LessonFormType.tugasKolaborasi) {
      _makPerKelompokOptions =
          _parseOptions(formMeta['mak_per_kelompok_options_json'] ?? '[]');
      if (_makPerKelompokOptions.isNotEmpty) {
        _selectedMakPerKelompok = _makPerKelompokOptions.first.value;
      }
    }

    if (widget.type == LessonFormType.peerAssessment) {
      _peerTaskOptions = _parseOptions(formMeta['peer_options_json'] ?? '[]');
      if (_peerTaskOptions.isNotEmpty) {
        _selectedPeerTask = _peerTaskOptions.first.value;
      }
    }
  }

  List<_OptionItem> _parseOptions(String encodedJson) {
    try {
      final decoded = jsonDecode(encodedJson);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => _OptionItem(
              value: (item['value'] ?? '').toString(),
              label: (item['label'] ?? '').toString(),
            ),
          )
          .where((item) => item.value.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  String get _title {
    switch (widget.type) {
      case LessonFormType.uploadFile:
        return 'Upload File';
      case LessonFormType.forum:
        return 'Tambah Forum';
      case LessonFormType.chat:
        return 'Tambah Chat Room';
      case LessonFormType.quiz:
        return 'Tambah Quiz';
      case LessonFormType.audio:
        return 'Upload Audio';
      case LessonFormType.video:
        return 'Upload Video';
      case LessonFormType.htmlPage:
        return 'Tambah HTML Page';
      case LessonFormType.urlEksternal:
        return 'Tambah URL Eksternal';
      case LessonFormType.peerAssessment:
        return 'Tambah Peer Assessment';
      case LessonFormType.tugasAssignment:
        return 'Tambah Tugas Assignment';
      case LessonFormType.tugasKolaborasi:
        return 'Tambah Tugas Kolaborasi';
      case LessonFormType.youtube:
        return 'Tambah URL YouTube';
      case LessonFormType.zoomMeeting:
        return 'Tambah Zoom Meeting';
      case LessonFormType.autodraw:
        return 'Tambah Autodraw';
      case LessonFormType.canva:
        return 'Tambah Canva';
    }
  }

  String get _nameLabel {
    switch (widget.type) {
      case LessonFormType.uploadFile:
        return 'Nama File';
      case LessonFormType.forum:
        return 'Nama Forum';
      case LessonFormType.chat:
        return 'Nama Chat Room';
      case LessonFormType.quiz:
        return 'Nama Quiz';
      case LessonFormType.audio:
        return 'Nama File Audio';
      case LessonFormType.video:
        return 'Nama File Video';
      case LessonFormType.htmlPage:
        return 'Judul Page';
      case LessonFormType.urlEksternal:
      case LessonFormType.zoomMeeting:
      case LessonFormType.autodraw:
      case LessonFormType.canva:
        return 'Nama URL';
      case LessonFormType.peerAssessment:
        return 'Peer Assessment';
      case LessonFormType.tugasAssignment:
      case LessonFormType.tugasKolaborasi:
        return 'Nama Tugas';
      case LessonFormType.youtube:
        return 'Keterangan';
    }
  }

  String get _urlLabel {
    switch (widget.type) {
      case LessonFormType.urlEksternal:
        return 'URL Eksternal';
      case LessonFormType.youtube:
        return 'URL YouTube';
      case LessonFormType.zoomMeeting:
        return 'URL Zoom Meeting';
      case LessonFormType.autodraw:
        return 'URL Autodraw';
      case LessonFormType.canva:
        return 'URL Canva';
      default:
        return 'URL';
    }
  }

  String get _urlHint {
    switch (widget.type) {
      case LessonFormType.youtube:
        return 'https://www.youtube.com/watch?v=...';
      case LessonFormType.zoomMeeting:
        return 'https://us04web.zoom.us/j/...';
      case LessonFormType.autodraw:
        return 'https://www.autodraw.com/';
      case LessonFormType.canva:
        return 'https://www.canva.com/...';
      default:
        return 'https://...';
    }
  }

  bool get _requiresFile {
    return widget.type == LessonFormType.uploadFile ||
        widget.type == LessonFormType.audio ||
        widget.type == LessonFormType.video;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) {
      return;
    }

    setState(() {
      _selectedFile = File(result.files.single.path!);
      _selectedFileName = result.files.single.name;
      if (_nameController.text.trim().isEmpty &&
          widget.type != LessonFormType.peerAssessment) {
        _nameController.text = result.files.single.name;
      }
    });
  }

  DateTime _parseOrNowDate(String value) {
    final parts = value.split('-');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.now();
  }

  TimeOfDay _parseOrNowTime(String value) {
    final parts = value.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    return TimeOfDay.now();
  }

  String _toDdMmYyyy(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$dd-$mm-$yyyy';
  }

  String _toHhMm(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initialDate = _parseOrNowDate(controller.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      controller.text = _toDdMmYyyy(picked);
    });
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final initialTime = _parseOrNowTime(controller.text.trim());
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      controller.text = _toHhMm(picked);
    });
  }

  Widget _buildPickerField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      showCursor: false,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: Icon(icon),
      ),
    );
  }

  Future<void> _submit() async {
    final skipName = widget.type == LessonFormType.peerAssessment;
    if (!skipName && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_nameLabel wajib diisi')),
      );
      return;
    }

    if (_requiresFile && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih file terlebih dahulu')),
      );
      return;
    }

    if ((_isUrlType || _isSingleUrlType) &&
        _urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_urlLabel wajib diisi')),
      );
      return;
    }

    if (_isTugasType &&
        (_selectedTugasUntuk == null || _selectedTugasUntuk!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori tugas wajib dipilih')),
      );
      return;
    }

    if (widget.type == LessonFormType.tugasKolaborasi &&
        (_selectedMakPerKelompok == null || _selectedMakPerKelompok!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maks. per kelompok wajib dipilih')),
      );
      return;
    }

    if (widget.type == LessonFormType.peerAssessment) {
      if (_selectedPeerTask == null || _selectedPeerTask!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tugas kolaborasi wajib dipilih')),
        );
        return;
      }

      if (_startDateController.text.trim().isEmpty ||
          _startTimeController.text.trim().isEmpty ||
          _endDateController.text.trim().isEmpty ||
          _endTimeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jadwal peer assessment wajib diisi')),
        );
        return;
      }
    }

    if (_isTugasType) {
      if (_startDateController.text.trim().isEmpty ||
          _startTimeController.text.trim().isEmpty ||
          _endDateController.text.trim().isEmpty ||
          _endTimeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jadwal tugas wajib diisi')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    String? resultMessage;
    switch (widget.type) {
      case LessonFormType.uploadFile:
        resultMessage = await _apiService.uploadMateriFileDosen(
          formMeta: _formMeta,
          filePath: _selectedFile!.path,
          fileName: _selectedFileName ?? _selectedFile!.path.split('/').last,
          namaFile: _nameController.text.trim(),
          keterangan: _descController.text.trim(),
        );
        break;
      case LessonFormType.audio:
        resultMessage = await _apiService.uploadMateriAudioDosen(
          formMeta: _formMeta,
          filePath: _selectedFile!.path,
          fileName: _selectedFileName ?? _selectedFile!.path.split('/').last,
          namaFile: _nameController.text.trim(),
          keterangan: _descController.text.trim(),
        );
        break;
      case LessonFormType.video:
        resultMessage = await _apiService.uploadMateriVideoDosen(
          formMeta: _formMeta,
          filePath: _selectedFile!.path,
          fileName: _selectedFileName ?? _selectedFile!.path.split('/').last,
          namaFile: _nameController.text.trim(),
          keterangan: _descController.text.trim(),
        );
        break;
      case LessonFormType.forum:
        resultMessage = await _apiService.submitTambahForum(
          formMeta: _formMeta,
          namaForum: _nameController.text.trim(),
          keterangan: _descController.text.trim(),
        );
        break;
      case LessonFormType.chat:
        resultMessage = await _apiService.submitTambahChat(
          formMeta: _formMeta,
          namaChatroom: _nameController.text.trim(),
          keterangan: _descController.text.trim(),
        );
        break;
      case LessonFormType.quiz:
        resultMessage = await _apiService.submitTambahQuiz(
          formMeta: _formMeta,
          namaQuiz: _nameController.text.trim(),
          instruksi: _descController.text.trim(),
        );
        break;
      case LessonFormType.htmlPage:
        resultMessage = await _apiService.submitTambahPage(
          formMeta: _formMeta,
          namaPage: _nameController.text.trim(),
          keterangan: _descController.text.trim(),
        );
        break;
      case LessonFormType.urlEksternal:
        resultMessage = await _apiService.submitTambahUrlEksternal(
          formMeta: _formMeta,
          namaUrl: _nameController.text.trim(),
          urlEksternal: _urlController.text.trim(),
          keterangan: _descController.text.trim(),
        );
        break;
      case LessonFormType.peerAssessment:
        resultMessage = await _apiService.submitTambahPeerAssessment(
          formMeta: _formMeta,
          tugasIdPeer: _selectedPeerTask!,
          tglMulai: _startDateController.text.trim(),
          jamMulai: _startTimeController.text.trim(),
          tglAkhir: _endDateController.text.trim(),
          jamAkhir: _endTimeController.text.trim(),
        );
        break;
      case LessonFormType.tugasAssignment:
        String? uploadedToken;
        if (_selectedFile != null) {
          uploadedToken = await _apiService.uploadTugasAssignmentFile(
            formMeta: _formMeta,
            filePath: _selectedFile!.path,
            fileName: _selectedFileName ?? _selectedFile!.path.split('/').last,
            namaTugas: _nameController.text.trim(),
            tugasUntuk: _selectedTugasUntuk!,
            keterangan: _descController.text.trim(),
            tglMulai: _startDateController.text.trim(),
            jamMulai: _startTimeController.text.trim(),
            tglAkhir: _endDateController.text.trim(),
            jamAkhir: _endTimeController.text.trim(),
          );
        }

        resultMessage = await _apiService.submitTambahTugasAssignment(
          formMeta: _formMeta,
          namaTugas: _nameController.text.trim(),
          tugasUntuk: _selectedTugasUntuk!,
          keterangan: _descController.text.trim(),
          tglMulai: _startDateController.text.trim(),
          jamMulai: _startTimeController.text.trim(),
          tglAkhir: _endDateController.text.trim(),
          jamAkhir: _endTimeController.text.trim(),
          tugasFile: uploadedToken,
        );
        break;
      case LessonFormType.tugasKolaborasi:
        String? uploadedToken;
        if (_selectedFile != null) {
          uploadedToken = await _apiService.uploadTugasKolaborasiFile(
            formMeta: _formMeta,
            filePath: _selectedFile!.path,
            fileName: _selectedFileName ?? _selectedFile!.path.split('/').last,
            namaTugas: _nameController.text.trim(),
            tugasUntuk: _selectedTugasUntuk!,
            makPerKelompok: _selectedMakPerKelompok!,
            keterangan: _descController.text.trim(),
            tglMulai: _startDateController.text.trim(),
            jamMulai: _startTimeController.text.trim(),
            tglAkhir: _endDateController.text.trim(),
            jamAkhir: _endTimeController.text.trim(),
          );
        }

        resultMessage = await _apiService.submitTambahTugasKolaborasi(
          formMeta: _formMeta,
          namaTugas: _nameController.text.trim(),
          tugasUntuk: _selectedTugasUntuk!,
          makPerKelompok: _selectedMakPerKelompok!,
          keterangan: _descController.text.trim(),
          tglMulai: _startDateController.text.trim(),
          jamMulai: _startTimeController.text.trim(),
          tglAkhir: _endDateController.text.trim(),
          jamAkhir: _endTimeController.text.trim(),
          tugasFile: uploadedToken,
        );
        break;
      case LessonFormType.youtube:
        resultMessage = await _apiService.submitTambahYoutube(
          formMeta: _formMeta,
          urlYoutube: _urlController.text.trim(),
          keterangan: _nameController.text.trim(),
        );
        break;
      case LessonFormType.zoomMeeting:
        resultMessage = await _apiService.submitTambahZoomMeeting(
          formMeta: _formMeta,
          namaUrl: _nameController.text.trim(),
          urlZoom: _urlController.text.trim(),
          keterangan: _descController.text.trim(),
        );
        break;
      case LessonFormType.autodraw:
        resultMessage = await _apiService.submitTambahAutodraw(
          formMeta: _formMeta,
          namaUrl: _nameController.text.trim(),
          urlDraw: _urlController.text.trim(),
          keterangan: _descController.text.trim(),
        );
        break;
      case LessonFormType.canva:
        resultMessage = await _apiService.submitTambahCanva(
          formMeta: _formMeta,
          namaUrl: _nameController.text.trim(),
          urlCanva: _urlController.text.trim(),
          keterangan: _descController.text.trim(),
        );
        break;
    }

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (resultMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan lesson')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resultMessage)),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final showNameField = widget.type != LessonFormType.peerAssessment;
    final showDescField = widget.type != LessonFormType.peerAssessment &&
        widget.type != LessonFormType.youtube;
    final showUrlField = _isUrlType || _isSingleUrlType;
    final showPeerFields = widget.type == LessonFormType.peerAssessment;
    final showTugasFields = _isTugasType;
    final showMakKelompokField = widget.type == LessonFormType.tugasKolaborasi;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (showNameField)
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: _nameLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                if (showNameField) const SizedBox(height: 12),
                if (showUrlField)
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: _urlLabel,
                      border: const OutlineInputBorder(),
                      hintText: _urlHint,
                    ),
                  ),
                if (showUrlField) const SizedBox(height: 12),
                if (showTugasFields)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTugasUntuk,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: _tugasUntukOptions
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.value,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedTugasUntuk = value);
                    },
                  ),
                if (showTugasFields) const SizedBox(height: 12),
                if (showMakKelompokField)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMakPerKelompok,
                    decoration: const InputDecoration(
                      labelText: 'Maks. per Kelompok',
                      border: OutlineInputBorder(),
                    ),
                    items: _makPerKelompokOptions
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.value,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedMakPerKelompok = value);
                    },
                  ),
                if (showMakKelompokField) const SizedBox(height: 12),
                if (showPeerFields)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPeerTask,
                    decoration: const InputDecoration(
                      labelText: 'Tugas Kolaborasi',
                      border: OutlineInputBorder(),
                    ),
                    items: _peerTaskOptions
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.value,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedPeerTask = value);
                    },
                  ),
                if (showPeerFields) const SizedBox(height: 12),
                if (showDescField)
                  TextField(
                    controller: _descController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan / Instruksi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (showDescField) const SizedBox(height: 12),
                if (showPeerFields || showTugasFields)
                  Row(
                    children: [
                      Expanded(
                        child: _buildPickerField(
                          controller: _startDateController,
                          label: 'Tanggal Mulai',
                          icon: Icons.calendar_today,
                          onTap: () => _pickDate(_startDateController),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPickerField(
                          controller: _startTimeController,
                          label: 'Jam Mulai',
                          icon: Icons.access_time,
                          onTap: () => _pickTime(_startTimeController),
                        ),
                      ),
                    ],
                  ),
                if (showPeerFields || showTugasFields)
                  const SizedBox(height: 12),
                if (showPeerFields || showTugasFields)
                  Row(
                    children: [
                      Expanded(
                        child: _buildPickerField(
                          controller: _endDateController,
                          label: 'Tanggal Akhir',
                          icon: Icons.calendar_today,
                          onTap: () => _pickDate(_endDateController),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPickerField(
                          controller: _endTimeController,
                          label: 'Jam Akhir',
                          icon: Icons.access_time,
                          onTap: () => _pickTime(_endTimeController),
                        ),
                      ),
                    ],
                  ),
                if (showPeerFields || showTugasFields)
                  const SizedBox(height: 12),
                if (_requiresFile || showTugasFields)
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      _selectedFileName == null
                          ? (showTugasFields
                              ? 'Pilih File Tambahan (Opsional)'
                              : 'Pilih File')
                          : 'File: $_selectedFileName',
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSubmitting ? 'Menyimpan...' : 'Simpan'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _OptionItem {
  final String value;
  final String label;

  const _OptionItem({required this.value, required this.label});
}
