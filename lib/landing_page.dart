import 'package:flutter/material.dart';

class LandingPage extends StatelessWidget {
  final VoidCallback onContinue;

  const LandingPage({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🔥 ICON / LOGO
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.record_voice_over_rounded,
                    size: 90,
                    color: Colors.teal,
                  ),
                ),

                const SizedBox(height: 25),

                // 🔥 TITLE
                const Text(
                  "CleftTune",
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 10),

                // 🔥 SUBTITLE
                const Text(
                  "AI Speech Translator for Cleft Speech",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 60),

                // 🔥 FEATURES (optional but looks professional)
                const Column(
                  children: [
                    Text(
                      "✔ Real-time speech translation",
                      style: TextStyle(color: Colors.white54),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "✔ Supports cleft speech correction",
                      style: TextStyle(color: Colors.white54),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "✔ Saves history automatically",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                // 🔥 BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      "Get Started",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
