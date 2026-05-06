import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'nlp_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NlpService().init();
  runApp(const TrainedVoiceApp());
}

class TrainedVoiceApp extends StatelessWidget {
  const TrainedVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TrainedVoiceScreen(),
    );
  }
}

class TrainedVoiceScreen extends StatefulWidget {
  const TrainedVoiceScreen({super.key});

  @override
  State<TrainedVoiceScreen> createState() => _TrainedVoiceScreenState();
}

class _TrainedVoiceScreenState extends State<TrainedVoiceScreen>
    with SingleTickerProviderStateMixin {
  final _nlp = NlpService();
  final stt.SpeechToText _speech = stt.SpeechToText();

  String _rawOutput = '';
  String _correctedOutput = '';
  bool _isProcessing = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  double _trainingProgress = 0.92;
  double _soundLevel = 0.0;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _initSpeech();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) {
        debugPrint('STT error: $e');
        setState(() => _isListening = false);
      },
      onStatus: (status) {
        debugPrint('STT status: $status');
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    setState(() {});
  }

  // ── Start / Stop microphone listening ─────────────────────────────────────
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      _showSnack('Microphone not available. Check permissions.');
      return;
    }

    setState(() {
      _rawOutput = '';
      _correctedOutput = '';
      _isListening = true;
      _soundLevel = 0.0;
    });

    await _speech.listen(
      onResult: (result) async {
        final recognized = result.recognizedWords.trim();
        if (recognized.isEmpty) return;

        setState(() {
          _rawOutput = recognized;
          // Keep listening state until finalResult
        });

        // When the engine gives a final result, run NLP correction
        if (result.finalResult) {
          setState(() {
            _isListening = false;
            _isProcessing = true;
          });
          await _runCorrection(recognized);
        }
      },
      onSoundLevelChange: (level) {
        setState(() => _soundLevel = (level + 160) / 160); // normalize
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
      localeId: 'en_US',
      cancelOnError: true,
    );
  }

  Future<void> _runCorrection(String raw) async {
    final corrected = await _nlp.correct(raw);
    setState(() {
      _correctedOutput = corrected;
      _isProcessing = false;
      _trainingProgress = (_trainingProgress + 0.005).clamp(0.0, 1.0);
    });
  }

  // ── Word correction bottom sheet ──────────────────────────────────────────
  void _showWordCorrectionSheet(String word) {
    final controller = TextEditingController(text: word);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Correct "$word"',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'What did you mean to say?',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0D2020),
                hintText: 'Correct word...',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.teal),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B5D5E),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final correct = controller.text.trim();
                if (correct.isNotEmpty && correct != word) {
                  await _nlp.learnPattern(word, correct);
                  final updated = await _nlp.correct(_rawOutput);
                  setState(() => _correctedOutput = updated);
                }
                if (mounted) Navigator.pop(context);
              },
              child: const Text(
                'Save & Teach AI',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tappable corrected words ───────────────────────────────────────────────
  Widget _buildCorrectedWords() {
    if (_correctedOutput.isEmpty) return const SizedBox.shrink();
    final words = _correctedOutput.split(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Corrected Output — tap any word to fix:',
          style:
              TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: words.map((word) {
            return GestureDetector(
              onTap: () => _showWordCorrectionSheet(word),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x261D9E75),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x401D9E75)),
                ),
                child: Text(
                  word,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          '${_nlp.patternCount} patterns learned',
          style: const TextStyle(color: Colors.teal, fontSize: 11),
        ),
      ],
    );
  }

  // ── Animated mic button ────────────────────────────────────────────────────
  Widget _buildMicButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = _isListening
            ? 1.0 + (_pulseController.value * 0.15) + (_soundLevel * 0.08)
            : 1.0;
        final glowOpacity =
            _isListening ? 0.3 + (_pulseController.value * 0.3) : 0.0;

        return GestureDetector(
          onTap: (_isProcessing) ? null : _toggleListening,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              if (_isListening)
                Transform.scale(
                  scale: scale + 0.3,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.teal
                          .withOpacity(glowOpacity * 0.4),
                    ),
                  ),
                ),
              // Inner glow ring
              if (_isListening)
                Transform.scale(
                  scale: scale + 0.1,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.teal.withOpacity(glowOpacity * 0.6),
                    ),
                  ),
                ),
              // Main button
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.red
                        : _isProcessing
                            ? Colors.grey
                            : const Color(0xFF0B5D5E),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.red : Colors.teal)
                            .withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── TOP BAR ──────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.arrow_back, color: Colors.white),
                  const SizedBox(width: 10),
                  const Text(
                    'Trained Voice',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0B5D5E),
                    ),
                    child: const Icon(Icons.settings, color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── STATUS CARD ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      _isListening
                          ? 'STATUS: LISTENING...'
                          : _isProcessing
                              ? 'STATUS: PROCESSING...'
                              : 'STATUS: ACTIVE',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text("Training: Alex's Voice Model...",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _trainingProgress,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFD1D0D0),
                        valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF0B5D5E)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(_trainingProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Refining acoustic nuances and tonal stability...',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── VOCAL PROFILES ────────────────────────────────────────────
              const Text(
                'Vocal Profiles',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              _profileCard(
                  title: "Alex's Trained",
                  subtitle: 'Optimized for daily conversation',
                  active: true),
              const SizedBox(height: 10),
              _profileCard(
                  title: 'Default',
                  subtitle: 'Standard system synthesized voice',
                  active: false),

              const SizedBox(height: 20),

              // ── ANALYSIS + MIC + NLP ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF8ECCCC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Detailed Analysis',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text('Focusing on high-frequency stability.'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '${(_trainingProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal),
                        ),
                        const SizedBox(width: 10),
                        const Text('QUALITY\nRATING'),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Waveform / sound level visualizer ─────────────────
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(25, (i) {
                          // Animate bars when listening
                          final heightFactor = _isListening
                              ? (((i % 5) + 1) * 4.0) +
                                  (_soundLevel * 20 * ((i % 3) + 1) / 3)
                              : ((i % 5) + 1) * 8.0;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: 3,
                            height: heightFactor.clamp(4.0, 52.0),
                            color: _isListening
                                ? Colors.teal
                                : const Color(0xFF040706),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Mic button centered ────────────────────────────────
                    Center(child: _buildMicButton()),

                    const SizedBox(height: 8),

                    Center(
                      child: Text(
                        _isListening
                            ? 'Tap to stop'
                            : _isProcessing
                                ? 'Processing...'
                                : _speechAvailable
                                    ? 'Tap to speak'
                                    : 'Microphone unavailable',
                        style: TextStyle(
                          color: _isListening ? Colors.red : Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Raw STT output ─────────────────────────────────────
                    if (_rawOutput.isNotEmpty) ...[
                      const Text(
                        'What the AI heard:',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _rawOutput,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── NLP corrected output / spinner ─────────────────────
                    if (_isProcessing)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(
                              color: Color(0xFF0B5D5E)),
                        ),
                      )
                    else
                      _buildCorrectedWords(),

                    const SizedBox(height: 20),

                    // ── Reset button ───────────────────────────────────────
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await _nlp.clearPatterns();
                        setState(() {
                          _rawOutput = '';
                          _correctedOutput = '';
                        });
                        _showSnack('Patterns cleared');
                      },
                      child: const Text('Reset NLP Patterns'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileCard({
    required String title,
    required String subtitle,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            active ? const Color(0xFF000101) : const Color(0xFF0B0404),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: active ? Colors.teal : const Color(0xFF0B0404),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.graphic_eq,
              color: active ? Colors.teal : Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
          if (active)
            const Icon(Icons.check_circle, color: Colors.teal),
        ],
      ),
    );
  }
}