import 'dart:async';
import 'dart:convert';
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
  String _lastCorrectedText = '';   // the last text we sent to Claude
  String _lastRawPartial    = '';   // the last raw partial we received

  /// Duration to wait after the last partial before calling Claude.
  static const _debounceDuration = Duration(milliseconds: 600);

  // ── Callback invoked when a real-time correction is ready ────────────────
  /// Set this from TranslatorScreen to receive corrected text asynchronously.
  void Function(String corrected)? onRealtimeCorrection;

  // ── Session timing ────────────────────────────────────────────────────────
  DateTime? _sessionStart;

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
    _sessionStart = DateTime.now();
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
        'sessionCount':    FieldValue.increment(1),
        'trainedSeconds':  FieldValue.increment(elapsed),
        'lastTrainedAt':   FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Real-time partial correction (debounced)
  // ─────────────────────────────────────────────────────────────────────────

  /// Call this with every partial speech result.
  ///
  /// - Applies local patterns immediately and returns the fast result.
  /// - Schedules a debounced Claude call; when ready it fires [onRealtimeCorrection].
  String correctPartialSync(String rawPartial) {
    _lastRawPartial = rawPartial;

    // Immediate local-pattern correction (no network, zero latency)
    final localResult = _applyLocalPatterns(rawPartial);

    // Schedule debounced Claude correction
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () async {
      // Only call Claude if the text has grown/changed since last call
      if (_lastRawPartial.trim() == _lastCorrectedText.trim()) return;
      _lastCorrectedText = _lastRawPartial;

      try {
        final corrected = await _callClaude(
          _applyLocalPatterns(_lastRawPartial),
          originalRaw: _lastRawPartial,
          isPartial: true,
        );
        onRealtimeCorrection?.call(corrected);
      } catch (_) {
        // Fall back to local-only result — already displayed
      }
    });

    return localResult;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Final correction (called on finalResult)
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> correct(String raw) async {
    // Cancel any in-flight debounce — final takes priority
    _debounceTimer?.cancel();

    if (raw.trim().isEmpty) return raw;

    final afterLocal = _applyLocalPatterns(raw);

    try {
      final aiResult = await _callClaude(afterLocal, originalRaw: raw);

      if (aiResult.trim().toLowerCase() != raw.trim().toLowerCase()) {
        await _saveAiCorrection(raw, aiResult);
      }

      return aiResult;
    } catch (e) {
      return afterLocal;
    }
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
  // Claude API
  // ─────────────────────────────────────────────────────────────────────────

  static const String _apiKey = 'YOUR_ANTHROPIC_API_KEY';

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
        'Content-Type':       'application/json',
        'x-api-key':          _apiKey,
        'anthropic-version':  '2023-06-01',
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
      throw Exception('Claude API error ${response.statusCode}: ${response.body}');
    }

    final data    = jsonDecode(response.body);
    final content = data['content'] as List<dynamic>;
    final corrected = content
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join(' ')
        .trim();

    return corrected.isEmpty ? text : corrected;
  }
}