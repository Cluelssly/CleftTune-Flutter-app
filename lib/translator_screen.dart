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
    with TickerProviderStateMixin {
  late stt.SpeechToText _speech;
  final NlpService _nlp = NlpService();

  bool _isListening   = false;
  bool _isInitialized = false;
  bool _userStopped   = false;
  bool _showCorrections = false;

  // Corrections stream
  Stream<QuerySnapshot>? _correctionsStream;

  // ── Text state ─────────────────────────────────────────────────────────────
  String _displayText    = '';
  String _committedText  = '';
  String _currentSegment = '';

  // ── Session duration tracker ───────────────────────────────────────────────
  Timer? _sessionTimer;
  int    _sessionSeconds = 0;

  // ── Debounce timers ────────────────────────────────────────────────────────
  Timer? _bgSaveTimer;
  Timer? _partialNlpDebounce;

  // ── Always-on engine ──────────────────────────────────────────────────────
  Timer? _alwaysOnRestartTimer;
  Timer? _keepAliveTimer;
  bool   _isRestarting = false;

  // ── Theme (Sky Blue / Navy) ────────────────────────────────────────────────
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

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;

  late AnimationController _dotController;
  late Animation<double>   _dotAnim;

  @override
  void initState() {
    super.initState();
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
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _dotAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _dotController, curve: Curves.easeInOut),
    );

    _initServices();
  }

  Future<void> _initServices() async {
    await _nlp.init();
    _initCorrectionsStream();
    dev.log('NLP ready — ${_nlp.patternCount} pattern(s) loaded');
    _nlp.onRealtimeCorrection = null;
    await _initSpeech();
  }

  void _initCorrectionsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _correctionsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('corrections')
        .snapshots();
  }

  Future<void> _initSpeech() async {
    _isInitialized = await _speech.initialize(
      onStatus: (status) {
        dev.log('STT STATUS: $status');
        if (!_userStopped && _isListening) {
          if (status == 'done' ||
              status == 'notListening' ||
              status == 'doneNoResult' ||
              status == 'notAvailable' ||
              status == 'error') {
            dev.log('STT stopped (status: $status) — restarting...');
            _scheduleAlwaysOnRestart();
          }
        }
      },
      onError: (error) {
        dev.log('STT ERROR: ${error.errorMsg}');
        if (!_userStopped && _isListening) {
          dev.log('STT error — restarting...');
          _scheduleAlwaysOnRestart();
        }
      },
    );
    setState(() {});
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER — joins committed history with live partial for display
  // ══════════════════════════════════════════════════════════════════════════

  String _buildDisplay(String committed, String segment) {
    if (committed.isEmpty) return segment;
    if (segment.isEmpty)   return committed;
    if (RegExp(r'^[.,!?;:]').hasMatch(segment)) return '$committed$segment';
    return '$committed $segment';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SESSION TIMER
  // ══════════════════════════════════════════════════════════════════════════

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionSeconds = 0;
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_isListening) { t.cancel(); return; }
      setState(() => _sessionSeconds++);
    });
  }

  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  String get _sessionLabel {
    final m = _sessionSeconds ~/ 60;
    final s = _sessionSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ALWAYS-ON RESTART LOOP
  // ══════════════════════════════════════════════════════════════════════════

  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_userStopped || !_isListening || !mounted) {
        _keepAliveTimer?.cancel();
        return;
      }
      if (!_speech.isListening) {
        dev.log('KeepAlive: mic went silent — restarting now');
        try { await _speech.stop(); } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 50));
        if (!_userStopped && _isListening && mounted) {
          await _startRealtimeListening();
        }
      }
    });
  }

  void _stopKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  void _scheduleAlwaysOnRestart() {
    if (_userStopped || !_isListening) return;
    _isRestarting = true;

    _alwaysOnRestartTimer?.cancel();
    _alwaysOnRestartTimer = Timer(const Duration(milliseconds: 50), () async {
      if (_userStopped || !_isListening || !mounted) {
        _isRestarting = false;
        return;
      }
      dev.log('Always-on: restarting STT engine');
      try { await _speech.stop(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 80));
      if (_userStopped || !_isListening || !mounted) {
        _isRestarting = false;
        return;
      }
      await _startRealtimeListening();
      _isRestarting = false;
    });
  }

  void _stopAlwaysOnLoop() {
    _alwaysOnRestartTimer?.cancel();
    _alwaysOnRestartTimer = null;
    _stopKeepAliveTimer();
    _isRestarting = false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ALWAYS-ON REAL-TIME LISTENING
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _startRealtimeListening() async {
    if (!_isInitialized) {
      await _initSpeech();
      if (!_isInitialized) return;
    }

    _currentSegment = '';
    _startKeepAliveTimer();

    await _speech.listen(
      localeId:       'en_US',
      listenFor:      const Duration(hours: 24),
      pauseFor:       const Duration(seconds: 300),
      partialResults: true,
      listenMode:     stt.ListenMode.dictation,
      onResult: (result) {
        if (_userStopped) return;

        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;

        final confidence = result.confidence > 0
            ? result.confidence.toDouble()
            : 0.6;

        if (words.split(' ').length < 2 && confidence < 0.35) {
          dev.log('Noise filtered: "$words" ($confidence)');
          return;
        }

        final syncCorrected = _nlp.correctPartialSync(words);

        if (result.finalResult) {
          _committedText  = _buildDisplay(_committedText, syncCorrected).trim();
          _currentSegment = '';

          if (mounted) setState(() => _displayText = _committedText);

          _partialNlpDebounce?.cancel();
          _partialNlpDebounce = Timer(
            const Duration(milliseconds: 800),
            () => _runBackgroundSave(words, _committedText),
          );
        } else {
          _currentSegment = syncCorrected;
          final preview   = _buildDisplay(_committedText, _currentSegment);
          if (mounted) setState(() => _displayText = preview);
        }
      },
    );
  }

  void _runBackgroundSave(String rawWords, String syncResult) {
    () async {
      String finalText = syncResult;

      try {
        final correctionResult = await _nlp.correct(syncResult)
            .timeout(const Duration(seconds: 4));
        final refined = (correctionResult['corrected'] as String? ?? '').trim();
        if (refined.isNotEmpty) finalText = refined;
      } catch (e) {
        dev.log('Background NLP error: $e — using sync result');
      }

      if (mounted && _committedText == syncResult && finalText != syncResult) {
        setState(() {
          _committedText = finalText;
          _displayText   = _buildDisplay(finalText, _currentSegment);
        });
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance.collection('translations').add({
          'text':    finalText,
          'rawText': rawWords,
          'time':    FieldValue.serverTimestamp(),
          'userId':  user.uid,
          'mode':    'realtime',
        }).catchError((e) => dev.log('Firestore save error: $e'));
      }
    }();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOGGLE MIC
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _toggleMic() async {
    if (_isListening) {
      _userStopped = true;
      _stopAlwaysOnLoop();
      _bgSaveTimer?.cancel();
      _partialNlpDebounce?.cancel();
      _stopSessionTimer();
      await _speech.stop();

      if (mounted) setState(() => _isListening = false);
    } else {
      _userStopped    = false;
      _isRestarting   = false;
      _displayText    = '';
      _committedText  = '';
      _currentSegment = '';
      _sessionSeconds = 0;
      if (mounted) setState(() => _isListening = true);
      _nlp.beginSession();
      _startSessionTimer();
      await _startRealtimeListening();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _subtitleHint {
    if (!_isListening && _displayText.isEmpty) {
      return 'Tap the mic to start speaking...';
    }
    if (_isListening && _displayText.isEmpty) {
      return 'Listening... speak now';
    }
    return '';
  }

  int get _wordCount => _displayText.trim().isEmpty
      ? 0
      : _displayText.trim().split(RegExp(r'\s+')).length;

  // ══════════════════════════════════════════════════════════════════════════
  // DELETE CORRECTION
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

  // ── Teach correction dialog ────────────────────────────────────────────────
  void _showAddCorrectionDialog() {
    final wrongController   = TextEditingController();
    final correctController = TextEditingController();

    if (_displayText.isNotEmpty) wrongController.text = _displayText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddCorrectionSheet(
        wrongController:   wrongController,
        correctController: correctController,
        nlp:               _nlp,
        onSaved: (wrong, correct) {
          if (mounted) {
            _initCorrectionsStream();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF0077B6), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '"$wrong" → "$correct" saved!',
                        style: const TextStyle(
                            color: Color(0xFF0D2B4E),
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Color(0xFFEAF4FB),
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

  @override
  void dispose() {
    _bgSaveTimer?.cancel();
    _sessionTimer?.cancel();
    _partialNlpDebounce?.cancel();
    _alwaysOnRestartTimer?.cancel();
    _keepAliveTimer?.cancel();
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _showCorrections ? null : _buildMicFab(),
    );
  }

  // ── APP BAR ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                    text: 'Cleft',
                    style: TextStyle(
                        color: _textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                TextSpan(
                    text: 'Tune',
                    style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
            ),
          ),
          const Spacer(),
          _appBarBtn(
            icon: _showCorrections
                ? Icons.close_rounded
                : Icons.format_list_bulleted_rounded,
            onTap: () => setState(() => _showCorrections = !_showCorrections),
            active: _showCorrections,
          ),
          const SizedBox(width: 8),
          _appBarBtn(
            icon: Icons.add_rounded,
            onTap: _showAddCorrectionDialog,
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
          border: Border.all(color: active ? _accentBorder : _white20),
        ),
        child: Icon(icon, size: 18,
            color: active ? _accent : _textSub),
      ),
    );
  }

  // ── TRANSLATOR BODY ────────────────────────────────────────────────────────
  Widget _buildTranslatorBody() {
    final hint    = _subtitleHint;
    final hasText = _displayText.isNotEmpty;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        // ── Status row ───────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              opacity:  _isListening ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 300),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('LIVE',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                ],
              ),
            ),
            if (_isListening) ...[
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accentTint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_rounded, color: _accent, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      _sessionLabel,
                      style: const TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 28),

        // ── Text card ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(minHeight: 140, maxHeight: 320),
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
                      blurRadius: 24,
                      spreadRadius: 2,
                    )]
                  : [BoxShadow(
                      color: _accent.withOpacity(0.05),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hint.isNotEmpty)
                  Text(hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, color: _textSub, height: 1.5)),
                if (hasText)
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        _displayText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                            height: 1.5),
                      ),
                    ),
                  ),
                if (hasText) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _textAction(Icons.content_copy_rounded, 'Copy', () {
                        Clipboard.setData(ClipboardData(text: _displayText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Copied to clipboard')),
                        );
                      }),
                      const SizedBox(width: 8),
                      _textAction(Icons.edit_note_rounded, 'Correct',
                          _showAddCorrectionDialog),
                      const SizedBox(width: 8),
                      _textAction(Icons.delete_sweep_rounded, 'Clear', () {
                        setState(() {
                          _displayText    = '';
                          _committedText  = '';
                          _currentSegment = '';
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

        // ── Session chips ────────────────────────────────────────────────────
        if (_isListening)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8, runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _accentTint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.all_inclusive_rounded,
                        color: _accent, size: 11),
                    SizedBox(width: 4),
                    Text('Always-On · Realtime',
                        style: TextStyle(
                            color: _accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _accentTint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.noise_aware_rounded,
                        color: _accent, size: 11),
                    SizedBox(width: 4),
                    Text('Noise Filter',
                        style: TextStyle(
                            color: _accent, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _white20),
                ),
                child: Text(
                  '$_wordCount words',
                  style: const TextStyle(
                      color: _textSub, fontSize: 11),
                ),
              ),
              if (_nlp.patternCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accentTint,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accentBorder),
                  ),
                  child: Text(
                    '${_nlp.patternCount} pattern${_nlp.patternCount == 1 ? '' : 's'} active',
                    style: const TextStyle(
                        color: _accent, fontSize: 11),
                  ),
                ),
            ],
          ),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _textAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _accentTint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _accentBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: _accent),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: _accent, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ── CORRECTIONS PANEL ──────────────────────────────────────────────────────
  Widget _buildCorrectionsPanel() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
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
                  child: const Row(
                    children: [
                      Icon(Icons.add_rounded, color: _accent, size: 14),
                      SizedBox(width: 4),
                      Text('Add',
                          style: TextStyle(
                              color: _accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
                            color: _accent, strokeWidth: 2),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                              'Use the mic, then tap "Correct"\nto teach CleftTune your patterns.',
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
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final data = sorted[i].data()
                            as Map<String, dynamic>;
                        final wrong =
                            data['wrong'] as String? ?? '';
                        final correct =
                            data['correct'] as String? ?? '';
                        final source =
                            data['source'] as String? ?? 'ai';
                        return _correctionTile(
                          wrong: wrong,
                          correct: correct,
                          source: source,
                          docId: sorted[i].id,
                          uid: uid,
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
        border: Border.all(color: isUser ? _accentBorder : _white20),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
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
            child: Row(
              children: [
                Flexible(
                  child: Text('"$wrong"',
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isUser ? _accentTint : _card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isUser ? 'You' : 'AI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isUser ? _accent : _textSub,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _deleteCorrection(
                  uid: uid,
                  docId: docId,
                  wrong: wrong,
                  correct: correct,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: Colors.redAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── MIC FAB ────────────────────────────────────────────────────────────────
  Widget _buildMicFab() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => Transform.scale(
        scale: _isListening ? _pulseAnim.value : 1.0,
        child: child,
      ),
      child: GestureDetector(
        onTap: _toggleMic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isListening ? Colors.redAccent : _accent,
            boxShadow: [
              BoxShadow(
                color: (_isListening ? Colors.redAccent : _accent)
                    .withOpacity(0.40),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(
            _isListening ? Icons.stop_rounded : Icons.mic_rounded,
            color: Colors.white,
            size: 34,
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
  State<_AddCorrectionSheet> createState() => _AddCorrectionSheetState();
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            Row(
              children: [
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
                    Text('Tell CleftTune what it heard wrong.',
                        style: TextStyle(
                            fontSize: 12, color: _labelColor)),
                  ],
                ),
              ],
            ),
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
            Row(
              children: [
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
                    onPressed:
                        _isSaving ? null : () => Navigator.pop(context),
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
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('Save',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11,
            color: _accent,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600));
  }

  Widget _field(
    TextEditingController controller, {
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: _textColor, fontSize: 14),
      decoration: InputDecoration(
        hintText:   hint,
        hintStyle:  const TextStyle(color: _hintColor, fontSize: 13),
        prefixIcon: Icon(icon, color: _labelColor, size: 18),
        filled:     true,
        fillColor:  _sheetSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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