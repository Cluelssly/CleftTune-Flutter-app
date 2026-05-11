import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nlp_service.dart';
import 'notifications.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Phoneme Analysis Engine
// ─────────────────────────────────────────────────────────────────────────────

class PhonemeIssue {
  final String original;
  final String expected;
  final String substitution;
  final String description;
  final String severity; // 'high' | 'medium' | 'low'
  final String category; // 'consonant' | 'vowel' | 'cluster' | 'stress'

  const PhonemeIssue({
    required this.original,
    required this.expected,
    required this.substitution,
    required this.description,
    required this.severity,
    required this.category,
  });

  @override
  String toString() => '"$original" → $expected (heard as "$substitution")';
}

class PhonemeAnalysisResult {
  final int clarityScore;
  final double similarity;
  final List<PhonemeIssue> issues;
  final String overallFeedback;
  final Map<String, int> categoryBreakdown;
  final List<String> drillSuggestions;

  const PhonemeAnalysisResult({
    required this.clarityScore,
    required this.similarity,
    required this.issues,
    required this.overallFeedback,
    required this.categoryBreakdown,
    required this.drillSuggestions,
  });
}

class PhonemeAnalyzer {
  // Common phoneme substitution patterns (what STT hears vs what was likely said)
  static const Map<String, Map<String, String>> _substitutionPatterns = {
    // Consonant substitutions
    'th_to_d': {'pattern': r'\b(d)(e|is|at|em|ey|ere|ose|ough)\b', 'expected': 'th', 'category': 'consonant'},
    'th_to_t': {'pattern': r'\b(t)(ink|ing|ings|ree|ree|rone)\b', 'expected': 'th', 'category': 'consonant'},
    'v_to_b': {'pattern': r'\b(b)(ery|ideo|oice|alue|ision)\b', 'expected': 'v', 'category': 'consonant'},
    'w_to_v': {'pattern': r'\b(v)(e|as|ith|ould|ater|ork)\b', 'expected': 'w', 'category': 'consonant'},
    'r_to_l': {'pattern': r'\b(\w*)(l)(ight|ead|ove|iver)\b', 'expected': 'r', 'category': 'consonant'},
    'l_to_r': {'pattern': r'\b(\w*)(r)(ong|eft|ike|ove)\b', 'expected': 'l', 'category': 'consonant'},
    'p_to_f': {'pattern': r'\b(f)(eople|hone|lace|aper)\b', 'expected': 'p', 'category': 'consonant'},
    'sh_to_s': {'pattern': r'\b(s)(ould|all|ip|ort|ow)\b', 'expected': 'sh', 'category': 'consonant'},
    'ch_to_s': {'pattern': r'\b(s)(eck|air|ance|ange)\b', 'expected': 'ch', 'category': 'consonant'},
    'j_to_y': {'pattern': r'\b(y)(ust|ob|ump|oin)\b', 'expected': 'j', 'category': 'consonant'},
    'ng_drop': {'pattern': r'\b(\w+)(in)\b', 'expected': 'ing', 'category': 'consonant'},
    // Vowel substitutions
    'i_to_e': {'pattern': r'\b(\w*)(e)(t|s|ll|n|nd)\b', 'expected': 'i', 'category': 'vowel'},
    'e_to_a': {'pattern': r'\b(\w*)(a)(nd|n|t|s)\b', 'expected': 'e', 'category': 'vowel'},
    'u_to_o': {'pattern': r'\b(o)(p|t|n|s|b)\b', 'expected': 'u', 'category': 'vowel'},
    // Cluster reductions
    'str_to_st': {'pattern': r'\b(st)(ong|eet|ing|ike)\b', 'expected': 'str', 'category': 'cluster'},
    'spr_to_sp': {'pattern': r'\b(sp)(ing|ead|ay)\b', 'expected': 'spr', 'category': 'cluster'},
    'pl_to_p': {'pattern': r'\b(p)(ay|ace|an|ant)\b', 'expected': 'pl', 'category': 'cluster'},
    'bl_to_b': {'pattern': r'\b(b)(ue|ack|ock|ow)\b', 'expected': 'bl', 'category': 'cluster'},
    'gr_to_g': {'pattern': r'\b(g)(een|eat|ow|ab)\b', 'expected': 'gr', 'category': 'cluster'},
    // Final consonant drops
    'final_t_drop': {'pattern': r'\b(\w+[aeiou])\b(?=\s|$)', 'expected': 't', 'category': 'consonant'},
    'final_d_drop': {'pattern': r'\b(\w+[aeiou])\b(?=\s|$)', 'expected': 'd', 'category': 'consonant'},
  };

