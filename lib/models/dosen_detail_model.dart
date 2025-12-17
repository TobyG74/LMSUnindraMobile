class DosenDetail {
  final String nama;
  final String nidn;
  final String fakultas;
  final String prodi;
  final String jabatanFungsional;
  final String statusIkatanKerja;
  final String jenisKelamin;
  final String pendidikanTerakhir;
  final String? photoUrl;
  final String? ponsel;
  final String? statusWa;

  DosenDetail({
    required this.nama,
    required this.nidn,
    required this.fakultas,
    required this.prodi,
    required this.jabatanFungsional,
    required this.statusIkatanKerja,
    required this.jenisKelamin,
    required this.pendidikanTerakhir,
    this.photoUrl,
    this.ponsel,
    this.statusWa,
  });
}
