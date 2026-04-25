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
  late stt.SpeechToText speech;

  bool isListening = false;
  bool isInitialized = false;

  String subtitleText = "Tap the mic to start speaking...";

  @override
  void initState() {
    super.initState();
    speech = stt.SpeechToText();
    initSpeech();
  }

  Future<void> initSpeech() async {
    isInitialized = await speech.initialize(
      onStatus: (status) {
        dev.log("STATUS: $status");

        if (status == "done" || status == "notListening") {
          if (mounted) {
            setState(() => isListening = false);
          }
        }
      },
      onError: (error) {
        dev.log("ERROR: ${error.errorMsg}");
      },
    );

    dev.log("Speech initialized: $isInitialized");
  }

  String cleanSpeech(String input) {
    String text = input.toLowerCase();

    final corrections = {
      "helo": "hello",
      "hallo": "hello",
      "yoo": "you",
      "yu": "you",
      "im": "i am",
      "i m": "i am",
      "tnx": "thanks",
      "yoo en ay": "you and i",
    };

    corrections.forEach((wrong, correct) {
      text = text.replaceAll(wrong, correct);
    });

    return text;
  }

  Future<void> toggleMic() async {
    if (!isInitialized) {
      await initSpeech();
      return;
    }

    if (!isListening) {
      await speech.stop();
      await Future.delayed(const Duration(milliseconds: 300));

      bool available = await speech.initialize();
      if (!available) return;

      setState(() => isListening = true);

      await speech.listen(
        localeId: "en_US",
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 5),
        onResult: (result) async {
          final words = result.recognizedWords;

          if (words.isEmpty) return;

          String cleaned = cleanSpeech(words);

          if (mounted) {
            setState(() {
              subtitleText = cleaned;
            });
          }

          if (result.finalResult) {
            final user = FirebaseAuth.instance.currentUser;

            if (user == null) return;

            await FirebaseFirestore.instance.collection('translations').add({
              'text': cleaned,
              'time': FieldValue.serverTimestamp(),
              'userId': user.uid,
            });

            dev.log("Saved: $cleaned");
          }
        },
      );
    } else {
      await speech.stop();
      setState(() => isListening = false);
    }
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

      // 🔥 FIXED CENTER LAYOUT
      body: SafeArea(
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "● LIVE",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    subtitleText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      floatingActionButton: FloatingActionButton(
        onPressed: toggleMic,
        backgroundColor: Colors.teal,
        child: Icon(isListening ? Icons.stop : Icons.mic, size: 32),
      ),
    );
  }
}
