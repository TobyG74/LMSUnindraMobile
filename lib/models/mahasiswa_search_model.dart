class MahasiswaSearchResult {
  final String id;
  final String nama;
  final String nim;
  final String namaPt;
  final String singkatanPt;
  final String namaProdi;

  MahasiswaSearchResult({
    required this.id,
    required this.nama,
    required this.nim,
    required this.namaPt,
    required this.singkatanPt,
    required this.namaProdi,
  });

  factory MahasiswaSearchResult.fromJson(Map<String, dynamic> json) {
    return MahasiswaSearchResult(
      id: json['id'] ?? '',
      nama: json['nama'] ?? '',
      nim: json['nim'] ?? '',
      namaPt: json['nama_pt'] ?? '',
      singkatanPt: json['sinkatan_pt'] ?? '',
      namaProdi: json['nama_prodi'] ?? '',
    );
  }
}
