import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PremiumGate {
  /// One-time check — returns true if current user has an active premium plan.
  static Future<bool> isPremium() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return (doc.data()?['plan'] ?? '') == 'premium';
  }

  /// Stream version — reacts instantly when plan changes in Firestore.
  /// TranslatorScreen subscribes to this so switching Free ↔ Premium
  /// takes effect immediately without restarting the screen.
  static Stream<bool> isPremiumStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => (doc.data()?['plan'] ?? '') == 'premium');
  }
}