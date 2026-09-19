import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/session_service.dart';
import '../../core/widgets/ai_chatbot_modal.dart';
import '../../core/widgets/support_desk_modal.dart';
import '../../models/user_model.dart';
import 'profile/franchise_profile_screen.dart';

class FranchiseSettingsScreen extends StatefulWidget {
  const FranchiseSettingsScreen({super.key});

  @override
  State<FranchiseSettingsScreen> createState() =>
      _FranchiseSettingsScreenState();
}

class _FranchiseSettingsScreenState
    extends State<FranchiseSettingsScreen> {
  bool orderNotifications = true;
  bool paymentNotifications = true;
  bool offerNotifications = false;
  bool stockAlerts = true;

  String language = 'English';
  bool _isSyncing = false;

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool isSaving = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.password_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 10),
              Text('Change Password', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your existing password and choose a strong new password.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: currentPassCtrl,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: newPassCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmPassCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.check_circle_outline),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () {
                      final curr = currentPassCtrl.text.trim();
                      final nPass = newPassCtrl.text.trim();
                      final cPass = confirmPassCtrl.text.trim();

                      if (curr.isEmpty || nPass.isEmpty || cPass.isEmpty) {
                        setDialogState(() => errorText = 'Please fill in all password fields.');
                        return;
                      }
                      if (nPass.length < 6) {
                        setDialogState(() => errorText = 'Password must be at least 6 characters.');
                        return;
                      }
                      if (nPass != cPass) {
                        setDialogState(() => errorText = 'New passwords do not match.');
                        return;
                      }

                      setDialogState(() {
                        errorText = null;
                        isSaving = true;
                      });

                      Future.delayed(const Duration(milliseconds: 700), () {
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Account password updated successfully!'),
                              ],
                            ),
                            backgroundColor: Color(0xFF16A34A),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      });
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 10),
            Text('Franchise Privacy Policy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Shivnath Agency - Data Protection & Compliance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              SizedBox(height: 8),
              Text(
                '1. Information Handling: All franchise records, customer transaction logs, delivery addresses, and billing records are encrypted and retained strictly for franchise fulfillment.\n\n'
                '2. Customer Confidentiality: Franchise partners agree not to disclose customer phone numbers, personal identities, or commercial pricing without authorization.\n\n'
                '3. Quality Compliance: Water quality test logs, batch manufacturing serials, and FSSAI guidelines must be kept up-to-date in the franchise ledger.\n\n'
                '4. Payments & Remittance: All distributor commissions and payments are audited and settled in compliance with GST guidelines.',
                style: TextStyle(fontSize: 12, height: 1.55, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Understand & Agree'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 10),
            Text('Franchise Agreement Terms', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Operational Guidelines & Territory Exclusivity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              SizedBox(height: 8),
              Text(
                '• Territory Rights: Exclusive distribution rights apply within the designated geographic cluster/pincode approved by Shivnath Agency.\n\n'
                '• Quality Assurance: Only authorized 20L jars, 1L, and 500ml Shivnath packaged water may be supplied under the franchise trade badge.\n\n'
                '• Returnable Jar Security: 20L empty water jar deposits and counts must be accounted for in the daily stock ledger.\n\n'
                '• Commission Structure: Standard base margin is 12% on direct customer retail orders and volume bonus on commercial deliveries.',
                style: TextStyle(fontSize: 12, height: 1.55, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _syncAppData() {
    setState(() => _isSyncing = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Franchise catalog, orders & stock synchronized successfully!'),
            ],
          ),
          backgroundColor: Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  void _checkAppUpdates() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 10),
            Text('Software Updates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are on the latest version of Shivnath Franchise Portal.', style: TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
            SizedBox(height: 10),
            Text('Version: 1.0.4+12 (Production Build)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7))),
            SizedBox(height: 4),
            Text('All security patches & order synchronization protocols are active.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: desktop
              ? null
              : AppBar(
                  title: const Text('Franchise Settings'),
                  actions: [
                    IconButton(
                      tooltip: 'Sync Data',
                      icon: _isSyncing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.sync_rounded),
                      onPressed: _isSyncing ? null : _syncAppData,
                    ),
                  ],
                ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 900,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desktop) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Settings & Preferences',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Manage notifications, language, security and operational preferences.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _isSyncing ? null : _syncAppData,
                            icon: _isSyncing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.sync_rounded),
                            label: Text(_isSyncing ? 'Syncing...' : 'Sync Catalog & Stock'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                    ],

                    _section(
                      'Notifications & Alerts',
                      Icons.notifications_active_outlined,
                      [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Order Status Alerts',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Immediate alerts when customers place or update water orders',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: orderNotifications,
                          onChanged: (value) {
                            setState(() => orderNotifications = value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Order alerts ${value ? "enabled" : "disabled"}'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Payment & Invoices',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Receive notifications for customer payments and monthly invoice remittances',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: paymentNotifications,
                          onChanged: (value) {
                            setState(() => paymentNotifications = value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Payment alerts ${value ? "enabled" : "disabled"}'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Low Stock & Raw Material Alerts',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Auto-alert when bottles, caps, or mineral preforms fall below re-order threshold',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: stockAlerts,
                          onChanged: (value) {
                            setState(() => stockAlerts = value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Low stock alerts ${value ? "enabled" : "disabled"}'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Promotional Schemes & Deals',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Receive special bulk discount schemes and monsoon season offers',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: offerNotifications,
                          onChanged: (value) {
                            setState(() => offerNotifications = value);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    _section(
                      'Language & Localization',
                      Icons.language_rounded,
                      [
                        RadioListTile<String>(
                          value: 'English',
                          groupValue: language,
                          title: const Text('English (Primary Interface)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          onChanged: (value) {
                            setState(() => language = value!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Language set to English'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
                            );
                          },
                        ),
                        RadioListTile<String>(
                          value: 'Hindi',
                          groupValue: language,
                          title: const Text('हिन्दी (Hindi)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          onChanged: (value) {
                            setState(() => language = value!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('भाषा हिन्दी सेट की गई'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
                            );
                          },
                        ),
                        RadioListTile<String>(
                          value: 'Marathi',
                          groupValue: language,
                          title: const Text('मराठी (Marathi)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          onChanged: (value) {
                            setState(() => language = value!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('भाषा मराठी सेट केली'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    _section(
                      'Security & Compliance',
                      Icons.lock_outline_rounded,
                      [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE0F2FE),
                            child: Icon(
                              Icons.password_rounded,
                              color: Color(0xFF0284C7),
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Change Password',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Update your franchise account credentials',
                            style: TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                          ),
                          onTap: _showChangePasswordDialog,
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFDCFCE7),
                            child: Icon(
                              Icons.privacy_tip_outlined,
                              color: Color(0xFF16A34A),
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Privacy Policy & Data Protection',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Customer data safety & regulatory compliance',
                            style: TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                          ),
                          onTap: _showPrivacyPolicyDialog,
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFEF3C7),
                            child: Icon(
                              Icons.gavel_rounded,
                              color: Color(0xFFD97706),
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Franchise Operating Agreement',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Territory exclusivity, quality standards & commission terms',
                            style: TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                          ),
                          onTap: _showTermsDialog,
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    _section(
                      'Business & Technical Support',
                      Icons.headset_mic_outlined,
                      [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE0F2FE),
                            child: Icon(
                              Icons.smart_toy_rounded,
                              color: Color(0xFF0284C7),
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'AI Operations Assistant',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Instant help with stock queries, order billing & inventory management',
                            style: TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                          ),
                          onTap: () => AiChatbotModal.show(context, mode: ChatbotMode.franchise),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFDCFCE7),
                            child: Icon(
                              Icons.phone_in_talk_rounded,
                              color: Color(0xFF16A34A),
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Franchise Support Desk',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Call or Chat with official support desk',
                            style: TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Color(0xFF16A34A),
                          ),
                          onTap: () => SupportDeskModal.show(context),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFF1F5F9),
                            child: Icon(
                              Icons.system_update_rounded,
                              color: Color(0xFF475569),
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Check for App Updates',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Installed version: v1.0.4+12',
                            style: TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                          ),
                          onTap: _checkAppUpdates,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _section(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}