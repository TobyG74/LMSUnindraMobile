class LoginRequest {
  final String csrfToken;
  final String hiddenField;
  final String username;
  final String password;
  final String captcha;
  final bool rememberMe;

  LoginRequest({
    required this.csrfToken,
    required this.hiddenField,
    required this.username,
    required this.password,
    required this.captcha,
    this.rememberMe = false,
  });

  Map<String, String> toFormData() {
    return {
      'csrf_token': csrfToken,
      '0e59f85937eebefad004de3c21e9c6ae': hiddenField,
      'username': username,
      'pswd': password,
      'kapca': captcha,
      if (rememberMe) 'login-check': 'on',
    };
  }
}

class LoginFormData {
  final String csrfToken;
  final String hiddenFieldName;
  final String hiddenFieldValue;

  LoginFormData({
    required this.csrfToken,
    required this.hiddenFieldName,
    required this.hiddenFieldValue,
  });
}
