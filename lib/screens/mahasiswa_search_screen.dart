import 'package:flutter/material.dart';
import '../models/mahasiswa_search_model.dart';
import '../services/api_service.dart';

class MahasiswaSearchScreen extends StatefulWidget {
  const MahasiswaSearchScreen({super.key});

  @override
  State<MahasiswaSearchScreen> createState() => _MahasiswaSearchScreenState();
}

class _MahasiswaSearchScreenState extends State<MahasiswaSearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<MahasiswaSearchResult> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasSearched = false;

  Future<void> _searchMahasiswa() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan NIM atau nama mahasiswa'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final results = await _apiService.searchMahasiswa(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _searchResults = [];
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
                  Icon(Icons.search_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Cari Mahasiswa',
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Masukkan NIM atau nama mahasiswa',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(
                          Icons.person_search_rounded,
                          color: Color(0xFF073163),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF073163),
                            size: 28,
                          ),
                          onPressed: _searchMahasiswa,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      onSubmitted: (_) => _searchMahasiswa(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Cari berdasarkan NIM atau nama mahasiswa',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(
                      child: Column(
                        children: [
                          SizedBox(height: 40),
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Mencari data mahasiswa...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else if (_errorMessage != null)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
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
                            'Gagal mencari data',
                            style: TextStyle(
                              fontSize: 18,
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
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _searchMahasiswa,
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
                    )
                  else if (!_hasSearched)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF073163).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              size: 64,
                              color: Color(0xFF073163),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Cari Mahasiswa PDDIKTI',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Masukkan NIM atau nama mahasiswa untuk mencari data di database PDDIKTI',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_searchResults.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_off_rounded,
                              color: Colors.orange,
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Data tidak ditemukan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Tidak ada mahasiswa dengan NIM atau nama tersebut',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final mahasiswa = _searchResults[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF073163),
                                              Color(0xFF1756a5),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              mahasiswa.nama,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1A1A1A),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF073163)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                mahasiswa.nim,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF073163),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  Icons.school_rounded,
                                  'Universitas',
                                  '${mahasiswa.namaPt} (${mahasiswa.singkatanPt})',
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  Icons.menu_book_rounded,
                                  'Program Studi',
                                  mahasiswa.namaProdi,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF073163).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF073163),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
