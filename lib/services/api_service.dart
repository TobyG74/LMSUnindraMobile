import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_model.dart';
import '../models/profile_model.dart';
import '../models/mahasiswa_search_model.dart';
import '../models/dosen_search_model.dart';
import '../models/dosen_detail_model.dart';

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
        await _saveCookies(request.username, request.password);
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
          return {
            'success': true,
            'message': 'Login berhasil',
            'redirect': location,
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
          return {
            'success': true,
            'message': 'Login berhasil',
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
            return {
              'success': true,
              'message': 'Login berhasil',
              'data': memberResponse.data,
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

  Future<void> _saveCookies(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('colek_member_username', username);
    await prefs.setString('colek_member_pswd', password);
    await prefs.setBool('colek_member_remember', true);
  }

  Future<Map<String, String>?> loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('colek_member_remember') ?? false;
    final username = prefs.getString('colek_member_username');

    if (remember && username != null) {
      final password = prefs.getString('colek_member_pswd');
      if (password != null) {
        return {
          'username': username,
          'password': password,
        };
      }
    }
    
    if (username != null) {
      return {
        'username': username,
      };
    }
    
    return null;
  }

  Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('colek_member_pswd');
    await prefs.setBool('colek_member_remember', false);
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
        final forumContent =
            document.querySelector('.callout p')?.text.trim() ?? '';

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
          replyClone.querySelectorAll('.pull-right.text-muted').forEach((span) => span.remove());
          
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
  Future<List<MahasiswaSearchResult>> searchMahasiswa(String query) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api-pddikti.kemdiktisaintek.go.id/pencarian/mhs/$query',
        options: Options(
          headers: {
            'origin': 'https://pddikti.kemdiktisaintek.go.id',
            'referer': 'https://pddikti.kemdiktisaintek.go.id/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0',
            'x-user-ip': _generateRandomIp(),
          },
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
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
