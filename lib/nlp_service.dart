import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// NlpService — corrects cleft-palate speech patterns in real-time.
///
/// Real-time pipeline:
/// 1. Partial results → debounced Claude call (600 ms idle window).
/// 2. Final result   → immediate full correction + Firestore save.
/// 3. Local patterns applied first in both paths for instant substitution.
///
/// Upgraded features:
/// - Pronunciation similarity scoring (Levenshtein-based)
/// - Phoneme error detection for common cleft-palate substitutions
/// - Confidence filtering to reject unreliable speech results
/// - Analytics tracking (score, issues, original vs corrected)
/// - Safer correction flow returning structured result maps
/// - Removed hardcoded API key (use _resolveApiKey() instead)
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

  // ── Phoneme substitution patterns (cleft-palate specific) ─────────────────
  //
  // Key   = the CORRECT sound the speaker is trying to produce.
  // Value = list of sounds that a cleft-palate speaker might substitute.
  //
  // Used by analyzePronunciation() to surface detected errors in the result.
  final Map<String, List<String>> _phonemePatterns = {
    'k':  ['t', 'g'],
    't':  ['k', 'd'],
    'p':  ['f', 'b'],
    's':  ['sh', 'h'],
    'b':  ['p'],
    'd':  ['g'],
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Init
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      _patterns.addAll(decoded.map((k, v) => MapEntry(k, v as String)));
    }
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
    _sessionStart          = DateTime.now();
    _lastCorrectedText     = '';
    _lastRawPartial        = '';
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

  /// Returns false when a speech recognition result is too unreliable to use.
  ///
  /// Use this before calling [correctPartialSync] or [correct] to avoid
  /// wasting API calls and showing junk corrections to the user.
  ///
  /// [text]       — the recognised text.
  /// [confidence] — value in [0.0, 1.0] reported by the speech engine.
  bool isReliableSpeechResult(String text, double confidence) {
    if (confidence < 0.55) return false;
    if (text.trim().length < 2) return false;
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pronunciation analysis
  // ─────────────────────────────────────────────────────────────────────────

  /// Compares [original] (raw speech) with [corrected] (AI-fixed text) and
  /// returns a structured map with:
  ///   - `similarity`   : double 0.0–1.0
  ///   - `clarityScore` : int 0–100
  ///   - `issues`       : List<String> of detected phoneme substitutions
  Map<String, dynamic> analyzePronunciation(
    String original,
    String corrected,
  ) {
    final similarity      = calculateSimilarity(original, corrected);
    final detectedIssues  = <String>[];

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

  /// Returns a normalised similarity score in [0.0, 1.0].
  ///
  ///   Similarity = 1 − (LevenshteinDistance / max(|s1|, |s2|))
  double calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    final distance  = _levenshtein(s1.toLowerCase(), s2.toLowerCase());
    final maxLength = max(s1.length, s2.length);
    return 1.0 - (distance / maxLength);
  }

  int _levenshtein(String s, String t) {
    final m = s.length;
    final n = t.length;

    // Build (m+1) × (n+1) DP table.
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,        // deletion
          dp[i][j - 1] + 1,        // insertion
          dp[i - 1][j - 1] + cost, // substitution
        ].reduce(min);
      }
    }

    return dp[m][n];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Real-time partial correction (debounced)
  // ─────────────────────────────────────────────────────────────────────────

  /// Call this with every partial speech result.
  ///
  /// - Applies local patterns immediately and returns the fast local result.
  /// - Schedules a debounced Claude call; when ready it fires
  ///   [onRealtimeCorrection] with a full result map.
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
      } catch (_) {
        // Fall back to local-only result — already displayed synchronously.
      }
    });

    return localResult;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Final correction (called on finalResult)
  // ─────────────────────────────────────────────────────────────────────────

  /// Full correction pipeline for a final (committed) speech result.
  ///
  /// Returns a map with:
  ///   - `corrected`  : String — the corrected text
  ///   - `score`      : int   — clarity score 0–100
  ///   - `issues`     : List<String> — detected phoneme substitutions
  ///   - `similarity` : double — raw similarity 0.0–1.0
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

  /// Saves a speech correction event to Firestore for admin dashboard analysis.
  ///
  /// Enables reporting on:
  ///   - Average clarity scores over time
  ///   - Most difficult phonemes / sounds
  ///   - Improvement trends per user
  Future<void> saveSpeechAnalytics({
    required String original,
    required String corrected,
    required int score,
    required List issues,
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
  // Pattern management
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> learnPattern(String wrong, String correct) async {
    final key = wrong.toLowerCase().trim();
    final val = correct.trim();

    _patterns[key] = val;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(_patterns));

    final col = _correctionsCol;
    if (col != null) {
      await col.doc(key).set({
        'wrong':     key,
        'correct':   val,
        'source':    'user',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);

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

  /// ⚠️  SECURITY: Never hardcode your API key in Flutter source code.
  ///     The compiled APK/IPA can be reverse-engineered and the key stolen.
  ///
  /// Recommended approaches (choose one):
  ///
  ///   Option A — Firebase Cloud Functions (recommended):
  ///     Deploy a Cloud Function that proxies the Claude API call server-side.
  ///     Your Flutter app calls YOUR function endpoint, not Anthropic directly.
  ///     The API key lives only in your Cloud Function environment variables.
  ///
  ///   Option B — Your own backend API:
  ///     Same concept — a backend endpoint that holds the key and forwards
  ///     the request to Anthropic. Add auth (e.g. Firebase ID token) so only
  ///     your app users can call it.
  ///
  ///   Option C — flutter_dotenv (dev/testing only, NOT for production):
  ///     Store the key in a .env file (gitignored) and load at startup.
  ///     Still ships inside the app bundle — only suitable for prototypes.
  ///
  /// Replace the placeholder below with your chosen strategy.
  Future<String> _resolveApiKey() async {
    // TODO: Replace with a secure key-fetch from your backend or Cloud Function.
    // Example using Flutter Secure Storage:
    //   final storage = FlutterSecureStorage();
    //   return await storage.read(key: 'anthropic_api_key') ?? '';
    //
    // Example fetching a short-lived token from your own backend:
    //   final resp = await http.get(Uri.parse('https://your-api.example.com/nlp-token'),
    //       headers: {'Authorization': 'Bearer ${await getFirebaseIdToken()}'});
    //   return jsonDecode(resp.body)['token'] as String;
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
}