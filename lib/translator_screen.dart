import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:developer' as dev;
import 'nlp_service.dart';
import 'notifications.dart'; // ← NEW

class TranslatorScreen extends StatefulWidget {
  final VoidCallback goToPremium;

  const TranslatorScreen({super.key, required this.goToPremium});

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen>
    with TickerProviderStateMixin {
  late stt.SpeechToText _speech;
  final NlpService _nlp = NlpService();

  bool _isListening     = false;
  bool _isInitialized   = false;
  bool _userStopped     = false;
  bool _showCorrections = false;

  String _displayText     = '';
  String _accumulatedText = '';
  bool   _isRefiningFinal = false;

  static const int _maxWords = 30;

  // ── Theme ──────────────────────────────────────────────────────────────────
  static const _bg         = Color(0xFF0D2B2B);
  static const _bgMid      = Color(0xFF0E2233);
  static const _bgDark     = Color(0xFF0B1A28);
  static const _teal       = Color(0xFF1D9E75);
  static const _tealDim    = Color(0x261D9E75);
  static const _tealBorder = Color(0x401D9E75);
  static const _card       = Color(0x0AFFFFFF);
  static const _white40    = Color(0x66FFFFFF);
  static const _white20    = Color(0x33FFFFFF);

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
    dev.log('NLP ready — ${_nlp.patternCount} pattern(s) loaded');

    _nlp.onRealtimeCorrection = (Map<String, dynamic> result) {
      if (!mounted) return;
      final corrected = result['corrected'] as String;
      final preview = (_accumulatedText.isEmpty
          ? corrected
          : '$_accumulatedText $corrected').trim();
      setState(() => _displayText = preview);
    };

    await _initSpeech();
  }

  Future<void> _initSpeech() async {
    _isInitialized = await _speech.initialize(
      onStatus: (status) {
        dev.log('STT STATUS: $status');
        if (!_userStopped &&
            _isListening &&
            (status == 'done' ||
                status == 'notListening' ||
                status == 'doneNoResult')) {
          _restartListening();
        }
      },
      onError: (error) {
        dev.log('STT ERROR: ${error.errorMsg}');
        if (!_userStopped && _isListening) {
          Future.delayed(
              const Duration(milliseconds: 80), _restartListening);
        }
      },
    );
    setState(() {});
  }

