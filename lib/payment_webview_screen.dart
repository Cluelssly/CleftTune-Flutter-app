// lib/screens/payment_webview_screen.dart
//
// Opens the PayMongo checkout URL in a WebView.
// Handles GCash / Maya deep links so the e-wallet app opens automatically.
// Calls onSuccess / onFailed when PayMongo redirects back.
//
// FIX: Maya returns to the app via an app-switch, not a WebView navigation,
// so onNavigationRequest never fires. We now also check the URL in
// onPageStarted and onPageFinished to catch those redirects.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading  = true;
  bool _didFinish  = false; // guard: fire callbacks only once

  static const _teal = Color(0xFF1D9E75);

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(

          // ── Fires when the WebView starts loading any URL ──────────────
          // Maya sometimes lands here instead of onNavigationRequest
          onPageStarted: (url) {
            setState(() => _isLoading = true);
            _handleUrl(url);
          },

          // ── Fires when a page fully loads ─────────────────────────────
          // Catches the case where Maya redirects and the page loads blank
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            _handleUrl(url);
          },

          onWebResourceError: (_) => setState(() => _isLoading = false),

          // ── Fires before navigation — catches most redirects ───────────
          onNavigationRequest: (request) {
            final url = request.url;

            if (_handleUrl(url)) {
              return NavigationDecision.prevent;
            }

            // ── GCash / Maya / PayMaya deep links ────────────────────────
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

  /// Checks if [url] is a success or failed redirect.
  /// Returns true if handled (so the caller can prevent navigation).
  bool _handleUrl(String url) {
    if (_didFinish) return true; // already handled, swallow everything

    if (url.startsWith(widget.successUrl)) {
      _didFinish = true;
      if (mounted) Navigator.of(context).pop();
      widget.onSuccess();
      return true;
    }

    if (url.startsWith(widget.failedUrl)) {
      _didFinish = true;
      if (mounted) Navigator.of(context).pop();
      widget.onFailed();
      return true;
    }

    return false;
  }

  Future<void> _openDeepLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    // If the wallet app isn't installed the WebView stays on the checkout
    // page so the user can still pay via QR code.
  }

  @override
  Widget build(BuildContext context) {
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
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0x401D9E75)),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: const Color(0xFF0A1F1A),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _teal, strokeWidth: 2),
                    SizedBox(height: 16),
                    Text(
                      'Loading payment page…',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
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