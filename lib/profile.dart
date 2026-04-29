import 'package:flutter/material.dart';
import 'premium.dart'; // make sure path is correct

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Alex Rivera';
  String _email = 'alex.rivera@example.com';
  String _plan = 'Free Plan';

  // ── Theme constants ────────────────────────────────────────────────────────
  static const _bg     = Color(0xFF0D2B2B);
  static const _bgMid  = Color(0xFF0E2233);
  static const _bgDark = Color(0xFF0B1A28);
  static const _card   = Color(0x0AFFFFFF);
  static const _teal   = Color(0xFF1D9E75);
  static const _tealDim    = Color(0x261D9E75);
  static const _tealBorder = Color(0x401D9E75);
  static const _white70 = Color(0xB3FFFFFF);
  static const _white40 = Color(0x66FFFFFF);
  static const _white20 = Color(0x33FFFFFF);
  static const _fieldBg = Color(0xFF0D2020);

  void _showEditSheet() {
    final nameController  = TextEditingController(text: _name);
    final emailController = TextEditingController(text: _email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 20),
              _sheetLabel('FULL NAME'),
              const SizedBox(height: 6),
              _sheetField(nameController, hint: 'Your name'),
              const SizedBox(height: 14),
              _sheetLabel('EMAIL'),
              const SizedBox(height: 6),
              _sheetField(emailController, hint: 'you@example.com',
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
                      onPressed: () {
                        setState(() {
                          _name  = nameController.text.trim();
                          _email = emailController.text.trim();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Save Changes',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

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
                child: isWide
                    ? _buildWideLayout()
                    : _buildMobileLayout(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── MOBILE LAYOUT ──────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildAvatarSection(centered: true),
          const SizedBox(height: 20),
          _buildStatsRow(),
          const SizedBox(height: 24),
          _buildSectionLabel('ACCOUNT'),
          const SizedBox(height: 10),
          _buildInfoCard(),
          const SizedBox(height: 24),
          _buildSectionLabel('SESSION'),
          const SizedBox(height: 10),
          _buildUpgradeButton(),
          const SizedBox(height: 8),
          _buildLogoutButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── WIDE / WEB LAYOUT ──────────────────────────────────────────────────────
  Widget _buildWideLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: avatar + stats
          SizedBox(
            width: 260,
            child: Column(
              children: [
                _buildAvatarSection(centered: true),
                const SizedBox(height: 20),
                _buildStatsRow(),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Right column: account info + session actions
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
                _buildUpgradeButton(),
                const SizedBox(height: 8),
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
  Widget _buildAvatarSection({bool centered = true}) {
    final initials = _name.isNotEmpty
        ? _name.trim().split(' ').map((w) => w[0]).take(2).join()
        : 'A';
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _tealDim,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _tealBorder),
          ),
          child: Text(_plan,
              style: const TextStyle(
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
        _statChip('24', 'Sessions'),
        const SizedBox(width: 10),
        _statChip('92%', 'Accuracy'),
        const SizedBox(width: 10),
        _statChip('3.2h', 'Trained'),
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
          _infoRow(Icons.calendar_today_outlined, 'Member Since', 'April 2025'),
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
            color: _tealDim,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _teal, size: 16),
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
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  // ── UPGRADE BUTTON ─────────────────────────────────────────────────────────
  Widget _buildUpgradeButton() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PremiumScreen(
            onBack: () => Navigator.pop(context),
            onLogin: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(
                    content: Text('Login clicked'))),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _teal.withOpacity(0.25),
              _teal.withOpacity(0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _tealBorder),
        ),
        child: const Row(
          children: [
            Icon(Icons.star_rounded, color: _teal, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upgrade to Premium',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Unlock all features — ₱99/month',
                      style: TextStyle(
                          color: _teal,
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: _teal),
          ],
        ),
      ),
    );
  }

  // ── LOGOUT BUTTON ──────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => _confirmLogout(),
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

  // ── SECTION LABEL ──────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label,
          style: const TextStyle(
              color: _white40, fontSize: 11, letterSpacing: 0.8)),
    );
  }

  // ── LOGOUT CONFIRM ─────────────────────────────────────────────────────────
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF112828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('You will be signed out of your CleftTune account.',
            style: TextStyle(color: _white40, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _white40)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              // TODO: call FirebaseAuth.instance.signOut()
            },
            child: const Text('Logout',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── SHEET HELPERS ──────────────────────────────────────────────────────────
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