  // ── Core listening loop ────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (!_isInitialized) {
      await _initSpeech();
      if (!_isInitialized) return;
    }

    await _speech.listen(
      localeId:       'en_US',
      listenFor:      const Duration(seconds: 60),
      pauseFor:       const Duration(seconds: 4),
      partialResults: true,
      listenMode:     stt.ListenMode.dictation,
      onResult: (result) async {
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;

        final confidence = result.confidence > 0
            ? result.confidence.toDouble()
            : 0.6;

        if (!_nlp.isReliableSpeechResult(words, confidence)) {
          dev.log('Skipping low-confidence result: "$words" ($confidence)');
          return;
        }

        if (result.finalResult) {
          // 1. Local patterns instantly
          final localResult = _nlp.correctPartialSync(words);

          final appended = (_accumulatedText.isEmpty
              ? localResult
              : '$_accumulatedText $localResult').trim();

          if (mounted) setState(() => _displayText = appended);

          // 2. Claude correction
          setState(() => _isRefiningFinal = true);
          try {
            final correctionResult = await _nlp.correct(appended);
            final corrected = correctionResult['corrected'] as String;

            if (mounted) {
              setState(() {
                _accumulatedText = corrected;
                _displayText     = corrected;
                _isRefiningFinal = false;
              });
            }

            // Save to Firestore
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await FirebaseFirestore.instance
                  .collection('translations')
                  .add({
                'text':    corrected,
                'rawText': words,
                'time':    FieldValue.serverTimestamp(),
                'userId':  user.uid,
              });
            }
          } catch (e) {
            dev.log('Final correction error: $e');
            if (mounted) {
              setState(() {
                _accumulatedText = appended;
                _isRefiningFinal = false;
              });
            }
          }
        } else {
          // Partial: local-pattern preview
          final localCorrected = _nlp.correctPartialSync(words);
          final preview = (_accumulatedText.isEmpty
              ? localCorrected
              : '$_accumulatedText $localCorrected').trim();
          if (mounted) setState(() => _displayText = preview);
        }
      },
    );
  }

  Future<void> _restartListening() async {
    if (!_isListening || _userStopped) return;
    await _speech.stop();
    await Future.delayed(const Duration(milliseconds: 40));
    if (!_isListening || _userStopped) return;
    await _startListening();
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      _userStopped = true;
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening     = false;
          _isRefiningFinal = false;
        });
      }
    } else {
      _userStopped     = false;
      _displayText     = '';
      _accumulatedText = '';
      if (mounted) setState(() => _isListening = true);
      _nlp.beginSession();
      await _startListening();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _subtitleHint {
    if (!_isListening && _displayText.isEmpty) return 'Tap the mic to start speaking...';
    if (_isListening  && _displayText.isEmpty) return 'Listening...';
    return '';
  }

  int get _wordCount => _displayText.trim().isEmpty
      ? 0
      : _displayText.trim().split(RegExp(r'\s+')).length;

  // ── Teach correction dialog ────────────────────────────────────────────────
  void _showAddCorrectionDialog() {
    final wrongController   = TextEditingController();
    final correctController = TextEditingController();

    if (_displayText.isNotEmpty) wrongController.text = _displayText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF112828),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: _white20,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Teach a Correction',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 6),
              const Text(
                'Tell CleftTune what word was heard wrong and what it should be.',
                style: TextStyle(fontSize: 12, color: _white40),
              ),
              const SizedBox(height: 20),
              _sheetLabel('WHAT WAS HEARD (WRONG)'),
              const SizedBox(height: 6),
              _sheetField(wrongController,
                  hint: 'e.g. "kea"', icon: Icons.hearing_outlined),
              const SizedBox(height: 14),
              _sheetLabel('WHAT IT SHOULD BE (CORRECT)'),
              const SizedBox(height: 6),
              _sheetField(correctController,
                  hint: 'e.g. "tea"', icon: Icons.check_circle_outline),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _white20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final wrong   = wrongController.text.trim();
                        final correct = correctController.text.trim();
                        if (wrong.isEmpty || correct.isEmpty) return;

                        await _nlp.learnPattern(wrong, correct);

                        // ── NEW: fire word-added notification ──────────────
                        await NotificationHelper.wordAdded(correct);

                        if (mounted) {
                          Navigator.pop(context);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('"$wrong" → "$correct" saved!'),
                              backgroundColor: const Color.fromARGB(255, 192, 252, 252),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      },
                      child: const Text('Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
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
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                TextSpan(
                    text: 'Tune',
                    style: TextStyle(
                        color: _teal,
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
            onTap: () =>
                setState(() => _showCorrections = !_showCorrections),
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
          color: active ? _tealDim : _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? _tealBorder : _white20),
        ),
        child: Icon(icon, size: 18,
            color: active ? _teal : Colors.white70),
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
        // LIVE + refining status row
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
            if (_isRefiningFinal) ...[
              const SizedBox(width: 16),
              AnimatedBuilder(
                animation: _dotAnim,
                builder: (_, __) => Opacity(
                  opacity: _dotAnim.value,
                  child: Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                            color: _teal, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      const Text('refining',
                          style: TextStyle(
                              color: _teal,
                              fontSize: 11,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 28),

        // ── Main subtitle box ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(minHeight: 140),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _isListening ? _teal.withOpacity(0.5) : _white20,
                width: 1,
              ),
              boxShadow: _isListening
                  ? [
                      BoxShadow(
                        color:      _teal.withOpacity(0.08),
                        blurRadius: 24,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Column(
              children: [
                if (hint.isNotEmpty)
                  Text(hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, color: _white40, height: 1.5)),
                if (hasText)
                  Text(_displayText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.45)),
                if (hasText) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _textAction(Icons.content_copy_rounded, 'Copy', () {
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
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Status footer
        if (_isListening)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$_wordCount/$_maxWords words',
                  style: const TextStyle(color: _white40, fontSize: 12)),
              if (_nlp.patternCount > 0) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _tealDim,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _tealBorder),
                  ),
                  child: Text(
                    '${_nlp.patternCount} pattern${_nlp.patternCount == 1 ? '' : 's'} active',
                    style: const TextStyle(color: _teal, fontSize: 11),
                  ),
                ),
              ],
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
          color: _tealDim,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _tealBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: _teal),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: _teal, fontSize: 11)),
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
                  color: _teal, size: 18),
              const SizedBox(width: 8),
              const Text('Learned Corrections',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              const Spacer(),
              GestureDetector(
                onTap: _showAddCorrectionDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _tealDim,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _tealBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_rounded, color: _teal, size: 14),
                      SizedBox(width: 4),
                      Text('Add',
                          style: TextStyle(
                              color: _teal,
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
                      style: TextStyle(color: _white40)))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('corrections')
                      .orderBy('updatedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: _teal, strokeWidth: 2),
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
                                  color: _tealDim,
                                  shape: BoxShape.circle),
                              child: const Icon(
                                  Icons.auto_fix_high_rounded,
                                  color: _teal,
                                  size: 32),
                            ),
                            const SizedBox(height: 16),
                            const Text('No corrections yet',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 6),
                            const Text(
                              'Use the mic, then tap "Correct"\nto teach CleftTune your patterns.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: _white40,
                                  fontSize: 12,
                                  height: 1.6),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final data =
                            docs[i].data() as Map<String, dynamic>;
                        final wrong   = data['wrong']   as String? ?? '';
                        final correct = data['correct'] as String? ?? '';
                        final source  = data['source']  as String? ?? 'ai';
                        return _correctionTile(
                          wrong:   wrong,
                          correct: correct,
                          source:  source,
                          docId:   docs[i].id,
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
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isUser ? _tealBorder : _white20),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: isUser
                  ? _tealDim
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isUser
                  ? Icons.person_rounded
                  : Icons.auto_fix_high_rounded,
              color: isUser ? _teal : Colors.white38,
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded,
                      color: _white40, size: 14),
                ),
                Flexible(
                  child: Text('"$correct"',
                      style: const TextStyle(
                          color: _teal,
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
                  color: isUser
                      ? _tealDim
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isUser ? 'You' : 'AI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isUser ? _teal : Colors.white38,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  // Delete from Firestore
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('corrections')
                      .doc(docId)
                      .delete();

                  // ── NEW: fire word-deleted notification ────────────────
                  await NotificationHelper.wordDeleted(wrong);
                },
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
            color: _isListening ? Colors.redAccent : _teal,
            boxShadow: [
              BoxShadow(
                color: (_isListening ? Colors.redAccent : _teal)
                    .withOpacity(0.45),
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

  // ── Sheet helpers ──────────────────────────────────────────────────────────
  Widget _sheetLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 11,
            color: _white40,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w500));
  }

  Widget _sheetField(
    TextEditingController controller, {
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText:   hint,
        hintStyle:  const TextStyle(color: _white40, fontSize: 13),
        prefixIcon: Icon(icon, color: _white40, size: 18),
        filled:     true,
        fillColor:  const Color(0xFF0D2020),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _white20),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _white20),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _teal, width: 1.2),
        ),
      ),
    );
  }
}