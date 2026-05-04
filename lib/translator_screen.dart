import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:developer' as dev;

class TranslatorScreen extends StatefulWidget {
  final VoidCallback goToPremium;

  const TranslatorScreen({super.key, required this.goToPremium});

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  late stt.SpeechToText _speech;

  bool _isListening = false;
  bool _isInitialized = false;
  bool _userStopped = false; // tracks if user manually stopped

  static const int _maxWords = 30;

  // Holds the last N words shown on screen
  List<String> _displayWords = [];

  // Accumulates the full sentence until a final result
  String _pendingText = '';

  String _subtitleText = 'Tap the mic to start speaking...';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _isInitialized = await _speech.initialize(
      onStatus: (status) {
        dev.log('STATUS: $status');
        if ((status == 'done' ||
                status == 'notListening' ||
                status == 'doneNoResult') &&
            _isListening &&
            !_userStopped) {
          _restartListening();
        }
      },
      onError: (error) {
        dev.log('ERROR: ${error.errorMsg}');
        if (_isListening && !_userStopped) {
          Future.delayed(const Duration(milliseconds: 100), _restartListening);
        }
      },
    );
    dev.log('Speech initialized: $_isInitialized');
  }

  String _cleanSpeech(String input) {
    String text = input.toLowerCase();
    final corrections = {
      'helo': 'hello',
      'hallo': 'hello',
      'yoo': 'you',
      'yu': 'you',
      'im': 'i am',
      'i m': 'i am',
      'tnx': 'thanks',
      'yoo en ay': 'you and i',
    };
    corrections.forEach((wrong, correct) {
      text = text.replaceAll(wrong, correct);
    });
    return text;
  }

  /// Keeps only the last [_maxWords] words and updates the display
  void _updateDisplay(String newText) {
    final allWords = newText.trim().split(RegExp(r'\s+'));
    final trimmed = allWords.length > _maxWords
        ? allWords.sublist(allWords.length - _maxWords)
        : allWords;

    setState(() {
      _displayWords = trimmed;
      _subtitleText = trimmed.join(' ');
    });
  }

  Future<void> _startListening() async {
    if (!_isInitialized) {
      await _initSpeech();
      if (!_isInitialized) return;
    }

    await _speech.stop();

    await _speech.listen(
      localeId: 'en_US',
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 10),
      partialResults: true,
      onResult: (result) async {
        final words = result.recognizedWords;
        if (words.isEmpty) return;

        final cleaned = _cleanSpeech(words);

        // Show rolling last 15 words in real time
        _updateDisplay(cleaned);

        if (result.finalResult) {
          _pendingText = cleaned;

          // Save to Firestore
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await FirebaseFirestore.instance.collection('translations').add({
              'text': cleaned,
              'time': FieldValue.serverTimestamp(),
              'userId': user.uid,
            });
            dev.log('Saved: $cleaned');
          }
        }
      },
    );
  }

  /// Seamlessly restarts the mic without user interaction
  Future<void> _restartListening() async {
    if (!_isListening || _userStopped) return;
    await _startListening();
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      // User manually stops
      _userStopped = true;
      await _speech.stop();
      setState(() {
        _isListening = false;
        _subtitleText = _displayWords.isEmpty
            ? 'Tap the mic to start speaking...'
            : _subtitleText;
      });
    } else {
      // User starts
      _userStopped = false;
      setState(() {
        _isListening = true;
        _displayWords = [];
        _subtitleText = 'Listening...';
      });
      await _startListening();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'CleftTune',
          style: TextStyle(
            color: Colors.teal[300],
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black.withOpacity(0.7),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.star, color: Colors.white),
            onPressed: widget.goToPremium,
          ),
        ],
      ),
      body: SafeArea(
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Live indicator
              AnimatedOpacity(
                opacity: _isListening ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 400),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Subtitle box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(minHeight: 120),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isListening
                          ? Colors.teal.withOpacity(0.5)
                          : Colors.white12,
                      width: 1,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _subtitleText,
                      key: ValueKey(_subtitleText),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Word count hint
              if (_isListening)
                Text(
                  '${_displayWords.length}/$_maxWords words',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: GestureDetector(
        onTap: _toggleMic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isListening ? Colors.redAccent : Colors.teal,
            boxShadow: [
              BoxShadow(
                color: (_isListening ? Colors.redAccent : Colors.teal)
                    .withOpacity(0.4),
                blurRadius: 20,
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