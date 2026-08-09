import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/api_service.dart';

/// Buka halaman yang diblokir Cloudflare supaya user menekan captcha.
/// Pop dengan `true` setelah cf_clearance didapat dan disimpan.
class CfChallengeScreen extends StatefulWidget {
  final String url;
  const CfChallengeScreen({super.key, required this.url});

  @override
  State<CfChallengeScreen> createState() => _CfChallengeScreenState();
}

class _CfChallengeScreenState extends State<CfChallengeScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // ponytail: polling 1 detik, challenge bisa selesai tanpa page load baru
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _checkCookies());
  }

  Future<void> _checkCookies() async {
    final cookies =
        await CookieManager.instance().getCookies(url: WebUri(widget.url));
    if (!cookies.any((c) => c.name == 'cf_clearance')) return;

    _poll?.cancel();
    await ApiService.savePddiktiCookie(
      cookies.map((c) => '${c.name}=${c.value}').join('; '),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF073163),
        foregroundColor: Colors.white,
        title: const Text('Verifikasi Cloudflare', style: TextStyle(fontSize: 16)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.amber[100],
            padding: const EdgeInsets.all(12),
            child: const Text(
              'Selesaikan verifikasi di bawah ini. Halaman akan tertutup otomatis '
              'setelah verifikasi berhasil.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                userAgent: ApiService.pddiktiUserAgent,
                javaScriptEnabled: true,
                thirdPartyCookiesEnabled: true,
              ),
              onLoadStop: (_, __) => _checkCookies(),
            ),
          ),
        ],
      ),
    );
  }
}
