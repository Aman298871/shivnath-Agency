import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/session_service.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/role_theme.dart';
import '../../core/widgets/ai_chatbot_modal.dart';
import '../../core/widgets/shivnath_logo.dart';
import '../../routes/app_routes.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final SessionService _sessionService = SessionService();

  // Default selection to customer
  String selectedRole = AppConstants.customerRole;

  Future<void> _continue() async {
    await _sessionService.saveRole(selectedRole);

    if (!mounted) return;

    Navigator.pushNamed(
      context,
      AppRoutes.login,
      arguments: selectedRole,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = RoleTheme.fromKey(selectedRole);

    return Scaffold(
      backgroundColor: BrandColors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // Official Shivnath Agency Brand Logo
                  const Center(
                    child: ShivnathLogo(
                      size: 58,
                      showSubtitle: true,
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Text(
                    'Welcome',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: BrandColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Select your account type to access your dedicated portal',
                    style: TextStyle(
                      fontSize: 14,
                      color: BrandColors.textSecondary,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // -----------------------------------------------------------
                  // 1. CUSTOMER CARD (Blue Accent)
                  // -----------------------------------------------------------
                  _ProfileCard(
                    title: 'Customer',
                    subtitle: 'Shop packaged drinking water and manage orders',
                    icon: Icons.person_rounded,
                    accentColor: BrandColors.primaryBlue,
                    softColor: BrandColors.blueSoft,
                    selected: selectedRole == AppConstants.customerRole,
                    onTap: () {
                      setState(() {
                        selectedRole = AppConstants.customerRole;
                      });
                    },
                  ),

                  const SizedBox(height: 14),

                  // -----------------------------------------------------------
                  // 2. WHOLESALE DEALER CARD (Green Accent)
                  // -----------------------------------------------------------
                  _ProfileCard(
                    title: 'Wholesale Dealer',
                    subtitle:
                        'Authorized Wholesale Dealer portal for stock, orders and billing',
                    icon: Icons.storefront_rounded,
                    accentColor: BrandColors.greenDark,
                    softColor: BrandColors.greenSoft,
                    selected: selectedRole == AppConstants.franchiseRole,
                    onTap: () {
                      setState(() {
                        selectedRole = AppConstants.franchiseRole;
                      });
                    },
                  ),

                  const SizedBox(height: 14),

                  // -----------------------------------------------------------
                  // 3. ADMIN CARD (Blue + Red Accent)
                  // -----------------------------------------------------------
                  _ProfileCard(
                    title: 'Admin',
                    subtitle:
                        'Central operations, plant inventory, production and sales control',
                    icon: Icons.admin_panel_settings_rounded,
                    accentColor: BrandColors.primaryBlue,
                    secondaryAccent: BrandColors.red,
                    softColor: BrandColors.blueSoft,
                    selected: selectedRole == AppConstants.adminRole,
                    onTap: () {
                      setState(() {
                        selectedRole = AppConstants.adminRole;
                      });
                    },
                  ),

                  const SizedBox(height: 28),

                  // Continue Button (dynamically themed by selected role)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _continue,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue as ${activeTheme.displayName}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Pure Water AI Assistant Support
                  Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          AiChatbotModal.show(context, mode: ChatbotMode.public),
                      icon: const Icon(
                        Icons.smart_toy_rounded,
                        color: BrandColors.primaryBlue,
                        size: 20,
                      ),
                      label: const Text(
                        'Have questions? Ask Pure Water AI Assistant',
                        style: TextStyle(
                          color: BrandColors.primaryBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color? secondaryAccent;
  final Color softColor;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.secondaryAccent,
    required this.softColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: BrandColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? accentColor : BrandColors.border,
          width: selected ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? accentColor.withValues(alpha: 0.12)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: selected ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                // Icon Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected ? softColor : BrandColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: selected
                        ? Border.all(
                            color: accentColor.withValues(alpha: 0.3),
                            width: 1,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 26,
                      color: selected ? accentColor : BrandColors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? BrandColors.textPrimary
                                  : BrandColors.textPrimary,
                            ),
                          ),
                          if (secondaryAccent != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: secondaryAccent!.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'CONTROL',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: secondaryAccent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.38,
                          color: BrandColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Selection Radio / Check
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? accentColor : Colors.transparent,
                    border: Border.all(
                      color: selected ? accentColor : BrandColors.borderDark,
                      width: selected ? 0 : 2,
                    ),
                  ),
                  child: selected
                      ? const Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}