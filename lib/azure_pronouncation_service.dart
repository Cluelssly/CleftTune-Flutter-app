import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

/// Scores for a single word returned by Azure.
class AzureWordResult {
  final String word;
  final double accuracyScore;
  final String errorType; // "None" | "Omission" | "Insertion" | "Mispronunciation"

  const AzureWordResult({
    required this.word,
    required this.accuracyScore,
    required this.errorType,
  });

  bool get hasMispronunciation => errorType != 'None';

  factory AzureWordResult.fromJson(Map<String, dynamic> json) {
    return AzureWordResult(
      word:          json['Word']          as String? ?? '',
      accuracyScore: (json['AccuracyScore'] as num?)?.toDouble() ?? 0.0,
      errorType:     json['ErrorType']     as String? ?? 'None',
    );
  }
}

/// Full assessment result returned to callers.
class AzurePronunciationResult {
  /// Overall pronunciation score (0–100). Weighted blend of all sub-scores.
  final double pronScore;

  /// How accurately each phoneme was produced (0–100).
  final double accuracyScore;

  /// How natural and native-like the speech flow is (0–100).
  final double fluencyScore;

  /// How much of the reference text was spoken (0–100).
  final double completenessScore;

  /// Prosody (rhythm, stress, intonation) score (0–100).
  final double prosodyScore;

  /// Per-word breakdown.
  final List<AzureWordResult> words;

  /// The text Azure recognised from the audio.
  final String recognisedText;

  const AzurePronunciationResult({
    required this.pronScore,
    required this.accuracyScore,
    required this.fluencyScore,
    required this.completenessScore,
    required this.prosodyScore,
    required this.words,
    required this.recognisedText,
  });

  /// Words with errors (omissions, insertions, or mispronunciations).
  List<AzureWordResult> get errorWords =>
      words.where((w) => w.hasMispronunciation).toList();

  /// Convenience label for the overall pron score.
  String get pronScoreLabel {
    if (pronScore >= 80) return 'Excellent';
    if (pronScore >= 60) return 'Good';
    if (pronScore >= 40) return 'Fair';
    return 'Needs Practice';
  }

  /// Empty result used as a safe default / placeholder.
  static const empty = AzurePronunciationResult(
    pronScore:          0,
    accuracyScore:      0,
    fluencyScore:       0,
    completenessScore:  0,
    prosodyScore:       0,
    words:              [],
    recognisedText:     '',
  );

  factory AzurePronunciationResult.fromJson(Map<String, dynamic> json) {
    final nBest = (json['NBest'] as List<dynamic>?)?.first as Map<String, dynamic>?;

    if (nBest == null) return empty;

    final wordList = (nBest['Words'] as List<dynamic>? ?? [])
        .map((w) => AzureWordResult.fromJson(w as Map<String, dynamic>))
        .toList();

    return AzurePronunciationResult(
      pronScore:         (nBest['PronScore']         as num?)?.toDouble() ?? 0,
      accuracyScore:     (nBest['AccuracyScore']     as num?)?.toDouble() ?? 0,
      fluencyScore:      (nBest['FluencyScore']      as num?)?.toDouble() ?? 0,
      completenessScore: (nBest['CompletenessScore'] as num?)?.toDouble() ?? 0,
      prosodyScore:      (nBest['ProsodyScore']      as num?)?.toDouble() ?? 0,
      words:             wordList,
      recognisedText:    json['DisplayText']         as String? ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AzurePronunciationService
// ─────────────────────────────────────────────────────────────────────────────

/// Records audio and sends it to Azure Speech REST API for pronunciation
/// assessment.
///
/// This service is completely independent of [NlpService]. It runs as a
/// parallel acoustic analysis layer — the NLP pipeline is unchanged.
///
/// Setup:
///   1. Create a free Azure Speech resource at portal.azure.com.
///   2. Copy your key and region into [_azureKey] and [_azureRegion].
///      ⚠️  Use a backend/Cloud Function to hold the key in production.
///   3. Add to pubspec.yaml:
///        record: ^5.1.1
///        path_provider: ^2.1.2
///        http: ^1.2.1   (already in project)
///   4. iOS  — add NSMicrophoneUsageDescription to Info.plist
///      Android — add RECORD_AUDIO permission to AndroidManifest.xml
///
/// Usage pattern (in a screen):
///   final _azure = AzurePronunciationService();
///
///   // Before the user speaks — give Azure the expected sentence:
///   _azure.setReferenceText('Good morning, my name is John.');
///
///   // Start recording when mic opens:
///   await _azure.startRecording();
///
///   // Stop when mic closes, get result:
///   final result = await _azure.stopAndAssess();
///   // result.pronScore, result.words, etc.
class AzurePronunciationService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AzurePronunciationService _instance =
      AzurePronunciationService._internal();
  factory AzurePronunciationService() => _instance;
  AzurePronunciationService._internal();

  // ── Azure config ───────────────────────────────────────────────────────────
  //
  // ⚠️  SECURITY: Do NOT ship API keys in production Flutter apps.
  //     Move these to a Cloud Function or your own backend, exactly
  //     like the note in NlpService._resolveApiKey().
  //
  // Free tier: 5 audio hours/month — plenty for a capstone/prototype.
  // Endpoint format: https://<REGION>.stt.speech.microsoft.com/...
  static const String _azureKey    = 'YOUR_AZURE_SPEECH_KEY';
  static const String _azureRegion = 'YOUR_AZURE_REGION'; // e.g. 'eastus'

  // ── Internal state ─────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;
  String  _referenceText = '';
  bool    _isRecording   = false;

  bool get isRecording => _isRecording;

  // ── Reference text ─────────────────────────────────────────────────────────

  /// Set this to the sentence the user is TRYING to say before recording.
  ///
  /// Azure compares the actual audio against this reference text to produce
  /// per-word accuracy scores.  If you don't set it, Azure will do an
  /// open-ended assessment without a reference.
  void setReferenceText(String text) {
    _referenceText = text.trim();
  }

  // ── Recording ──────────────────────────────────────────────────────────────

  /// Start recording microphone audio to a temp WAV file.
  ///
  /// Call this when the user opens the mic.  The recording runs in the
  /// background — your STT session (speech_to_text) continues as normal.
  Future<bool> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint('[Azure] Microphone permission denied');
        return false;
      }

      final dir  = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/azure_pron_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(
          encoder:    AudioEncoder.wav,
          sampleRate: 16000,   // Azure requires 16 kHz
          numChannels: 1,      // Mono
          bitRate:    128000,
        ),
        path: _recordingPath!,
      );

