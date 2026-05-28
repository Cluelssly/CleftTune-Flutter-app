import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name        = '';
  String _email       = '';
  String _memberSince = '';
  bool   _isLoading   = true;

  int    _sessionCount     = 0;
  double _trainingProgress = 0.0;
  double _trainedHours     = 0.0;

  // ─── PALETTE (Sky Blue / Navy — matches LandingPage) ──────────────────────
  static const _bg           = Color(0xFFEAF4FB);
  static const _bgMid        = Color(0xFFD6EEFF);
  static const _bgDark       = Color(0xFFBFDFF7);
  static const _card         = Color(0x99FFFFFF);
  static const _accent       = Color(0xFF0077B6);
  static const _accentDim    = Color(0x260077B6);
  static const _accentBorder = Color(0x400077B6);
  static const _textDark     = Color(0xFF0D2B4E);
  static const _textSub      = Color(0xFF5A7A96);
  static const _fieldBg      = Color(0xFFD6EEFF);

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
  Future<void> _logout() async {
    if (mounted) Navigator.of(context).pop();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bgMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?',
            style: TextStyle(color: _textDark, fontWeight: FontWeight.bold)),
        content: const Text(
          'You will be signed out of your CleftTune account.',
          style: TextStyle(color: _textSub, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: _textSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _logout,
            child: const Text('Logout',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── DELETE ACCOUNT ─────────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) Navigator.of(context).pop();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      await user.delete();

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'requires-recent-login'
                ? 'Please log out and log back in before deleting your account.'
                : 'Could not delete account: ${e.message}',
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete account: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFEAF4FB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade500, size: 22),
            const SizedBox(width: 8),
            const Text('Delete Account?',
                style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete your CleftTune account and all associated data. This action cannot be undone.',
              style: TextStyle(color: _textSub, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.red.shade400, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sessions, progress and preferences will be lost forever.',
                      style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 11,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: _textSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _deleteAccount,
            child: const Text('Delete Forever',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── EDIT SHEET ─────────────────────────────────────────────────────────────
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
              color: Color(0xFFEAF4FB),
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
                      color: _accentBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Edit Profile',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _textDark)),
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
                          side: const BorderSide(color: _accentBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel',
                            style: TextStyle(color: _textSub)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
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

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _accent)),
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
          _buildSectionLabel('ACCOUNT'),
          const SizedBox(height: 10),
          _buildInfoCard(),
          const SizedBox(height: 24),
          _buildSectionLabel('SESSION'),
          const SizedBox(height: 10),
          _buildLogoutButton(),
          const SizedBox(height: 12),
          _buildDeleteAccountButton(),
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
                const SizedBox(height: 12),
                _buildDeleteAccountButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: _textDark, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Center(
              child: Text('Profile',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _textDark)),
            ),
          ),
          GestureDetector(
            onTap: _showEditSheet,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _accentDim,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _accentBorder),
              ),
              child: const Icon(Icons.edit_outlined, size: 17, color: _accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    final initials = _name.isNotEmpty
        ? _name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'U';

    return Column(
      children: [
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF0077B6), Color(0xFF005F8E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: _accent, width: 2),
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(0.25),
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
        const SizedBox(height: 14),
        Text(_name,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _textDark)),
        const SizedBox(height: 4),
        Text(_email,
            style: const TextStyle(fontSize: 13, color: _textSub)),
      ],
    );
  }

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
          border: Border.all(color: _accentBorder),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _accent)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(fontSize: 11, color: _textSub)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentBorder),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _infoRow(Icons.person_outline_rounded, 'Full Name', _name),
          Divider(color: _accent.withOpacity(0.1), height: 20),
          _infoRow(Icons.email_outlined, 'Email', _email),
          Divider(color: _accent.withOpacity(0.1), height: 20),
          _infoRow(Icons.calendar_today_outlined, 'Member Since',
              _memberSince.isEmpty ? '—' : _memberSince),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _accentDim,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _accent, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: _textSub, letterSpacing: 0.3)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _textDark)),
            ],
          ),
        ),
      ],
    );
  }

  // ── SESSION BUTTONS ────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _confirmLogout,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.logout, color: Colors.red.shade500, size: 20),
            const SizedBox(width: 12),
            Text('Logout',
                style: TextStyle(
                    color: Colors.red.shade500,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return GestureDetector(
      onTap: _confirmDeleteAccount,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_forever_rounded,
                  color: Colors.red.shade500, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delete Account',
                      style: TextStyle(
                          color: Colors.red.shade500,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Permanently remove your account and data',
                      style: TextStyle(
                          color: Colors.red.withOpacity(0.45),
                          fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.red.withOpacity(0.4), size: 18),
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
              color: _textSub, fontSize: 11, letterSpacing: 0.8)),
    );
  }

  Widget _sheetLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 11, color: _textSub, letterSpacing: 0.8));
  }

  Widget _sheetField(
    TextEditingController controller, {
    required String hint,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: _textDark, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSub),
        filled: true,
        fillColor: _fieldBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accentBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accentBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}