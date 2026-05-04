import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'profile.dart';
import 'firebase_options.dart';
import 'premium.dart';
import 'profile.dart';
import 'phonetic.dart';
import 'cloud.dart';
import 'notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'translator_screen.dart';
import 'landing_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const CleftTuneApp());
}

class CleftTuneApp extends StatelessWidget {
  const CleftTuneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CleftTune',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const AppLayout(),
    );
  }
}

class AppLayout extends StatefulWidget {
  const AppLayout({super.key});

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  int currentIndex = 0;

  bool showLanding = true;
  bool showPremiumLogin = false;

  // 🔥 LANDING → PREMIUM SCREEN
  void enterAppFlow() {
    setState(() {
      showLanding = false;
      showPremiumLogin = true;
    });
  }

  // 🔥 LOGIN → MAIN APP (FIXED FLOW)
  Future<void> completeLogin() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint("Auth error: $e");
    }

    setState(() {
      showPremiumLogin = false;
      showLanding = false; // 🔥 IMPORTANT FIX
      currentIndex = 0; // go to translator
    });
  }

  void switchPage(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  // 🔥 OPEN PREMIUM FROM TRANSLATOR
  void openPremium() {
    setState(() {
      showPremiumLogin = true;
      showLanding = false;
    });
  }

  // 🔥 BACK TO LANDING
  void backToLanding() {
    setState(() {
      showPremiumLogin = false;
      showLanding = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;

    // 🔥 1. LANDING PAGE
    if (showLanding) {
      currentScreen = LandingPage(onContinue: enterAppFlow);
    }
    // 🔥 2. PREMIUM LOGIN PAGE
    else if (showPremiumLogin) {
      currentScreen = PremiumScreen(
        onLogin: completeLogin,
        onBack: backToLanding,
      );
    }
    // 🔥 3. MAIN APP
    else {
      switch (currentIndex) {
        case 0:
          currentScreen = TranslatorScreen(goToPremium: openPremium);
          break;

        case 1:
          currentScreen = const HistoryScreen();
          break;

        case 2:
          currentScreen = const SettingsScreen();
          break;

        default:
          currentScreen = TranslatorScreen(goToPremium: openPremium);
      }
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isSmall = constraints.maxWidth < 800;

          return Row(
            children: [
              // 🔥 DESKTOP NAVIGATION
              if (!isSmall && !showLanding && !showPremiumLogin)
                NavigationRail(
                  backgroundColor: Colors.black,
                  selectedIndex: currentIndex,
                  onDestinationSelected: switchPage,
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: IconThemeData(color: Colors.teal[300]),
                  unselectedIconTheme: const IconThemeData(color: Colors.grey),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.mic),
                      label: Text("Translate"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history),
                      label: Text("History"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.tune),
                      label: Text("Settings"),
                    ),
                  ],
                ),

              Expanded(
                child: Scaffold(
                  body: currentScreen,

                  // 🔥 MOBILE NAVIGATION
                  bottomNavigationBar:
                      isSmall && !showLanding && !showPremiumLogin
                      ? BottomNavigationBar(
                          backgroundColor: Colors.black,
                          selectedItemColor: Colors.teal,
                          unselectedItemColor: Colors.grey,
                          currentIndex: currentIndex,
                          onTap: switchPage,
                          items: const [
                            BottomNavigationBarItem(
                              icon: Icon(Icons.mic),
                              label: "Translate",
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.history),
                              label: "History",
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.tune),
                              label: "Settings",
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 📜 HISTORY SCREEN

/// 📜 HISTORY SCREEN

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0F172A))),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double width = constraints.maxWidth;
                double padding = width < 800 ? 16 : 40;
                double contentWidth = width < 1000 ? width : 900;

                return Center(
                  child: Container(
                    width: contentWidth,
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔥 HEADER (UPDATED)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "CleftTune",
                              style: TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // ✅ CLICKABLE PROFILE ICON
                            InkWell(
                              borderRadius: BorderRadius.circular(30),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ProfileScreen(),
                                  ),
                                );
                              },
                              child: const CircleAvatar(
                                backgroundColor: Color.fromARGB(
                                  31,
                                  255,
                                  255,
                                  255,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        const Text(
                          "History",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          "Your recent vocal bridge captures.",
                          style: TextStyle(color: Colors.white54),
                        ),

                        const SizedBox(height: 20),

                        // SEARCH BAR
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value.toLowerCase();
                              });
                            },
                            decoration: const InputDecoration(
                              icon: Icon(Icons.search),
                              hintText: "Search history...",
                              border: InputBorder.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // 🔥 FIRESTORE HISTORY
                        Expanded(
                          child: user == null
                              ? const Center(
                                  child: Text(
                                    "User not initialized",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                )
                              : StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('translations')
                                      .where('userId', isEqualTo: user.uid)
                                      .orderBy('time', descending: true)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    final docs = snapshot.data!.docs;

                                    final filteredDocs = docs.where((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final text = (data['text'] ?? "")
                                          .toString()
                                          .toLowerCase();
                                      return text.contains(searchQuery);
                                    }).toList();

                                    if (filteredDocs.isEmpty) {
                                      return const Center(
                                        child: Text(
                                          "No history found",
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      );
                                    }

                                    Map<String, List<QueryDocumentSnapshot>>
                                    grouped = {"Today": [], "Yesterday": []};

                                    DateTime now = DateTime.now();
                                    DateTime today = DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                    );
                                    DateTime yesterday = today.subtract(
                                      const Duration(days: 1),
                                    );

                                    for (var doc in filteredDocs) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final timestamp = data['time'];

                                      if (timestamp == null) continue;

                                      DateTime date = timestamp.toDate();
                                      DateTime dateOnly = DateTime(
                                        date.year,
                                        date.month,
                                        date.day,
                                      );

                                      if (dateOnly == today) {
                                        grouped["Today"]!.add(doc);
                                      } else if (dateOnly == yesterday) {
                                        grouped["Yesterday"]!.add(doc);
                                      }
                                    }

                                    return ListView(
                                      children: [
                                        if (grouped["Today"]!.isNotEmpty) ...[
                                          const Text(
                                            "TODAY",
                                            style: TextStyle(
                                              color: Colors.white54,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          ...grouped["Today"]!.map((doc) {
                                            final data =
                                                doc.data()
                                                    as Map<String, dynamic>;
                                            final text = data['text'] ?? '';
                                            final date = data['time'].toDate();

                                            final timeString =
                                                "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

                                            return chatBubble(
                                              text,
                                              timeString,
                                            );
                                          }),
                                          const SizedBox(height: 20),
                                        ],

                                        if (grouped["Yesterday"]!
                                            .isNotEmpty) ...[
                                          const Text(
                                            "YESTERDAY",
                                            style: TextStyle(
                                              color: Colors.white54,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          ...grouped["Yesterday"]!.map((doc) {
                                            final data =
                                                doc.data()
                                                    as Map<String, dynamic>;
                                            final text = data['text'] ?? '';
                                            final date = data['time'].toDate();

                                            final timeString =
                                                "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

                                            return chatBubble(
                                              text,
                                              timeString,
                                            );
                                          }),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget chatBubble(String text, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.translate, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    time,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// settings

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            double width = constraints.maxWidth;

            double padding = width < 800 ? 16 : 40;
            double contentWidth = width < 1000 ? width : 900;

            return Center(
              child: Container(
                width: contentWidth,
                padding: EdgeInsets.all(padding),
                child: ListView(
                  children: [
                    /// HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Row(
                          children: [
                            Icon(Icons.arrow_back, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              "Settings",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        CircleAvatar(
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    /// PREMIUM CARD
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PREMIUM",
                            style: TextStyle(color: Colors.white70),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Upgrade to\nPremium",
                            style: TextStyle(
                              fontSize: 26,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Unlimited offline translations\nand ad-free experience.",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// FONT SIZE
                    card(
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Font Size",
                                style: TextStyle(color: Colors.white),
                              ),
                              Text(
                                "18px",
                                style: TextStyle(color: Colors.teal),
                              ),
                            ],
                          ),
                          Slider(
                            value: 18,
                            min: 12,
                            max: 30,
                            onChanged: (value) {},
                            activeColor: Colors.teal,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// OPTIONS
                    optionTile(context, "Trained Voice"),
                    optionTile(context, "Cloud Based"),
                    optionTile(context, "Notifications"),

                    const SizedBox(height: 20),

                    /// ABOUT
                    const Text(
                      "ABOUT",
                      style: TextStyle(color: Colors.white54),
                    ),

                    const SizedBox(height: 10),

                    card(
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "App Version",
                            style: TextStyle(color: Colors.white),
                          ),
                          Text(
                            "v2.4.0",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 🔥 reusable card
  Widget card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  /// 🔥 option tile (FIXED STRUCTURE)
  Widget optionTile(BuildContext context, String title) {
    return InkWell(
      onTap: () {
        if (title == "Trained Voice") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Phonetic()),
          );
        } else if (title == "Cloud Based") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Cloud()),
          );
        } else if (title == "Notifications") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white)),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}
