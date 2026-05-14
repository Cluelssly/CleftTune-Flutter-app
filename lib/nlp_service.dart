import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// NlpService — corrects cleft-palate speech patterns in real-time.
///
/// Patterns are stored in BOTH Firestore (account-level) and SharedPreferences
/// (local cache). On init, Firestore is the source of truth — so corrections
/// persist across logout/login and across devices.
class NlpService {
  static final NlpService _instance = NlpService._internal();
  factory NlpService() => _instance;
  NlpService._internal();

  // ── Local learned patterns ────────────────────────────────────────────────
  final Map<String, String> _patterns = {};
  static const _prefKey = 'nlp_patterns_v1';

  int get patternCount => _patterns.length;
  Map<String, String> get patterns => Map.unmodifiable(_patterns);

  // ── Debounce state for real-time partials ─────────────────────────────────
  Timer? _debounceTimer;
  String _lastCorrectedText = '';
  String _lastRawPartial    = '';

  static const _debounceDuration = Duration(milliseconds: 600);

  // ── Callback invoked when a real-time correction is ready ─────────────────
  void Function(Map<String, dynamic> result)? onRealtimeCorrection;

  // ── Session timing ────────────────────────────────────────────────────────
  DateTime? _sessionStart;

  // ── Auth listener — reloads patterns when user signs in ───────────────────
  StreamSubscription<User?>? _authSub;