  // Known homophones and common mishearings
  static const Map<String, List<String>> _commonMishearings = {
    'there': ['their', 'they\'re', 'dare'],
    'your': ['you\'re', 'yer'],
    'to': ['too', 'two'],
    'than': ['den', 'ten'],
    'that': ['dat', 'tat'],
    'the': ['de', 'da'],
    'this': ['dis'],
    'these': ['dese', 'dis'],
    'three': ['tree', 'free'],
    'through': ['trough', 'true'],
    'very': ['berry', 'bery'],
    'voice': ['boys', 'choice'],
    'would': ['wood', 'could'],
    'should': ['could', 'wood'],
    'think': ['tink', 'sink'],
    'thank': ['tank', 'dank'],
    'thing': ['ting', 'sing'],
    'nothing': ['nutting', 'noting'],
    'something': ['sumthing', 'someting'],
    'everything': ['everyting'],
    'with': ['wit', 'wid'],
    'without': ['widout', 'witout'],
    'what': ['wot', 'wat'],
    'where': ['were', 'ware'],
    'whether': ['weather', 'wether'],
    'which': ['witch', 'wich'],
    'while': ['wile', 'vile'],
    'white': ['wite', 'vite'],
    'right': ['light', 'write'],
    'world': ['word', 'worl'],
    'girl': ['gurl', 'gril'],
    'strength': ['strenth', 'stength'],
    'clothes': ['close', 'cloths'],
    'comfortable': ['comftable', 'comforable'],
    'probably': ['probly', 'prolly'],
    'actually': ['acually', 'ackually'],
    'literally': ['litrally', 'literaly'],
    'especially': ['expecially', 'especally'],
    'particularly': ['particuly', 'partiularly'],
  };

  // Drill suggestions per category
  static const Map<String, List<String>> _drillMap = {
    'consonant': [
      'Practice "th" sounds: "the, this, that, there, think"',
      'Minimal pairs drill: "tin/thin, den/then, vet/wet"',
      'Tongue placement: tip of tongue between teeth for /θ/ and /ð/',
    ],
    'vowel': [
      'Vowel ladder: "bit, bet, bat, but, boot"',
      'Mirror practice: watch your mouth shape for each vowel',
      'Record and compare your vowels to a native speaker',
    ],
    'cluster': [
      'Consonant cluster drill: "street, spring, strong, split"',
      'Slow articulation: break clusters into parts, then blend',
      'Tongue twisters: "She sells seashells by the seashore"',
    ],
    'stress': [
      'Word stress practice: "PHOtograph, phoTOGraphy, photoGRAPHic"',
      'Sentence stress: emphasize content words over function words',
      'Rhythm practice: clap syllable stress patterns',
    ],
  };

