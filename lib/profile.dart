import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';
import 'premium.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController =
      TextEditingController(text: 'Alex Rivera');
  File? _profileImage;
  bool _isEditingName = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
      });
    }
  }

  void _toggleNameEdit() {
    setState(() {
      _isEditingName = !_isEditingName;
    });
  }

  void _saveName() {
    setState(() {
      _isEditingName = false;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── TOP BAR ──────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _CircleIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    const Text(
                      'CleftTune',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    _CircleIconButton(icon: Icons.settings_outlined),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── PROFILE AVATAR ───────────────────────────────────────────
              Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: _profileImage == null
                            ? const LinearGradient(
                                colors: [Color(0xFF1D9E75), Color(0xFF2DD4BF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        image: _profileImage != null
                            ? DecorationImage(
                                image: FileImage(_profileImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: _profileImage == null
                          ? const Text(
                              'AR',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0F172A),
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.edit,
                            size: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── EDITABLE NAME ────────────────────────────────────────────
              _isEditingName
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              autofocus: true,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.teal.shade300, width: 1.5),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.teal.shade300, width: 1.5),
                                ),
                              ),
                              onSubmitted: (_) => _saveName(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _saveName,
                            child: const Icon(Icons.check_circle,
                                color: Color(0xFF2DD4BF), size: 22),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: _toggleNameEdit,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _nameController.text,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit,
                              size: 15, color: Color(0xFF2DD4BF)),
                        ],
                      ),
                    ),

              const SizedBox(height: 4),

              // ── EMAIL (read-only) ────────────────────────────────────────
              const Text(
                'alex.rivera@example.com',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0x73FFFFFF),
                ),
              ),

              const SizedBox(height: 8),

              // ── PREMIUM BADGE ─────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x1F2DD4BF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Premium Member',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2DD4BF),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── STATS ROW ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _StatCard(value: '342', label: 'Mins saved'),
                    const SizedBox(width: 10),
                    _StatCard(value: '84', label: 'Sessions'),
                    const SizedBox(width: 10),
                    _StatCard(value: '97%', label: 'Accuracy'),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── MEMBERSHIP CARD ───────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F766E),
                      Color(0xFF1D9E75),
                      Color(0xFF2DD4BF),
                    ],
                    stops: [0.0, 0.6, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MEMBERSHIP',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: Color(0xA6FFFFFF),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Premium Plan',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            _MembershipDetail(
                                label: 'Renews', value: 'Oct 12, 2025'),
                            _MembershipDetail(
                                label: 'Member since',
                                value: 'Jan 2024',
                                alignRight: true),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── SPEECH SECTION ────────────────────────────────────────────
              _SectionLabel('SPEECH'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DottedBorder(
                  dashPattern: const [5, 5],
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(14),
                  color: Colors.white.withOpacity(0.15),
                  strokeWidth: 1,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _IconTile(
                          icon: Icons.mic_none_rounded,
                          color: Colors.white.withOpacity(0.08),
                          iconColor: Colors.white38,
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Speech profile',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white54,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Customized vocal synthesis',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white30),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x1F60A5FA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Coming soon',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFF60A5FA)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ── PREFERENCES SECTION ───────────────────────────────────────
              _SectionLabel('PREFERENCES'),
              _SettingsRow(
                icon: Icons.accessibility_new_rounded,
                title: 'Accessibility',
                subtitle: 'Display & interaction options',
                onTap: () {},
              ),

              const SizedBox(height: 22),

              // ── SUPPORT SECTION ───────────────────────────────────────────
              _SectionLabel('SUPPORT'),
              _SettingsRow(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Help & feedback',
                subtitle: 'Send us a message',
                onTap: () {},
              ),
              const SizedBox(height: 8),
              _SettingsRow(
                icon: Icons.description_outlined,
                title: 'Terms & privacy',
                subtitle: 'Legal documents',
                onTap: () {},
              ),

              const SizedBox(height: 22),

              // ── LOGOUT ────────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withOpacity(0.15)),
                ),
                child: ListTile(
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.logout_rounded,
                        color: Colors.redAccent, size: 18),
                  ),
                  title: const Text(
                    'Log out',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PremiumScreen(
                          onBack: () => Navigator.pop(context),
                          onLogin: () => Navigator.pop(context),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// ── HELPERS ──────────────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2DD4BF),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0x73FFFFFF)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipDetail extends StatelessWidget {
  final String label;
  final String value;
  final bool alignRight;

  const _MembershipDetail({
    required this.label,
    required this.value,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: Color(0x99FFFFFF))),
        const SizedBox(height: 2),
        Text(value,
            style:
                const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            color: Color(0x59FFFFFF),
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;

  const _IconTile(
      {required this.icon, required this.color, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: iconColor, size: 18),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF2DD4BF), size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0x73FFFFFF))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: Color(0x4DFFFFFF)),
          ],
        ),
      ),
    );
  }
}