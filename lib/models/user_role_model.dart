enum UserRole {
  mahasiswa,
  dosen,
}

extension UserRoleX on UserRole {
  String get levelKey {
    switch (this) {
      case UserRole.mahasiswa:
        return 'mhs';
      case UserRole.dosen:
        return 'dosen';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.mahasiswa:
        return 'Mahasiswa';
      case UserRole.dosen:
        return 'Dosen';
    }
  }

  String get credentialPrefix {
    switch (this) {
      case UserRole.mahasiswa:
        return 'mhs';
      case UserRole.dosen:
        return 'dosen';
    }
  }
}
