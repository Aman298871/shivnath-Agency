import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/session_service.dart';
import '../../core/widgets/ai_chatbot_modal.dart';
import '../../routes/app_routes.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final SessionService _sessionService = SessionService();

  String? selectedRole;

  Future<void> _continue() async {
    if (selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an account type'),
        ),
      );

      return;
    }

    await _sessionService.saveRole(selectedRole!);

    if (!mounted) return;

    Navigator.pushNamed(
      context,
      AppRoutes.login,
      arguments: selectedRole,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  const Icon(
                    Icons.water_drop_rounded,
                    size: 46,
                    color: Color(0xFF0284C7),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Welcome',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Select your account type to continue',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _RoleCard(
                    title: 'Customer',
                    subtitle: 'Shop packaged drinking water and manage orders',
                    icon: Icons.person_outline_rounded,
                    selected: selectedRole == AppConstants.customerRole,
                    onTap: () {
                      setState(() {
                        selectedRole = AppConstants.customerRole;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  _RoleCard(
                    title: 'Franchise',
                    subtitle:
                        'Authorized Franchise portal for stock, invoices and payments',
                    icon: Icons.storefront_outlined,
                    selected: selectedRole == AppConstants.franchiseRole,
                    onTap: () {
                      setState(() {
                        selectedRole = AppConstants.franchiseRole;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  _RoleCard(
                    title: 'Company Staff / Admin',
                    subtitle: 'Super Admin, Plant Operations & Sales Executive portal',
                    icon: Icons.admin_panel_settings_outlined,
                    selected: selectedRole == AppConstants.adminRole,
                    onTap: () {
                      setState(() {
                        selectedRole = AppConstants.adminRole;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _continue,
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          AiChatbotModal.show(context, mode: ChatbotMode.public),
                      icon: const Icon(
                        Icons.smart_toy_rounded,
                        color: Color(0xFF0284C7),
                      ),
                      label: const Text(
                        'Have questions? Ask Pure Water AI Assistant',
                        style: TextStyle(
                          color: Color(0xFF0284C7),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                ],
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
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE0F2FE)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF0284C7)
                : const Color(0xFFE2E8F0),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF0284C7)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected
                    ? Colors.white
                    : const Color(0xFF475569),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? const Color(0xFF0284C7)
                  : const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}