  static PhonemeAnalysisResult analyze({
    required String rawInput,
    required String correctedOutput,
    required double confidence,
    required int patternCount,
  }) {
    final issues = <PhonemeIssue>[];
    final categoryCount = <String, int>{
      'consonant': 0,
      'vowel': 0,
      'cluster': 0,
      'stress': 0,
    };

    final rawWords = rawInput.toLowerCase().split(RegExp(r'\s+'));
    final corrWords = correctedOutput.toLowerCase().split(RegExp(r'\s+'));

    // Check for known mishearings
    for (int i = 0; i < rawWords.length; i++) {
      final word = rawWords[i].replaceAll(RegExp(r'[^a-z]'), '');
      if (word.isEmpty) continue;

      _commonMishearings.forEach((target, variants) {
        if (variants.contains(word) || _levenshtein(word, target) == 1) {
          final severity = variants.contains(word) ? 'high' : 'medium';
          issues.add(PhonemeIssue(
            original: word,
            expected: target,
            substitution: word,
            description: _describeMishearing(word, target),
            severity: severity,
            category: _classifyMishearing(word, target),
          ));
          categoryCount[_classifyMishearing(word, target)] =
              (categoryCount[_classifyMishearing(word, target)] ?? 0) + 1;
        }
      });
    }

    // Word-level comparison between raw and corrected
    final minLen = rawWords.length < corrWords.length
        ? rawWords.length
        : corrWords.length;
    for (int i = 0; i < minLen; i++) {
      final raw = rawWords[i].replaceAll(RegExp(r'[^a-z]'), '');
      final cor = corrWords[i].replaceAll(RegExp(r'[^a-z]'), '');
      if (raw == cor || raw.isEmpty || cor.isEmpty) continue;

      final dist = _levenshtein(raw, cor);
      if (dist > 0 && dist <= 3) {
        final category = _detectSubstitutionCategory(raw, cor);
        final severity = dist == 1 ? 'low' : dist == 2 ? 'medium' : 'high';
        final alreadyReported = issues.any((iss) => iss.original == raw);
        if (!alreadyReported) {
          issues.add(PhonemeIssue(
            original: raw,
            expected: cor,
            substitution: raw,
            description: _describeSubstitution(raw, cor, category),
            severity: severity,
            category: category,
          ));
          categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        }
      }
    }

    // Remove duplicates
    final seen = <String>{};
    final uniqueIssues = issues.where((i) => seen.add(i.original)).toList();

    // Clarity score calculation
    final baseScore = (confidence * 100).round().clamp(30, 100);
    final penaltyHigh = uniqueIssues.where((i) => i.severity == 'high').length * 8;
    final penaltyMed  = uniqueIssues.where((i) => i.severity == 'medium').length * 4;
    final penaltyLow  = uniqueIssues.where((i) => i.severity == 'low').length * 2;
    final patternBonus = (patternCount * 0.5).round().clamp(0, 15);
    final clarityScore = (baseScore - penaltyHigh - penaltyMed - penaltyLow + patternBonus)
        .clamp(0, 100);

    // Similarity
    final similarity = _stringSimilarity(rawInput.toLowerCase(), correctedOutput.toLowerCase());

    // Feedback
    final feedback = _buildFeedback(clarityScore, uniqueIssues, categoryCount);

    // Drill suggestions
    final drills = <String>{};
    for (final cat in categoryCount.keys) {
      if ((categoryCount[cat] ?? 0) > 0 && _drillMap.containsKey(cat)) {
        final catDrills = _drillMap[cat]!;
        drills.add(catDrills[uniqueIssues.length % catDrills.length]);
      }
    }
    if (drills.isEmpty && clarityScore < 70) {
      drills.add('General: Read aloud for 10 minutes daily, recording yourself');
    }

    return PhonemeAnalysisResult(
      clarityScore: clarityScore,
      similarity: similarity,
      issues: uniqueIssues,
      overallFeedback: feedback,
      categoryBreakdown: categoryCount,
      drillSuggestions: drills.toList(),
    );
  }

  static String _classifyMishearing(String heard, String target) {
    final heardL = heard.toLowerCase();
    final targetL = target.toLowerCase();

    // Consonant substitutions
    if ((heardL.startsWith('d') && targetL.startsWith('th')) ||
        (heardL.startsWith('t') && targetL.startsWith('th')) ||
        (heardL.startsWith('b') && targetL.startsWith('v')) ||
        (heardL.startsWith('v') && targetL.startsWith('w'))) {
      return 'consonant';
    }
    // Vowel substitutions
    final vowelPairs = [['e', 'i'], ['a', 'e'], ['o', 'u']];
    for (final pair in vowelPairs) {
      if (heardL.contains(pair[0]) && targetL.contains(pair[1])) return 'vowel';
    }
    // Cluster reductions
    if (targetL.length - heardL.length >= 1 &&
        RegExp(r'^[bcdfghjklmnpqrstvwxyz]{2}').hasMatch(targetL)) {
      return 'cluster';
    }
    return 'consonant';
  }

