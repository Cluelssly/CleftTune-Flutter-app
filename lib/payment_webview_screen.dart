// lib/screens/payment_webview_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class PaymentWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final String successUrl;
  final String failedUrl;
  final VoidCallback onSuccess;
  final VoidCallback onFailed;

  const PaymentWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.successUrl,
    required this.failedUrl,
    required this.onSuccess,
    required this.onFailed,
  });

  @override
  State<PaymentWebViewScreen> createState() =>
      _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState
    extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _didFinish = false;

  static const _teal = Color(0xFF1D9E75);

  @override
  void initState() {
    super.initState();

    // ── WEB FIX ───────────────────────────────────────────────────────
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final url = widget.checkoutUrl;

        // ✅ Open PayMongo in new tab
        html.window.open(url, '_blank');
      });

      return;
    }

    // ── MOBILE WEBVIEW ────────────────────────────────────────────────
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(

          // ── PAGE START ───────────────────────────────────────────────
          onPageStarted: (url) {
            setState(() => _isLoading = true);
            _handleUrl(url);
          },

          // ── PAGE FINISH ──────────────────────────────────────────────
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            _handleUrl(url);
          },

          onWebResourceError: (_) {
            setState(() => _isLoading = false);
          },

          // ── NAVIGATION ───────────────────────────────────────────────
          onNavigationRequest: (request) {
            final url = request.url;

            if (_handleUrl(url)) {
              return NavigationDecision.prevent;
            }

            // ── GCash / Maya deep links ────────────────────────────────
            if (url.startsWith('gcash://') ||
                url.startsWith('maya://') ||
                url.startsWith('paymaya://') ||
                url.startsWith('intent://')) {
              _openDeepLink(url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  /// SUCCESS / FAILED REDIRECTS
  bool _handleUrl(String url) {
    if (_didFinish) return true;

    if (url.startsWith(widget.successUrl)) {
      _didFinish = true;

      if (mounted) {
        Navigator.of(context).pop();
      }

      widget.onSuccess();
      return true;
    }

    if (url.startsWith(widget.failedUrl)) {
      _didFinish = true;

      if (mounted) {
        Navigator.of(context).pop();
      }

      widget.onFailed();
      return true;
    }

    return false;
  }

  Future<void> _openDeepLink(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    // ── WEB UI ────────────────────────────────────────────────────────
    if (kIsWeb) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1F1A),
        body: Center(
          child: CircularProgressIndicator(
            color: _teal,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2020),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Complete Payment',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.white70,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0x401D9E75),
          ),
        ),
      ),
      body: Stack(
        children: [

          // ── PAYMENT WEBVIEW ──────────────────────────────────────────
          WebViewWidget(controller: _controller),

          // ── LOADING OVERLAY ─────────────────────────────────────────
          if (_isLoading)
            Container(
              color: const Color(0xFF0A1F1A),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: _teal,
                      strokeWidth: 2,
                    ),

                    SizedBox(height: 16),

                    Text(
                      'Loading payment page…',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}