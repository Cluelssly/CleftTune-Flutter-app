import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:developer' as dev;
import 'nlp_service.dart';
import 'notifications.dart';

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key});

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late stt.SpeechToText _speech;
  final NlpService _nlp = NlpService();

  bool _isListening     = false;
  bool _isInitialized   = false;
  bool _userStopped     = false; // only true while the screen is closing
  bool _showCorrections = false;
  bool _micBlocked      = false; // browser/phone refused microphone access

  String? _activeUserId;
  Stream<QuerySnapshot>? _correctionsStream;

  String _displayText    = '';
  String _committedText  = '';
  String _currentSegment = '';

  Timer? _sessionTimer;
  int    _sessionSeconds = 0;

  Timer? _partialNlpDebounce;

  // ── Subtitle state ─────────────────────────────────────────────────────────
  // The subtitle shows the sentence being heard right now (or the last finished
  // sentence) and disappears after _captionHold of silence. It comes back by
  // itself the moment the user speaks again.
  String _lastFinal      = '';
  bool   _captionVisible = false;
  Timer? _captionHideTimer;
  static const Duration _captionHold = Duration(seconds: 5);

  // Keep the on-screen transcript from growing forever while always-on.
  static const int _maxTranscriptChars = 3000;

  // ── Restart + watchdog (keeps the mic on nonstop) ──────────────────────────
  Timer? _restartTimer;
  Timer? _watchdog;
  bool   _isRestarting = false;

  // ── Theme ──────────────────────────────────────────────────────────────────
  static const _bg           = Color(0xFFEAF4FB);
  static const _bgMid        = Color(0xFFDAEEFA);
  static const _bgDark       = Color(0xFFC8E3F5);
  static const _accent       = Color(0xFF0077B6);
  static const _accentTint   = Color(0x260077B6);
  static const _accentBorder = Color(0x400077B6);
  static const _textDark     = Color(0xFF0D2B4E);
  static const _textSub      = Color(0xFF5A7A96);
  static const _card         = Color(0x1A0077B6);
  static const _white20      = Color(0xFF8AAEC8);

  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;
  late AnimationController _dotController;
  late Animation<double>   _dotAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = stt.SpeechToText();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _dotAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _dotController, curve: Curves.easeInOut),
    );

    _initServices();
  }

  // When the app/tab comes back to the foreground, make sure the mic is on.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _isListening &&
        !_speech.isListening) {
      _scheduleRestart();
    }
  }

  Future<void> _initServices() async {
    await _nlp.init();
    _initCorrectionsStream();
    dev.log('NLP ready — ${_nlp.patternCount} pattern(s) loaded');
    _nlp.onRealtimeCorrection = null;
    await _initSpeech();
    // The mic starts only when the user taps the Start button.
  }

  void _initCorrectionsStream() {
    final uid = _activeUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _correctionsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('corrections')
        .snapshots();
  }

  Future<void> _initSpeech() async {
    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          dev.log('STT STATUS: $status');
          // Chrome fires 'done' after every utterance. Restart right away so
          // the next sentence is captured and the mic never goes quiet.
          if (!_userStopped && _isListening) {
            if (status == 'done' ||
                status == 'notListening' ||
                status == 'doneNoResult') {
              dev.log('STT stopped ($status) — scheduling restart');
              _scheduleRestart();
            }
          }
        },
        onError: (error) {
          dev.log('STT ERROR: ${error.errorMsg}');
          final msg = error.errorMsg.toLowerCase();
          if (msg.contains('permission') ||
              msg.contains('not-allowed') ||
              msg.contains('not_allowed') ||
              msg.contains('denied')) {
            _handleMicBlocked();
            return;
          }
          // no-speech, timeouts, network blips, etc. are normal: just continue.
          if (!_userStopped && _isListening) {
            _scheduleRestart();
          }
        },
      );
    } catch (e) {
      dev.log('STT initialize failed: $e');
      _isInitialized = false;
    }
    if (mounted) setState(() {});
  }

  void _handleMicBlocked() {
    _cancelRestart();
    _watchdog?.cancel();
    _stopSessionTimer();
    if (mounted) {
      setState(() {
        _isListening = false;
        _micBlocked  = true;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESTART — debounced, single-path, guarded
  // 150 ms debounce + 200 ms stop gap = 350 ms total (was 900 ms).
  // If your browser fails to re-open the mic, raise these two values.
  // ══════════════════════════════════════════════════════════════════════════

  void _scheduleRestart() {
    if (_userStopped || !_isListening || _isRestarting) return;

    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 150), () async {
      if (_userStopped || !_isListening || !mounted) return;
      if (_isRestarting) return;
      if (_speech.isListening) {
        dev.log('Restart skipped — still listening');
        return;
      }

      _isRestarting = true;
      dev.log('Restart: stopping...');
      try { await _speech.stop(); } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 200));

      if (_userStopped || !_isListening || !mounted) {
        _isRestarting = false;
        return;
      }

      dev.log('Restart: calling listen()...');
      await _startListening();
      _isRestarting = false;
    });
  }

  void _cancelRestart() {
    _restartTimer?.cancel();
    _restartTimer = null;
    _isRestarting = false;
  }

  // Safety net: if the mic ever stops without an event reaching us, bring it
  // back within a couple of seconds. This is what makes it truly nonstop.
  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _userStopped || !_isListening) return;
      if (!_speech.isListening && !_isRestarting) {
        dev.log('Watchdog: mic was not listening — restarting');
        _scheduleRestart();
      }
    });
  }

  // Hides the subtitle after a few seconds of silence. Called every time new
  // speech arrives, so while you keep talking the subtitle never disappears.
  void _restartCaptionTimer() {
    _captionHideTimer?.cancel();
    _captionHideTimer = Timer(_captionHold, () {
      if (mounted) setState(() => _captionVisible = false);
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FIRESTORE SAVE
  // ══════════════════════════════════════════════════════════════════════════

  void _saveToFirestore(String text, String rawText,
      {String mode = 'realtime'}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final uid = _activeUserId;
    dev.log('=== SAVE [$mode] uid=$uid  text="$trimmed"');

    if (uid == null || uid.isEmpty) {
      dev.log('❌ Save aborted: no uid');
      return;
    }

    FirebaseFirestore.instance.collection('translations').add({
      'text':    trimmed,
      'rawText': rawText.trim(),
      'time':    FieldValue.serverTimestamp(),
      'userId':  uid,
      'mode':    mode,
    }).then((ref) {
      dev.log('✅ Saved [$mode]: "$trimmed" (id=${ref.id})');
    }).catchError((e) {
      dev.log('❌ Firestore save error: $e');
    });
  }

  // If a session ended before the engine sent a final result, keep the words
  // that were already on screen instead of throwing them away.
  void _commitPendingSegment() {
    final pending = _currentSegment.trim();
    _currentSegment = '';
    if (pending.isEmpty) return;
    _committedText = _capText(_buildDisplay(_committedText, pending).trim());
    _lastFinal = pending;
    _displayText = _committedText;
    _saveToFirestore(pending, pending, mode: 'realtime');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STT — start one listening session
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _startListening() async {
    if (!_isInitialized) {
      await _initSpeech();
      if (!_isInitialized) {
        dev.log('STT not initialized — aborting');
        return false;
      }
    }

    // Hard guard: never call listen() twice on web
    if (_speech.isListening) {
      dev.log('Already listening — skipping');
      return true;
    }

    _commitPendingSegment();

    try {
      await _speech.listen(
        localeId:       'en_US',
        listenFor:      const Duration(minutes: 30),
        pauseFor:       const Duration(seconds: 2),
        partialResults: true,
        listenMode:     stt.ListenMode.dictation,

        onResult: (result) {
          if (_userStopped) return;

          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;

          final confidence =
              result.confidence > 0 ? result.confidence.toDouble() : 0.6;

          if (result.finalResult &&
              words.split(' ').length < 2 &&
              confidence < 0.35) {
            dev.log('Noise filtered: "$words" (conf=$confidence)');
            return;
          }

          final syncCorrected = _nlp.correctPartialSync(words);

          if (result.finalResult) {
            _committedText = _capText(
                _buildDisplay(_committedText, syncCorrected).trim());
            _currentSegment = '';

            _lastFinal = syncCorrected;
            dev.log('✔ Final: "$syncCorrected"');
            if (mounted) {
              setState(() {
                _displayText    = _committedText;
                _captionVisible = true;
              });
            }
            _restartCaptionTimer();

            // Save every sentence to Firestore
            _saveToFirestore(syncCorrected, words, mode: 'realtime');

            _partialNlpDebounce?.cancel();
            _partialNlpDebounce = Timer(
              const Duration(milliseconds: 300),
              () => _runNlpRefinement(words, syncCorrected),
            );
          } else {
            // Live words appear immediately as the user speaks.
            _currentSegment = syncCorrected;
            final preview = _buildDisplay(_committedText, _currentSegment);
            if (mounted) {
              setState(() {
                _displayText    = preview;
                _captionVisible = true;
              });
            }
            _restartCaptionTimer();
          }
        },
      );
      return true;
    } catch (e) {
      dev.log('listen() failed: $e');
      return false;
    }
  }

  void _runNlpRefinement(String rawWords, String syncResult) {
    () async {
      String finalText = syncResult;
      try {
        final res = await _nlp
            .correct(syncResult)
            .timeout(const Duration(seconds: 4));
        final refined = (res['corrected'] as String? ?? '').trim();
        if (refined.isNotEmpty) finalText = refined;
      } catch (e) {
        dev.log('NLP refinement error: $e');
        return;
      }

      if (finalText == syncResult) return;

      if (mounted && _committedText.contains(syncResult)) {
        setState(() {
          if (_lastFinal == syncResult) _lastFinal = finalText;
          _committedText =
              _committedText.replaceFirst(syncResult, finalText);
          _displayText =
              _buildDisplay(_committedText, _currentSegment);
        });
      }
      _saveToFirestore(finalText, rawWords, mode: 'realtime_refined');
    }();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SESSION HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  String _buildDisplay(String committed, String segment) {
    if (committed.isEmpty) return segment;
    if (segment.isEmpty)   return committed;
    if (RegExp(r'^[.,!?;:]').hasMatch(segment)) {
      return '$committed$segment';
    }
    return '$committed $segment';
  }

  // Keep only the most recent text so an all-day session stays fast.
  String _capText(String text) {
    if (text.length <= _maxTranscriptChars) return text;
    final cut = text.substring(text.length - _maxTranscriptChars);
    final space = cut.indexOf(' ');
    return space == -1 ? cut : cut.substring(space + 1);
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionSeconds = 0;
    _sessionTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_isListening) { t.cancel(); return; }
      setState(() => _sessionSeconds++);
    });
  }

  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  String get _sessionLabel {
    final h = _sessionSeconds ~/ 3600;
    final m = (_sessionSeconds % 3600) ~/ 60;
    final s = _sessionSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ALWAYS-ON MIC
  // Starts by itself when the screen opens and then never stops. If the
  // browser blocked auto-start, the mic button appears; one tap starts it
  // and from then on it stays on.
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _startAlwaysOn({bool fromUser = false}) async {
    if (_isListening) return;

    _activeUserId = FirebaseAuth.instance.currentUser?.uid;
    dev.log('=== MIC START — cached uid=$_activeUserId');

    if (_activeUserId == null) {
      if (fromUser && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in before recording.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    _initCorrectionsStream();

    _userStopped    = false;
    _isRestarting   = false;
    _displayText    = '';
    _committedText  = '';
    _currentSegment = '';
    _lastFinal      = '';
    _captionVisible = false;
    _captionHideTimer?.cancel();
    _sessionSeconds = 0;

    if (mounted) {
      setState(() {
        _isListening = true;
        _micBlocked  = false;
      });
    }
    _nlp.beginSession();
    _startSessionTimer();
    _startWatchdog();

    final ok = await _startListening();
    if (!ok && !_isInitialized) {
      // Microphone could not be opened (permission not given).
      _handleMicBlocked();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STOP — user taps the Stop button
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _stopListening() async {
    if (!_isListening) return;

    _userStopped = true; // blocks restarts and ignores late STT callbacks
    _cancelRestart();
    _watchdog?.cancel();
    _stopSessionTimer();

    // Keep whatever was being said when Stop was pressed.
    _commitPendingSegment();

    if (mounted) {
      setState(() {
        _isListening = false;
        _isRestarting = false;
        _captionVisible = _displayText.isNotEmpty;
      });
    }
    _restartCaptionTimer();

    try { await _speech.stop(); } catch (_) {}
    dev.log('=== MIC STOPPED by user');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CORRECTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _deleteCorrection({
    required String uid,
    required String docId,
    required String wrong,
    required String correct,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('corrections')
          .doc(docId)
          .delete();
      await _nlp.forgetPattern(wrong, correct);
      dev.log('Correction deleted: "$wrong" → "$correct"');
      await NotificationHelper.wordDeleted(wrong);
      if (mounted) setState(() {});
    } catch (e) {
      dev.log('Delete correction error: $e');
    }
  }

  void _showAddCorrectionDialog() {
    final wrongCtrl   = TextEditingController();
    final correctCtrl = TextEditingController();
    if (_displayText.isNotEmpty) wrongCtrl.text = _displayText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddCorrectionSheet(
        wrongController:   wrongCtrl,
        correctController: correctCtrl,
        nlp:               _nlp,
        onSaved: (wrong, correct) {
          if (mounted) {
            _initCorrectionsStream();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF0077B6), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('"$wrong" → "$correct" saved!',
                        style: const TextStyle(
                            color: Color(0xFF0D2B4E),
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ]),
                backgroundColor: const Color(0xFFEAF4FB),
                behavior: SnackBarBehavior.floating,
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  String get _subtitleHint {
    if (_captionVisible) return '';
    if (_isListening) return 'Listening… just start speaking';
    if (_micBlocked) {
      return 'Tap Start and allow microphone access.\nAfter that it stays on by itself.';
    }
    return 'Tap Start to begin.\nTap Stop whenever you are done.';
  }

  int get _wordCount => _displayText.trim().isEmpty
      ? 0
      : _displayText.trim().split(RegExp(r'\s+')).length;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userStopped = true;
    _sessionTimer?.cancel();
    _partialNlpDebounce?.cancel();
    _restartTimer?.cancel();
    _watchdog?.cancel();
    _captionHideTimer?.cancel();
    _nlp.onRealtimeCorrection = null;
    _speech.stop();
    _pulseController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // One button: Start when the mic is off, Stop when it is on.
    final showMicButton = !_showCorrections;

    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bg, _bgMid, _bgDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _showCorrections
                    ? _buildCorrectionsPanel()
                    : _buildTranslatorBody(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      floatingActionButton: showMicButton ? _buildMicFab() : null,
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(children: [
              TextSpan(
                  text: 'Voice',
                  style: TextStyle(
                      color: _textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              TextSpan(
                  text: 'Mate',
                  style: TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ]),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _appBarBtn(
                icon: _showCorrections
                    ? Icons.close_rounded
                    : Icons.format_list_bulleted_rounded,
                onTap: () =>
                    setState(() => _showCorrections = !_showCorrections),
                active: _showCorrections,
              ),
              const SizedBox(width: 8),
              _appBarBtn(
                  icon: Icons.add_rounded,
                  onTap: _showAddCorrectionDialog),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appBarBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: active ? _accentTint : _card,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: active ? _accentBorder : _white20),
        ),
        child: Icon(icon,
            size: 18, color: active ? _accent : _textSub),
      ),
    );
  }

  // ── LIVE SUBTITLE ──────────────────────────────────────────────────────────
  // Shows the sentence being heard right now. While you are speaking it updates
  // word by word; once a sentence is finished it stays on screen until the next
  // speech starts (which replaces it) or until _captionHold of silence passes.
  Widget _buildLiveCaption() {
    final live = _currentSegment.trim();
    final text = live.isNotEmpty ? live : _lastFinal;

    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: _textDark,
        height: 1.5,
      ),
    );
  }

  Widget _buildTranslatorBody() {
    final hint    = _subtitleHint;
    final hasText = _displayText.isNotEmpty;
    final showCaption = _captionVisible &&
        (_currentSegment.trim().isNotEmpty || _lastFinal.isNotEmpty);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              opacity:  _isListening ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 300),
              child: Row(children: [
                FadeTransition(
                  opacity: _isListening
                      ? _dotAnim
                      : const AlwaysStoppedAnimation<double>(1.0),
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('LIVE',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
              ]),
            ),
            if (_isListening) ...[
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accentTint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer_rounded,
                      color: _accent, size: 11),
                  const SizedBox(width: 4),
                  Text(_sessionLabel,
                      style: const TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ],
        ),

        const SizedBox(height: 28),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(
                minHeight: 140, maxHeight: 320),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _isListening
                    ? _accent.withOpacity(0.5)
                    : _accentBorder,
                width: 1,
              ),
              boxShadow: _isListening
                  ? [BoxShadow(
                      color: _accent.withOpacity(0.12),
                      blurRadius: 24, spreadRadius: 2)]
                  : [BoxShadow(
                      color: _accent.withOpacity(0.05),
                      blurRadius: 8,  spreadRadius: 1)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hint.isNotEmpty)
                  Text(hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16,
                          color: _textSub,
                          height: 1.5)),
                if (showCaption)
                  Flexible(
                    child: SingleChildScrollView(
                      reverse: true,
                      physics: const BouncingScrollPhysics(),
                      child: _buildLiveCaption(),
                    ),
                  ),
                if (hasText) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _textAction(
                          Icons.content_copy_rounded, 'Copy', () {
                        Clipboard.setData(
                            ClipboardData(text: _displayText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Copied to clipboard')),
                        );
                      }),
                      const SizedBox(width: 8),
                      _textAction(Icons.edit_note_rounded, 'Correct',
                          _showAddCorrectionDialog),
                      const SizedBox(width: 8),
                      _textAction(
                          Icons.delete_sweep_rounded, 'Clear', () {
                        setState(() {
                          _displayText    = '';
                          _committedText  = '';
                          _currentSegment = '';
                          _lastFinal      = '';
                          _captionVisible = false;
                        });
                      }),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        if (_isListening)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(Icons.all_inclusive_rounded,
                  'Always-On · Realtime', tinted: true),
              _chip(Icons.noise_aware_rounded, 'Noise Filter',
                  tinted: true),
              _chip(null, '$_wordCount words', tinted: false),
              if (_nlp.patternCount > 0)
                _chip(
                    null,
                    '${_nlp.patternCount} pattern${_nlp.patternCount == 1 ? '' : 's'} active',
                    tinted: true),
            ],
          ),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _chip(IconData? icon, String label, {required bool tinted}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: tinted ? _accentTint : _card,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: tinted ? _accentBorder : _white20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon,
              color: tinted ? _accent : _textSub, size: 11),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: TextStyle(
                color: tinted ? _accent : _textSub, fontSize: 11)),
      ]),
    );
  }

  Widget _textAction(
      IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _accentTint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _accentBorder),
        ),
        child: Row(children: [
          Icon(icon, size: 13, color: _accent),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(color: _accent, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildCorrectionsPanel() {
    final uid =
        _activeUserId ?? FirebaseAuth.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(children: [
            const Icon(Icons.format_list_bulleted_rounded,
                color: _accent, size: 18),
            const SizedBox(width: 8),
            const Text('Learned Corrections',
                style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            const Spacer(),
            GestureDetector(
              onTap: _showAddCorrectionDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _accentTint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentBorder),
                ),
                child: const Row(children: [
                  Icon(Icons.add_rounded, color: _accent, size: 14),
                  SizedBox(width: 4),
                  Text('Add',
                      style: TextStyle(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
        Expanded(
          child: uid == null
              ? const Center(
                  child: Text('Not signed in',
                      style: TextStyle(color: _textSub)))
              : StreamBuilder<QuerySnapshot>(
                  stream: _correctionsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: _accent, strokeWidth: 2));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                  color: _accentTint,
                                  shape: BoxShape.circle),
                              child: const Icon(
                                  Icons.auto_fix_high_rounded,
                                  color: _accent,
                                  size: 32),
                            ),
                            const SizedBox(height: 16),
                            const Text('No corrections yet',
                                style: TextStyle(
                                    color: _textDark,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 6),
                            const Text(
                              'Speak, then tap "Correct"\nto teach VoiceMate your patterns.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: _textSub,
                                  fontSize: 12,
                                  height: 1.6),
                            ),
                          ],
                        ),
                      );
                    }
                    final sorted = List.of(docs)
                      ..sort((a, b) {
                        final aData =
                            a.data() as Map<String, dynamic>;
                        final bData =
                            b.data() as Map<String, dynamic>;
                        final aIsUser =
                            (aData['source'] as String? ?? '') ==
                                'user';
                        final bIsUser =
                            (bData['source'] as String? ?? '') ==
                                'user';
                        if (aIsUser != bIsUser) {
                          return aIsUser ? -1 : 1;
                        }
                        return (aData['wrong'] as String? ?? '')
                            .compareTo(
                                bData['wrong'] as String? ?? '');
                      });
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          20, 0, 20, 100),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final data = sorted[i].data()
                            as Map<String, dynamic>;
                        return _correctionTile(
                          wrong:   data['wrong']   as String? ?? '',
                          correct: data['correct'] as String? ?? '',
                          source:  data['source']  as String? ?? 'ai',
                          docId:   sorted[i].id,
                          uid:     uid,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _correctionTile({
    required String wrong,
    required String correct,
    required String source,
    required String docId,
    required String uid,
  }) {
    final isUser = source == 'user';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isUser ? _accentBorder : _white20),
        boxShadow: [
          BoxShadow(
              color: _accent.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: isUser ? _accentTint : _card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isUser
                ? Icons.person_rounded
                : Icons.auto_fix_high_rounded,
            color: isUser ? _accent : _textSub,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text('"$wrong"',
                  style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded,
                  color: _textSub, size: 14),
            ),
            Flexible(
              child: Text('"$correct"',
                  style: const TextStyle(
                      color: _accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isUser ? _accentTint : _card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(isUser ? 'You' : 'AI',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isUser ? _accent : _textSub)),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _deleteCorrection(
                uid: uid,
                docId: docId,
                wrong: wrong,
                correct: correct),
            child: const Icon(Icons.delete_outline_rounded,
                size: 16, color: Colors.redAccent),
          ),
        ]),
      ]),
    );
  }

  // Start / Stop button. Shows Start when the mic is off and Stop (pulsing,
  // red) while it is listening.
  Widget _buildMicFab() {
    final listening = _isListening;
    final color = listening ? Colors.redAccent : _accent;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => Transform.scale(
        scale: listening ? _pulseAnim.value : 1.0,
        child: child,
      ),
      child: GestureDetector(
        onTap: listening
            ? _stopListening
            : () => _startAlwaysOn(fromUser: true),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.40),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 10),
              Text(
                listening ? 'Stop' : 'Start',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADD CORRECTION BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _AddCorrectionSheet extends StatefulWidget {
  final TextEditingController wrongController;
  final TextEditingController correctController;
  final NlpService nlp;
  final void Function(String wrong, String correct) onSaved;

  const _AddCorrectionSheet({
    required this.wrongController,
    required this.correctController,
    required this.nlp,
    required this.onSaved,
  });

  @override
  State<_AddCorrectionSheet> createState() =>
      _AddCorrectionSheetState();
}

class _AddCorrectionSheetState extends State<_AddCorrectionSheet> {
  bool _isSaving = false;

  static const _sheetBg      = Color(0xFFEAF4FB);
  static const _sheetSurface = Color(0xFFFFFFFF);
  static const _labelColor   = Color(0xFF5A7A96);
  static const _textColor    = Color(0xFF0D2B4E);
  static const _accent       = Color(0xFF0077B6);
  static const _accentLight  = Color(0xFFD6EEFF);
  static const _borderColor  = Color(0xFFB8D4E8);
  static const _hintColor    = Color(0xFF8AAEC8);

  Future<void> _handleSave() async {
    final wrong   = widget.wrongController.text.trim();
    final correct = widget.correctController.text.trim();
    if (wrong.isEmpty || correct.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await widget.nlp.learnPattern(wrong, correct);
      await NotificationHelper.wordAdded(correct);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (mounted) {
      Navigator.pop(context);
      widget.onSaved(wrong, correct);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: _sheetBg,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_fix_high_rounded,
                    color: _accent, size: 18),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Teach a Correction',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _textColor)),
                  SizedBox(height: 2),
                  Text('Tell VoiceMate what it heard wrong.',
                      style: TextStyle(
                          fontSize: 12, color: _labelColor)),
                ],
              ),
            ]),
            const SizedBox(height: 24),
            _label('WHAT WAS HEARD (WRONG)'),
            const SizedBox(height: 6),
            _field(widget.wrongController,
                hint: 'e.g. "kea"',
                icon: Icons.hearing_outlined),
            const SizedBox(height: 16),
            _label('WHAT IT SHOULD BE (CORRECT)'),
            const SizedBox(height: 6),
            _field(widget.correctController,
                hint: 'e.g. "tea"',
                icon: Icons.check_circle_outline),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _labelColor,
                    side: const BorderSide(color: _borderColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: _sheetSurface,
                  ),
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor:
                        _accent.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          color: _accent,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600));

  Widget _field(TextEditingController controller,
      {required String hint, required IconData icon}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: _textColor, fontSize: 14),
      decoration: InputDecoration(
        hintText:   hint,
        hintStyle:  const TextStyle(color: _hintColor, fontSize: 13),
        prefixIcon: Icon(icon, color: _labelColor, size: 18),
        filled:     true,
        fillColor:  _sheetSurface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }
}