  // ── Phoneme substitution patterns (cleft-palate specific) ─────────────────
  final Map<String, List<String>> _phonemePatterns = {
    'k':  ['t', 'g'],
    't':  ['k', 'd'],
    'p':  ['f', 'b'],
    's':  ['sh', 'h'],
    'b':  ['p'],
    'd':  ['g'],
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Init — loads from Firestore first, falls back to local cache
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Listen for auth state changes so patterns reload on every login
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await _loadPatternsFromFirestore();
      }
    });

    // Load immediately for the current session
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _loadPatternsFromFirestore();
    } else {
      // Not signed in — fall back to local cache
      await _loadPatternsFromLocal();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Load patterns: Firestore (source of truth) → merge into local cache
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadPatternsFromFirestore() async {
    final col = _correctionsCol;
    if (col == null) {
      await _loadPatternsFromLocal();
      return;
    }

    try {
      final snapshot = await col.get();
      _patterns.clear();

      for (final doc in snapshot.docs) {
        final data    = doc.data() as Map<String, dynamic>;
        final wrong   = data['wrong']   as String?;
        final correct = data['correct'] as String?;
        if (wrong != null && correct != null) {
          _patterns[wrong] = correct;
        }
      }

      // Mirror to local cache so the app works offline too
      await _persistLocal();
    } catch (_) {
      // Firestore unavailable — fall back to local
      await _loadPatternsFromLocal();
    }
  }

  Future<void> _loadPatternsFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_prefKey);
    if (raw != null) {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      _patterns.addAll(decoded.map((k, v) => MapEntry(k, v as String)));
    }
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(_patterns));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Firestore helpers
  // ─────────────────────────────────────────────────────────────────────────

  DocumentReference? get _userDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  CollectionReference? get _correctionsCol {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('corrections');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Session tracking
  // ─────────────────────────────────────────────────────────────────────────

  void beginSession() {
    _sessionStart      = DateTime.now();
    _lastCorrectedText = '';
    _lastRawPartial    = '';
    _debounceTimer?.cancel();
  }

  Future<void> endSession() async {
    _debounceTimer?.cancel();

    final doc = _userDoc;
    if (doc == null) return;

    final elapsed = _sessionStart != null
        ? DateTime.now().difference(_sessionStart!).inSeconds
        : 0;
    _sessionStart = null;

    await doc.set({
      'training': {
        'sessionCount':   FieldValue.increment(1),
        'trainedSeconds': FieldValue.increment(elapsed),
        'lastTrainedAt':  FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Confidence filtering
  // ─────────────────────────────────────────────────────────────────────────

  bool isReliableSpeechResult(String text, double confidence) {
    if (confidence < 0.55) return false;
    if (text.trim().length < 2) return false;
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pronunciation analysis
  // ─────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> analyzePronunciation(String original, String corrected) {
    final similarity     = calculateSimilarity(original, corrected);
    final detectedIssues = <String>[];

    final lowerOriginal  = original.toLowerCase();
    final lowerCorrected = corrected.toLowerCase();

    _phonemePatterns.forEach((correctSound, wrongSounds) {
      for (final wrong in wrongSounds) {
        if (lowerOriginal.contains(wrong) &&
            lowerCorrected.contains(correctSound)) {
          detectedIssues.add('$wrong → $correctSound substitution');
        }
      }
    });

    return {
      'similarity':   similarity,
      'clarityScore': (similarity * 100).round(),
      'issues':       detectedIssues,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Levenshtein similarity
  // ─────────────────────────────────────────────────────────────────────────

  double calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    final distance  = _levenshtein(s1.toLowerCase(), s2.toLowerCase());
    final maxLength = max(s1.length, s2.length);
    return 1.0 - (distance / maxLength);
  }

  int _levenshtein(String s, String t) {
    final m  = s.length;
    final n  = t.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }
    return dp[m][n];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Real-time partial correction (debounced)
  // ─────────────────────────────────────────────────────────────────────────

  String correctPartialSync(String rawPartial) {
    _lastRawPartial = rawPartial;

    final localResult = _applyLocalPatterns(rawPartial);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () async {
      if (_lastRawPartial.trim() == _lastCorrectedText.trim()) return;
      _lastCorrectedText = _lastRawPartial;

      try {
        final aiResult = await _callClaude(
          _applyLocalPatterns(_lastRawPartial),
          originalRaw: _lastRawPartial,
          isPartial:   true,
        );

        final analysis = analyzePronunciation(_lastRawPartial, aiResult);

        onRealtimeCorrection?.call({
          'corrected':  aiResult,
          'score':      analysis['clarityScore'],
          'issues':     analysis['issues'],
          'similarity': analysis['similarity'],
        });
      } catch (_) {}
    });

    return localResult;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Final correction
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> correct(String raw) async {
    _debounceTimer?.cancel();

    if (raw.trim().isEmpty) {
      return {'corrected': raw, 'score': 100, 'issues': [], 'similarity': 1.0};
    }

    final afterLocal = _applyLocalPatterns(raw);

    try {
      final aiResult = await _callClaude(afterLocal, originalRaw: raw);
      final analysis = analyzePronunciation(raw, aiResult);

      if (aiResult.trim().toLowerCase() != raw.trim().toLowerCase()) {
        await _saveAiCorrection(raw, aiResult);
        await saveSpeechAnalytics(
          original:  raw,
          corrected: aiResult,
          score:     analysis['clarityScore'] as int,
          issues:    analysis['issues'] as List,
        );
      }

      return {
        'corrected':  aiResult,
        'score':      analysis['clarityScore'],
        'issues':     analysis['issues'],
        'similarity': analysis['similarity'],
      };
    } catch (e) {
      return {
        'corrected':  afterLocal,
        'score':      0,
        'issues':     [],
        'similarity': 0.0,
      };
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Analytics tracking
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> saveSpeechAnalytics({
    required String original,
    required String corrected,
    required int    score,
    required List   issues,
  }) async {
    final col = _correctionsCol;
    if (col == null) return;

    await col.add({
      'original':  original,
      'corrected': corrected,
      'score':     score,
      'issues':    issues,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pattern management — always writes to BOTH Firestore + local cache
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> learnPattern(String wrong, String correct) async {
    final key = wrong.toLowerCase().trim();
    final val = correct.trim();

    // 1. Update in-memory map
    _patterns[key] = val;

    // 2. Persist locally (offline support)
    await _persistLocal();

    // 3. Save to Firestore (account-level, survives logout)
    final col = _correctionsCol;
    if (col != null) {
      await col.doc(key).set({
        'wrong':     key,
        'correct':   val,
        'source':    'user',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 4. Update user stats
    final doc = _userDoc;
    if (doc == null) return;
    await doc.set({
      'training': {
        'correctionCount': FieldValue.increment(1),
        'patternCount':    _patterns.length,
        'lastTrainedAt':   FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> _saveAiCorrection(String wrong, String correct) async {
    final key = wrong.toLowerCase().trim();

    // Update in-memory + local cache
    _patterns[key] = correct.trim();
    await _persistLocal();

    // Save to Firestore
    final col = _correctionsCol;
    if (col == null) return;

    await col.doc(key).set({
      'wrong':     key,
      'correct':   correct.trim(),
      'source':    'ai',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearPatterns() async {
    _patterns.clear();

    // Clear local cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);

    // Clear Firestore patterns for this account
    final col = _correctionsCol;
    if (col != null) {
      final snapshot = await col.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // Reset user stats
    final doc = _userDoc;
    if (doc == null) return;
    await doc.set({
      'training': {
        'patternCount':    0,
        'correctionCount': 0,
      }
    }, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local pattern substitution
  // ─────────────────────────────────────────────────────────────────────────

  String _applyLocalPatterns(String text) {
    var result = text;
    for (final entry in _patterns.entries) {
      final regex = RegExp(
        r'\b' + RegExp.escape(entry.key) + r'\b',
        caseSensitive: false,
      );
      result = result.replaceAll(regex, entry.value);
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // API key resolution
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _resolveApiKey() async {
    throw UnimplementedError(
      '_resolveApiKey() must be implemented before using Claude API calls. '
      'See the security notes in the source code above this method.',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Claude API
  // ─────────────────────────────────────────────────────────────────────────

  static const String _systemPrompt = '''
You are a speech correction assistant for individuals with cleft palate.

Cleft palate speakers often:
- Replace "t" sounds with "k" or glottal stops (e.g. "tea" → "kea" or "ea")
- Replace "p" sounds with "f" or "b" (e.g. "pie" → "fie")
- Replace "s" sounds with nasal fricatives or "sh" (e.g. "sun" → "hun")
- Have hypernasality causing vowel distortions
- Substitute bilabial stops (p/b) with glottal stops
- Mix up "d" and "g" sounds

Your job:
1. Read the speech recognition output (may be a partial/incomplete sentence).
2. Interpret what the speaker MOST LIKELY intended to say.
3. Return ONLY the corrected text — no explanations, no labels.
4. Preserve the original meaning, tone, and any words that already look correct.
5. If the input already looks correct, return it unchanged.
6. For partial sentences, correct what you see without completing the sentence.
''';

  Future<String> _callClaude(
    String text, {
    required String originalRaw,
    bool isPartial = false,
  }) async {
    final apiKey = await _resolveApiKey();

    final learnedNote = _patterns.isNotEmpty
        ? '\n\nUser-taught corrections for reference: ${jsonEncode(_patterns)}'
        : '';

    final partialNote = isPartial
        ? '\nNote: This may be an incomplete/partial sentence — correct only what is present.'
        : '';

    final userPrompt =
        'Original speech recognition output: "$originalRaw"\n'
        'After local pattern correction: "$text"'
        '$learnedNote$partialNote\n\n'
        'Return the corrected text:';

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type':      'application/json',
        'x-api-key':         apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model':      'claude-haiku-4-5-20251001',
        'max_tokens': 256,
        'system':     _systemPrompt,
        'messages': [
          {'role': 'user', 'content': userPrompt},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Claude API error ${response.statusCode}: ${response.body}',
      );
    }

    final data      = jsonDecode(response.body);
    final content   = data['content'] as List<dynamic>;
    final corrected = content
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join(' ')
        .trim();

    return corrected.isEmpty ? text : corrected;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────────────────────────────────

  void dispose() {
    _authSub?.cancel();
    _debounceTimer?.cancel();
  }
}