      _isRecording = true;
      debugPrint('[Azure] Recording started → $_recordingPath');
      return true;
    } catch (e) {
      debugPrint('[Azure] startRecording error: $e');
      return false;
    }
  }

  /// Stop recording and send audio to Azure for pronunciation assessment.
  ///
  /// Returns [AzurePronunciationResult.empty] on any error so the UI never
  /// crashes — the NLP results are always shown regardless.
  Future<AzurePronunciationResult> stopAndAssess() async {
    if (!_isRecording) return AzurePronunciationResult.empty;

    try {
      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null) {
        debugPrint('[Azure] No recording path returned');
        return AzurePronunciationResult.empty;
      }

      debugPrint('[Azure] Recording stopped → $path');
      return await _sendToAzure(path);
    } catch (e) {
      debugPrint('[Azure] stopAndAssess error: $e');
      _isRecording = false;
      return AzurePronunciationResult.empty;
    }
  }

  /// Cancel recording without sending to Azure (e.g. user tapped stop quickly).
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    await _recorder.cancel();
    _isRecording = false;
    debugPrint('[Azure] Recording cancelled');
  }

  // ── Azure REST API call ────────────────────────────────────────────────────

  Future<AzurePronunciationResult> _sendToAzure(String audioPath) async {
    try {
      final audioFile = File(audioPath);
      if (!audioFile.existsSync()) {
        debugPrint('[Azure] Audio file not found: $audioPath');
        return AzurePronunciationResult.empty;
      }

      final audioBytes = await audioFile.readAsBytes();
      debugPrint('[Azure] Sending ${audioBytes.length} bytes to Azure');

      // Build the Pronunciation-Assessment header (base64-encoded JSON)
      final assessmentParams = <String, dynamic>{
        'GradingSystem':          'HundredMark',
        'Granularity':            'Word',        // per-word scores
        'Dimension':              'Comprehensive',
        'EnableProsodyAssessment': 'True',
      };

      // Only add ReferenceText if we have one — allows open-ended mode
      if (_referenceText.isNotEmpty) {
        assessmentParams['ReferenceText'] = _referenceText;
      }

      final assessmentJson   = jsonEncode(assessmentParams);
      final assessmentBase64 = base64Encode(utf8.encode(assessmentJson));

      final endpoint =
          'https://$_azureRegion.stt.speech.microsoft.com'
          '/speech/recognition/conversation/cognitiveservices/v1'
          '?language=en-US&format=detailed';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type':          'audio/wav; codecs=audio/pcm; samplerate=16000',
          'Accept':                'application/json',
          'Ocp-Apim-Subscription-Key': _azureKey,
          'Pronunciation-Assessment':  assessmentBase64,
        },
        body: audioBytes,
      ).timeout(const Duration(seconds: 30));

      debugPrint('[Azure] Response ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('[Azure] Error body: ${response.body}');
        return AzurePronunciationResult.empty;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['RecognitionStatus'] != 'Success') {
        debugPrint('[Azure] Recognition failed: ${data['RecognitionStatus']}');
        return AzurePronunciationResult.empty;
      }

      final result = AzurePronunciationResult.fromJson(data);
      debugPrint('[Azure] PronScore=${result.pronScore} '
          'Accuracy=${result.accuracyScore} '
          'Fluency=${result.fluencyScore}');

      // Clean up temp file
      try { audioFile.deleteSync(); } catch (_) {}

      return result;
    } catch (e) {
      debugPrint('[Azure] _sendToAzure error: $e');
      return AzurePronunciationResult.empty;
    }
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    if (_isRecording) await _recorder.cancel();
    _recorder.dispose();
  }
}