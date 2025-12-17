class DosenSearchResult {
  final String nama;
  final String nidn;
  final String prodi;
  final String kepakaran;
  final String kode;
  final String? photoUrl;
  final String? ponsel;
  final String? statusWa;

  DosenSearchResult({
    required this.nama,
    required this.nidn,
    required this.prodi,
    required this.kepakaran,
    required this.kode,
    this.photoUrl,
    this.ponsel,
    this.statusWa,
  });
}
