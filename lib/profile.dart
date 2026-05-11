import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'premium.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOW THE LOGOUT → LOGIN → TRANSLATOR FLOW WORKS
// ─────────────────────────────────────────────────────────────────────────────
//
// Your main.dart should have a StreamBuilder<User?> at the root, like this:
//
//   MaterialApp(
//     home: StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const SplashScreen(); // or a loader
//         }
//         if (snapshot.hasData) {
//           return const TranslatorScreen(); // ← your main app screen
//         }
//         return PremiumScreen(           // ← login screen
//           onLogin: () {},               //   stream handles navigation
//           onBack: () {},
//         );
//       },
//     ),
//   )
//
// With that in place:
//   • Logout  → FirebaseAuth.signOut() → stream emits null → shows PremiumScreen
//   • Login   → FirebaseAuth signs in  → stream emits User → shows Translator
//   No manual Navigator calls needed for the auth transition at all.
//
// The _logout() below simply signs out and pops back to root. The stream does
// the rest automatically.
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name        = '';
  String _email       = '';
  String _plan        = 'free';
  String _memberSince = '';
  bool   _isLoading   = true;

  int    _sessionCount     = 0;
  double _trainingProgress = 0.0;
  double _trainedHours     = 0.0;

  // ── Theme ──────────────────────────────────────────────────────────────────
  static const _bg         = Color(0xFF0D2B2B);
  static const _bgMid      = Color(0xFF0E2233);
  static const _bgDark     = Color(0xFF0B1A28);
  static const _card       = Color(0x0AFFFFFF);
  static const _teal       = Color(0xFF1D9E75);
  static const _tealDim    = Color(0x261D9E75);
  static const _tealBorder = Color(0x401D9E75);
  static const _white70    = Color(0xB3FFFFFF);
  static const _white40    = Color(0x66FFFFFF);
  static const _white20    = Color(0x33FFFFFF);
  static const _fieldBg    = Color(0xFF0D2020);

  bool get _isPremium => _plan == 'premium';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      String memberSince = '';
      if (data?['createdAt'] != null) {
        final ts = (data!['createdAt'] as Timestamp).toDate();
        memberSince = '${_monthName(ts.month)} ${ts.year}';
      } else if (user.metadata.creationTime != null) {
        final ts = user.metadata.creationTime!;
        memberSince = '${_monthName(ts.month)} ${ts.year}';
      }

      setState(() {
        _name             = data?['name']  ?? user.displayName ?? 'User';
        _email            = data?['email'] ?? user.email       ?? '';
        _plan             = data?['plan']  ?? 'free';
        _memberSince      = memberSince;
        _sessionCount     = (data?['sessionCount']     ?? 0) as int;
        _trainingProgress = (data?['trainingProgress'] ?? 0.0).toDouble().clamp(0.0, 1.0);
        _trainedHours     = (data?['trainedHours']     ?? 0.0).toDouble();
        _isLoading        = false;
      });
    } catch (e) {
      setState(() {
        _name      = user.displayName ?? 'User';
        _email     = user.email       ?? '';
        _isLoading = false;
      });
    }
  }

  String _monthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }

  Future<void> _saveProfile(String name, String email) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'name':      name,
      'email':     email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await user.updateDisplayName(name);

    if (email != user.email && email.isNotEmpty) {
      await user.verifyBeforeUpdateEmail(email);
    }

    setState(() {
      _name  = name;
      _email = email;
    });
  }

  // ── LOGOUT ─────────────────────────────────────────────────────────────────
  //
  // Steps:
  //   1. Close the confirm dialog.
  //   2. Sign out — this triggers FirebaseAuth.authStateChanges() to emit null.
  //   3. Your root StreamBuilder sees null → automatically shows PremiumScreen.
  //   4. User logs in → stream emits User → automatically shows TranslatorScreen.
  //
  // We do NOT manually push PremiumScreen here. The stream handles everything.
  // All we do after sign-out is pop back to the root so the stream can rebuild.
  //
  Future<void> _logout() async {
    // 1. Close the confirm dialog
    if (mounted) Navigator.of(context).pop();

    // 2. Sign out from Firebase — triggers authStateChanges stream
    await FirebaseAuth.instance.signOut();

    // 3. Guard against unmounted widget
    if (!mounted) return;

    // 4. Pop all the way back to root (the StreamBuilder in main.dart).
    //    The stream now sees no user → renders PremiumScreen automatically.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF112828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'You will be signed out of your CleftTune account.',
          style: TextStyle(color: _white40, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: _white40)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _logout,
            child: const Text('Logout',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditSheet() {
    final nameController  = TextEditingController(text: _name);
    final emailController = TextEditingController(text: _email);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF112828),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: _white20,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Edit Profile',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 20),
                _sheetLabel('FULL NAME'),
                const SizedBox(height: 6),
                _sheetField(nameController, hint: 'Your name'),
                const SizedBox(height: 14),
                _sheetLabel('EMAIL'),
                const SizedBox(height: 6),
                _sheetField(emailController,
                    hint: 'you@example.com',
                    type: TextInputType.emailAddress),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _white20),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel',
                            style: TextStyle(color: _white70)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _teal,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                setSheetState(() => isSaving = true);
                                try {
                                  await _saveProfile(
                                    nameController.text.trim(),
                                    emailController.text.trim(),
                                  );
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text('Save failed: $e'),
                                      backgroundColor: Colors.red,
                                    ));
                                  }
                                } finally {
                                  setSheetState(() => isSaving = false);
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Save Changes',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bg, _bgMid, _bgDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: isWide ? _buildWideLayout() : _buildMobileLayout(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── LAYOUTS ────────────────────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildAvatarSection(),
          const SizedBox(height: 20),
          _buildStatsRow(),
          const SizedBox(height: 20),
          if (_isPremium) ...[
            _buildPremiumActiveCard(),
            const SizedBox(height: 20),
          ],
          _buildSectionLabel('ACCOUNT'),
          const SizedBox(height: 10),
          _buildInfoCard(),
          const SizedBox(height: 24),
          _buildSectionLabel('SESSION'),
          const SizedBox(height: 10),
          _buildLogoutButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 260,
            child: Column(
              children: [
                _buildAvatarSection(),
                const SizedBox(height: 20),
                _buildStatsRow(),
                if (_isPremium) ...[
                  const SizedBox(height: 20),
                  _buildPremiumActiveCard(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionLabel('ACCOUNT'),
                const SizedBox(height: 10),
                _buildInfoCard(),
                const SizedBox(height: 24),
                _buildSectionLabel('SESSION'),
                const SizedBox(height: 10),
                _buildLogoutButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TOP BAR ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Center(
              child: Text('Profile',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white)),
            ),
          ),
          GestureDetector(
            onTap: _showEditSheet,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _tealDim,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _tealBorder),
              ),
              child: const Icon(Icons.edit_outlined, size: 17, color: _teal),
            ),
          ),
        ],
      ),
    );
  }

  // ── AVATAR SECTION ─────────────────────────────────────────────────────────
  Widget _buildAvatarSection() {
    final initials = _name.isNotEmpty
        ? _name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'U';

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D9E75), Color(0xFF0E5C47)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: _teal, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _teal.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(initials,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: _teal,
                shape: BoxShape.circle,
                border: Border.all(color: _bgDark, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 13, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(_name,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text(_email,
            style: const TextStyle(fontSize: 13, color: _white40)),
        const SizedBox(height: 10),
        _isPremium
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D9E75), Color(0xFF0E5C47)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _teal.withOpacity(0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.white, size: 13),
                    SizedBox(width: 5),
                    Text('Premium Member',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3)),
                  ],
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _tealDim,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _tealBorder),
                ),
                child: const Text('Free Plan',
                    style: TextStyle(
                        fontSize: 12,
                        color: _teal,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
              ),
      ],
    );
  }

  // ── STATS ROW ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        _statChip('$_sessionCount', 'Sessions'),
        const SizedBox(width: 10),
        _statChip(
            '${(_trainingProgress * 100).toStringAsFixed(0)}%', 'Accuracy'),
        const SizedBox(width: 10),
        _statChip('${_trainedHours.toStringAsFixed(1)}h', 'Trained'),
      ],
    );
  }

  Widget _statChip(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _white20),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _teal)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(fontSize: 11, color: _white40)),
          ],
        ),
      ),
    );
  }

  // ── PREMIUM ACTIVE CARD ────────────────────────────────────────────────────
  Widget _buildPremiumActiveCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E5C47), Color(0xFF1D9E75)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: _teal.withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('PREMIUM ACTIVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.verified_rounded,
                  color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "You're all set! 🎉",
            style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enjoy all premium features — unlimited\nsubtitles, voice training & ad-free.',
            style: TextStyle(
                color: Colors.white70, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              _premiumChip(Icons.closed_caption_rounded, 'Unlimited'),
              _premiumChip(Icons.graphic_eq_rounded, 'Voice Training'),
              _premiumChip(Icons.block_rounded, 'Ad-Free'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _premiumChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── ACCOUNT INFO CARD ──────────────────────────────────────────────────────
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _white20),
      ),
      child: Column(
        children: [
          _infoRow(Icons.person_outline_rounded, 'Full Name', _name),
          Divider(color: Colors.white.withOpacity(0.07), height: 20),
          _infoRow(Icons.email_outlined, 'Email', _email),
          Divider(color: Colors.white.withOpacity(0.07), height: 20),
          _infoRow(Icons.calendar_today_outlined, 'Member Since',
              _memberSince.isEmpty ? '—' : _memberSince),
          Divider(color: Colors.white.withOpacity(0.07), height: 20),
          _infoRow(
            _isPremium ? Icons.star_rounded : Icons.star_border_rounded,
            'Plan',
            _isPremium ? 'Premium' : 'Free',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final isPlanRow = label == 'Plan';
    return Row(
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: isPlanRow && _isPremium
                ? const Color(0xFF1D9E75).withOpacity(0.3)
                : _tealDim,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: isPlanRow && _isPremium ? Colors.white : _teal,
              size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: _white40, letterSpacing: 0.3)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isPlanRow && _isPremium
                          ? _teal
                          : Colors.white)),
            ],
          ),
        ),
        if (isPlanRow && _isPremium)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _tealDim,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _tealBorder),
            ),
            child: const Text('Active',
                style: TextStyle(
                    color: _teal,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  // ── LOGOUT BUTTON ──────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _confirmLogout,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.logout, color: Colors.red.shade400, size: 20),
            const SizedBox(width: 12),
            Text('Logout',
                style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label,
          style: const TextStyle(
              color: _white40, fontSize: 11, letterSpacing: 0.8)),
    );
  }

  Widget _sheetLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 11, color: _white40, letterSpacing: 0.8));
  }

  Widget _sheetField(
    TextEditingController controller, {
    required String hint,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _white40),
        filled: true,
        fillColor: _fieldBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _white20),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _white20),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _teal, width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}