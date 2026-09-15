import 'package:flutter/material.dart';

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

  String language = 'English';

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
                  title: const Text('Settings'),
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
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'Manage franchise account preferences.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],

                    _section(
                      'Notifications',
                      Icons.notifications_outlined,
                      [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Order Notifications',
                          ),
                          subtitle: const Text(
                            'Receive order status updates',
                          ),
                          value: orderNotifications,
                          onChanged: (value) {
                            setState(() {
                              orderNotifications = value;
                            });
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Payment Notifications',
                          ),
                          subtitle: const Text(
                            'Receive invoice and payment reminders',
                          ),
                          value: paymentNotifications,
                          onChanged: (value) {
                            setState(() {
                              paymentNotifications = value;
                            });
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Offers',
                          ),
                          subtitle: const Text(
                            'Receive new schemes and offers',
                          ),
                          value: offerNotifications,
                          onChanged: (value) {
                            setState(() {
                              offerNotifications = value;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    _section(
                      'Language',
                      Icons.language_rounded,
                      [
                        RadioListTile<String>(
                          value: 'English',
                          groupValue: language,
                          title: const Text('English'),
                          onChanged: (value) {
                            setState(() {
                              language = value!;
                            });
                          },
                        ),
                        RadioListTile<String>(
                          value: 'Hindi',
                          groupValue: language,
                          title: const Text('हिन्दी'),
                          onChanged: (value) {
                            setState(() {
                              language = value!;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    _section(
                      'Security',
                      Icons.lock_outline_rounded,
                      [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.password_rounded,
                            color: Color(0xFF0284C7),
                          ),
                          title: const Text(
                            'Change Password',
                          ),
                          subtitle: const Text(
                            'Update your account password',
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                          ),
                          onTap: () {},
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.privacy_tip_outlined,
                            color: Color(0xFF0284C7),
                          ),
                          title: const Text(
                            'Privacy Policy',
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    _section(
                      'About',
                      Icons.info_outline_rounded,
                      const [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Shivnath Agency'),
                          subtitle: Text(
                            'Franchise Portal',
                          ),
                          trailing: Text('v1.0.0'),
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