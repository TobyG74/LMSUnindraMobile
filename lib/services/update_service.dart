import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  static const String versionCheckUrl =
      'https://raw.githubusercontent.com/TobyG74/LMSUnindraMobile/master/version.json';

  static const String _lastCheckKey = 'last_update_check';
  static const String _skipVersionKey = 'skip_version';

  Future<bool> shouldCheckUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final dayInMillis = 24 * 60 * 60 * 1000;

    return (now - lastCheck) > dayInMillis;
  }

  Future<void> _saveLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> isVersionSkipped(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final skippedVersion = prefs.getString(_skipVersionKey);
    return skippedVersion == version;
  }

  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skipVersionKey, version);
  }

  Future<void> clearSkipVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_skipVersionKey);
  }

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final response = await http.get(
        Uri.parse(versionCheckUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        final latestVersion = data['version'] as String;
        final latestVersionCode = data['versionCode'] as int;
        final updateRequired = data['updateRequired'] as bool? ?? false;

        if (latestVersionCode > currentBuildNumber) {
          if (await isVersionSkipped(latestVersion)) {
            return null;
          }

          await _saveLastCheckTime();

          return UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            updateRequired: updateRequired,
            updateTitle: data['updateTitle'] as String? ?? 'Update Tersedia',
            updateMessage: data['updateMessage'] as String? ??
                'Versi baru aplikasi tersedia',
            downloadUrl: data['downloadUrl'] as String? ?? '',
            changelog: (data['changelog'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            releaseDate: data['releaseDate'] as String?,
          );
        }

        await _saveLastCheckTime();
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  List<int> _parseVersion(String version) {
    try {
      return version.split('.').map((e) => int.parse(e)).toList();
    } catch (e) {
      return [0, 0, 0];
    }
  }

  int compareVersions(String v1, String v2) {
    final parts1 = _parseVersion(v1);
    final parts2 = _parseVersion(v2);

    for (int i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;

      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }

    return 0;
  }
}

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool updateRequired;
  final String updateTitle;
  final String updateMessage;
  final String downloadUrl;
  final List<String> changelog;
  final String? releaseDate;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateRequired,
    required this.updateTitle,
    required this.updateMessage,
    required this.downloadUrl,
    required this.changelog,
    this.releaseDate,
  });
}
