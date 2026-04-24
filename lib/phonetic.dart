import 'package:flutter/material.dart';

void main() {
  runApp(const TrainedVoiceApp());
}

class TrainedVoiceApp extends StatelessWidget {
  const TrainedVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Phonetic(), // 👈 now starts from Phonetic
    );
  }
}

class Phonetic extends StatelessWidget {
  const Phonetic({super.key});

  @override
  Widget build(BuildContext context) {
    return const TrainedVoiceScreen();
  }
}

class TrainedVoiceScreen extends StatelessWidget {
  const TrainedVoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// TOP BAR
              Row(
                children: [
                  const Icon(Icons.arrow_back),
                  const SizedBox(width: 10),
                  const Text(
                    "Trained Voice",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0B5D5E),
                    ),
                    child: const Icon(
                      Icons.settings,
                      color: Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// STATUS CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      "STATUS: ACTIVE",
                      style: TextStyle(
                        color: Color.fromARGB(255, 247, 247, 247),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Training: Alex’s Voice Model...",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),

                    /// PROGRESS
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: 0.92,
                        minHeight: 10,
                        backgroundColor: const Color.fromARGB(
                          255,
                          209,
                          208,
                          208,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF0B5D5E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text("92%"),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Refining acoustic nuances and tonal stability...",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color.fromRGBO(0, 0, 0, 1),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// VOCAL PROFILES
              const Text(
                "Vocal Profiles",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              profileCard(
                title: "Alex’s Trained",
                subtitle: "Optimized for daily conversation",
                active: true,
              ),

              const SizedBox(height: 10),

              profileCard(
                title: "Default",
                subtitle: "Standard system synthesized voice",
                active: false,
              ),

              const SizedBox(height: 20),

              /// ANALYSIS
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 142, 204, 204),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Detailed Analysis",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Focusing on high-frequency stability.",
                      style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: const [
                        Text(
                          "92%",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text("QUALITY\nRATING"),
                      ],
                    ),

                    const SizedBox(height: 20),

                    /// fake waveform
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 255, 254, 254),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          25,
                          (index) => Container(
                            width: 3,
                            height: (index % 5 + 1) * 8,
                            color: const Color.fromARGB(255, 4, 7, 6),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// BUTTONS
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B5D5E),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () {},
                      child: const Text("Train Sound"),
                    ),

                    const SizedBox(height: 10),

                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () {},
                      child: const Text("Save Comparison"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget profileCard({
    required String title,
    required String subtitle,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active
            ? const Color.fromARGB(255, 0, 1, 1)
            : const Color.fromARGB(255, 11, 4, 4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: active ? Colors.teal : const Color.fromARGB(255, 11, 4, 4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.graphic_eq,
            color: active
                ? Colors.teal
                : const Color.fromARGB(255, 239, 239, 239),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color.fromARGB(255, 28, 25, 25),
                  ),
                ),
              ],
            ),
          ),
          if (active) const Icon(Icons.check_circle, color: Colors.teal),
        ],
      ),
    );
  }
}
