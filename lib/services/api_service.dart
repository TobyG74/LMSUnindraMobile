import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_model.dart';
import '../models/profile_model.dart';

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
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36 Edg/142.0.0.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
      followRedirects: true,
      validateStatus: (status) => status! < 500,
    ));
  }
  // Ambil token CSRF dari halaman login
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
            print('Stored ci_session from captcha: $_ciSession');
            break;
          }
        }
      }
      
      print('Captcha response headers: ${response.headers}');
      
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
      print('Sending login data: $formData');
      
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
      print('Using ci_session: $_ciSession');
      print('Sending cookies: $cookieHeader');

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

      print('Login response status: ${response.statusCode}');
      print('Login response headers: ${response.headers}');

      if (response.statusCode == 302 || response.statusCode == 301 || response.statusCode == 303) {
        final location = response.headers.value('location');
        
        print('Redirect detected: $location');
        
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
        
        print('Response length: ${responseData.length}');
        print('Has user_level: ${responseData.contains('user_level')}');
        print('Has Member title: ${responseData.contains('Member | LMS UNINDRA')}');
        print('Has Login title: ${responseData.contains('Login | LMS UNINDRA')}');
        print('Has login-check: ${responseData.contains('login-check')}');
        
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
        
        if (responseData.contains('Incorrect') || responseData.contains('salah')) {
          final startIdx = responseData.toLowerCase().indexOf('incorrect') >= 0 
              ? responseData.toLowerCase().indexOf('incorrect')
              : responseData.toLowerCase().indexOf('salah');
          if (startIdx >= 0) {
            final errorSnippet = responseData.substring(
              startIdx > 50 ? startIdx - 50 : 0,
              (startIdx + 200) < responseData.length ? startIdx + 200 : responseData.length
            );
            print('Error context: $errorSnippet');
          }
        }
        
        // Cek kalo udah masuk halaman member
        if (responseData.contains('user_level') && 
            responseData.contains('Member | LMS UNINDRA')) {
          print('✓ Login successful - detected member page');
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
          print('✗ Login failed - error message detected');
          
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
            'message': errorMsg.isNotEmpty ? errorMsg : 'Username, password, atau captcha salah',
          };
        }

        if (responseData.contains('login-check') || 
            responseData.contains('Enter username') ||
            responseData.contains('Login | LMS UNINDRA')) {
          print('✗ Login failed - still on login page');
          
          final doc = html_parser.parse(responseData);
          final alerts = doc.querySelectorAll('.alert, .error, [class*="danger"], [class*="error"]');
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
    
    if (remember) {
      final username = prefs.getString('colek_member_username');
      final password = prefs.getString('colek_member_pswd');
      
      if (username != null && password != null) {
        return {
          'username': username,
          'password': password,
        };
      }
    }
    return null;
  }

  Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('colek_member_username');
    await prefs.remove('colek_member_pswd');
    await prefs.remove('colek_member_remember');
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

      if (response.statusCode == 200 || response.statusCode == 302 || response.statusCode == 303) {
        final responseData = response.data.toString();
        final doc = html_parser.parse(responseData);
        
        final successAlerts = doc.querySelectorAll('.alert-success, .text-success, [class*="success"]');
        for (var alert in successAlerts) {
          final text = alert.text.trim();
          if (text.isNotEmpty && text.length < 200) {
            return {
              'success': true,
              'message': text,
            };
          }
        }
        
        final errorAlerts = doc.querySelectorAll('.alert-danger, .alert-error, .error, [class*="danger"]');
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
          'message': 'Gagal mengirim reset password. Periksa email atau captcha Anda.',
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
        
        final name = document.querySelector('.profile-username')?.text.trim() ?? '';
        final usernameText = document.querySelector('.text-muted.text-center')?.text.trim() ?? '';
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

      if (response.statusCode == 200 || response.statusCode == 302 || response.statusCode == 303) {
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

      if (response.statusCode == 200 || response.statusCode == 302 || response.statusCode == 303) {
        final responseData = response.data.toString();
        
        if (responseData.contains('salah') || responseData.contains('tidak sesuai')) {
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
          cookieHeader += 'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
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

  Future<String?> downloadFile(String encryptedUrl, String savePath) async {
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
          cookieHeader += 'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
        }
      }

      await _dio.download(
        '/pertemuan/force_download/$encryptedUrl',
        savePath,
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
          cookieHeader += 'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
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
          cookieHeader += 'colek_member_username=$username; colek_member_pswd=$password; colek_member_remember=1';
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
        print('External URL response HTML length: ${html.length}');
        
        var match = RegExp(r'https://forms\.gle/[a-zA-Z0-9]+').firstMatch(html);
        if (match != null) {
          final url = match.group(0) ?? '';
          print('Found forms.gle URL: $url');
          return url;
        }
        
        match = RegExp(r'https://docs\.google\.com/[^\s<>]+').firstMatch(html);
        if (match != null) {
          final url = match.group(0) ?? '';
          print('Found docs.google.com URL: $url');
          return url;
        }
        
        final allUrls = RegExp(r'https://[^\s<>]+').allMatches(html);
        for (var urlMatch in allUrls) {
          final url = urlMatch.group(0) ?? '';
          if (!url.contains('lms.unindra.ac.id') && !url.contains('cdn') && !url.contains('.js') && !url.contains('.css')) {
            print('Found external URL: $url');
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
}
