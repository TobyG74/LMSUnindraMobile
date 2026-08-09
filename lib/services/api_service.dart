import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_model.dart';
import '../models/user_role_model.dart';
import '../models/profile_model.dart';
import '../models/mahasiswa_search_model.dart';
import '../models/dosen_search_model.dart';
import '../models/dosen_detail_model.dart';

/// Dilempar saat PDDIKTI dijawab Cloudflare ("Just a moment" / verify captcha).
/// UI harus membuka [url] di WebView agar user menyelesaikan captcha.
class CloudflareChallengeException implements Exception {
  final String url;
  CloudflareChallengeException(this.url);

  @override
  String toString() => 'Perlu verifikasi Cloudflare';
}

class ApiService {
  static const String baseUrl = 'https://lms.unindra.ac.id';
  static const String loginUrl = '$baseUrl/login_new';
  static const String captchaUrl = '$baseUrl/kapca';

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  final CookieJar _cookieJar = CookieJar();

  String? _ciSession;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36 Edg/142.0.0.0',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
      followRedirects: true,
      validateStatus: (status) => status! < 500,
    ));
  }

  Future<LoginFormData> fetchLoginPage() async {
    try {
      final response = await _dio.get('/login_new');

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);

        final csrfInput = document.querySelector('input[name="csrf_token"]');
        final csrfToken = csrfInput?.attributes['value'] ?? '';

        final hiddenInputs = document.querySelectorAll('input[type="hidden"]');
        String hiddenFieldName = '';
        String hiddenFieldValue = '';

        for (var input in hiddenInputs) {
          final name = input.attributes['name'] ?? '';
          if (name.isNotEmpty && name != 'csrf_token' && name.length > 20) {
            hiddenFieldName = name;
            hiddenFieldValue = input.attributes['value'] ?? '';
            break;
          }
        }

        return LoginFormData(
          csrfToken: csrfToken,
          hiddenFieldName: hiddenFieldName,
          hiddenFieldValue: hiddenFieldValue,
        );
      } else {
        throw Exception('Failed to load login page');
      }
    } catch (e) {
      throw Exception('Error fetching login page: $e');
    }
  }

  Future<Uint8List> fetchCaptchaImage() async {
    try {
      final response = await _dio.get(
        captchaUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Referer': loginUrl,
            if (_ciSession != null) 'Cookie': 'ci_session=$_ciSession',
          },
        ),
      );

      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) {
        for (var cookie in setCookie) {
          if (cookie.startsWith('ci_session=')) {
            _ciSession = cookie.split(';')[0].substring('ci_session='.length);
            break;
          }
        }
      }

      if (response.statusCode == 200) {
        return Uint8List.fromList(response.data);
      } else {
        throw Exception('Failed to load captcha');
      }
    } catch (e) {
      throw Exception('Error fetching captcha: $e');
    }
  }

  Future<Map<String, dynamic>> login(LoginRequest request) async {
    try {
      final formData = request.toFormData();

      final cookieParts = <String>[];

      if (request.rememberMe) {
        cookieParts.add('colek_member_username=${request.username}');
        cookieParts.add('colek_member_pswd=${request.password}');
        cookieParts.add('colek_member_remember=true');
        await _saveCookies(
          request.username,
          request.password,
          request.userRole,
        );
      }

      if (_ciSession != null) {
        cookieParts.add('ci_session=$_ciSession');
      }

      final cookieHeader = cookieParts.join('; ');

      final response = await _dio.post(
        loginUrl,
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (status) => status! < 500,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
            'Referer': loginUrl,
            'Origin': baseUrl,
          },
        ),
      );

      if (response.statusCode == 302 ||
          response.statusCode == 301 ||
          response.statusCode == 303) {
        final location = response.headers.value('location');

        if (location != null && location.contains('/member')) {
          final roleValidation = await _validateLoggedInRole(request.userRole);
          if (!roleValidation['success']) {
            return roleValidation;
          }

          return {
            'success': true,
            'message': 'Login berhasil',
            'redirect': location,
            'user_level': roleValidation['user_level'],
          };
        }
      }

      if (response.statusCode == 200) {
        final responseData = response.data.toString();

        // Cari pesan error
        final doc = html_parser.parse(responseData);

        final possibleErrors = [
          ...doc.querySelectorAll('.alert'),
          ...doc.querySelectorAll('.error'),
          ...doc.querySelectorAll('[class*="alert"]'),
          ...doc.querySelectorAll('[class*="danger"]'),
          ...doc.querySelectorAll('[class*="error"]'),
          ...doc.querySelectorAll('.text-danger'),
          ...doc.querySelectorAll('.invalid-feedback'),
        ];

        for (var elem in possibleErrors) {
          final text = elem.text.trim();
          if (text.isNotEmpty && text.length < 200) {
            print('Found error element: $text');
          }
        }

        if (responseData.contains('Incorrect') ||
            responseData.contains('salah')) {
          final startIdx = responseData.toLowerCase().indexOf('incorrect') >= 0
              ? responseData.toLowerCase().indexOf('incorrect')
              : responseData.toLowerCase().indexOf('salah');
          if (startIdx >= 0) {
            final errorSnippet = responseData.substring(
                startIdx > 50 ? startIdx - 50 : 0,
                (startIdx + 200) < responseData.length
                    ? startIdx + 200
                    : responseData.length);
            print('Error context: $errorSnippet');
          }
        }

        // Cek udah masuk halaman member apa belum
        if (responseData.contains('user_level') &&
            responseData.contains('Member | LMS UNINDRA')) {
          final roleValidation = await _validateLoggedInRole(request.userRole);
          if (!roleValidation['success']) {
            return roleValidation;
          }

          return {
            'success': true,
            'message': 'Login berhasil',
            'user_level': roleValidation['user_level'],
          };
        }

        if (responseData.contains('Incorrect') ||
            responseData.contains('salah') ||
            responseData.contains('Invalid') ||
            responseData.contains('Wrong') ||
            responseData.contains('captcha')) {
          String errorMsg = '';
          for (var elem in possibleErrors) {
            final text = elem.text.trim();
            if (text.isNotEmpty && text.length < 200 && !text.contains('×')) {
              errorMsg = text;
              print('Selected error message: $errorMsg');
              break;
            }
          }

          return {
            'success': false,
            'message': errorMsg.isNotEmpty
                ? errorMsg
                : 'Username, password, atau captcha salah',
          };
        }

        if (responseData.contains('login-check') ||
            responseData.contains('Enter username') ||
            responseData.contains('Login | LMS UNINDRA')) {
          final doc = html_parser.parse(responseData);
          final alerts = doc.querySelectorAll(
              '.alert, .error, [class*="danger"], [class*="error"]');
          for (var alert in alerts) {
            final text = alert.text.trim();
            if (text.isNotEmpty) {
              print('Found alert/error: $text');
            }
          }

          return {
            'success': false,
            'message': 'Login gagal, silakan periksa kredensial Anda',
          };
        }
      }

      final cookies = await _cookieJar.loadForRequest(Uri.parse(baseUrl));
      final hasSession = cookies.any((cookie) => cookie.name == 'ci_session');

      if (hasSession) {
        try {
          final memberResponse = await _dio.get('/member');
          if (memberResponse.statusCode == 200) {
            final roleValidation =
                await _validateLoggedInRole(request.userRole);
            if (!roleValidation['success']) {
              return roleValidation;
            }

            return {
              'success': true,
              'message': 'Login berhasil',
              'data': memberResponse.data,
              'user_level': roleValidation['user_level'],
            };
          }
        } catch (e) {
          print('Error: $e');
        }
      }

      return {
        'success': false,
        'message': 'Login gagal, silakan coba lagi',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  Future<void> _saveCookies(
    String username,
    String password,
    UserRole role,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = role.credentialPrefix;
    await prefs.setString('colek_member_username_$prefix', username);
    await prefs.setString('colek_member_pswd_$prefix', password);
    await prefs.setBool('colek_member_remember_$prefix', true);

    // Backward compatibility for legacy keys.
    await prefs.setString('colek_member_username', username);
    await prefs.setString('colek_member_pswd', password);
    await prefs.setBool('colek_member_remember', true);
  }

  Future<Map<String, String>?> loadSavedCredentials(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = role.credentialPrefix;
    final remember = prefs.getBool('colek_member_remember_$prefix') ?? false;
    final username = prefs.getString('colek_member_username_$prefix');

    final legacyUsername = prefs.getString('colek_member_username');
    final effectiveUsername = username ?? legacyUsername;

    if (remember && effectiveUsername != null) {
      final password = prefs.getString('colek_member_pswd_$prefix');
      if (password != null) {
        return {
          'username': effectiveUsername,
          'password': password,
        };
      }
    }

    if (effectiveUsername != null) {
      return {
        'username': effectiveUsername,
      };
    }

    return null;
  }

  Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('colek_member_pswd');
    await prefs.setBool('colek_member_remember', false);
    await prefs.remove('colek_member_pswd_mhs');
    await prefs.remove('colek_member_pswd_dosen');
    await prefs.setBool('colek_member_remember_mhs', false);
    await prefs.setBool('colek_member_remember_dosen', false);
  }

  Future<Map<String, dynamic>> _validateLoggedInRole(
      UserRole expectedRole) async {
    try {
      final html = await fetchDashboardPage();
      final level = _extractUserLevelFromHtml(html);

      if (level == null || level.isEmpty) {
        return {
          'success': false,
          'message': 'Gagal memverifikasi tipe akun. Silakan coba lagi.',
        };
      }

      if (level != expectedRole.levelKey) {
        return {
          'success': false,
          'message':
              'Akun ini terdeteksi sebagai ${_roleNameFromLevel(level)}. Silakan gunakan menu login yang sesuai.',
          'user_level': level,
        };
      }

      return {
        'success': true,
        'user_level': level,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal memverifikasi tipe akun: $e',
      };
    }
  }

  String? _extractUserLevelFromHtml(String html) {
    final match = RegExp(r'user_level\s*=\s*"([^"]+)"').firstMatch(html);
    return match?.group(1)?.trim();
  }

  String _roleNameFromLevel(String level) {
    if (level == UserRole.mahasiswa.levelKey) {
      return 'Mahasiswa';
    }
    if (level == UserRole.dosen.levelKey) {
      return 'Dosen';
    }
    return level;
  }

  Future<Map<String, dynamic>> submitForgotPassword({
    required String email,
    required String captcha,
    required String csrfToken,
    required String hiddenField,
  }) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final formData = {
        'csrf_token': csrfToken,
        '0e59f85937eebefad004de3c21e9c6ae': hiddenField,
        'txt_email': email,
        'kapca': captcha,
      };

      final response = await _dio.post(
        '/lupa_password/proses',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        final responseData = response.data.toString();

        if (responseData.contains('window.location') &&
            responseData.contains('login_new')) {
          return {
            'success': true,
            'message': 'Link reset password telah dikirim ke email Anda',
          };
        }

        final doc = html_parser.parse(responseData);

        final successAlerts = doc.querySelectorAll(
            '.alert-success, .text-success, [class*="success"]');
        for (var alert in successAlerts) {
          final text = alert.text.trim();
          if (text.isNotEmpty && text.length < 200) {
            return {
              'success': true,
              'message': text,
            };
          }
        }

        final errorAlerts = doc.querySelectorAll(
            '.alert-danger, .alert-error, .error, [class*="danger"]');
        for (var alert in errorAlerts) {
          final text = alert.text.trim();
          if (text.isNotEmpty && text.length < 200) {
            return {
              'success': false,
              'message': text,
            };
          }
        }

        if (response.statusCode == 302 || response.statusCode == 303) {
          return {
            'success': true,
            'message': 'Link reset password telah dikirim ke email Anda',
          };
        }

        if (responseData.contains('berhasil') ||
            responseData.contains('success') ||
            responseData.contains('terkirim') ||
            responseData.contains('sent')) {
          return {
            'success': true,
            'message': 'Link reset password telah dikirim ke email Anda',
          };
        }

        return {
          'success': false,
          'message':
              'Gagal mengirim reset password. Periksa email atau captcha Anda.',
        };
      }

      return {
        'success': false,
        'message': 'Error: Status ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  Future<ProfileData> fetchProfile() async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final response = await _dio.get(
        '/member/profil',
        options: Options(
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);

        final name =
            document.querySelector('.profile-username')?.text.trim() ?? '';
        final usernameText =
            document.querySelector('.text-muted.text-center')?.text.trim() ??
                '';
        final username = usernameText.replaceAll('Username: ', '');

        String userType = 'Mahasiswa';
        final listItems = document.querySelectorAll('.list-group-item');
        for (var item in listItems) {
          final boldText = item.querySelector('b')?.text.trim() ?? '';
          if (boldText == 'Jenis User') {
            userType = item.querySelector('a')?.text.trim() ?? 'Mahasiswa';
            break;
          }
        }

        String lastVisit = '';
        for (var item in listItems) {
          final boldText = item.querySelector('b')?.text.trim() ?? '';
          if (boldText == 'Last Visit') {
            lastVisit = item.querySelector('a')?.text.trim() ?? '';
            break;
          }
        }

        final phoneInput = document.querySelector('input[name="hp"]');
        final phone = phoneInput?.attributes['value'] ?? '';

        final gmailInput = document.querySelector('input[name="gmail"]');
        final email = gmailInput?.attributes['value'] ?? '';

        final photoImg = document.querySelector('.profile-user-img');
        final photoUrl = photoImg?.attributes['src'];

        return ProfileData(
          name: name,
          username: username,
          userType: userType,
          lastVisit: lastVisit,
          phone: phone,
          email: email,
          photoUrl: photoUrl,
        );
      }

      throw Exception('Failed to load profile: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String phone,
    required String email,
  }) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final formData = {
        'hp': phone,
        'gmail': email,
        'h1_0e59f85937eebefad004de3c21e9c6ae': '',
      };

      final response = await _dio.post(
        '/member/ganti_profil_proses',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return {
          'success': true,
          'message': 'Profil berhasil diperbarui',
        };
      }

      return {
        'success': false,
        'message': 'Gagal memperbarui profil',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final formData = {
        'pswd_lama': oldPassword,
        'pswd_baru': newPassword,
        'pswd_ulangi': confirmPassword,
        'h1_0e59f85937eebefad004de3c21e9c6ae': '',
      };

      final response = await _dio.post(
        '/member/ganti_password_proses',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        final responseData = response.data.toString();

        if (responseData.contains('salah') ||
            responseData.contains('tidak sesuai')) {
          return {
            'success': false,
            'message': 'Password lama salah atau password baru tidak sesuai',
          };
        }

        return {
          'success': true,
          'message': 'Password berhasil diubah',
        };
      }

      return {
        'success': false,
        'message': 'Gagal mengubah password',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  Future<String?> fetchPertemuanPage(String encryptedUrl) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final response = await _dio.get(
        '/pertemuan/pke/$encryptedUrl',
        options: Options(
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data as String;
      }

      return null;
    } catch (e) {
      print('Error fetching pertemuan page: $e');
      return null;
    }
  }

  Future<String?> fetchTambahLessonPopup(String kode) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final response = await _dio.post(
        '/pertemuan/lesson_pop',
        data: {
          'kode': kode,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data.toString();
      }

      return null;
    } catch (e) {
      print('Error fetching tambah lesson popup: $e');
      return null;
    }
  }

  Future<bool> hapusItemPertemuan(String linkHapus) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final response = await _dio.post(
        '/pertemuan/hapus_item_pertemuan',
        data: {
          'link_hapus': linkHapus,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting pertemuan item: $e');
      return false;
    }
  }

  Future<Map<String, String>?> fetchTambahForumForm(String urlOrPath) async {
    try {
      final html = await fetchPageByUrl(urlOrPath);
      if (html == null || html.isEmpty) return null;

      final doc = html_parser.parse(html);
      return {
        'csrf_token': doc
                .querySelector('input[name="csrf_token"]')
                ?.attributes['value'] ??
            '',
        'hidden_token': doc
                .querySelector(
                  'input[name="0e59f85937eebefad004de3c21e9c6ae"]',
                )
                ?.attributes['value'] ??
            '',
        'h_kode':
            doc.querySelector('input[name="h_kode"]')?.attributes['value'] ??
                '',
        'tgl_mulai_forum': doc
                .querySelector('input[name="tgl_mulai_forum"]')
                ?.attributes['value'] ??
            '',
        'jam_mulai_forum': doc
                .querySelector('input[name="jam_mulai_forum"]')
                ?.attributes['value'] ??
            '',
        'tgl_akhir_forum': doc
                .querySelector('input[name="tgl_akhir_forum"]')
                ?.attributes['value'] ??
            '',
        'jam_akhir_forum': doc
                .querySelector('input[name="jam_akhir_forum"]')
                ?.attributes['value'] ??
            '',
      };
    } catch (e) {
      print('Error fetching tambah forum form: $e');
      return null;
    }
  }

  Future<String?> submitTambahForum({
    required Map<String, String> formMeta,
    required String namaForum,
    required String keterangan,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final response = await _dio.post(
        '/member_forum/tambah_proses',
        data: {
          'csrf_token': formMeta['csrf_token'] ?? '',
          '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
          'h_kode': formMeta['h_kode'] ?? '',
          'nama_forum': namaForum,
          'keterangan': '<p>$keterangan</p>',
          'tgl_mulai_forum': formMeta['tgl_mulai_forum'] ?? '',
          'jam_mulai_forum': formMeta['jam_mulai_forum'] ?? '',
          'tgl_akhir_forum': formMeta['tgl_akhir_forum'] ?? '',
          'jam_akhir_forum': formMeta['jam_akhir_forum'] ?? '',
          'btn_simpan': 'Simpan',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return 'Forum berhasil ditambahkan';
      }
      return null;
    } catch (e) {
      print('Error submit tambah forum: $e');
      return null;
    }
  }

  Future<Map<String, String>?> fetchTambahChatForm(String urlOrPath) async {
    try {
      final html = await fetchPageByUrl(urlOrPath);
      if (html == null || html.isEmpty) return null;

      final doc = html_parser.parse(html);
      return {
        'csrf_token': doc
                .querySelector('input[name="csrf_token"]')
                ?.attributes['value'] ??
            '',
        'hidden_token': doc
                .querySelector(
                  'input[name="0e59f85937eebefad004de3c21e9c6ae"]',
                )
                ?.attributes['value'] ??
            '',
        'h_kode':
            doc.querySelector('input[name="h_kode"]')?.attributes['value'] ??
                '',
        'tgl_mulai_chat': doc
                .querySelector('input[name="tgl_mulai_chat"]')
                ?.attributes['value'] ??
            '',
        'jam_mulai_chat': doc
                .querySelector('input[name="jam_mulai_chat"]')
                ?.attributes['value'] ??
            '',
        'tgl_akhir_chat': doc
                .querySelector('input[name="tgl_akhir_chat"]')
                ?.attributes['value'] ??
            '',
        'jam_akhir_chat': doc
                .querySelector('input[name="jam_akhir_chat"]')
                ?.attributes['value'] ??
            '',
      };
    } catch (e) {
      print('Error fetching tambah chat form: $e');
      return null;
    }
  }

  Future<String?> submitTambahChat({
    required Map<String, String> formMeta,
    required String namaChatroom,
    required String keterangan,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final response = await _dio.post(
        '/member_chat/tambah_proses',
        data: {
          'csrf_token': formMeta['csrf_token'] ?? '',
          '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
          'h_kode': formMeta['h_kode'] ?? '',
          'nama_chatroom': namaChatroom,
          'keterangan': '<p>$keterangan</p>',
          'tgl_mulai_chat': formMeta['tgl_mulai_chat'] ?? '',
          'jam_mulai_chat': formMeta['jam_mulai_chat'] ?? '',
          'tgl_akhir_chat': formMeta['tgl_akhir_chat'] ?? '',
          'jam_akhir_chat': formMeta['jam_akhir_chat'] ?? '',
          'btn_simpan': 'Simpan',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return 'Chat room berhasil ditambahkan';
      }
      return null;
    } catch (e) {
      print('Error submit tambah chat: $e');
      return null;
    }
  }

  Future<Map<String, String>?> fetchTambahQuizForm(String urlOrPath) async {
    try {
      final html = await fetchPageByUrl(urlOrPath);
      if (html == null || html.isEmpty) return null;

      final doc = html_parser.parse(html);
      String selectedValue(String name, {String fallback = ''}) {
        final select = doc.querySelector('select[name="$name"]');
        final selected = select?.querySelector('option[selected]');
        if (selected != null) {
          return selected.attributes['value'] ?? selected.text.trim();
        }
        final first = select?.querySelector('option');
        if (first != null) {
          return first.attributes['value'] ?? first.text.trim();
        }
        return fallback;
      }

      return {
        'csrf_token': doc
                .querySelector('input[name="csrf_token"]')
                ?.attributes['value'] ??
            '',
        'hidden_token': doc
                .querySelector(
                  'input[name="0e59f85937eebefad004de3c21e9c6ae"]',
                )
                ?.attributes['value'] ??
            '',
        'h_kode':
            doc.querySelector('input[name="h_kode"]')?.attributes['value'] ??
                '',
        'kategori_quiz': selectedValue('kategori_quiz', fallback: 'objektif'),
        'tampil_soal': selectedValue('tampil_soal', fallback: 'all'),
        'sifat_quiz': selectedValue('sifat_quiz', fallback: '1'),
        'quiz_media': doc
                .querySelector('input[name="quiz_media"]')
                ?.attributes['value'] ??
            'WEB',
        'tgl_mulai_quiz': doc
                .querySelector('input[name="tgl_mulai_quiz"]')
                ?.attributes['value'] ??
            '',
        'jam_mulai_quiz': doc
                .querySelector('input[name="jam_mulai_quiz"]')
                ?.attributes['value'] ??
            '',
        'tgl_akhir_quiz': doc
                .querySelector('input[name="tgl_akhir_quiz"]')
                ?.attributes['value'] ??
            '',
        'jam_akhir_quiz': doc
                .querySelector('input[name="jam_akhir_quiz"]')
                ?.attributes['value'] ??
            '',
      };
    } catch (e) {
      print('Error fetching tambah quiz form: $e');
      return null;
    }
  }

  Future<String?> submitTambahQuiz({
    required Map<String, String> formMeta,
    required String namaQuiz,
    required String instruksi,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final response = await _dio.post(
        '/member_quiz/tambah_proses',
        data: {
          'csrf_token': formMeta['csrf_token'] ?? '',
          '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
          'h_kode': formMeta['h_kode'] ?? '',
          'nama_quiz': namaQuiz,
          'kategori_quiz': formMeta['kategori_quiz'] ?? 'objektif',
          'tampil_soal': formMeta['tampil_soal'] ?? 'all',
          'sifat_quiz': formMeta['sifat_quiz'] ?? '1',
          'quiz_media': formMeta['quiz_media'] ?? 'WEB',
          'instruksi': '<p>$instruksi</p>',
          'tgl_mulai_quiz': formMeta['tgl_mulai_quiz'] ?? '',
          'jam_mulai_quiz': formMeta['jam_mulai_quiz'] ?? '',
          'tgl_akhir_quiz': formMeta['tgl_akhir_quiz'] ?? '',
          'jam_akhir_quiz': formMeta['jam_akhir_quiz'] ?? '',
          'btn_simpan': 'Simpan',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return 'Quiz berhasil ditambahkan';
      }
      return null;
    } catch (e) {
      print('Error submit tambah quiz: $e');
      return null;
    }
  }

  Future<Map<String, String>?> fetchUploadFileForm(String urlOrPath) async {
    try {
      final html = await fetchPageByUrl(urlOrPath);
      if (html == null || html.isEmpty) return null;

      final doc = html_parser.parse(html);
      return {
        'csrf_token': doc
                .querySelector('form#formUpload input[name="csrf_token"]')
                ?.attributes['value'] ??
            '',
        'hidden_token': doc
                .querySelector(
                  'form#formUpload input[name="0e59f85937eebefad004de3c21e9c6ae"]',
                )
                ?.attributes['value'] ??
            '',
        'h_kode': doc
                .querySelector('form#formUpload input[name="h_kode"]')
                ?.attributes['value'] ??
            '',
        'h_kd_jdw_enc': doc
                .querySelector('form#formUpload input[name="h_kd_jdw_enc"]')
                ?.attributes['value'] ??
            '',
      };
    } catch (e) {
      print('Error fetching upload file form: $e');
      return null;
    }
  }

  Future<String?> uploadMateriFileDosen({
    required Map<String, String> formMeta,
    required String filePath,
    required String fileName,
    required String namaFile,
    required String keterangan,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();

      final formData = FormData.fromMap({
        'csrf_token': formMeta['csrf_token'] ?? '',
        '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
        'h_kode': formMeta['h_kode'] ?? '',
        'h_kd_jdw_enc': formMeta['h_kd_jdw_enc'] ?? '',
        'nama_file': namaFile,
        'keterangan': '<p>$keterangan</p>',
        'myfile[]': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        '/member_file/upload_file_proses',
        data: formData,
        options: Options(
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return 'Upload file berhasil';
      }

      return null;
    } catch (e) {
      print('Error upload materi file dosen: $e');
      return null;
    }
  }

  Future<Map<String, String>?> fetchUploadAudioForm(String urlOrPath) async {
    try {
      final html = await fetchPageByUrl(urlOrPath);
      if (html == null || html.isEmpty) return null;

      final doc = html_parser.parse(html);
      return {
        'csrf_token': doc
                .querySelector('form#formUpload input[name="csrf_token"]')
                ?.attributes['value'] ??
            '',
        'hidden_token': doc
                .querySelector(
                  'form#formUpload input[name="0e59f85937eebefad004de3c21e9c6ae"]',
                )
                ?.attributes['value'] ??
            '',
        'h_kode': doc
                .querySelector('form#formUpload input[name="h_kode"]')
                ?.attributes['value'] ??
            '',
      };
    } catch (e) {
      print('Error fetching upload audio form: $e');
      return null;
    }
  }

  Future<String?> uploadMateriAudioDosen({
    required Map<String, String> formMeta,
    required String filePath,
    required String fileName,
    required String namaFile,
    required String keterangan,
  }) async {
    return _uploadMateriByEndpoint(
      endpoint: '/member_audio/upload_file_proses',
      successMessage: 'Upload audio berhasil',
      formMeta: formMeta,
      filePath: filePath,
      fileName: fileName,
      namaFile: namaFile,
      keterangan: keterangan,
    );
  }

  Future<Map<String, String>?> fetchUploadVideoForm(String urlOrPath) async {
    try {
      final html = await fetchPageByUrl(urlOrPath);
      if (html == null || html.isEmpty) return null;

      final doc = html_parser.parse(html);
      return {
        'csrf_token': doc
                .querySelector('form#formUpload input[name="csrf_token"]')
                ?.attributes['value'] ??
            '',
        'hidden_token': doc
                .querySelector(
                  'form#formUpload input[name="0e59f85937eebefad004de3c21e9c6ae"]',
                )
                ?.attributes['value'] ??
            '',
        'h_kode': doc
                .querySelector('form#formUpload input[name="h_kode"]')
                ?.attributes['value'] ??
            '',
      };
    } catch (e) {
      print('Error fetching upload video form: $e');
      return null;
    }
  }

  Future<String?> uploadMateriVideoDosen({
    required Map<String, String> formMeta,
    required String filePath,
    required String fileName,
    required String namaFile,
    required String keterangan,
  }) async {
    return _uploadMateriByEndpoint(
      endpoint: '/member_video/upload_file_proses',
      successMessage: 'Upload video berhasil',
      formMeta: formMeta,
      filePath: filePath,
      fileName: fileName,
      namaFile: namaFile,
      keterangan: keterangan,
    );
  }

  Future<Map<String, String>?> fetchTambahPageForm(String urlOrPath) async {
    try {
      final html = await fetchPageByUrl(urlOrPath);
      if (html == null || html.isEmpty) return null;

      final doc = html_parser.parse(html);
      return {
        'csrf_token': doc
                .querySelector('input[name="csrf_token"]')
                ?.attributes['value'] ??
            '',
        'hidden_token': doc
                .querySelector(
                  'input[name="0e59f85937eebefad004de3c21e9c6ae"]',
                )
                ?.attributes['value'] ??
            '',
        'h_kode':
            doc.querySelector('input[name="h_kode"]')?.attributes['value'] ??
                '',
      };
    } catch (e) {
      print('Error fetching tambah page form: $e');
      return null;
    }
  }

  Future<String?> submitTambahPage({
    required Map<String, String> formMeta,
    required String namaPage,
    required String keterangan,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final response = await _dio.post(
        '/member_page/tambah_proses',
        data: {
          'csrf_token': formMeta['csrf_token'] ?? '',
          '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
          'h_kode': formMeta['h_kode'] ?? '',
          'nama_page': namaPage,
          'keterangan': '<p>$keterangan</p>',
          'btn_simpan': 'Simpan',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return 'Page berhasil ditambahkan';
      }
      return null;
    } catch (e) {
      print('Error submit tambah page: $e');
      return null;
    }
  }

  Future<Map<String, String>?> fetchTambahUrlEksternalForm(
      String urlOrPath) async {
    try {
      final html = await fetchPageByUrl(urlOrPath);
      if (html == null || html.isEmpty) return null;

      final doc = html_parser.parse(html);
      return {
        'csrf_token': doc
                .querySelector('input[name="csrf_token"]')
                ?.attributes['value'] ??
            '',
        'hidden_token': doc
                .querySelector(
                  'input[name="0e59f85937eebefad004de3c21e9c6ae"]',
                )
                ?.attributes['value'] ??
            '',
        'h_kode':
            doc.querySelector('input[name="h_kode"]')?.attributes['value'] ??
                '',
      };
    } catch (e) {
      print('Error fetching tambah url eksternal form: $e');
      return null;
    }
  }

  Future<String?> submitTambahUrlEksternal({
    required Map<String, String> formMeta,
    required String namaUrl,
    required String urlEksternal,
    required String keterangan,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final response = await _dio.post(
        '/member_url/tambah_proses',
        data: {
          'csrf_token': formMeta['csrf_token'] ?? '',
          '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
          'h_kode': formMeta['h_kode'] ?? '',
          'nama_url': namaUrl,
          'url_eksternal': urlEksternal,
          'keterangan': '<p>$keterangan</p>',
          'btn_simpan': 'Simpan',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return 'URL eksternal berhasil ditambahkan';
      }
      return null;
    } catch (e) {
      print('Error submit tambah url eksternal: $e');
      return null;
    }
  }

  Future<Map<String, String>?> fetchTambahPeerAssessmentForm(
      String urlOrPath) async {
    try {
      final html = await fetchPageByUrl(urlOrPath);
      if (html == null || html.isEmpty) return null;

      final doc = html_parser.parse(html);
      final peerOptions = doc
          .querySelectorAll('select[name="tugas_id_peer"] option')
          .map(
            (option) => {
              'value': option.attributes['value'] ?? '',
              'label': option.text.trim(),
            },
          )
          .where((item) => (item['value'] ?? '').isNotEmpty)
          .toList();

      return {
        'csrf_token': doc
                .querySelector('input[name="csrf_token"]')
                ?.attributes['value'] ??
            '',
        'hidden_token': doc
                .querySelector(
                  'input[name="0e59f85937eebefad004de3c21e9c6ae"]',
                )
                ?.attributes['value'] ??
            '',
        'h_kode':
            doc.querySelector('input[name="h_kode"]')?.attributes['value'] ??
                '',
        'tgl_mulai_peer': doc
                .querySelector('input[name="tgl_mulai_peer"]')
                ?.attributes['value'] ??
            '',
        'jam_mulai_peer': doc
                .querySelector('input[name="jam_mulai_peer"]')
                ?.attributes['value'] ??
            '',
        'tgl_akhir_peer': doc
                .querySelector('input[name="tgl_akhir_peer"]')
                ?.attributes['value'] ??
            '',
        'jam_akhir_peer': doc
                .querySelector('input[name="jam_akhir_peer"]')
                ?.attributes['value'] ??
            '',
        'peer_options_json': jsonEncode(peerOptions),
      };
    } catch (e) {
      print('Error fetching tambah peer assessment form: $e');
      return null;
    }
  }

  Future<String?> submitTambahPeerAssessment({
    required Map<String, String> formMeta,
    required String tugasIdPeer,
    required String tglMulai,
    required String jamMulai,
    required String tglAkhir,
    required String jamAkhir,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final response = await _dio.post(
        '/member_peer_evaluation/tambah_proses',
        data: {
          'csrf_token': formMeta['csrf_token'] ?? '',
          '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
          'h_kode': formMeta['h_kode'] ?? '',
          'tugas_id_peer': tugasIdPeer,
          'tgl_mulai_peer': tglMulai,
          'jam_mulai_peer': jamMulai,
          'tgl_akhir_peer': tglAkhir,
          'jam_akhir_peer': jamAkhir,
          'btn_simpan': 'Simpan',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return 'Peer assessment berhasil ditambahkan';
      }
      return null;
    } catch (e) {
      print('Error submit tambah peer assessment: $e');
      return null;
    }
  }

  Future<Map<String, String>?> fetchTambahTugasAssignmentForm(
      String urlOrPath) async {
    try {
      final html = await fetchPageByUrl(urlOrPath);
      if (html == null || html.isEmpty) return null;

      final doc = html_parser.parse(html);
      final kategoriOptions = doc
          .querySelectorAll('select[name="tugas_untuk"] option')
          .map(
            (option) => {
              'value': option.attributes['value'] ?? '',
              'label': option.text.trim(),
            },
          )
          .where((item) => (item['value'] ?? '').isNotEmpty)
          .toList();

      return {
        'csrf_token': doc
                .querySelector('input[name="csrf_token"]')
                ?.attributes['value'] ??
            '',
        'hidden_token': doc
                .querySelector(
                  'input[name="0e59f85937eebefad004de3c21e9c6ae"]',
                )
                ?.attributes['value'] ??
            '',
        'h_kode':
            doc.querySelector('input[name="h_kode"]')?.attributes['value'] ??
                '',
        'tgl_mulai_tugas': doc
                .querySelector('input[name="tgl_mulai_tugas"]')
                ?.attributes['value'] ??
            '',
        'jam_mulai_tugas': doc
                .querySelector('input[name="jam_mulai_tugas"]')
                ?.attributes['value'] ??
            '',
        'tgl_akhir_tugas': doc
                .querySelector('input[name="tgl_akhir_tugas"]')
                ?.attributes['value'] ??
            '',
        'jam_akhir_tugas': doc
                .querySelector('input[name="jam_akhir_tugas"]')
                ?.attributes['value'] ??
            '',
        'tugas_untuk_options_json': jsonEncode(kategoriOptions),
      };
    } catch (e) {
      print('Error fetching tambah tugas assignment form: $e');
      return null;
    }
  }

  Future<String?> uploadTugasAssignmentFile({
    required Map<String, String> formMeta,
    required String filePath,
    required String fileName,
    required String namaTugas,
    required String tugasUntuk,
    required String keterangan,
    required String tglMulai,
    required String jamMulai,
    required String tglAkhir,
    required String jamAkhir,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final formData = FormData.fromMap({
        'csrf_token': formMeta['csrf_token'] ?? '',
        '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
        'h_kode': formMeta['h_kode'] ?? '',
        'nama_tugas': namaTugas,
        'tugas_untuk': tugasUntuk,
        'keterangan': '<p>$keterangan</p>',
        'isi_keterangan': '<p>$keterangan</p>',
        'tgl_mulai_tugas': tglMulai,
        'jam_mulai_tugas': jamMulai,
        'tgl_akhir_tugas': tglAkhir,
        'jam_akhir_tugas': jamAkhir,
        'btn_simpan': 'Simpan',
        'myfile': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        '/member_tugas/upload_file_proses',
        data: formData,
        options: Options(
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return response.data?.toString().trim();
      }
      return null;
    } catch (e) {
      print('Error upload tugas assignment file: $e');
      return null;
    }
  }

  Future<String?> submitTambahTugasAssignment({
    required Map<String, String> formMeta,
    required String namaTugas,
    required String tugasUntuk,
    required String keterangan,
    required String tglMulai,
    required String jamMulai,
    required String tglAkhir,
    required String jamAkhir,
    String? tugasFile,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final response = await _dio.post(
        '/member_tugas/tambah_proses',
        data: {
          'csrf_token': formMeta['csrf_token'] ?? '',
          '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
          'h_kode': formMeta['h_kode'] ?? '',
          'nama_tugas': namaTugas,
          'tugas_untuk': tugasUntuk,
          'keterangan': '<p>$keterangan</p>',
          'tugas_file': tugasFile ?? '',
          'tgl_mulai_tugas': tglMulai,
          'jam_mulai_tugas': jamMulai,
          'tgl_akhir_tugas': tglAkhir,
          'jam_akhir_tugas': jamAkhir,
          'btn_simpan': 'Simpan',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return 'Tugas assignment berhasil ditambahkan';
      }
      return null;
    } catch (e) {
      print('Error submit tambah tugas assignment: $e');
      return null;
    }
  }

  Future<Map<String, String>?> fetchTambahTugasKolaborasiForm(
      String urlOrPath) async {
    try {
      final html = await fetchPageByUrl(urlOrPath);
      if (html == null || html.isEmpty) return null;

      final doc = html_parser.parse(html);
      final kategoriOptions = doc
          .querySelectorAll('select[name="tugas_untuk"] option')
          .map(
            (option) => {
              'value': option.attributes['value'] ?? '',
              'label': option.text.trim(),
            },
          )
          .where((item) => (item['value'] ?? '').isNotEmpty)
          .toList();
      final kelompokOptions = doc
          .querySelectorAll('select[name="mak_per_kelompok"] option')
          .map(
            (option) => {
              'value': option.attributes['value'] ?? '',
              'label': option.text.trim(),
            },
          )
          .where((item) => (item['value'] ?? '').isNotEmpty)
          .toList();

      return {
        'csrf_token': doc
                .querySelector('input[name="csrf_token"]')
                ?.attributes['value'] ??
            '',
        'hidden_token': doc
                .querySelector(
                  'input[name="0e59f85937eebefad004de3c21e9c6ae"]',
                )
                ?.attributes['value'] ??
            '',
        'h_kode':
            doc.querySelector('input[name="h_kode"]')?.attributes['value'] ??
                '',
        'tgl_mulai_tugas': doc
                .querySelector('input[name="tgl_mulai_tugas"]')
                ?.attributes['value'] ??
            '',
        'jam_mulai_tugas': doc
                .querySelector('input[name="jam_mulai_tugas"]')
                ?.attributes['value'] ??
            '',
        'tgl_akhir_tugas': doc
                .querySelector('input[name="tgl_akhir_tugas"]')
                ?.attributes['value'] ??
            '',
        'jam_akhir_tugas': doc
                .querySelector('input[name="jam_akhir_tugas"]')
                ?.attributes['value'] ??
            '',
        'tugas_untuk_options_json': jsonEncode(kategoriOptions),
        'mak_per_kelompok_options_json': jsonEncode(kelompokOptions),
      };
    } catch (e) {
      print('Error fetching tambah tugas kolaborasi form: $e');
      return null;
    }
  }

  Future<String?> uploadTugasKolaborasiFile({
    required Map<String, String> formMeta,
    required String filePath,
    required String fileName,
    required String namaTugas,
    required String tugasUntuk,
    required String makPerKelompok,
    required String keterangan,
    required String tglMulai,
    required String jamMulai,
    required String tglAkhir,
    required String jamAkhir,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final formData = FormData.fromMap({
        'csrf_token': formMeta['csrf_token'] ?? '',
        '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
        'h_kode': formMeta['h_kode'] ?? '',
        'nama_tugas': namaTugas,
        'tugas_untuk': tugasUntuk,
        'mak_per_kelompok': makPerKelompok,
        'keterangan': '<p>$keterangan</p>',
        'isi_keterangan': '<p>$keterangan</p>',
        'tgl_mulai_tugas': tglMulai,
        'jam_mulai_tugas': jamMulai,
        'tgl_akhir_tugas': tglAkhir,
        'jam_akhir_tugas': jamAkhir,
        'btn_simpan': 'Simpan',
        'myfile': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        '/member_tugas_kolaborasi/upload_file_proses',
        data: formData,
        options: Options(
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return response.data?.toString().trim();
      }
      return null;
    } catch (e) {
      print('Error upload tugas kolaborasi file: $e');
      return null;
    }
  }

  Future<String?> submitTambahTugasKolaborasi({
    required Map<String, String> formMeta,
    required String namaTugas,
    required String tugasUntuk,
    required String makPerKelompok,
    required String keterangan,
    required String tglMulai,
    required String jamMulai,
    required String tglAkhir,
    required String jamAkhir,
    String? tugasFile,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final response = await _dio.post(
        '/member_tugas_kolaborasi/tambah_proses',
        data: {
          'csrf_token': formMeta['csrf_token'] ?? '',
          '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
          'h_kode': formMeta['h_kode'] ?? '',
          'nama_tugas': namaTugas,
          'tugas_untuk': tugasUntuk,
          'mak_per_kelompok': makPerKelompok,
          'keterangan': '<p>$keterangan</p>',
          'tugas_file': tugasFile ?? '',
          'tgl_mulai_tugas': tglMulai,
          'jam_mulai_tugas': jamMulai,
          'tgl_akhir_tugas': tglAkhir,
          'jam_akhir_tugas': jamAkhir,
          'btn_simpan': 'Simpan',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return 'Tugas kolaborasi berhasil ditambahkan';
      }
      return null;
    } catch (e) {
      print('Error submit tambah tugas kolaborasi: $e');
      return null;
    }
  }

  Future<Map<String, String>?> fetchTambahYoutubeForm(String urlOrPath) async {
    try {
      final html = await fetchPageByUrl(urlOrPath);
      if (html == null || html.isEmpty) return null;

      final doc = html_parser.parse(html);
      return {
        'csrf_token': doc
                .querySelector('input[name="csrf_token"]')
                ?.attributes['value'] ??
            '',
        'hidden_token': doc
                .querySelector(
                  'input[name="0e59f85937eebefad004de3c21e9c6ae"]',
                )
                ?.attributes['value'] ??
            '',
        'h_kode':
            doc.querySelector('input[name="h_kode"]')?.attributes['value'] ??
                '',
      };
    } catch (e) {
      print('Error fetching tambah youtube form: $e');
      return null;
    }
  }

  Future<String?> submitTambahYoutube({
    required Map<String, String> formMeta,
    required String urlYoutube,
    required String keterangan,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final response = await _dio.post(
        '/member_video/upload_ytb_proses',
        data: {
          'csrf_token': formMeta['csrf_token'] ?? '',
          '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
          'h_kode': formMeta['h_kode'] ?? '',
          'url_youtube': urlYoutube,
          'keterangan': keterangan,
          'btn_simpan': 'Simpan',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return 'URL YouTube berhasil ditambahkan';
      }
      return null;
    } catch (e) {
      print('Error submit tambah youtube: $e');
      return null;
    }
  }

  Future<Map<String, String>?> fetchTambahZoomMeetingForm(
      String urlOrPath) async {
    return fetchTambahUrlEksternalForm(urlOrPath);
  }

  Future<String?> submitTambahZoomMeeting({
    required Map<String, String> formMeta,
    required String namaUrl,
    required String urlZoom,
    required String keterangan,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final response = await _dio.post(
        '/member_url/tambah_zoom_proses',
        data: {
          'csrf_token': formMeta['csrf_token'] ?? '',
          '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
          'h_kode': formMeta['h_kode'] ?? '',
          'nama_url': namaUrl,
          'url_zoom': urlZoom,
          'keterangan': '<p>$keterangan</p>',
          'btn_simpan': 'Simpan',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return 'Zoom meeting berhasil ditambahkan';
      }
      return null;
    } catch (e) {
      print('Error submit tambah zoom meeting: $e');
      return null;
    }
  }

  Future<Map<String, String>?> fetchTambahAutodrawForm(String urlOrPath) async {
    return fetchTambahUrlEksternalForm(urlOrPath);
  }

  Future<String?> submitTambahAutodraw({
    required Map<String, String> formMeta,
    required String namaUrl,
    required String urlDraw,
    required String keterangan,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final response = await _dio.post(
        '/member_draw/tambah_proses',
        data: {
          'csrf_token': formMeta['csrf_token'] ?? '',
          '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
          'h_kode': formMeta['h_kode'] ?? '',
          'nama_url': namaUrl,
          'url_draw': urlDraw,
          'keterangan': '<p>$keterangan</p>',
          'btn_simpan': 'Simpan',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return 'Autodraw berhasil ditambahkan';
      }
      return null;
    } catch (e) {
      print('Error submit tambah autodraw: $e');
      return null;
    }
  }

  Future<Map<String, String>?> fetchTambahCanvaForm(String urlOrPath) async {
    return fetchTambahUrlEksternalForm(urlOrPath);
  }

  Future<String?> submitTambahCanva({
    required Map<String, String> formMeta,
    required String namaUrl,
    required String urlCanva,
    required String keterangan,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final response = await _dio.post(
        '/member_canva/tambah_proses',
        data: {
          'csrf_token': formMeta['csrf_token'] ?? '',
          '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
          'h_kode': formMeta['h_kode'] ?? '',
          'nama_url': namaUrl,
          'url_canva': urlCanva,
          'keterangan': '<p>$keterangan</p>',
          'btn_simpan': 'Simpan',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return 'Canva berhasil ditambahkan';
      }
      return null;
    } catch (e) {
      print('Error submit tambah canva: $e');
      return null;
    }
  }

  Future<String?> _uploadMateriByEndpoint({
    required String endpoint,
    required String successMessage,
    required Map<String, String> formMeta,
    required String filePath,
    required String fileName,
    required String namaFile,
    required String keterangan,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      final formData = FormData.fromMap({
        'csrf_token': formMeta['csrf_token'] ?? '',
        '0e59f85937eebefad004de3c21e9c6ae': formMeta['hidden_token'] ?? '',
        'h_kode': formMeta['h_kode'] ?? '',
        'nama_file': namaFile,
        'keterangan': keterangan,
        'myfile': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        return successMessage;
      }
      return null;
    } catch (e) {
      print('Error upload materi endpoint $endpoint: $e');
      return null;
    }
  }

  Future<String> _buildCookieHeader() async {
    String cookieHeader = '';
    if (_ciSession != null) {
      cookieHeader = 'ci_session=$_ciSession';
    }

    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('colek_member_remember') ?? false;
    if (remember) {
      final username = prefs.getString('colek_member_username');
      final password = prefs.getString('colek_member_pswd');
      if (username != null && password != null) {
        if (cookieHeader.isNotEmpty) cookieHeader += '; ';
        cookieHeader +=
            'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
      }
    }

    return cookieHeader;
  }

  Future<String?> downloadFile(
    String encryptedUrl,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      await _dio.download(
        '/pertemuan/force_download/$encryptedUrl',
        savePath,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      return savePath;
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }

  Future<String?> fetchPresensiPage() async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final response = await _dio.get(
        '/presensi',
        options: Options(
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data as String;
      }

      return null;
    } catch (e) {
      print('Error fetching presensi page: $e');
      return null;
    }
  }

  Future<String?> fetchLaporanPage() async {
    return fetchPageByUrl('/rps');
  }

  Future<String?> generateRps(String kode) async {
    try {
      final cookieHeader = await _buildCookieHeader();

      final response = await _dio.post(
        '/rps/generate_rps',
        data: {
          'kode': kode,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final raw = response.data?.toString() ?? '';
      if (raw.trim().isEmpty) return null;

      final plain = html_parser
          .parse(raw)
          .documentElement
          ?.text
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      return (plain == null || plain.isEmpty) ? raw.trim() : plain;
    } catch (e) {
      print('Error generate rps: $e');
      return null;
    }
  }

  Future<String?> generateRpsPdf(String kdJdw) async {
    try {
      final cookieHeader = await _buildCookieHeader();

      final response = await _dio.post(
        '/rps_cetak/pdf_rps',
        data: {
          'kd_jdw': kdJdw,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode != 200) return null;

      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        final status = payload['status'];
        final namaFile = payload['namaFile']?.toString();
        if ((status == true || status == 'true') &&
            namaFile != null &&
            namaFile.isNotEmpty) {
          return namaFile;
        }
      }

      if (payload is String) {
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            final status = decoded['status'];
            final namaFile = decoded['namaFile']?.toString();
            if ((status == true || status == 'true') &&
                namaFile != null &&
                namaFile.isNotEmpty) {
              return namaFile;
            }
          }
        } catch (_) {
          return null;
        }
      }

      return null;
    } catch (e) {
      print('Error generate rps pdf: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchRpsEditFormData(String kode) async {
    try {
      final cookieHeader = await _buildCookieHeader();

      final response = await _dio.post(
        '/rps/ubah_rps',
        data: {
          'kode': kode,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode != 200) return null;

      final html = response.data?.toString() ?? '';
      if (html.trim().isEmpty) return null;

      final doc = html_parser.parse(html);
      final form =
          doc.querySelector('form#form_rps') ?? doc.querySelector('form');
      if (form == null) return null;

      final action =
          (form.attributes['action'] ?? '/rps/realisasi_rps_proses').trim();

      final fields = <String, String>{};

      for (final input in form.querySelectorAll('input')) {
        final name = (input.attributes['name'] ?? '').trim();
        if (name.isEmpty) continue;

        final type = (input.attributes['type'] ?? 'text').toLowerCase();
        if (type == 'checkbox') {
          final checked = input.attributes.containsKey('checked');
          fields[name] = checked ? (input.attributes['value'] ?? 'Y') : '';
        } else {
          fields[name] = input.attributes['value'] ?? '';
        }
      }

      for (final textarea in form.querySelectorAll('textarea')) {
        final name = (textarea.attributes['name'] ?? '').trim();
        if (name.isEmpty) continue;
        fields[name] = textarea.text.trim();
      }

      final options = <String>{};
      for (final select in form.querySelectorAll('select')) {
        final name = (select.attributes['name'] ?? '').trim();
        if (name.isEmpty) continue;

        String selectedValue = '';
        for (final option in select.querySelectorAll('option')) {
          final value = (option.attributes['value'] ?? option.text).trim();
          final label = option.text.trim();
          if (value.isNotEmpty && label != '--Pilih Ruang--') {
            options.add(value);
          }
          if (option.attributes.containsKey('selected')) {
            selectedValue = value;
          }
        }

        if (selectedValue.isEmpty) {
          final selectedOption = select.querySelector('option[selected]');
          if (selectedOption != null) {
            selectedValue = (selectedOption.attributes['value'] ?? '').trim();
          }

          if (selectedValue.isEmpty) {
            for (final option in select.querySelectorAll('option')) {
              final value = (option.attributes['value'] ?? '').trim();
              if (value.isNotEmpty) {
                selectedValue = value;
                break;
              }
            }
          }

          if (selectedValue.isEmpty) {
            final firstOption = select.querySelector('option');
            if (firstOption != null) {
              selectedValue =
                  (firstOption.attributes['value'] ?? firstOption.text).trim();
            }
          }
        }

        fields[name] = selectedValue;
      }

      return {
        'action': action,
        'fields': fields,
        'ruangan_options': options.toList(),
      };
    } catch (e) {
      print('Error fetching rps edit form: $e');
      return null;
    }
  }

  Future<bool> submitRpsEditForm({
    required String actionUrl,
    required Map<String, String> fields,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();

      final target = actionUrl.trim().isEmpty
          ? '/rps/realisasi_rps_proses'
          : actionUrl.trim();

      final response = await _dio.post(
        target,
        data: fields,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      return response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303;
    } catch (e) {
      print('Error submit rps edit form: $e');
      return false;
    }
  }

  Future<bool> deleteRpsPertemuan(String href) async {
    try {
      final cookieHeader = await _buildCookieHeader();

      String target = href.trim();
      if (target.isEmpty) return false;

      final uri = Uri.tryParse(target);
      if (uri != null &&
          uri.hasScheme &&
          uri.host.contains('lms.unindra.ac.id')) {
        target = uri.path.isEmpty ? '/' : uri.path;
        if (uri.hasQuery) {
          target = '$target?${uri.query}';
        }
      }

      final response = await _dio.get(
        target,
        options: Options(
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      return response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303;
    } catch (e) {
      print('Error delete rps pertemuan: $e');
      return false;
    }
  }

  Future<String?> fetchPageByUrl(String urlOrPath) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      String target = urlOrPath.trim();
      if (target.isEmpty) return null;

      final parsed = Uri.tryParse(target);
      if (parsed != null &&
          parsed.hasScheme &&
          parsed.host.contains('lms.unindra.ac.id')) {
        final path = parsed.path.isEmpty ? '/' : parsed.path;
        final query = parsed.hasQuery ? '?${parsed.query}' : '';
        target = '$path$query';
      }

      final response = await _dio.get(
        target,
        options: Options(
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data.toString();
      }

      final body = response.data?.toString() ?? '';
      if (body.trim().isNotEmpty) {
        return body;
      }

      if ((response.statusCode == 301 ||
              response.statusCode == 302 ||
              response.statusCode == 303) &&
          (response.headers.value('location') ?? '').isNotEmpty) {
        final location = response.headers.value('location')!;
        final redirected = await _dio.get(
          location,
          options: Options(
            headers: {
              'Cookie': cookieHeader,
            },
          ),
        );

        if (redirected.statusCode == 200) {
          return redirected.data.toString();
        }
      }

      return null;
    } catch (e) {
      // Retry once with URL-encoded target for paths containing special chars.
      try {
        String cookieHeader = '';
        if (_ciSession != null) {
          cookieHeader = 'ci_session=$_ciSession';
        }

        final prefs = await SharedPreferences.getInstance();
        final remember = prefs.getBool('colek_member_remember') ?? false;
        if (remember) {
          final username = prefs.getString('colek_member_username');
          final password = prefs.getString('colek_member_pswd');
          if (username != null && password != null) {
            if (cookieHeader.isNotEmpty) cookieHeader += '; ';
            cookieHeader +=
                'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
          }
        }

        final fallbackTarget = Uri.encodeFull(urlOrPath.trim());
        if (fallbackTarget.isNotEmpty) {
          final retry = await _dio.get(
            fallbackTarget,
            options: Options(
              headers: {
                'Cookie': cookieHeader,
              },
            ),
          );

          final retryBody = retry.data?.toString() ?? '';
          if (retryBody.trim().isNotEmpty) {
            return retryBody;
          }
        }
      } catch (_) {
        // ignore secondary failure and continue returning null
      }

      print('Error fetching page by url: $e');
      return null;
    }
  }

  Future<String?> fetchPresensiMonitoringTu(String kode) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final response = await _dio.post(
        '/presensi/monitoring_tu',
        data: {
          'kode': kode,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data.toString();
      }

      return null;
    } catch (e) {
      print('Error fetching monitoring TU: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchPresensiPeserta(
      String kdJdw, String pertemuan) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final response = await _dio.post(
        '/presensi/list_peserta',
        data: {
          'kd_jdw': kdJdw,
          'pertemuan': pertemuan,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        return payload;
      }

      if (payload is String) {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }

      return null;
    } catch (e) {
      print('Error fetching presensi peserta: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> simpanPresensiPeserta({
    required String kdJdw,
    required String pertemuan,
    required List<Map<String, dynamic>> peserta,
  }) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final formData = <String, dynamic>{
        'h_kd_jdw': kdJdw,
        'h_pertemuan': pertemuan,
        'nim_absen[]': peserta.map((e) => (e['nim'] ?? '').toString()).toList(),
        'cek[]': peserta
            .where((e) => e['hadir'] == true)
            .map((e) => (e['nim'] ?? '').toString())
            .toList(),
        'ket[]': peserta.map((e) => (e['ket'] ?? '').toString()).toList(),
      };

      final response = await _dio.post(
        '/presensi/simpan_data',
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        return payload;
      }

      if (payload is String) {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }

      return null;
    } catch (e) {
      print('Error saving presensi peserta: $e');
      return null;
    }
  }

  Future<String?> generatePresensiRekapPdf(String kdJdw) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final response = await _dio.post(
        '/presensi_rekap_cetak/pdf_rekap',
        data: {
          'kd_jdw': kdJdw,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        final status = payload['status'];
        final namaFile = payload['namaFile']?.toString();
        if ((status == true || status == 'true') &&
            namaFile != null &&
            namaFile.isNotEmpty) {
          return namaFile;
        }
        return null;
      }

      if (payload is String) {
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            final status = decoded['status'];
            final namaFile = decoded['namaFile']?.toString();
            if ((status == true || status == 'true') &&
                namaFile != null &&
                namaFile.isNotEmpty) {
              return namaFile;
            }
          }
        } catch (_) {
          return null;
        }
      }

      return null;
    } catch (e) {
      print('Error generating rekap pdf: $e');
      return null;
    }
  }

  Future<String?> fetchNilaiPage() async {
    return fetchPageByUrl('/nilai');
  }

  Future<Map<String, dynamic>?> fetchNilaiFormData(String urlOrPath) async {
    try {
      String? html;
      final tried = <String>{};

      final candidates = <String>[urlOrPath];
      try {
        candidates.addAll(_buildNilaiFormCandidates(urlOrPath));
      } catch (_) {
        // keep base URL candidate only
      }
      for (final candidate in candidates) {
        final trimmed = candidate.trim();
        if (trimmed.isEmpty || tried.contains(trimmed)) continue;
        tried.add(trimmed);

        final fetched = await fetchPageByUrl(trimmed);
        if (fetched != null && fetched.trim().isNotEmpty) {
          html = fetched;
          break;
        }
      }

      if (html == null || html.isEmpty) return null;

      final normalizedHtml = html.trim();
      if (normalizedHtml.isEmpty) return null;

      final doc = html_parser.parse(normalizedHtml);

      String normalize(String raw) {
        return raw
            .replaceAll('\u00A0', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      final classInfo = <String, String>{};
      final infoTable = doc.querySelector(
            'div.box-info.table-responsive > table.table.table-striped',
          ) ??
          doc.querySelector('table.table.table-striped');

      if (infoTable != null) {
        for (final tr in infoTable.querySelectorAll('tr')) {
          final cells = tr.children;
          for (int i = 0; i < cells.length; i++) {
            final cell = cells[i];
            if (cell.localName != 'th') continue;

            final key = normalize(cell.text).replaceAll(RegExp(r':+$'), '');
            if (key.isEmpty) continue;

            String value = '';
            for (int j = i + 1; j < cells.length; j++) {
              final next = cells[j];
              if (next.localName == 'th') break;
              if (next.localName != 'td') continue;
              final candidate = normalize(next.text);
              if (candidate.isNotEmpty && candidate != ':') {
                value = candidate;
                break;
              }
            }

            if (value.isNotEmpty) {
              classInfo[key] = value;
            }
          }
        }
      }

      String jenisLabel = 'Nilai';
      final h1 = doc.querySelector('section.content-header h1');
      if (h1 != null) {
        final heading = normalize(h1.text);
        if (heading.toLowerCase().contains('form nilai')) {
          jenisLabel = heading
              .replaceAll(
                RegExp(r'form\s+nilai\s*', caseSensitive: false),
                '',
              )
              .trim();
          if (jenisLabel.isEmpty) {
            jenisLabel = 'Nilai';
          }
        }
      }

      final rows = <Map<String, String>>[];
      dynamic nilaiTable;
      for (final table in doc.querySelectorAll('table')) {
        final headers = table
            .querySelectorAll('thead th')
            .map((th) => normalize(th.text).toLowerCase())
            .toList();
        if (headers.contains('nim') && headers.contains('nama')) {
          nilaiTable = table;
          break;
        }
      }

      if (nilaiTable != null) {
        for (final tr in nilaiTable.querySelectorAll('tbody tr')) {
          final tds = tr.querySelectorAll('td');
          if (tds.length < 4) continue;

          final nim =
              tr.querySelector('input[name="nim[]"]')?.attributes['value'] ??
                  normalize(tds[1].text);
          if (nim.isEmpty) continue;

          final nilaiInput = tr.querySelector('input[name="nilai[]"]');
          final nilaiValue = nilaiInput?.attributes['value'] ?? '';

          rows.add({
            'nim': nim,
            'nama': normalize(tds[2].text),
            'nilai': nilaiValue,
          });
        }
      }

      return {
        'class_info': classInfo,
        'jenis_label': jenisLabel,
        'h_kd_jdw':
            doc.querySelector('input[name="h_kd_jdw"]')?.attributes['value'] ??
                '',
        'h_jenis':
            doc.querySelector('input[name="h_jenis"]')?.attributes['value'] ??
                '',
        'rows': rows,
      };
    } catch (e) {
      print('Error fetching nilai form data: $e');
      return null;
    }
  }

  List<String> _buildNilaiFormCandidates(String rawUrl) {
    final results = <String>[];
    final raw = rawUrl.trim();
    if (raw.isEmpty) return results;

    String toRelative(String input) {
      final uri = Uri.tryParse(input);
      if (uri != null &&
          uri.hasScheme &&
          uri.host.contains('lms.unindra.ac.id')) {
        final path = uri.path.isEmpty ? '/' : uri.path;
        final query = uri.hasQuery ? '?${uri.query}' : '';
        return '$path$query';
      }
      return input;
    }

    final relative = toRelative(raw);
    results.add(relative);

    final m =
        RegExp(r'(/nilai/nilai_form/)([^\?]+)(\?.*)?$').firstMatch(relative);
    if (m != null) {
      final prefix = m.group(1) ?? '/nilai/nilai_form/';
      final token = m.group(2) ?? '';
      final query = m.group(3) ?? '';

      if (token.isNotEmpty) {
        results.add('$prefix${Uri.encodeComponent(token)}$query');

        try {
          final decoded = Uri.decodeComponent(token);
          final encoded = Uri.encodeComponent(decoded);
          results.add('$prefix$encoded$query');
        } catch (_) {
          // Ignore malformed percent-encoding in token.
        }
      }
    }

    return results;
  }

  Future<String?> submitNilaiForm({
    required String kdJdw,
    required String jenis,
    required List<Map<String, String>> entries,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();

      final nimList = <String>[];
      final nilaiList = <String>[];

      for (final item in entries) {
        final nim = (item['nim'] ?? '').trim();
        if (nim.isEmpty) continue;
        nimList.add(nim);
        nilaiList.add((item['nilai'] ?? '').trim());
      }

      final response = await _dio.post(
        '/nilai/simpan_proses',
        data: {
          'h_kd_jdw': kdJdw,
          'h_jenis': jenis,
          'nim[]': nimList,
          'nilai[]': nilaiList,
          'btn_simpan': 'Simpan',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        final message = response.data?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        return 'Nilai berhasil disimpan';
      }

      return null;
    } catch (e) {
      print('Error submit nilai form: $e');
      return null;
    }
  }

  Future<String?> generateNilaiPdf({
    required String kdJdw,
    required String jenisNilai,
  }) async {
    try {
      final cookieHeader = await _buildCookieHeader();
      String endpoint;
      if (jenisNilai == 'uts') {
        endpoint = '/nilai_cetak/pdf_uts';
      } else if (jenisNilai == 'uas') {
        endpoint = '/nilai_cetak/pdf_uas';
      } else {
        endpoint = '/nilai_cetak/pdf_nilai';
      }

      final response = await _dio.post(
        endpoint,
        data: {
          'kd_jdw': kdJdw,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        final status = payload['status'];
        final namaFile = payload['namaFile']?.toString();
        if ((status == true || status == 'true') &&
            namaFile != null &&
            namaFile.isNotEmpty) {
          return namaFile;
        }
        return null;
      }

      if (payload is String) {
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            final status = decoded['status'];
            final namaFile = decoded['namaFile']?.toString();
            if ((status == true || status == 'true') &&
                namaFile != null &&
                namaFile.isNotEmpty) {
              return namaFile;
            }
          }
        } catch (_) {
          return null;
        }
      }

      return null;
    } catch (e) {
      print('Error generating nilai pdf: $e');
      return null;
    }
  }

  Future<String?> downloadByUrl(
    String url,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          headers: {
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
        ),
      );

      return savePath;
    } catch (e) {
      print('Error downloading by url: $e');
      return null;
    }
  }

  Future<String?> fetchExternalUrl(String encryptedUrl) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final response = await _dio.get(
        '/member_url/kelas/$encryptedUrl',
        options: Options(
          headers: {
            'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status! < 400,
        ),
      );

      if (response.statusCode == 200) {
        final html = response.data as String;

        var match = RegExp(r'https://forms\.gle/[a-zA-Z0-9]+').firstMatch(html);
        if (match != null) {
          final url = match.group(0) ?? '';
          return url;
        }

        match = RegExp(r'https://docs\.google\.com/[^\s<>]+').firstMatch(html);
        if (match != null) {
          final url = match.group(0) ?? '';
          return url;
        }

        final allUrls = RegExp(r'https://[^\s<>]+').allMatches(html);
        for (var urlMatch in allUrls) {
          final url = urlMatch.group(0) ?? '';
          if (!url.contains('lms.unindra.ac.id') &&
              !url.contains('cdn') &&
              !url.contains('.js') &&
              !url.contains('.css')) {
            return url;
          }
        }
      }

      return null;
    } catch (e) {
      print('Error fetching external URL: $e');
      return null;
    }
  }

  Future<String?> fetchGoogleMeetUrl(String encryptedUrl) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final response = await _dio.get(
        '/member_url/kelas_gmeet/$encryptedUrl',
        options: Options(
          headers: {
            'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status! < 400,
        ),
      );

      if (response.statusCode == 200) {
        final html = response.data as String;

        final match =
            RegExp(r'https://meet\.google\.com/[a-z\-]+').firstMatch(html);
        if (match != null) {
          final url = match.group(0) ?? '';
          return url;
        }
      }

      return null;
    } catch (e) {
      print('Error fetching Google Meet URL: $e');
      return null;
    }
  }

  Future<String?> fetchYouTubeUrl(String encryptedUrl) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final response = await _dio.get(
        '/member_video/kelas_yt/$encryptedUrl',
        options: Options(
          headers: {
            'Cookie': cookieHeader,
          },
          followRedirects: false,
          validateStatus: (status) => status! < 400,
        ),
      );

      if (response.statusCode == 200) {
        final html = response.data.toString();

        RegExpMatch? match =
            RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]+)', caseSensitive: false)
                .firstMatch(html);
        if (match != null) {
          final videoId = match.group(1) ?? '';
          final url = 'https://www.youtube.com/watch?v=$videoId';
          return url;
        }

        match = RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]+)',
                caseSensitive: false)
            .firstMatch(html);
        if (match != null) {
          final videoId = match.group(1) ?? '';
          final url = 'https://www.youtube.com/watch?v=$videoId';
          return url;
        }

        match = RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)', caseSensitive: false)
            .firstMatch(html);
        if (match != null) {
          final videoId = match.group(1) ?? '';
          final url = 'https://www.youtube.com/watch?v=$videoId';
          return url;
        }
      }

      return null;
    } catch (e) {
      print('Error fetching YouTube URL: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> fetchAssignmentDetail(
      String encryptedUrl) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final response = await _dio.get(
        '/member_tugas/kelas/$encryptedUrl',
        options: Options(
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);

        final tokens = <String, String>{};
        for (final fieldName in ['h_id_tugas', 'h_kode', 'h_id_aktifitas']) {
          final input = document.querySelector('input#$fieldName');
          if (input != null) {
            tokens[fieldName] = input.attributes['value'] ?? '';
          }
        }

        String? assignmentTitle;
        final titleElement =
            document.querySelector('h4.attachment-heading.text-primary');
        if (titleElement != null) {
          assignmentTitle = titleElement.text.trim();
        }

        String? description;
        final descContainer =
            document.querySelector('div[style*="padding-left"]');
        if (descContainer != null) {
          final contentParts = <String>[];

          for (final child in descContainer.children) {
            final tagName = child.localName?.toLowerCase();

            if (tagName == 'p') {
              final text = child.text.trim();
              if (text.isNotEmpty) {
                contentParts.add(text);
              }
            } else if (tagName == 'ol') {
              final listItems = child.querySelectorAll('li');
              if (listItems.isNotEmpty) {
                final items = listItems
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value.text.trim()}')
                    .toList();
                contentParts.add(items.join('\n'));
              }
            } else if (tagName == 'ul') {
              final listItems = child.querySelectorAll('li');
              if (listItems.isNotEmpty) {
                final items =
                    listItems.map((li) => '• ${li.text.trim()}').toList();
                contentParts.add(items.join('\n'));
              }
            }
          }

          if (contentParts.isNotEmpty) {
            description = contentParts.join('\n\n');
          } else {
            description = descContainer.text.trim();
          }
        }

        String? assignmentFileName;
        String? assignmentFileParam;
        final tables = document.querySelectorAll('table.table tbody');
        for (final tbody in tables) {
          final rows = tbody.querySelectorAll('tr');
          for (final row in rows) {
            final th = row.querySelector('th');
            if (th != null && th.text.contains('File Tugas')) {
              final td = row.querySelector('td');
              if (td != null) {
                final link = td.querySelector('a[onclick*="lihat_pdf"]');
                if (link != null) {
                  assignmentFileName = link.text.trim();
                  final onclickAttr = link.attributes['onclick'] ?? '';
                  final regex = RegExp(r"lihat_pdf\('([^']+)'\)");
                  final match = regex.firstMatch(onclickAttr);
                  if (match != null) {
                    assignmentFileParam = match.group(1);
                  }
                }
              }
            }
          }
        }

        // Fungsi buat ambil nilai dari tabel status submit
        String getTableValue(String label) {
          final allTh = document.querySelectorAll('th');
          for (final th in allTh) {
            if (th.text.contains(label)) {
              final td = th.nextElementSibling;
              if (td != null) {
                return td.text.trim();
              }
            }
          }
          return '-';
        }

        return {
          'assignment_title': assignmentTitle,
          'description': description,
          'assignment_file_name': assignmentFileName,
          'assignment_file_param': assignmentFileParam,
          'status': getTableValue('Status Submit'),
          'deadline': getTableValue('Akhir Submit'),
          'remaining': getTableValue('Sisa Waktu'),
          'file_uploaded': getTableValue('File Upload'),
          'upload_time': getTableValue('Waktu Upload'),
          'tokens': tokens,
        };
      }

      throw Exception('Failed to load assignment detail');
    } catch (e) {
      print('Error fetching assignment detail: $e');
      rethrow;
    }
  }

  Future<String?> uploadAssignment({
    required Map<String, dynamic> tokens,
    required String filePath,
    required String fileName,
  }) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final formData = FormData.fromMap({
        'h_id_tugas': tokens['h_id_tugas'],
        'h_kode': tokens['h_kode'],
        'h_id_aktifitas': tokens['h_id_aktifitas'],
        'btn_simpan': 'Simpan',
        'myfile': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        '/member_tugas/mhs_upload_file_proses',
        data: formData,
        options: Options(
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode == 200) {
        final result = response.data
            .toString()
            .replaceAll(RegExp(r"<script>alert\('"), '')
            .replaceAll(RegExp(r"'\);</script>"), '')
            .trim();
        return result.isEmpty ? 'Upload berhasil' : result;
      }

      throw Exception('Upload failed');
    } catch (e) {
      print('Error uploading assignment: $e');
      rethrow;
    }
  }

  Future<String> fetchDashboardPage() async {
    try {
      if (_ciSession == null) {
        throw Exception('Not authenticated');
      }

      final cookieHeader = 'ci_session=$_ciSession';

      final response = await _dio.get(
        '/member',
        options: Options(
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data as String;
      } else {
        throw Exception('Failed to load dashboard page');
      }
    } catch (e) {
      throw Exception('Error fetching dashboard: $e');
    }
  }

  Future<Map<String, dynamic>> fetchForumDetail(String encryptedUrl) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final response = await _dio.get(
        '/member_forum/kelas/$encryptedUrl',
        options: Options(
          headers: {
            'Cookie': cookieHeader,
          },
        ),
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);

        final mainPost = <String, dynamic>{};
        final userBlock = document.querySelector('.user-block');
        if (userBlock != null) {
          final authorName =
              userBlock.querySelector('.username a')?.text.trim() ?? '';
          final authorImgRaw =
              userBlock.querySelector('img')?.attributes['src'] ?? '';
          final createdDate = userBlock
                  .querySelector('.description')
                  ?.text
                  .replaceAll('Dibuat - ', '')
                  .trim() ??
              '';

          // Cek apakah foto valid (bukan placeholder atau error)
          String authorImg = '';
          if (authorImgRaw.isNotEmpty &&
              !authorImgRaw.contains('no-image') &&
              !authorImgRaw.contains('default') &&
              !authorImgRaw.contains('placeholder')) {
            authorImg = authorImgRaw.startsWith('http')
                ? authorImgRaw
                : 'https://lms.unindra.ac.id/$authorImgRaw';
          }

          mainPost['author_name'] = authorName;
          mainPost['author_img'] = authorImg;
          mainPost['created_date'] = createdDate;
        }

        final forumTitle =
            document.querySelector('.attachment-heading')?.text.trim() ?? '';
        final calloutDiv = document.querySelector('.callout');
        final forumContent = calloutDiv != null
            ? calloutDiv
                .querySelectorAll('p')
                .map((p) => p.text.trim())
                .where((t) => t.isNotEmpty)
                .join('\n\n')
            : (document.querySelector('.callout p')?.text.trim() ?? '');

        mainPost['title'] = forumTitle;
        mainPost['content'] = forumContent;

        // Ambil data button reply
        final mainReplyBtn =
            document.querySelector('button[onclick*="pop_form_reply"]');
        if (mainReplyBtn != null) {
          final onclick = mainReplyBtn.attributes['onclick'] ?? '';
          final regex = RegExp(
              r"pop_form_reply\('([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)'\)");
          final match = regex.firstMatch(onclick);
          if (match != null) {
            mainPost['parent_id'] = match.group(1);
            mainPost['kd_jdw_enc'] = match.group(2);
            mainPost['id_aktifitas'] = match.group(3);
            mainPost['reply_id'] = match.group(4);
            mainPost['forum_nama'] = match.group(5);
          }
        }

        // Ambil semua balasan
        final replies = <Map<String, dynamic>>[];
        final replyElements =
            document.querySelectorAll('.box-comments .comment-text');

        for (final replyElem in replyElements) {
          final reply = <String, dynamic>{};

          final date = replyElem
                  .querySelector('.username .text-muted.pull-right')
                  ?.text
                  .trim() ??
              '';

          final usernameElem = replyElem.querySelector('.username');
          String username = '';
          if (usernameElem != null) {
            final usernameClone = usernameElem.clone(true);
            final dateInUsername =
                usernameClone.querySelector('.text-muted.pull-right');
            if (dateInUsername != null) {
              dateInUsername.remove();
            }
            username = usernameClone.text.trim();
          }

          String message = '';

          final replyClone = replyElem.clone(true);

          replyClone.querySelector('.username')?.remove();
          replyClone.querySelectorAll('button').forEach((btn) => btn.remove());
          replyClone
              .querySelectorAll('.pull-right.text-muted')
              .forEach((span) => span.remove());

          final remainingHtml = replyClone.innerHtml.trim();

          if (remainingHtml.isNotEmpty) {
            message = remainingHtml
                .replaceAll(RegExp(r'<p>\s*</p>'), '')
                .replaceAll(RegExp(r'<p>\s*<br>\s*</p>'), '')
                .trim();

            if (!message.contains('<p>') && message.isNotEmpty) {
              message = '<p>$message</p>';
            }
          }

          final imgElem = replyElem.parent?.querySelector('img');
          final authorImgRaw = imgElem?.attributes['src'] ?? '';

          // Cek apakah foto valid (bukan placeholder atau error)
          String authorImg = '';
          if (authorImgRaw.isNotEmpty &&
              !authorImgRaw.contains('no-image') &&
              !authorImgRaw.contains('default') &&
              !authorImgRaw.contains('placeholder')) {
            authorImg = authorImgRaw.startsWith('http')
                ? authorImgRaw
                : 'https://lms.unindra.ac.id/$authorImgRaw';
          }

          final replyBtn =
              replyElem.querySelector('button[onclick*="pop_form_reply"]');
          if (replyBtn != null) {
            final onclick = replyBtn.attributes['onclick'] ?? '';
            final regex = RegExp(
                r"pop_form_reply\('([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)'\)");
            final match = regex.firstMatch(onclick);
            if (match != null) {
              reply['parent_id'] = match.group(1);
              reply['kd_jdw_enc'] = match.group(2);
              reply['id_aktifitas'] = match.group(3);
              reply['reply_id'] = match.group(4);
              reply['forum_nama'] = match.group(5);
            }
          }

          reply['author_name'] = username;
          reply['author_img'] = authorImg;
          reply['date'] = date;
          reply['message'] = message;

          final isSubReply =
              replyElem.parent?.parent?.classes.contains('sub_reply') ?? false;
          reply['is_sub_reply'] = isSubReply;

          if (message.isNotEmpty) {
            replies.add(reply);
          }
        }

        // Ambil daftar user yang ikut
        final joinedUsers = <Map<String, String>>[];
        final userElements =
            document.querySelectorAll('.contacts-list-success');
        for (final userElem in userElements) {
          final name =
              userElem.querySelector('.contacts-list-name')?.text.trim() ?? '';
          final joinDate =
              userElem.querySelector('.contacts-list-msg')?.text.trim() ?? '';
          if (name.isNotEmpty) {
            joinedUsers.add({'name': name, 'join_date': joinDate});
          }
        }

        return {
          'main_post': mainPost,
          'replies': replies,
          'joined_users': joinedUsers,
        };
      }

      throw Exception('Failed to load forum detail');
    } catch (e) {
      print('Error fetching forum detail: $e');
      rethrow;
    }
  }

  Future<String?> submitForumReply({
    required String parentId,
    required String kdJdwEnc,
    required String idAktifitas,
    required String replyId,
    required String forumNama,
    required String message,
  }) async {
    try {
      String cookieHeader = '';
      if (_ciSession != null) {
        cookieHeader = 'ci_session=$_ciSession';
      }

      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('colek_member_remember') ?? false;
      if (remember) {
        final username = prefs.getString('colek_member_username');
        final password = prefs.getString('colek_member_pswd');
        if (username != null && password != null) {
          if (cookieHeader.isNotEmpty) cookieHeader += '; ';
          cookieHeader +=
              'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      final formResponse = await _dio.post(
        '/member_forum/reply',
        data: {
          'kd_jdw_enc': kdJdwEnc,
          'parent_id': parentId,
          'id_aktifitas': idAktifitas,
          'reply_id': replyId,
          'forum_nama': forumNama,
          'aksi': 'reply',
        },
        options: Options(
          headers: {
            'Cookie': cookieHeader,
            'Referer': '$baseUrl/member_forum/kelas/$kdJdwEnc',
          },
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final formDoc = html_parser.parse(formResponse.data);
      final csrfToken = formDoc
              .querySelector('input[name="csrf_token"]')
              ?.attributes['value'] ??
          '';
      final hiddenField = formDoc
              .querySelector('input[name="0e59f85937eebefad004de3c21e9c6ae"]')
              ?.attributes['value'] ??
          '';
      final hReplyId = formDoc
              .querySelector('input[name="h_reply_id"]')
              ?.attributes['value'] ??
          '';
      final hParentId = formDoc
              .querySelector('input[name="h_parent_id"]')
              ?.attributes['value'] ??
          '';
      final hKode =
          formDoc.querySelector('input[name="h_kode"]')?.attributes['value'] ??
              '';
      final hIdAktifitas = formDoc
              .querySelector('input[name="h_id_aktifitas"]')
              ?.attributes['value'] ??
          '';
      final hForumId = formDoc
              .querySelector('input[name="h_forum_id"]')
              ?.attributes['value'] ??
          '';

      final formData = {
        'nama_forum': 'Reply: $forumNama',
        'keterangan': '',
        'kd_jdw_enc': kdJdwEnc,
        'isi_reply': '<p>$message</p>\n',
        'h_reply_id': hReplyId,
        'h_parent_id': hParentId,
        'h_kode': hKode,
        'h_id_aktifitas': hIdAktifitas,
        'h_forum_id': hForumId,
        'csrf_token': csrfToken,
        'aksi': 'reply',
        '0e59f85937eebefad004de3c21e9c6ae': hiddenField,
      };

      final response = await _dio.post(
        '/member_forum/reply_tambah_proses',
        data: formData,
        options: Options(
          headers: {
            'Cookie': cookieHeader,
            'Referer': '$baseUrl/member_forum/kelas/$kdJdwEnc',
            'Origin': baseUrl,
          },
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (status) => status! < 500,
        ),
      );

      // Kalo redirect ke member_forum/kelas berarti berhasil
      if (response.statusCode == 302 || response.statusCode == 303) {
        final location = response.headers.value('location');
        if (location != null && location.contains('member_forum/kelas')) {
          return 'Pesan berhasil dikirim';
        }
      }

      if (response.statusCode == 200) {
        final responseData = response.data.toString();

        if (responseData.contains('error') ||
            responseData.contains('gagal') ||
            responseData.contains('failed')) {
          throw Exception('Submit failed - server returned error');
        }

        return 'Pesan berhasil dikirim';
      }

      throw Exception('Failed to submit reply: Status ${response.statusCode}');
    } catch (e) {
      print('Error submitting forum reply: $e');
      rethrow;
    }
  }

  // Generate IP address acak
  String _generateRandomIp() {
    final random = Random();
    return '${random.nextInt(256)}.${random.nextInt(256)}.${random.nextInt(256)}.${random.nextInt(256)}';
  }

  // Cari mahasiswa di PDDIKTI
  // cf_clearance terikat ke User-Agent, jadi WebView challenge WAJIB pakai UA ini juga
  static const String pddiktiUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0';

  static const String _pddiktiCookieKey = 'pddikti_cf_cookie';

  static Future<String?> getPddiktiCookie() async =>
      (await SharedPreferences.getInstance()).getString(_pddiktiCookieKey);

  static Future<void> savePddiktiCookie(String cookie) async =>
      (await SharedPreferences.getInstance())
          .setString(_pddiktiCookieKey, cookie);

  Future<List<MahasiswaSearchResult>> searchMahasiswa(String query) async {
    final url =
        'https://api-pddikti.kemdiktisaintek.go.id/pencarian/mhs/$query';
    try {
      final cookie = await getPddiktiCookie();
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'origin': 'https://pddikti.kemdiktisaintek.go.id',
            'referer': 'https://pddikti.kemdiktisaintek.go.id/',
            'User-Agent': pddiktiUserAgent,
            'x-user-ip': _generateRandomIp(),
            if (cookie != null) 'cookie': cookie,
          },
        ),
      );

      final body = response.data?.toString() ?? '';
      if (body.contains('Just a moment') ||
          body.contains('challenge-platform') ||
          body.contains('cf-chl')) {
        throw CloudflareChallengeException(url);
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(body);
        // API sekarang membungkus hasil: {"status":"success","data":[...]}
        final List<dynamic> data =
            decoded is Map ? (decoded['data'] as List? ?? []) : decoded as List;
        return data
            .map((json) => MahasiswaSearchResult.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to search mahasiswa: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching mahasiswa: $e');
      rethrow;
    }
  }

  // Cari dosen dari SIMPEG UNINDRA
  Future<List<DosenSearchResult>> searchDosen(String query) async {
    try {
      final dio = Dio();
      final formData = FormData.fromMap({
        'nidn_nama': query,
        'prodi': '',
      });

      final response = await dio.post(
        'https://simpeg.unindra.ac.id/pegawai/cari',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ),
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);
        final productItems = document.querySelectorAll('.product-item');

        final List<DosenSearchResult> results = [];

        for (var item in productItems) {
          try {
            final nama = item.querySelector('.text-header')?.text.trim() ?? '';
            final nidnElement = item.querySelector('.category.secondary');
            final nidn = nidnElement?.text.replaceAll('NIDN:', '').trim() ?? '';

            final prodiElement = item.querySelectorAll('.category.gray')[0];
            final prodi = prodiElement.text.replaceAll('Prodi:', '').trim();

            final kepakaranElement = item.querySelectorAll('.category.gray')[1];
            final kepakaran =
                kepakaranElement.text.replaceAll('Kepakaran:', '').trim();

            final onclickAttr =
                item.querySelector('a[onclick]')?.attributes['onclick'] ?? '';
            final kodeMatch =
                RegExp(r"dosen_detail\('([^']+)'\)").firstMatch(onclickAttr);
            final kode = kodeMatch?.group(1) ?? '';

            final photoUrl = item.querySelector('img')?.attributes['src'];

            if (nama.isNotEmpty && kode.isNotEmpty) {
              results.add(DosenSearchResult(
                nama: nama,
                nidn: nidn,
                prodi: prodi,
                kepakaran: kepakaran,
                kode: kode,
                photoUrl: photoUrl,
              ));
            }
          } catch (e) {
            print('Error parsing dosen item: $e');
            continue;
          }
        }

        return results;
      } else {
        throw Exception('Failed to search dosen: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching dosen: $e');
      rethrow;
    }
  }

  Future<DosenDetail> getDosenDetail(String kode, {String? nidn}) async {
    try {
      final dio = Dio();

      final formData = FormData.fromMap({'kode': kode});
      final response = await dio.post(
        'https://simpeg.unindra.ac.id/pegawai/detail/$kode',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ),
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);

        final inputs = document.querySelectorAll('input[readonly]');
        final nama =
            inputs.isNotEmpty ? inputs[0].attributes['value'] ?? '' : '';
        final fakultas =
            inputs.length > 1 ? inputs[1].attributes['value'] ?? '' : '';
        final prodi =
            inputs.length > 2 ? inputs[2].attributes['value'] ?? '' : '';
        final jabatanFungsional =
            inputs.length > 3 ? inputs[3].attributes['value'] ?? '' : '';
        final statusIkatanKerja =
            inputs.length > 4 ? inputs[4].attributes['value'] ?? '' : '';
        final jenisKelamin =
            inputs.length > 5 ? inputs[5].attributes['value'] ?? '' : '';
        final pendidikanTerakhir =
            inputs.length > 6 ? inputs[6].attributes['value'] ?? '' : '';

        final photoUrl =
            document.querySelector('img[alt="dosen-image"]')?.attributes['src'];

        String? ponsel;
        String? statusWa;

        // Matching nama dosen di simpeg dengan nama dosen di doesnt.json
        try {
          final jsonResponse = await dio.get(
            'https://raw.githubusercontent.com/dandiedutech/unindra/refs/heads/main/doesnt.json',
          );

          if (jsonResponse.statusCode == 200) {
            final Map<String, dynamic> data = jsonResponse.data is String
                ? json.decode(jsonResponse.data)
                : jsonResponse.data;

            String normalizedNama = nama
                .toLowerCase()
                .replaceAll(RegExp(r'[.,\s]+'), ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();

            for (var prodiData in data.values) {
              if (prodiData is List) {
                for (var dosenData in prodiData) {
                  if (nama.isNotEmpty && dosenData['nama'] != null) {
                    String jsonNama = dosenData['nama'].toString();
                    String normalizedJsonNama = jsonNama
                        .toLowerCase()
                        .replaceAll(RegExp(r'[.,\s]+'), ' ')
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim();

                    bool isMatch = normalizedNama == normalizedJsonNama;

                    if (!isMatch) {
                      List<String> namaWords = normalizedNama
                          .split(' ')
                          .where((w) => w.length > 2)
                          .toList();
                      List<String> jsonWords = normalizedJsonNama
                          .split(' ')
                          .where((w) => w.length > 2)
                          .toList();

                      if (namaWords.isNotEmpty && jsonWords.isNotEmpty) {
                        String firstName = namaWords[0];
                        bool firstNameMatch = jsonWords.any((jw) =>
                            jw == firstName ||
                            (jw.length >= 4 &&
                                firstName.length >= 4 &&
                                (jw.startsWith(firstName.substring(0, 3)) ||
                                    firstName.startsWith(jw.substring(0, 3)))));

                        if (firstNameMatch) {
                          int exactMatches = 0;
                          for (var word in namaWords) {
                            if (jsonWords.contains(word)) {
                              exactMatches++;
                            }
                          }

                          double similarity = exactMatches / namaWords.length;
                          if (similarity >= 0.8) {
                            isMatch = true;
                          }
                        }
                      }
                    }

                    if (isMatch) {
                      ponsel = dosenData['ponsel']?.toString();
                      statusWa = dosenData['status_wa']?.toString();
                      break;
                    }
                  }
                }
                if (ponsel != null) break;
              }
            }

            if (ponsel == null) {
              print('No phone number found for: $nama');
            }
          }
        } catch (e) {
          print('Error fetching phone number: $e');
        }

        return DosenDetail(
          nama: nama,
          nidn: nidn ?? '',
          fakultas: fakultas,
          prodi: prodi,
          jabatanFungsional: jabatanFungsional,
          statusIkatanKerja: statusIkatanKerja,
          jenisKelamin: jenisKelamin,
          pendidikanTerakhir: pendidikanTerakhir,
          photoUrl: photoUrl,
          ponsel: ponsel,
          statusWa: statusWa,
        );
      } else {
        throw Exception('Failed to get dosen detail: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting dosen detail: $e');
      rethrow;
    }
  }
}
