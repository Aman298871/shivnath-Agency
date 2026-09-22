import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  void _onSelectRole(String role) {
    setState(() {
      selectedRole = role;
    });
    Provider.of<RoleThemeProvider>(context, listen: false).setRole(role);
  }

  Future<void> _continueWithRole([String? role]) async {
    final roleToUse = role ?? selectedRole;
    Provider.of<RoleThemeProvider>(context, listen: false).setRole(roleToUse);
    await _sessionService.saveRole(roleToUse);

    if (!mounted) return;

    Navigator.pushNamed(
      context,
      AppRoutes.login,
      arguments: roleToUse,
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
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // Official Shivnath Agency Multi-color Brand Logo
                      const Center(
                        child: ShivnathLogo(
                          size: 58,
                          showSubtitle: true,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Header
                      const Text(
                        'Choose Your Role',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: BrandColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'Select an option to continue',
                        style: TextStyle(
                          fontSize: 14,
                          color: BrandColors.textSecondary,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // -----------------------------------------------------------
                      // 1. CUSTOMER CARD (Blue)
                      // -----------------------------------------------------------
                      _RoleCard(
                        title: 'Customer',
                        subtitle: 'Browse products, place orders & track delivery',
                        icon: Icons.person_rounded,
                        accentColor: BrandColors.primaryBlue,
                        softColor: BrandColors.blueSoft,
                        selected: selectedRole == AppConstants.customerRole,
                        onTap: () => _onSelectRole(AppConstants.customerRole),
                      ),

                      const SizedBox(height: 14),

                      // -----------------------------------------------------------
                      // 2. FRANCHISE CARD (Green)
                      // -----------------------------------------------------------
                      _RoleCard(
                        title: 'Franchise',
                        subtitle: 'Receive company stock, manage orders & local sales',
                        icon: Icons.storefront_rounded,
                        accentColor: BrandColors.greenDark,
                        softColor: BrandColors.greenSoft,
                        selected: selectedRole == AppConstants.franchiseRole,
                        onTap: () => _onSelectRole(AppConstants.franchiseRole),
                      ),

                      const SizedBox(height: 14),

                      // -----------------------------------------------------------
                      // 3. ADMIN CARD (Red)
                      // -----------------------------------------------------------
                      _RoleCard(
                        title: 'Admin',
                        subtitle: 'Platform management & control',
                        icon: Icons.admin_panel_settings_rounded,
                        accentColor: BrandColors.redDark,
                        softColor: BrandColors.redSoft,
                        selected: selectedRole == AppConstants.adminRole,
                        onTap: () => _onSelectRole(AppConstants.adminRole),
                      ),

                      const SizedBox(height: 28),

                      // Continue Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => _continueWithRole(),
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

                      const Spacer(),

                      // Support / AI Assistant link
                      Center(
                        child: TextButton.icon(
                          onPressed: () =>
                              AiChatbotModal.show(context, mode: ChatbotMode.public),
                          icon: const Icon(
                            Icons.smart_toy_rounded,
                            color: BrandColors.primaryBlue,
                            size: 19,
                          ),
                          label: const Text(
                            'Need help? Ask Pure Water AI Assistant',
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color softColor;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.softColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BrandColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accentColor : BrandColors.border,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? accentColor.withValues(alpha: 0.12)
                  : const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: selected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Role Icon Container
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: selected ? softColor : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? accentColor.withValues(alpha: 0.3)
                      : BrandColors.border,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: selected ? accentColor : BrandColors.textSecondary,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Role Title + Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: selected ? accentColor : BrandColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: BrandColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Role Colored Arrow
            Icon(
              Icons.chevron_right_rounded,
              color: selected ? accentColor : BrandColors.borderDark,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}