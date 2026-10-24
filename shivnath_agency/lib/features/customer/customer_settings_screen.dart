import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/repositories/app_repositories.dart';
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

  void _showComingSoon(String feature) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

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

            const Divider(height: 1),

            _SettingsTile(
              icon: Icons.receipt_long_rounded,
              title: 'GST Billing Profile (Optional)',
              subtitle:
                  'Saved business GSTIN and billing address for tax invoices',
              onTap: _showGstProfileDialog,
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
              value: AppConstants.appName,
            ),
            const Divider(height: 1),
            const _InfoRow(
              title: 'Tagline',
              value: AppConstants.appTagline,
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

  void _showGstProfileDialog() async {
    final authRepo = AuthRepository();
    final gstinController = TextEditingController();
    final legalNameController = TextEditingController();
    final addressController = TextEditingController();
    final stateController = TextEditingController();
    final pincodeController = TextEditingController();
    bool isGstRequested = false;
    bool isLoading = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (isLoading) {
              authRepo.getCurrentUser().then((res) {
                if (res['success'] == true && res['data'] is Map) {
                  final data = res['data'] as Map<String, dynamic>;
                  gstinController.text = data['gstin']?.toString() ?? '';
                  legalNameController.text = data['gst_legal_name']?.toString() ?? '';
                  addressController.text = data['gst_billing_address']?.toString() ?? '';
                  stateController.text = data['gst_state_name']?.toString() ?? '';
                  pincodeController.text = data['gst_pincode']?.toString() ?? '';
                  isGstRequested = data['is_gst_requested'] == true || gstinController.text.isNotEmpty;
                }
                setDialogState(() => isLoading = false);
              }).catchError((_) {
                setDialogState(() => isLoading = false);
              });

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Text('GST Billing Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('GST Billing Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Save business GST details for tax-compliant invoices and Input Tax Credit.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable GST Invoices', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: const Text('Include GST details in future orders by default', style: TextStyle(fontSize: 11)),
                      value: isGstRequested,
                      activeColor: const Color(0xFF16A34A),
                      onChanged: (val) {
                        setDialogState(() => isGstRequested = val);
                      },
                    ),
                    const Divider(height: 16),
                    TextField(
                      controller: gstinController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 15,
                      decoration: const InputDecoration(
                        labelText: 'GSTIN (15 Characters)',
                        hintText: 'e.g. 22AAAAA0000A1Z5',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: legalNameController,
                      decoration: const InputDecoration(
                        labelText: 'Legal / Business Name',
                        hintText: 'Registered business name',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'GST Registered Address',
                        hintText: 'Principal place of business address',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: stateController,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              hintText: 'e.g. Chhattisgarh',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: pincodeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: 'PIN Code',
                              counterText: '',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final gstin = gstinController.text.trim().toUpperCase();
                    if (isGstRequested && gstin.isNotEmpty) {
                      final gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
                      if (!gstRegex.hasMatch(gstin)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid 15-character GSTIN format')),
                        );
                        return;
                      }
                    }
                    Navigator.pop(dialogCtx);
                    final updateRes = await authRepo.updateProfile({
                      'is_gst_requested': isGstRequested,
                      'gstin': gstin,
                      'gst_legal_name': legalNameController.text.trim(),
                      'gst_billing_address': addressController.text.trim(),
                      'gst_state_name': stateController.text.trim(),
                      'gst_pincode': pincodeController.text.trim(),
                    });
                    if (mounted) {
                      if (updateRes['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('GST billing profile saved successfully!'),
                            backgroundColor: Color(0xFF166534),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(updateRes['message']?.toString() ?? 'Failed to update GST profile'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save Profile'),
                ),
              ],
            );
          },
        );
      },
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