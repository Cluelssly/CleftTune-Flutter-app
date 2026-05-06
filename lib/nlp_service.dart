import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// NlpService — corrects cleft-palate speech patterns.
///
/// 1. Applies locally-learned word patterns first (from user corrections).
/// 2. Then sends the text to Claude claude-haiku-4-5-20251001 with a cleft-palate-aware
///    system prompt for any remaining corrections.
class NlpService {
  static final NlpService _instance = NlpService._internal();
  factory NlpService() => _instance;
  NlpService._internal();

  // ── Local learned patterns (persisted via SharedPreferences) ─────────────
  final Map<String, String> _patterns = {};
  static const _prefKey = 'nlp_patterns_v1';

  int get patternCount => _patterns.length;

  /// Load patterns saved from previous sessions.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      _patterns.addAll(decoded.map((k, v) => MapEntry(k, v as String)));
    }
  }

  /// Save a user-provided correction (wrong → correct).
  Future<void> learnPattern(String wrong, String correct) async {
    _patterns[wrong.toLowerCase()] = correct;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(_patterns));
  }

  /// Remove all learned patterns.
  Future<void> clearPatterns() async {
    _patterns.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  // ── Main correction pipeline ──────────────────────────────────────────────

  /// Apply local patterns then call Claude AI for deeper correction.
  Future<String> correct(String raw) async {
    if (raw.trim().isEmpty) return raw;

    // Step 1: apply local patterns
    final afterLocal = _applyLocalPatterns(raw);

    // Step 2: call Claude
    try {
      final aiResult = await _callClaude(afterLocal, originalRaw: raw);
      return aiResult;
    } catch (e) {
      // If API fails, still return the locally-corrected version
      return afterLocal;
    }
  }

  // ── Local pattern substitution ────────────────────────────────────────────

  String _applyLocalPatterns(String text) {
    var result = text;
    for (final entry in _patterns.entries) {
      // Word-boundary aware replacement (case-insensitive)
      final regex = RegExp(
        r'\b' + RegExp.escape(entry.key) + r'\b',
        caseSensitive: false,
      );
      result = result.replaceAll(regex, entry.value);
    }
    return result;
  }

  // ── Claude API call ───────────────────────────────────────────────────────

  /// Replace with your actual Anthropic API key.
  /// For production, load this from a secure config / backend proxy.
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
1. Read the speech recognition output, which may already have partial corrections applied.
2. Interpret what the speaker MOST LIKELY intended to say, using common cleft palate substitution patterns.
3. Return ONLY the corrected sentence — no explanations, no labels, no punctuation changes beyond what is natural.
4. Preserve the original meaning and tone.
5. If the input already looks correct, return it unchanged.
''';

  Future<String> _callClaude(String text, {required String originalRaw}) async {
    final learnedPatternsNote = _patterns.isNotEmpty
        ? '\n\nUser-taught corrections for reference: ${jsonEncode(_patterns)}'
        : '';

    final userPrompt =
        'Original speech recognition output: "$originalRaw"\n'
        'After local pattern correction: "$text"'
        '$learnedPatternsNote\n\n'
        'Please return the corrected sentence:';

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 256,
        'system': _systemPrompt,
        'messages': [
          {'role': 'user', 'content': userPrompt},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Claude API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['content'] as List<dynamic>;
    final corrected = content
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join(' ')
        .trim();

    return corrected.isEmpty ? text : corrected;
  }
}