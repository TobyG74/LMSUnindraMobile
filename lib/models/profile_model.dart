class ProfileData {
  final String name;
  final String username;
  final String userType;
  final String lastVisit;
  final String phone;
  final String email;
  final String? photoUrl;

  ProfileData({
    required this.name,
    required this.username,
    required this.userType,
    required this.lastVisit,
    required this.phone,
    required this.email,
    this.photoUrl,
  });

  factory ProfileData.fromHtml(String html) {
    return ProfileData(
      name: '',
      username: '',
      userType: 'Mahasiswa',
      lastVisit: '',
      phone: '',
      email: '',
    );
  }
}