  static String _describeMishearing(String heard, String target) {
    if (heard.startsWith('d') && target.startsWith('th')) {
      return '/d/ substituted for /ð/ — dental fricative not formed';
    }
    if (heard.startsWith('t') && target.startsWith('th')) {
      return '/t/ substituted for /θ/ — tongue not between teeth';
    }
    if (heard.startsWith('b') && target.startsWith('v')) {
      return '/b/ substituted for /v/ — labiodental friction missing';
    }
    if (heard.startsWith('v') && target.startsWith('w')) {
      return '/v/ substituted for /w/ — lip rounding inconsistent';
    }
    return 'Phoneme substitution detected — review articulation';
  }

  static String _detectSubstitutionCategory(String raw, String cor) {
    // Cluster check
    if (RegExp(r'^[bcdfghjklmnpqrstvwxyz]{2}').hasMatch(cor) &&
        !RegExp(r'^[bcdfghjklmnpqrstvwxyz]{2}').hasMatch(raw)) {
      return 'cluster';
    }
    // Vowel-only diff
    final rawC = raw.replaceAll(RegExp(r'[aeiou]'), '');
    final corC = cor.replaceAll(RegExp(r'[aeiou]'), '');
    if (rawC == corC) return 'vowel';
    // Stress (length difference)
    if ((raw.length - cor.length).abs() >= 2) return 'stress';
    return 'consonant';
  }

  static String _describeSubstitution(String raw, String cor, String category) {
    switch (category) {
      case 'cluster':
        return 'Consonant cluster /${_getCluster(cor)}/ reduced — blend both sounds';
      case 'vowel':
        return 'Vowel quality shift in "$raw" → "$cor" — check tongue height/position';
      case 'stress':
        return 'Syllable stress pattern off in "$raw" — emphasize the stressed syllable';
      default:
        return 'Consonant substitution: "$raw" heard instead of "$cor"';
    }
  }

  static String _getCluster(String word) {
    final match = RegExp(r'^[bcdfghjklmnpqrstvwxyz]{2,3}').firstMatch(word);
    return match?.group(0) ?? word.substring(0, 2);
  }

  static String _buildFeedback(
    int score,
    List<PhonemeIssue> issues,
    Map<String, int> cats,
  ) {
    if (score >= 85) return 'Excellent clarity! Minor refinements may improve precision.';
    if (score >= 70) {
      final dominant = _dominantCategory(cats);
      return 'Good clarity. Focus on $dominant articulation for improvement.';
    }
    if (score >= 50) {
      final count = issues.length;
      return '$count phoneme substitution${count == 1 ? '' : 's'} detected. Targeted drills recommended.';
    }
    return 'Multiple articulation patterns need attention. Daily drilling will help significantly.';
  }

  static String _dominantCategory(Map<String, int> cats) {
    String top = 'consonant';
    int max = 0;
    cats.forEach((k, v) { if (v > max) { max = v; top = k; } });
    return top;
  }

