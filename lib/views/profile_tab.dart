import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // Sleek App Bar
          const SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Settings & Privacy',
              style: TextStyle(
                color: Color(0xFF1E1E1E),
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 100% Free & Privacy First Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E293B),
                          Color(0xFF0F172A),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF10B981)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 14,
                                    color: Color(0xFF10B981),
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    '100% OFFLINE & FREE',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'AIAnthro Suite',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Privacy First Experience',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your documents never leave this device. All conversions, signing, merging, and compression run purely in local memory with zero server uploads.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Unlimited Free Access to All 13 Tools',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Section 1: Storage & Details
                  const Text(
                    'STORAGE & FILES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSettingsGroup([
                    const _SettingsTile(
                      icon: Icons.folder_special_rounded,
                      title: 'Public PDF Directory',
                      subtitle: 'Internal Storage / Download / PDFReader',
                      trailing: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    const _SettingsTile(
                      icon: Icons.photo_library_rounded,
                      title: 'Public Image Directory',
                      subtitle: 'Internal Storage / Pictures / PDFReader',
                      trailing: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                  ]),

                  const SizedBox(height: 28),

                  // Section 2: Privacy & Legal
                  const Text(
                    'LEGAL & TRUST',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSettingsGroup([
                    _SettingsTile(
                      icon: Icons.security_rounded,
                      title: 'Privacy Policy',
                      subtitle: 'We do not collect or upload your files',
                      onTap: () => _showPolicyDialog(context),
                    ),
                    _SettingsTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Offline Security Pledge',
                      subtitle: 'Why on-device processing matters',
                      onTap: () => _showSecurityPledge(context),
                    ),
                    _SettingsTile(
                      icon: Icons.gavel_rounded,
                      title: 'Terms of Service',
                      subtitle: 'Standard license & terms',
                      onTap: () => _showTermsDialog(context),
                    ),
                  ]),

                  const SizedBox(height: 28),

                  // Section 3: Share & App Support
                  const Text(
                    'SHARE & SUPPORT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSettingsGroup([
                    _SettingsTile(
                      icon: Icons.share_rounded,
                      title: 'Share App with Friends',
                      subtitle: 'Help friends convert, merge & sign PDFs for free',
                      onTap: () {
                        SharePlus.instance.share(
                          ShareParams(
                            text: 'Hey! Check out PDF Reader – PDF Viewer by AIAnthro. It has 13 completely free offline PDF tools with zero ads and no subscription required!',
                          ),
                        );
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.star_rate_rounded,
                      title: 'Rate on Google Play',
                      subtitle: 'Support this project with 5 stars',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Thank you! Rating will be live once published on Google Play.'),
                            backgroundColor: const Color(0xFF1E1E1E),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                    ),
                  ]),

                  const SizedBox(height: 36),

                  // Branding Footer
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset('assets/images/app_logo.png'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'PDF Reader – PDF Viewer',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Version 1.0.0 • Package: com.aianthro.pdftools',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(tiles.length, (index) {
          return Column(
            children: [
              tiles[index],
              if (index < tiles.length - 1)
                const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF0F0F0)),
            ],
          );
        }),
      ),
    );
  }

  void _showPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_rounded, color: Color(0xFFE5252A)),
            SizedBox(width: 8),
            Text('Privacy Policy'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'We value your privacy above everything.\n\n'
            '1. 100% Offline: Your documents, images, and converted files are processed directly on your device.\n\n'
            '2. No Server Uploads: We never upload, transfer, or store any of your files on external clouds or servers.\n\n'
            '3. Zero Data Mining: Your document contents and passwords remain strictly on your device.\n\n'
            'Developed with trust by AIAnthro.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFFE5252A))),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'By using PDF Reader – PDF Viewer, you agree to:\n\n'
            '• Use the application for lawful personal and professional purposes.\n'
            '• All tools operate offline on local files without guarantees of third-party file structures.\n\n'
            'Thank you for using AIAnthro tools.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: Color(0xFFE5252A))),
          ),
        ],
      ),
    );
  }

  void _showSecurityPledge(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Security Pledge'),
          ],
        ),
        content: const Text(
          'Your files NEVER leave your phone.\n\n'
          'Unlike many online tools that upload your bank statements, Aadhaar, and IDs to remote clouds, '
          'all tools (merge, split, protect, sign, compress) run purely in local device memory.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood', style: TextStyle(color: Color(0xFF10B981))),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFE5252A).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFFE5252A), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E1E1E),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF8E8E93)),
      ),
      trailing: trailing ??
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFC7C7CC)),
    );
  }
}
