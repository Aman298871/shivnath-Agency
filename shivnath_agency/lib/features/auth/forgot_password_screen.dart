import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/brand_colors.dart';
import '../../core/theme/role_theme.dart';
import '../../core/widgets/shivnath_logo.dart';

class ForgotPasswordScreen extends StatelessWidget {
  final String? initialEmail;
  final String? initialRole;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
    this.initialRole,
  });

  RoleThemeConfig get roleConfig {
    final role = initialRole ?? '';
    return RoleTheme.fromKey(role);
  }

  Future<void> _makePhoneCall(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot initiate call to $phone')),
        );
      }
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/91$cleanPhone?text=Hello%20WaterNow%20Support,%20I%20need%20assistance%20with%20resetting%20my%20account%20password.');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp for $phone')),
        );
      }
    }
  }

  Future<void> _sendEmail(BuildContext context, String email) async {
    final uri = Uri.parse('mailto:$email?subject=WaterNow%20Password%20Reset%20Request');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open email app for $email')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = roleConfig;
    final primaryThemeColor = cfg.primary;

    const supportPhone = '+91 98765 43210';
    const supportWhatsApp = '9876543210';
    const supportEmail = 'support@waternow.in';

    return Scaffold(
      backgroundColor: BrandColors.white,
      appBar: AppBar(
        backgroundColor: BrandColors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: BrandColors.textPrimary),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18.0),
            child: ShivnathLogo.horizontal(size: 32),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Role Badge Icon
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: primaryThemeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryThemeColor.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 32,
                  color: primaryThemeColor,
                ),
              ),

              const SizedBox(height: 20),

              // Title
              const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: BrandColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Assisted Account Recovery',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primaryThemeColor,
                ),
              ),

              const SizedBox(height: 16),

              // Explanation Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BrandColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BrandColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 20,
                          color: primaryThemeColor,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Verified Admin Assistance',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: BrandColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'To protect your orders, delivery routes, and account security, password resets are processed through verified administrative assistance.\n\nPlease contact our central operations desk or your assigned franchise administrator to verify your identity and receive a secure temporary password.',
                      style: TextStyle(
                        fontSize: 13,
                        color: BrandColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Official Support Channels',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              // Channel 1: Phone
              _buildChannelTile(
                context: context,
                icon: Icons.phone_in_talk_rounded,
                iconColor: BrandColors.primaryBlue,
                title: 'Phone Support Hotline',
                subtitle: supportPhone,
                actionLabel: 'Call Now',
                onTap: () => _makePhoneCall(context, supportPhone),
              ),

              const SizedBox(height: 10),

              // Channel 2: WhatsApp
              _buildChannelTile(
                context: context,
                icon: Icons.chat_rounded,
                iconColor: BrandColors.greenDark,
                title: 'WhatsApp Official Helpdesk',
                subtitle: 'Direct operational assistance',
                actionLabel: 'Chat',
                onTap: () => _openWhatsApp(context, supportWhatsApp),
              ),

              const SizedBox(height: 10),

              // Channel 3: Email
              _buildChannelTile(
                context: context,
                icon: Icons.email_outlined,
                iconColor: BrandColors.textPrimary,
                title: 'Email Support',
                subtitle: supportEmail,
                actionLabel: 'Email',
                onTap: () => _sendEmail(context, supportEmail),
              ),

              const SizedBox(height: 20),

              // Security Guarantee Alert
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BrandColors.warningSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BrandColors.warningDark.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_clock_rounded,
                      size: 20,
                      color: BrandColors.warningDark,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Security Notice: WaterNow officials will NEVER ask for your current password or UPI PIN. An authorized admin will only provide a temporary password after verifying your identity.',
                        style: TextStyle(
                          fontSize: 12,
                          color: BrandColors.warningDark,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Return to login button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryThemeColor,
                    side: BorderSide(color: primaryThemeColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BrandColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: BrandColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(60, 34),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