  // Levenshtein distance
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final rows = List.generate(
      a.length + 1, (i) => List.generate(b.length + 1, (j) => i == 0 ? j : (j == 0 ? i : 0)),
    );
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        rows[i][j] = [
          rows[i - 1][j] + 1,
          rows[i][j - 1] + 1,
          rows[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return rows[a.length][b.length];
  }

  // String similarity 0.0–1.0
  static double _stringSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final dist = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1.0 - (dist / maxLen);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main App & Screen
// ─────────────────────────────────────────────────────────────────────────────

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

  // ── User data ──────────────────────────────────────────────────────────────
  String _userName = '';
  bool _isLoadingUser = true;

  // ── Training state ─────────────────────────────────────────────────────────
  String _rawOutput        = '';
  String _correctedOutput  = '';
  bool   _isProcessing     = false;
  bool   _isListening      = false;
  bool   _speechAvailable  = false;
  double _trainingProgress = 0.0;
  double _soundLevel       = 0.0;
  int    _sessionCount     = 0;
  double _trainedHours     = 0.0;
  double _lastConfidence   = 0.6;

  // ── Phoneme analysis ───────────────────────────────────────────────────────
  PhonemeAnalysisResult? _phonemeResult;

  late AnimationController _pulseController;

  // ── Color constants ────────────────────────────────────────────────────────
  static const _bg        = Color(0xFF060F1A);
  static const _surface   = Color(0xFF0D1F2D);
  static const _card      = Color(0xFF112233);
  static const _teal      = Color(0xFF0ECFB0);
  static const _tealDark  = Color(0xFF0A8A78);
  static const _tealDeep  = Color(0xFF0B5D5E);
  static const _accent    = Color(0xFF1AE5C8);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _initSpeech();
    _loadUserData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Load user data ─────────────────────────────────────────────────────────
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _isLoadingUser = false); return; }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final data = doc.data();
      setState(() {
        _userName         = data?['name'] ?? user.displayName ?? 'Aljhen';
        _trainingProgress = (data?['trainingProgress'] ?? 0.0).toDouble().clamp(0.0, 1.0);
        _sessionCount     = (data?['sessionCount'] ?? 0) as int;
        _trainedHours     = (data?['trainedHours'] ?? 0.0).toDouble();
        _isLoadingUser    = false;
      });
      await _nlp.init();
    } catch (_) {
      setState(() {
        _userName      = FirebaseAuth.instance.currentUser?.displayName ?? 'Aljhen';
        _isLoadingUser = false;
      });
    }
  }

  // ── Save training progress ─────────────────────────────────────────────────
  Future<void> _saveTrainingProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'trainingProgress': _trainingProgress,
      'patternCount':     _nlp.patternCount,
      'sessionCount':     _sessionCount,
      'trainedHours':     _trainedHours,
      'lastTrainedAt':    FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError:  (e) { debugPrint('STT error: $e'); setState(() => _isListening = false); },
      onStatus: (s) {
        debugPrint('STT status: $s');
        if (s == 'done' || s == 'notListening') setState(() => _isListening = false);
      },
    );
    setState(() {});
  }

  // ── Toggle mic ─────────────────────────────────────────────────────────────
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    if (!_speechAvailable) { _showSnack('Microphone not available. Check permissions.'); return; }

    setState(() {
      _rawOutput       = '';
      _correctedOutput = '';
      _phonemeResult   = null;
      _isListening     = true;
      _soundLevel      = 0.0;
      _lastConfidence  = 0.6;
    });

    await NotificationHelper.trainingStarted();

    await _speech.listen(
      onResult: (result) async {
        final recognized = result.recognizedWords.trim();
        if (recognized.isEmpty) return;
        setState(() {
          _rawOutput      = recognized;
          _lastConfidence = result.confidence > 0 ? result.confidence.toDouble() : 0.6;
        });

        if (!_nlp.isReliableSpeechResult(recognized, _lastConfidence)) return;

        if (result.finalResult) {
          setState(() {
            _isListening   = false;
            _isProcessing  = true;
            _sessionCount += 1;
            _trainedHours  = double.parse((_trainedHours + 0.05).toStringAsFixed(2));
          });
          await _runCorrection(recognized);
        }
      },
      onSoundLevelChange: (level) => setState(() => _soundLevel = (level + 160) / 160),
      listenFor:      const Duration(seconds: 30),
      pauseFor:       const Duration(seconds: 4),
      partialResults: true,
      localeId:       'en_US',
      cancelOnError:  true,
    );
  }

  // ── Run NLP + phoneme analysis ─────────────────────────────────────────────
  Future<void> _runCorrection(String raw) async {
    final result = await _nlp.correct(raw);
    final correctedText = result['corrected'] as String;

    // Full phoneme analysis
    final phoneme = PhonemeAnalyzer.analyze(
      rawInput:        raw,
      correctedOutput: correctedText,
      confidence:      _lastConfidence,
      patternCount:    _nlp.patternCount,
    );

    final gain = 0.003 * (1.0 - _trainingProgress);

    setState(() {
      _correctedOutput  = correctedText;
      _phonemeResult    = phoneme;
      _isProcessing     = false;
      _trainingProgress = (_trainingProgress + gain).clamp(0.0, 1.0);
    });

    await _saveTrainingProgress();
    await NotificationHelper.trainingCompleted(accuracy: _trainingProgress * 100);
  }

  // ── Word correction sheet ──────────────────────────────────────────────────
  void _showWordCorrectionSheet(String word) {
    final controller = TextEditingController(text: word);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 20),
            Row(children: [
              const Icon(Icons.edit_note_rounded, color: _teal, size: 20),
              const SizedBox(width: 8),
              Text('Correct "$word"',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            const Text('What did you mean to say?',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true, fillColor: _surface,
                hintText: 'Correct word...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.record_voice_over_rounded, color: _teal, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _teal, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _tealDeep,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.model_training_rounded, color: Colors.white, size: 18),
              label: const Text('Save & Teach AI',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () async {
                final correctWord = controller.text.trim();
                if (correctWord.isNotEmpty && correctWord != word) {
                  await _nlp.learnPattern(word, correctWord);
                  final r       = await _nlp.correct(_rawOutput);
                  final updated = r['corrected'] as String;

                  final phoneme = PhonemeAnalyzer.analyze(
                    rawInput:        _rawOutput,
                    correctedOutput: updated,
                    confidence:      _lastConfidence,
                    patternCount:    _nlp.patternCount,
                  );

                  final gain = 0.008 * (1.0 - _trainingProgress);
                  setState(() {
                    _correctedOutput  = updated;
                    _phonemeResult    = phoneme;
                    _trainingProgress = (_trainingProgress + gain).clamp(0.0, 1.0);
                  });
                  await _saveTrainingProgress();
                  await NotificationHelper.wordAdded(correctWord);
                }
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 20),
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 20),
              _buildVocalProfileCard(),
              const SizedBox(height: 20),
              _buildAnalysisPanel(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trained Voice',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Voice Model Training',
                  style: TextStyle(fontSize: 11, color: Colors.white38)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _tealDeep,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
        ),
      ],
    );
  }

  // ── Status card ────────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    final statusLabel = _isListening ? 'LISTENING...' : _isProcessing ? 'PROCESSING...' : 'ACTIVE';
    final pct = (_trainingProgress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A6E6F), Color(0xFF0C8A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: _teal.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? Colors.redAccent : Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('STATUS: $statusLabel',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  ],
                ),
              ),
              Text('$pct%',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          Text("Training: $_userName's Voice Model",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Refining acoustic nuances and tonal stability',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _trainingProgress,
              minHeight: 8,
              backgroundColor: Colors.black26,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_nlp.patternCount} patterns learned',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text('${_trainedHours.toStringAsFixed(1)}h trained',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        _statChip(Icons.mic_rounded, '$_sessionCount', 'Sessions'),
        const SizedBox(width: 10),
        _statChip(Icons.track_changes_rounded,
            '${(_trainingProgress * 100).toStringAsFixed(0)}%', 'Accuracy'),
        const SizedBox(width: 10),
        _statChip(Icons.timer_outlined,
            '${_trainedHours.toStringAsFixed(1)}h', 'Trained'),
      ],
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: _teal, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
          ],
        ),
      ),
    );
  }

  // ── Vocal profile card (only trained) ─────────────────────────────────────
  Widget _buildVocalProfileCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vocal Profile',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _teal.withOpacity(0.4), width: 1.2),
            boxShadow: [BoxShadow(color: _teal.withOpacity(0.08), blurRadius: 12)],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.graphic_eq_rounded, color: _teal, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$_userName's Trained Voice",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 3),
                    const Text('Optimized for daily conversation',
                        style: TextStyle(fontSize: 12, color: Colors.white54)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _teal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('ACTIVE',
                          style: TextStyle(color: _teal, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle_rounded, color: _teal, size: 22),
            ],
          ),
        ),
      ],
    );
  }

  // ── Analysis panel ─────────────────────────────────────────────────────────
  Widget _buildAnalysisPanel() {
    final clarity = _phonemeResult?.clarityScore ?? 0;
    final match   = _phonemeResult != null
        ? '${(_phonemeResult!.similarity * 100).toStringAsFixed(0)}%'
        : '—';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Icon(Icons.analytics_rounded, color: _teal, size: 18),
            const SizedBox(width: 8),
            const Text('Detailed Analysis',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
          ]),
          const SizedBox(height: 4),
          const Text('Focusing on high-frequency stability and phoneme precision.',
              style: TextStyle(color: Colors.white38, fontSize: 12)),

          const SizedBox(height: 16),

          // Clarity + Match chips
          Row(
            children: [
              _analyticsChip(
                icon: Icons.graphic_eq_rounded,
                label: 'Clarity',
                value: clarity > 0 ? '$clarity%' : '—',
                color: clarity > 0 ? _clarityColor(clarity) : Colors.white38,
              ),
              const SizedBox(width: 10),
              _analyticsChip(
                icon: Icons.compare_arrows_rounded,
                label: 'Match',
                value: match,
                color: _teal,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Waveform
          _buildWaveform(),

          const SizedBox(height: 20),

          // Mic button
          Center(child: _buildMicButton()),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _isListening ? 'Tap to stop' : _isProcessing ? 'Processing...'
                  : _speechAvailable ? 'Tap mic to start speaking' : 'Microphone unavailable',
              style: TextStyle(
                color: _isListening ? Colors.redAccent : Colors.white38,
                fontSize: 12, fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Raw STT
          if (_rawOutput.isNotEmpty) ...[
            _sectionLabel('What the AI Heard'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(_rawOutput,
                  style: const TextStyle(fontSize: 14, color: Colors.white70, fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 14),
          ],

          // Processing spinner
          if (_isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(color: _teal, strokeWidth: 2.5),
              ),
            )
          else if (_correctedOutput.isNotEmpty) ...[
            _buildCorrectedWordsSection(),
            const SizedBox(height: 16),
            _buildPhonemePanel(),
            const SizedBox(height: 8),
            Text('${_nlp.patternCount} patterns learned',
                style: const TextStyle(color: _teal, fontSize: 11)),
          ],

          const SizedBox(height: 20),
          _buildResetButton(),
        ],
      ),
    );
  }

  // ── Waveform ───────────────────────────────────────────────────────────────
  Widget _buildWaveform() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(28, (i) {
            final h = _isListening
                ? (((i % 5) + 1) * 3.5 + _soundLevel * 18 * ((i % 3) + 1) / 3).clamp(4.0, 44.0)
                : ((i % 5) + 1) * 6.0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 2.5,
              height: h,
              decoration: BoxDecoration(
                color: _isListening ? _teal : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Mic button ─────────────────────────────────────────────────────────────
  Widget _buildMicButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final scale = _isListening
            ? 1.0 + (_pulseController.value * 0.12) + (_soundLevel * 0.07)
            : 1.0;
        final glowOpacity = _isListening ? 0.3 + (_pulseController.value * 0.3) : 0.0;

        return GestureDetector(
          onTap: _isProcessing ? null : _toggleListening,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isListening) ...[
                Transform.scale(scale: scale + 0.35, child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withOpacity(glowOpacity * 0.3),
                  ),
                )),
                Transform.scale(scale: scale + 0.15, child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withOpacity(glowOpacity * 0.5),
                  ),
                )),
              ],
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.redAccent
                        : _isProcessing ? Colors.white24
                        : _tealDeep,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.redAccent : _teal).withOpacity(0.4),
                        blurRadius: 20, spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white, size: 32,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Corrected words (tappable) ─────────────────────────────────────────────
  Widget _buildCorrectedWordsSection() {
    if (_correctedOutput.isEmpty) return const SizedBox.shrink();
    final words = _correctedOutput.split(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('AI Corrected Output — tap any word to fix'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: words.map((word) => GestureDetector(
            onTap: () => _showWordCorrectionSheet(word),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _teal.withOpacity(0.25)),
              ),
              child: Text(word, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          )).toList(),
        ),
      ],
    );
  }

  // ── Phoneme panel (fully functional) ──────────────────────────────────────
  Widget _buildPhonemePanel() {
    final r = _phonemeResult;
    if (r == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Icon(Icons.spatial_audio_off_rounded, color: _teal, size: 16),
            const SizedBox(width: 6),
            const Text('Phoneme Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ]),

          const SizedBox(height: 10),

          // Overall feedback
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _clarityColor(r.clarityScore).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _clarityColor(r.clarityScore).withOpacity(0.2)),
            ),
            child: Text(r.overallFeedback,
                style: TextStyle(color: _clarityColor(r.clarityScore), fontSize: 12, fontWeight: FontWeight.w500)),
          ),

          const SizedBox(height: 12),

          // Category breakdown
          if (r.categoryBreakdown.values.any((v) => v > 0)) ...[
            _sectionLabel('Substitution Categories'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: r.categoryBreakdown.entries
                  .where((e) => e.value > 0)
                  .map((e) => _categoryBadge(e.key, e.value))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Detected issues
          if (r.issues.isNotEmpty) ...[
            _sectionLabel('Detected Substitutions'),
            const SizedBox(height: 8),
            ...r.issues.map((issue) => _issueRow(issue)),
            const SizedBox(height: 12),
          ] else ...[
            Row(children: const [
              Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 14),
              SizedBox(width: 6),
              Text('No phoneme substitutions detected',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
          ],

          // Drill suggestions
          if (r.drillSuggestions.isNotEmpty) ...[
            _sectionLabel('Practice Drills'),
            const SizedBox(height: 8),
            ...r.drillSuggestions.map((drill) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.fitness_center_rounded, color: _teal, size: 13),
                  const SizedBox(width: 6),
                  Expanded(child: Text(drill,
                      style: const TextStyle(color: Colors.white60, fontSize: 11))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _issueRow(PhonemeIssue issue) {
    final color = issue.severity == 'high' ? Colors.redAccent
        : issue.severity == 'medium' ? Colors.orangeAccent
        : Colors.yellowAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color, size: 13),
              const SizedBox(width: 5),
              Text('"${issue.original}" → "${issue.expected}"',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(issue.severity.toUpperCase(),
                    style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(issue.description,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _categoryBadge(String category, int count) {
    const colors = {
      'consonant': Colors.blueAccent,
      'vowel':     Colors.purpleAccent,
      'cluster':   Colors.orangeAccent,
      'stress':    Colors.pinkAccent,
    };
    final color = colors[category] ?? Colors.white38;
    final icons = {
      'consonant': Icons.keyboard_rounded,
      'vowel':     Icons.record_voice_over_rounded,
      'cluster':   Icons.link_rounded,
      'stress':    Icons.bar_chart_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icons[category] ?? Icons.circle, color: color, size: 11),
          const SizedBox(width: 5),
          Text('${category[0].toUpperCase()}${category.substring(1)} ($count)',
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Reset button ───────────────────────────────────────────────────────────
  Widget _buildResetButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Colors.white24),
      ),
      icon: const Icon(Icons.restart_alt_rounded, color: Colors.white54, size: 18),
      label: const Text('Reset NLP Patterns',
          style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600)),
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: _card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Reset Training?', style: TextStyle(color: Colors.white)),
            content: const Text(
              'This will clear all learned patterns and reset your training progress to 0%.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await _nlp.clearPatterns();
          setState(() {
            _rawOutput        = '';
            _correctedOutput  = '';
            _phonemeResult    = null;
            _trainingProgress = 0.0;
            _sessionCount     = 0;
            _trainedHours     = 0.0;
          });
          await _saveTrainingProgress();
          _showSnack('Training reset successfully');
        }
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.6, fontWeight: FontWeight.w600),
  );

  Widget _analyticsChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 9, letterSpacing: 0.4)),
                Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _clarityColor(int score) {
    if (score >= 75) return Colors.greenAccent;
    if (score >= 45) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}