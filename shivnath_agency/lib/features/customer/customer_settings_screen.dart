import 'package:flutter/material.dart';
import '../../core/widgets/support_desk_modal.dart';

class CustomerSettingsScreen extends StatefulWidget {
  const CustomerSettingsScreen({super.key});

  @override
  State<CustomerSettingsScreen> createState() =>
      _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState
    extends State<CustomerSettingsScreen> {
  bool orderNotifications = true;
  bool deliveryNotifications = true;
  bool offerNotifications = false;
  bool emailNotifications = true;

  String selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          return _buildDesktop();
        }

        return _buildMobile();
      },
    );
  }

  // =========================================================
  // MOBILE
  // =========================================================

  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          30,
        ),
        child: _settingsContent(),
      ),
    );
  }

  // =========================================================
  // DESKTOP
  // =========================================================

  Widget _buildDesktop() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1000,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Manage your account preferences, notifications and security.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 26),

                _settingsContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SETTINGS CONTENT
  // =========================================================

  Widget _settingsContent() {
    return Column(
      children: [
        // =====================================================
        // NOTIFICATIONS
        // =====================================================

        _SettingsSection(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          subtitle: 'Choose which notifications you want to receive.',
          children: [
            _SwitchSetting(
              title: 'Order Notifications',
              subtitle:
                  'Receive updates when your order status changes.',
              value: orderNotifications,
              onChanged: (value) {
                setState(() {
                  orderNotifications = value;
                });
              },
            ),

            const Divider(height: 1),

            _SwitchSetting(
              title: 'Delivery Notifications',
              subtitle:
                  'Get notified when your order is dispatched or delivered.',
              value: deliveryNotifications,
              onChanged: (value) {
                setState(() {
                  deliveryNotifications = value;
                });
              },
            ),

            const Divider(height: 1),

            _SwitchSetting(
              title: 'Offers & Promotions',
              subtitle:
                  'Receive offers, discounts and promotional updates.',
              value: offerNotifications,
              onChanged: (value) {
                setState(() {
                  offerNotifications = value;
                });
              },
            ),

            const Divider(height: 1),

            _SwitchSetting(
              title: 'Email Notifications',
              subtitle:
                  'Receive important account updates by email.',
              value: emailNotifications,
              onChanged: (value) {
                setState(() {
                  emailNotifications = value;
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 18),

        // =====================================================
        // LANGUAGE
        // =====================================================

        _SettingsSection(
          icon: Icons.language_rounded,
          title: 'Language',
          subtitle: 'Choose your preferred application language.',
          children: [
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'English',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Use application in English',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
              value: 'English',
              groupValue: selectedLanguage,
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedLanguage = value;
                });
              },
            ),

            const Divider(height: 1),

            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'हिन्दी',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'ऐप को हिन्दी में उपयोग करें',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
              value: 'Hindi',
              groupValue: selectedLanguage,
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedLanguage = value;
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 18),

        // =====================================================
        // PRIVACY & SECURITY
        // =====================================================

        _SettingsSection(
          icon: Icons.lock_outline_rounded,
          title: 'Privacy & Security',
          subtitle: 'Manage password and account security.',
          children: [
            _SettingsTile(
              icon: Icons.password_rounded,
              title: 'Change Password',
              subtitle: 'Update your account password',
              onTap: () {
                _showChangePasswordDialog();
              },
            ),

            const Divider(height: 1),

            _SettingsTile(
              icon: Icons.devices_outlined,
              title: 'Logged In Devices',
              subtitle: 'View devices logged into your account',
              onTap: () {
                _showComingSoon(
                  'Logged In Devices',
                );
              },
            ),

            const Divider(height: 1),

            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'View our privacy policy',
              onTap: () {
                _showComingSoon(
                  'Privacy Policy',
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 18),

        // =====================================================
        // ACCOUNT SETTINGS
        // =====================================================

        _SettingsSection(
          icon: Icons.person_outline_rounded,
          title: 'Account',
          subtitle: 'Manage your account preferences.',
          children: [
            _SettingsTile(
              icon: Icons.location_on_outlined,
              title: 'Default Delivery Address',
              subtitle:
                  'Choose your default address for orders',
              onTap: () {
                _showComingSoon(
                  'Default Delivery Address',
                );
              },
            ),

            const Divider(height: 1),

            _SettingsTile(
              icon: Icons.support_agent_rounded,
              title: 'Help & Support',
              subtitle:
                  'Contact Water Wala support team',
              onTap: () {
                SupportDeskModal.show(context);
              },
            ),
          ],
        ),

        const SizedBox(height: 18),

        // =====================================================
        // ABOUT
        // =====================================================

        _SettingsSection(
          icon: Icons.info_outline_rounded,
          title: 'About',
          subtitle: 'Application information.',
          children: [
            const _InfoRow(
              title: 'Application',
              value: 'Water Wala',
            ),

            const Divider(height: 1),

            const _InfoRow(
              title: 'Version',
              value: '1.0.0',
            ),

            const Divider(height: 1),

            _SettingsTile(
              icon: Icons.description_outlined,
              title: 'Terms & Conditions',
              subtitle: 'Read our terms and conditions',
              onTap: () {
                _showComingSoon(
                  'Terms & Conditions',
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  // =========================================================
  // CHANGE PASSWORD
  // =========================================================

  void _showChangePasswordDialog() {
    final currentPasswordController =
        TextEditingController();

    final newPasswordController =
        TextEditingController();

    final confirmPasswordController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.lock_reset_rounded,
                color: Color(0xFF0284C7),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Change Password',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller:
                        currentPasswordController,
                    obscureText: true,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Current Password',
                      prefixIcon: Icon(
                        Icons.lock_outline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller:
                        newPasswordController,
                    obscureText: true,
                    decoration:
                        const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(
                        Icons.password_rounded,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller:
                        confirmPasswordController,
                    obscureText: true,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Confirm New Password',
                      prefixIcon: Icon(
                        Icons.password_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),

            ElevatedButton(
              onPressed: () {
                if (newPasswordController.text
                        .trim() !=
                    confirmPasswordController.text
                        .trim()) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'New password and confirm password do not match',
                      ),
                    ),
                  );

                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password updated successfully',
                    ),
                  ),
                );
              },
              child: const Text(
                'Update Password',
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // COMING SOON
  // =========================================================

  void _showComingSoon(
    String title,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$title will be available soon',
          ),
          duration:
              const Duration(seconds: 2),
        ),
      );
  }
}

// =========================================================
// SETTINGS SECTION
// =========================================================

class _SettingsSection
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFE0F2FE,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color:
                        const Color(
                      0xFF0284C7,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 13,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        title,
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight
                                  .w800,
                          color:
                              Color(
                            0xFF0F172A,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        subtitle,
                        style:
                            const TextStyle(
                          fontSize: 11,
                          color:
                              Color(
                            0xFF64748B,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
          ),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 5,
            ),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// SWITCH SETTING
// =========================================================

class _SwitchSetting
    extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchSetting({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding:
          EdgeInsets.zero,
      title: Text(
        title,
        style:
            const TextStyle(
          fontSize: 13,
          fontWeight:
              FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style:
            const TextStyle(
          fontSize: 10,
          color:
              Color(0xFF64748B),
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

// =========================================================
// SETTINGS TILE
// =========================================================

class _SettingsTile
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color:
              const Color(0xFFF1F5F9),
          borderRadius:
              BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color:
              const Color(0xFF0284C7),
        ),
      ),
      title: Text(
        title,
        style:
            const TextStyle(
          fontSize: 13,
          fontWeight:
              FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style:
            const TextStyle(
          fontSize: 10,
          color:
              Color(0xFF64748B),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color:
            Color(0xFF94A3B8),
      ),
    );
  }
}

// =========================================================
// INFO ROW
// =========================================================

class _InfoRow
    extends StatelessWidget {
  final String title;
  final String value;

  const _InfoRow({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 17,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style:
                  const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style:
                const TextStyle(
              fontSize: 12,
              color:
                  Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}