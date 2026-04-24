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

  // 🔥 INIT
  Future<void> initSpeech() async {
    isInitialized = await speech.initialize(
      onStatus: (status) {
        dev.log("STATUS: $status");

        if (status == "done" || status == "notListening") {
          setState(() => isListening = false);
        }
      },
      onError: (error) {
        dev.log("ERROR MSG: ${error.errorMsg}");
      },
    );

    dev.log("Speech initialized: $isInitialized");
  }

  // 🔥 CLEANING (CLEFT SUPPORT)
  String cleanSpeech(String input) {
    String text = input.toLowerCase();

    Map<String, String> corrections = {
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

  // 🔥 MIC CONTROL + FIRESTORE SAVE
  void toggleMic() async {
    if (!isInitialized) {
      await initSpeech();
      return;
    }

    if (!isListening) {
      await speech.stop();
      await Future.delayed(const Duration(milliseconds: 300));

      bool available = await speech.initialize();

      if (available) {
        setState(() => isListening = true);

        await speech.listen(
          localeId: "en_US",
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 5),
          onResult: (result) {
            dev.log("RAW: ${result.recognizedWords}");

            if (result.recognizedWords.isNotEmpty) {
              String cleaned = cleanSpeech(result.recognizedWords);

              setState(() {
                subtitleText = cleaned;
              });

              // 🔥 SAVE ONLY FINAL RESULT
              if (result.finalResult) {
                final user = FirebaseAuth.instance.currentUser; // ✅ GET USER

                FirebaseFirestore.instance.collection('translations').add({
                  'text': cleaned,
                  'time': FieldValue.serverTimestamp(),
                  'userId': user!.uid, // 🔥 IMPORTANT LINE
                });

                dev.log("Saved to Firestore (user): $cleaned");
              }
            }
          },
        );
      }
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

      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                "● LIVE",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
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
            ),

            const SizedBox(height: 100),
          ],
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
