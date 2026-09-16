import 'package:flutter/material.dart';
import '../../../core/widgets/app_toast.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  String activeTab = 'Business';

  final businessName =
      TextEditingController(text: 'Pure Water Industries');
  final phone = TextEditingController(text: '9876543210');
  final email =
      TextEditingController(text: 'admin@purewater.com');
  final gst =
      TextEditingController(text: '22ABCDE1234F1Z5');
  final invoicePrefix =
      TextEditingController(text: 'INV');
  final orderPrefix =
      TextEditingController(text: 'ORD');
  final address =
      TextEditingController(text: 'Raipur, Chhattisgarh');

  bool lowStock = true;
  bool followup = true;
  bool payment = true;
  bool newOrder = true;
  bool franchiseRenewal = true;
  final defaultGstController =
    TextEditingController(text: '18');

final lowStockPercentController =
    TextEditingController(text: '20');

String creditPeriod = '7 Days';
String currency = 'INR - Indian Rupee';

String lastBackup = 'No backup created yet';

final List<Map<String, dynamic>> backupHistory = [];

final List<Map<String, dynamic>> activityLogs = [
  {
    'id': 1,
    'title': 'Franchise updated',
    'description':
        'Rahul Sharma franchise information updated by Admin',
    'user': 'Admin User',
    'module': 'Franchises',
    'date': '10 Sep 2026',
    'time': '10:45 AM',
  },
  {
    'id': 2,
    'title': 'Payment recorded',
    'description':
        '₹5,000 payment recorded for INV-2002',
    'user': 'Accounts Team',
    'module': 'Billing',
    'date': '10 Sep 2026',
    'time': '10:23 AM',
  },
  {
    'id': 3,
    'title': 'Stock adjusted',
    'description':
        '500ml Water Bottle stock updated',
    'user': 'Admin User',
    'module': 'Inventory',
    'date': '10 Sep 2026',
    'time': '09:55 AM',
  },
  {
    'id': 4,
    'title': 'New lead added',
    'description':
        'New franchise enquiry received from Raipur',
    'user': 'Aman Verma',
    'module': 'Leads',
    'date': '10 Sep 2026',
    'time': '09:20 AM',
  },
];

  final List<Map<String, dynamic>> users = [
    {
      'id': 1,
      'name': 'Admin User',
      'email': 'admin@company.com',
      'role': 'Super Admin',
      'status': 'Active',
    },
    {
      'id': 2,
      'name': 'Aman Verma',
      'email': 'aman@company.com',
      'role': 'Sales Executive',
      'status': 'Active',
    },
    {
      'id': 3,
      'name': 'Accounts Team',
      'email': 'accounts@company.com',
      'role': 'Accounts',
      'status': 'Active',
    },
  ];

  final permissions = <String, Map<String, bool>>{
    'Dashboard': {
      'Admin': true,
      'Sales': true,
      'Accounts': true,
      'Inventory': true,
    },
    'Leads': {
      'Admin': true,
      'Sales': true,
      'Accounts': false,
      'Inventory': false,
    },
    'Follow-ups': {
      'Admin': true,
      'Sales': true,
      'Accounts': false,
      'Inventory': false,
    },
    'Franchises': {
      'Admin': true,
      'Sales': true,
      'Accounts': true,
      'Inventory': false,
    },
    'Inventory': {
      'Admin': true,
      'Sales': false,
      'Accounts': false,
      'Inventory': true,
    },
    'Products': {
      'Admin': true,
      'Sales': true,
      'Accounts': false,
      'Inventory': true,
    },
    'Suppliers': {
      'Admin': true,
      'Sales': false,
      'Accounts': true,
      'Inventory': true,
    },
    'Orders': {
      'Admin': true,
      'Sales': true,
      'Accounts': true,
      'Inventory': true,
    },
    'Billing': {
      'Admin': true,
      'Sales': false,
      'Accounts': true,
      'Inventory': false,
    },
    'Reports': {
      'Admin': true,
      'Sales': false,
      'Accounts': true,
      'Inventory': false,
    },
    'Settings': {
      'Admin': true,
      'Sales': false,
      'Accounts': false,
      'Inventory': false,
    },
  };

  @override
  void dispose() {
    businessName.dispose();
    phone.dispose();
    email.dispose();
    gst.dispose();
    invoicePrefix.dispose();
    orderPrefix.dispose();
    address.dispose();
    defaultGstController.dispose();
  lowStockPercentController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF5F7FB),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 1350),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Manage business configuration, users and permissions',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 22),

                    if (desktop)
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 235,
                            child: _menu(),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _content(true),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _mobileMenu(),
                          const SizedBox(height: 14),
                          _content(false),
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

  // =========================================================
  // SETTINGS MENU
  // =========================================================

  Widget _menu() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: _settingsCard(),
      child: Column(
        children: [
          _menuItem(
            'Business',
            Icons.business_outlined,
          ),
          _menuItem(
            'Users',
            Icons.people_outline,
          ),
          _menuItem(
            'Roles & Permissions',
            Icons.admin_panel_settings_outlined,
          ),
          _menuItem(
            'Notifications',
            Icons.notifications_none_rounded,
          ),
          _menuItem(
            'System Configuration',
            Icons.settings_outlined,
          ),
          _menuItem(
            'Backup & Logs',
            Icons.storage_outlined,
          ),
        ],
      ),
    );
  }

  Widget _mobileMenu() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          'Business',
          'Users',
          'Roles & Permissions',
          'Notifications',
          'System Configuration',
          'Backup & Logs',
        ].map((tab) {
          final selected = activeTab == tab;

          return Padding(
            padding:
                const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(tab),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  activeTab = tab;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _menuItem(
    String title,
    IconData icon,
  ) {
    final selected = activeTab == title;

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () {
        setState(() {
          activeTab = title;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE0F2FE)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? const Color(0xFF0284C7)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: selected
                      ? const Color(0xFF0284C7)
                      : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // CONTENT
  // =========================================================

  Widget _content(bool desktop) {
    switch (activeTab) {
      case 'Users':
        return _users();

      case 'Roles & Permissions':
        return _permissions();

      case 'Notifications':
        return _notifications();

      case 'System Configuration':
        return _systemConfiguration(desktop);

      case 'Backup & Logs':
        return _backup();

      default:
        return _business(desktop);
    }
  }

  // =========================================================
  // BUSINESS
  // =========================================================

  Widget _business(bool desktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _settingsCard(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Business Information',
            'Company and invoice configuration',
          ),

          const SizedBox(height: 20),

          _formGrid(
            desktop,
            [
              _input(
                businessName,
                'Business Name',
              ),
              _input(
                phone,
                'Phone',
              ),
              _input(
                email,
                'Email',
              ),
              _input(
                gst,
                'GST Number',
              ),
              _input(
                invoicePrefix,
                'Invoice Prefix',
              ),
              _input(
                orderPrefix,
                'Order Prefix',
              ),
            ],
          ),

          const SizedBox(height: 14),

          TextField(
            controller: address,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Business Address',
            ),
          ),

          const SizedBox(height: 20),

          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 150,
              height: 44,
              child: ElevatedButton.icon(
                style:
                    ElevatedButton.styleFrom(
                  minimumSize:
                      const Size(0, 44),
                  maximumSize:
                      const Size(150, 44),
                ),
                onPressed: () {
                  if (businessName.text
                      .trim()
                      .isEmpty) {
                    AppToast.error(
                      context,
                      'Business name is required.',
                      title: 'Validation Error',
                    );
                    return;
                  }

                  AppToast.success(
                    context,
                    'Business settings saved successfully.',
                    title: 'Settings Saved',
                  );
                },
                icon: const Icon(
                  Icons.save_outlined,
                  size: 18,
                ),
                label: const Text(
                  'Save Changes',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // USERS
  // =========================================================

  Widget _users() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            constraints.maxWidth >= 700;

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(
                desktop ? 20 : 16,
              ),
              decoration: _settingsCard(),
              child: desktop
                  ? Row(
                      children: [
                        Expanded(
                          child: _sectionTitle(
                            'User Management',
                            'Add admin and staff accounts',
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 145,
                          height: 44,
                          child:
                              ElevatedButton.icon(
                            style:
                                ElevatedButton
                                    .styleFrom(
                              minimumSize:
                                  const Size(
                                0,
                                44,
                              ),
                              maximumSize:
                                  const Size(
                                145,
                                44,
                              ),
                              backgroundColor:
                                  const Color(
                                0xFF0284C7,
                              ),
                              foregroundColor:
                                  Colors.white,
                              elevation: 0,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  10,
                                ),
                              ),
                            ),
                            onPressed: _addUser,
                            icon: const Icon(
                              Icons.add_rounded,
                              size: 19,
                            ),
                            label: const Text(
                              'Add User',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          'User Management',
                          'Add admin and staff accounts',
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child:
                              ElevatedButton.icon(
                            style:
                                ElevatedButton
                                    .styleFrom(
                              minimumSize:
                                  const Size(
                                0,
                                44,
                              ),
                            ),
                            onPressed: _addUser,
                            icon: const Icon(
                              Icons.add_rounded,
                            ),
                            label: const Text(
                              'Add User',
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              decoration: _settingsCard(),
              clipBehavior: Clip.antiAlias,
              child: desktop
                  ? _desktopUsersTable()
                  : _mobileUsersList(),
            ),
          ],
        );
      },
    );
  }

  Widget _desktopUsersTable() {
    return Column(
      children: [
        // HEADER
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          color: const Color(0xFFF8FAFC),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'USER',
                  style: _settingsHeaderStyle,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'ROLE',
                  style: _settingsHeaderStyle,
                ),
              ),
              Expanded(
                child: Text(
                  'STATUS',
                  style: _settingsHeaderStyle,
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  'ACTIONS',
                  style: _settingsHeaderStyle,
                ),
              ),
            ],
          ),
        ),

        ...users.map((user) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Color(0xFFF1F5F9),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment:
                            Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFE0F2FE,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),
                        child: Text(
                          _userInitials(
                            user['name']
                                .toString(),
                          ),
                          style:
                              const TextStyle(
                            color: Color(
                              0xFF0284C7,
                            ),
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              user['name']
                                  .toString(),
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    FontWeight
                                        .w700,
                                color: Color(
                                  0xFF111827,
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              user['email']
                                  .toString(),
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                fontSize: 11,
                                color: Color(
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

                Expanded(
                  flex: 2,
                  child: Text(
                    user['role'].toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w500,
                      color:
                          Color(0xFF334155),
                    ),
                  ),
                ),

                Expanded(
                  child: Align(
                    alignment:
                        Alignment.centerLeft,
                    child: _userStatusBadge(
                      user['status']
                          .toString(),
                    ),
                  ),
                ),

                SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: IconButton(
                          tooltip: 'Edit User',
                          padding:
                              EdgeInsets.zero,
                          onPressed: () {
                            _editUser(user);
                          },
                          icon: const Icon(
                            Icons
                                .edit_outlined,
                            size: 18,
                            color: Color(
                              0xFF475569,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: IconButton(
                          tooltip:
                              'Delete User',
                          padding:
                              EdgeInsets.zero,
                          onPressed: () {
                            _deleteUser(user);
                          },
                          icon: const Icon(
                            Icons
                                .delete_outline_rounded,
                            size: 18,
                            color: Color(
                              0xFFEF4444,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _mobileUsersList() {
    return Column(
      children: users.map((user) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFF1F5F9),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment:
                        Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFE0F2FE,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                    child: Text(
                      _userInitials(
                        user['name'].toString(),
                      ),
                      style: const TextStyle(
                        color:
                            Color(0xFF0284C7),
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['name'].toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user['email'].toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(
                              0xFF64748B,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _userStatusBadge(
                    user['status'].toString(),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  const SizedBox(
                    width: 75,
                    child: Text(
                      'Role',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      user['role'].toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () {
                      _editUser(user);
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      color:
                          Color(0xFF475569),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () {
                      _deleteUser(user);
                    },
                    icon: const Icon(
                      Icons
                          .delete_outline_rounded,
                      color:
                          Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _userStatusBadge(String status) {
    final active = status == 'Active';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFECFDF5)
            : const Color(0xFFF1F5F9),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: active
              ? const Color(0xFF15803D)
              : const Color(0xFF64748B),
        ),
      ),
    );
  }

  String _userInitials(String name) {
    final parts = name
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'U';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'
        .toUpperCase();
  }

  // =========================================================
  // ROLES & PERMISSIONS
  // =========================================================

  Widget _permissions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _settingsCard(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (_, constraints) {
              final wide =
                  constraints.maxWidth >= 550;

              if (!wide) {
                return Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(
                      'Roles & Permissions',
                      'Control module access for different users',
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 140,
                      height: 40,
                      child: OutlinedButton(
                        onPressed:
                            _resetPermissions,
                        child: const Text(
                          'Reset Defaults',
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _sectionTitle(
                      'Roles & Permissions',
                      'Control module access for different users',
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    height: 40,
                    child: OutlinedButton(
                      style:
                          OutlinedButton.styleFrom(
                        minimumSize:
                            const Size(0, 40),
                        maximumSize:
                            const Size(140, 40),
                      ),
                      onPressed:
                          _resetPermissions,
                      child: const Text(
                        'Reset Defaults',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 22),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 720,
              child: Column(
                children: [
                  const Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'MODULE',
                          style:
                              _settingsHeaderStyle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'ADMIN',
                          style:
                              _settingsHeaderStyle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'SALES',
                          style:
                              _settingsHeaderStyle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'ACCOUNTS',
                          style:
                              _settingsHeaderStyle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'INVENTORY',
                          style:
                              _settingsHeaderStyle,
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 24),

                  ...permissions.entries.map(
                    (entry) {
                      return Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 5,
                        ),
                        decoration:
                            const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(
                                0xFFF8FAFC,
                              ),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                entry.key,
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            _permissionCheck(
                              entry.key,
                              'Admin',
                            ),
                            _permissionCheck(
                              entry.key,
                              'Sales',
                            ),
                            _permissionCheck(
                              entry.key,
                              'Accounts',
                            ),
                            _permissionCheck(
                              entry.key,
                              'Inventory',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetPermissions() {
    setState(() {
      permissions['Dashboard'] = {
        'Admin': true,
        'Sales': true,
        'Accounts': true,
        'Inventory': true,
      };

      permissions['Leads'] = {
        'Admin': true,
        'Sales': true,
        'Accounts': false,
        'Inventory': false,
      };

      permissions['Follow-ups'] = {
        'Admin': true,
        'Sales': true,
        'Accounts': false,
        'Inventory': false,
      };

      permissions['Franchises'] = {
        'Admin': true,
        'Sales': true,
        'Accounts': true,
        'Inventory': false,
      };

      permissions['Inventory'] = {
        'Admin': true,
        'Sales': false,
        'Accounts': false,
        'Inventory': true,
      };

      permissions['Products'] = {
        'Admin': true,
        'Sales': true,
        'Accounts': false,
        'Inventory': true,
      };

      permissions['Suppliers'] = {
        'Admin': true,
        'Sales': false,
        'Accounts': true,
        'Inventory': true,
      };

      permissions['Orders'] = {
        'Admin': true,
        'Sales': true,
        'Accounts': true,
        'Inventory': true,
      };

      permissions['Billing'] = {
        'Admin': true,
        'Sales': false,
        'Accounts': true,
        'Inventory': false,
      };

      permissions['Reports'] = {
        'Admin': true,
        'Sales': false,
        'Accounts': true,
        'Inventory': false,
      };

      permissions['Settings'] = {
        'Admin': true,
        'Sales': false,
        'Accounts': false,
        'Inventory': false,
      };
    });

    AppToast.success(
      context,
      'Default permissions restored successfully.',
      title: 'Permissions Reset',
    );
  }

  Widget _permissionCheck(
    String module,
    String role,
  ) {
    return Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Checkbox(
          value:
              permissions[module]?[role] ??
                  false,
          onChanged: (value) {
            setState(() {
              permissions[module]?[role] =
                  value ?? false;
            });
          },
        ),
      ),
    );
  }

  // =========================================================
  // NOTIFICATIONS
  // =========================================================

  Widget _notifications() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _settingsCard(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Notification Settings',
            'Configure system alerts',
          ),

          const SizedBox(height: 15),

          _toggle(
            'Low Stock Alert',
            'Notify when inventory reaches minimum level',
            lowStock,
            (value) {
              setState(() {
                lowStock = value;
              });
            },
          ),

          _toggle(
            'Follow-up Reminder',
            'Reminder for pending lead follow-ups',
            followup,
            (value) {
              setState(() {
                followup = value;
              });
            },
          ),

          _toggle(
            'Payment Reminder',
            'Alert for unpaid and overdue invoices',
            payment,
            (value) {
              setState(() {
                payment = value;
              });
            },
          ),

          _toggle(
            'New Order Alert',
            'Notify admin when franchise places an order',
            newOrder,
            (value) {
              setState(() {
                newOrder = value;
              });
            },
          ),

          _toggle(
            'Franchise Renewal',
            'Notify before agreement renewal date',
            franchiseRenewal,
            (value) {
              setState(() {
                franchiseRenewal = value;
              });
            },
          ),

          const SizedBox(height: 18),

          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 165,
              height: 44,
              child: ElevatedButton.icon(
                style:
                    ElevatedButton.styleFrom(
                  minimumSize:
                      const Size(0, 44),
                  maximumSize:
                      const Size(165, 44),
                ),
                onPressed: () {
                  AppToast.success(
                    context,
                    'Notification preferences saved successfully.',
                    title:
                        'Notifications Saved',
                  );
                },
                icon: const Icon(
                  Icons.save_outlined,
                  size: 18,
                ),
                label: const Text(
                  'Save Preferences',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SYSTEM CONFIGURATION
  // =========================================================

Widget _systemConfiguration(
  bool desktop,
) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: _settingsCard(),
    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'System Configuration',
          'Manage default business rules and application settings',
        ),

        const SizedBox(height: 20),

        _formGrid(
          desktop,
          [
            TextFormField(
              controller:
                  defaultGstController,
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
              decoration:
                  const InputDecoration(
                labelText:
                    'Default GST %',
                prefixIcon: Icon(
                  Icons.percent,
                ),
              ),
            ),

            DropdownButtonFormField<
                String>(
              value: creditPeriod,
              isExpanded: true,
              decoration:
                  const InputDecoration(
                labelText:
                    'Default Credit Period',
                prefixIcon: Icon(
                  Icons
                      .credit_score_outlined,
                ),
              ),
              items: const [
                'Immediate',
                '7 Days',
                '15 Days',
                '30 Days',
                '45 Days',
                '60 Days',
              ].map(
                (value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  );
                },
              ).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  creditPeriod = value;
                });
              },
            ),

            TextFormField(
              controller:
                  lowStockPercentController,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                labelText:
                    'Low Stock Alert %',
                prefixIcon: Icon(
                  Icons
                      .warning_amber_outlined,
                ),
              ),
            ),

            DropdownButtonFormField<
                String>(
              value: currency,
              isExpanded: true,
              decoration:
                  const InputDecoration(
                labelText: 'Currency',
                prefixIcon: Icon(
                  Icons
                      .currency_rupee,
                ),
              ),
              items: const [
                'INR - Indian Rupee',
              ].map(
                (value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  );
                },
              ).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  currency = value;
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                const Color(0xFFF8FAFC),
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color:
                  const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Configuration',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              _configurationLine(
                'Default GST',
                '${defaultGstController.text}%',
              ),

              _configurationLine(
                'Credit Period',
                creditPeriod,
              ),

              _configurationLine(
                'Low Stock Alert',
                '${lowStockPercentController.text}%',
              ),

              _configurationLine(
                'Currency',
                currency,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: 190,
          height: 44,
          child: ElevatedButton.icon(
            style:
                ElevatedButton.styleFrom(
              minimumSize:
                  const Size(0, 44),
              maximumSize:
                  const Size(190, 44),
            ),
            onPressed:
                _saveSystemConfiguration,
            icon: const Icon(
              Icons.save_outlined,
              size: 18,
            ),
            label: const Text(
              'Save Configuration',
            ),
          ),
        ),
      ],
    ),
  );
}
void _saveSystemConfiguration() {
  final gstValue =
      double.tryParse(
    defaultGstController.text.trim(),
  );

  final stockValue =
      int.tryParse(
    lowStockPercentController.text
        .trim(),
  );

  if (gstValue == null ||
      gstValue < 0 ||
      gstValue > 100) {
    AppToast.error(
      context,
      'Enter a valid GST percentage.',
      title: 'Invalid GST',
    );
    return;
  }

  if (stockValue == null ||
      stockValue < 0 ||
      stockValue > 100) {
    AppToast.error(
      context,
      'Enter valid low stock percentage.',
      title: 'Invalid Stock Alert',
    );
    return;
  }

  setState(() {
    activityLogs.insert(
      0,
      {
        'id': DateTime.now()
            .millisecondsSinceEpoch,
        'title':
            'System configuration updated',
        'description':
            'GST ${gstValue.toStringAsFixed(gstValue.truncateToDouble() == gstValue ? 0 : 1)}%, Credit $creditPeriod, Low Stock $stockValue%',
        'user': 'Admin User',
        'module':
            'System Configuration',
        'date':
            _settingsDate(),
        'time':
            _settingsTime(),
      },
    );
  });

  AppToast.success(
    context,
    'System configuration saved successfully.',
    title: 'Configuration Saved',
  );
}
Widget _configurationLine(
  String label,
  String value,
) {
  return Padding(
    padding:
        const EdgeInsets.only(
      bottom: 8,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style:
                const TextStyle(
              fontSize: 11,
              color:
                  Color(
                0xFF64748B,
              ),
            ),
          ),
        ),
        Text(
          value,
          style:
              const TextStyle(
            fontSize: 11,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

  // =========================================================
  // BACKUP & LOGS
  // =========================================================

  Widget _backup() {
  return Column(
    children: [
      _backupManagementCard(),

      const SizedBox(height: 18),

      _activityLogCard(),
    ],
  );
}
Widget _backupManagementCard() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: _settingsCard(),
    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Backup Management',
          'Create and manage system backup snapshots',
        ),

        const SizedBox(height: 18),

        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                const Color(0xFFF8FAFC),
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color:
                  const Color(0xFFE2E8F0),
            ),
          ),
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
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: const Icon(
                  Icons
                      .cloud_done_outlined,
                  color:
                      Color(
                    0xFF0284C7,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Text(
                      'Last Backup',
                      style:
                          TextStyle(
                        fontSize: 11,
                        color:
                            Color(
                          0xFF64748B,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      lastBackup,
                      style:
                          const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 165,
              height: 44,
              child:
                  ElevatedButton.icon(
                style:
                    ElevatedButton
                        .styleFrom(
                  minimumSize:
                      const Size(
                    0,
                    44,
                  ),
                  maximumSize:
                      const Size(
                    165,
                    44,
                  ),
                ),
                onPressed:
                    _createBackup,
                icon: const Icon(
                  Icons
                      .backup_outlined,
                  size: 18,
                ),
                label:
                    const Text(
                  'Create Backup',
                ),
              ),
            ),

            if (backupHistory
                .isNotEmpty)
              SizedBox(
                width: 160,
                height: 44,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _viewBackupHistory,
                  icon: const Icon(
                    Icons.history,
                    size: 18,
                  ),
                  label:
                      const Text(
                    'Backup History',
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
Future<void> _createBackup() async {
  final confirmed =
      await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text(
          'Create System Backup',
        ),
        content: const Text(
          'Create a new backup snapshot of current application data and configuration?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
                false,
              );
            },
            child:
                const Text('Cancel'),
          ),
          SizedBox(
            width: 120,
            height: 42,
            child:
                ElevatedButton.icon(
              style:
                  ElevatedButton
                      .styleFrom(
                minimumSize:
                    const Size(
                  0,
                  42,
                ),
                maximumSize:
                    const Size(
                  120,
                  42,
                ),
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons
                    .backup_outlined,
                size: 16,
              ),
              label:
                  const Text(
                'Backup',
              ),
            ),
          ),
        ],
      );
    },
  );

  if (confirmed != true) {
    return;
  }

  final now =
      DateTime.now();

  final backupId =
      'BKP-${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}'
      '-${now.millisecondsSinceEpoch.toString().substring(7)}';

  final date =
      _settingsDate();

  final time =
      _settingsTime();

  setState(() {
    lastBackup = '$date • $time';

    backupHistory.insert(
      0,
      {
        'id': backupId,
        'date': date,
        'time': time,
        'createdBy':
            'Admin User',
        'status':
            'Completed',
      },
    );

    activityLogs.insert(
      0,
      {
        'id': DateTime.now()
            .millisecondsSinceEpoch,
        'title':
            'System backup created',
        'description':
            '$backupId backup snapshot created successfully.',
        'user':
            'Admin User',
        'module':
            'Backup',
        'date': date,
        'time': time,
      },
    );
  });

  if (!mounted) return;

  AppToast.success(
    context,
    'Backup snapshot created successfully.',
    title: 'Backup Created',
  );
}
void _viewBackupHistory() {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title:
            const Text(
          'Backup History',
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
          ),
          child:
              SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children:
                  backupHistory.map(
                (backup) {
                  return Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets
                            .all(
                      14,
                    ),
                    margin:
                        const EdgeInsets
                            .only(
                      bottom: 10,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFF8FAFC,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                      border:
                          Border.all(
                        color:
                            const Color(
                          0xFFE2E8F0,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons
                              .storage_outlined,
                          color:
                              Color(
                            0xFF0284C7,
                          ),
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                backup['id']
                                    .toString(),
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                '${backup['date']} • ${backup['time']} • ${backup['createdBy']}',
                                style:
                                    const TextStyle(
                                  fontSize:
                                      10,
                                  color:
                                      Color(
                                    0xFF64748B,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                8,
                            vertical:
                                5,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFECFDF5,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                          ),
                          child: Text(
                            backup['status']
                                .toString(),
                            style:
                                const TextStyle(
                              fontSize: 9,
                              fontWeight:
                                  FontWeight
                                      .w700,
                              color:
                                  Color(
                                0xFF15803D,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ).toList(),
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
            child:
                const Text('Close'),
          ),
        ],
      );
    },
  );
}
Widget _activityLogCard() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: _settingsCard(),
    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionTitle(
                'Activity Logs',
                'Recent admin and system activities',
              ),
            ),

            Text(
              '${activityLogs.length} Activities',
              style:
                  const TextStyle(
                fontSize: 10,
                color:
                    Color(
                  0xFF64748B,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        if (activityLogs.isEmpty)
          const Padding(
            padding:
                EdgeInsets.all(30),
            child: Center(
              child: Text(
                'No activity logs available.',
                style:
                    TextStyle(
                  color:
                      Color(
                    0xFF64748B,
                  ),
                ),
              ),
            ),
          )
        else
          ...activityLogs.map(
            (activity) {
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 13,
                ),
                decoration:
                    const BoxDecoration(
                  border: Border(
                    bottom:
                        BorderSide(
                      color:
                          Color(
                        0xFFF1F5F9,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFE0F2FE,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .history_outlined,
                        size: 18,
                        color:
                            Color(
                          0xFF0284C7,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            activity[
                                    'title']
                                .toString(),
                            style:
                                const TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),

                          const SizedBox(
                            height: 3,
                          ),

                          Text(
                            activity[
                                    'description']
                                .toString(),
                            style:
                                const TextStyle(
                              fontSize: 10,
                              color:
                                  Color(
                                0xFF64748B,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          Wrap(
                            spacing: 8,
                            children: [
                              Text(
                                activity[
                                        'user']
                                    .toString(),
                                style:
                                    const TextStyle(
                                  fontSize:
                                      9,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                  color:
                                      Color(
                                    0xFF0284C7,
                                  ),
                                ),
                              ),

                              Text(
                                activity[
                                        'module']
                                    .toString(),
                                style:
                                    const TextStyle(
                                  fontSize:
                                      9,
                                  color:
                                      Color(
                                    0xFF64748B,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .end,
                      children: [
                        Text(
                          activity['date']
                              .toString(),
                          style:
                              const TextStyle(
                            fontSize: 9,
                            color:
                                Color(
                              0xFF64748B,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          activity['time']
                              .toString(),
                          style:
                              const TextStyle(
                            fontSize: 9,
                            color:
                                Color(
                              0xFF94A3B8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    ),
  );
}
String _settingsDate() {
  final now = DateTime.now();

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${now.day.toString().padLeft(2, '0')} '
      '${months[now.month - 1]} '
      '${now.year}';
}

String _settingsTime() {
  final now = DateTime.now();

  var hour = now.hour;

  final period =
      hour >= 12 ? 'PM' : 'AM';

  if (hour == 0) {
    hour = 12;
  } else if (hour > 12) {
    hour -= 12;
  }

  return '${hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')} '
      '$period';
}
  // =========================================================
  // ADD / EDIT USER
  // =========================================================

  Future<void> _addUser() async {
    await _userForm();
  }

  Future<void> _editUser(
    Map<String, dynamic> user,
  ) async {
    await _userForm(user: user);
  }

  Future<void> _userForm({
    Map<String, dynamic>? user,
  }) async {
    final editing = user != null;

    final name = TextEditingController(
      text: user?['name'] ?? '',
    );

    final emailController =
        TextEditingController(
      text: user?['email'] ?? '',
    );

    String role =
        user?['role'] ?? 'Sales Executive';

    String status =
        user?['status'] ?? 'Active';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, updateDialog) {
            return Dialog(
              backgroundColor:
                  Colors.transparent,
              insetPadding:
                  const EdgeInsets.all(16),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9 > 520 ? 520 : MediaQuery.of(context).size.width * 0.9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(
                        alpha: 0.10,
                      ),
                      blurRadius: 30,
                      offset:
                          const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    // HEADER
                    Padding(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        22,
                        20,
                        14,
                        18,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration:
                                BoxDecoration(
                              color: const Color(
                                0xFFE0F2FE,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                11,
                              ),
                            ),
                            child: Icon(
                              editing
                                  ? Icons
                                      .manage_accounts_outlined
                                  : Icons
                                      .person_add_alt_1_outlined,
                              color:
                                  const Color(
                                0xFF0284C7,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 12,
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  editing
                                      ? 'Edit User'
                                      : 'Add New User',
                                  style:
                                      const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                  ),
                                ),
                                const SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  editing
                                      ? 'Update staff account information'
                                      : 'Create a new admin or staff account',
                                  style:
                                      const TextStyle(
                                    color: Color(
                                      0xFF64748B,
                                    ),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            onPressed: () {
                              Navigator.pop(
                                dialogContext,
                              );
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    Flexible(
                      child:
                          SingleChildScrollView(
                        padding:
                            const EdgeInsets
                                .all(22),
                        child: Column(
                          children: [
                            _dialogInput(
                              controller: name,
                              label:
                                  'Full Name *',
                              hint:
                                  'Enter full name',
                              icon: Icons
                                  .person_outline,
                            ),

                            const SizedBox(
                              height: 16,
                            ),

                            _dialogInput(
                              controller:
                                  emailController,
                              label:
                                  'Email Address *',
                              hint:
                                  'name@company.com',
                              icon: Icons
                                  .email_outlined,
                              keyboardType:
                                  TextInputType
                                      .emailAddress,
                            ),

                            const SizedBox(
                              height: 16,
                            ),

                            _dialogDropdown(
                              label: 'Role',
                              value: role,
                              icon: Icons
                                  .admin_panel_settings_outlined,
                              items: const [
                                'Sales Executive',
                                'Accounts',
                                'Inventory Manager',
                                'Admin',
                                'Super Admin',
                              ],
                              onChanged:
                                  (value) {
                                if (value ==
                                    null) {
                                  return;
                                }

                                updateDialog(
                                  () {
                                    role =
                                        value;
                                  },
                                );
                              },
                            ),

                            const SizedBox(
                              height: 16,
                            ),

                            _dialogDropdown(
                              label: 'Status',
                              value: status,
                              icon: Icons
                                  .verified_user_outlined,
                              items: const [
                                'Active',
                                'Inactive',
                              ],
                              onChanged:
                                  (value) {
                                if (value ==
                                    null) {
                                  return;
                                }

                                updateDialog(
                                  () {
                                    status =
                                        value;
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    Padding(
                      padding:
                          const EdgeInsets
                              .all(18),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 90,
                            height: 44,
                            child: TextButton(
                              style: TextButton
                                  .styleFrom(
                                minimumSize:
                                    const Size(
                                  0,
                                  44,
                                ),
                                maximumSize:
                                    const Size(
                                  90,
                                  44,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(
                                  dialogContext,
                                );
                              },
                              child: const Text(
                                'Cancel',
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          SizedBox(
                            width: editing
                                ? 130
                                : 115,
                            height: 44,
                            child:
                                ElevatedButton(
                              style:
                                  ElevatedButton
                                      .styleFrom(
                                minimumSize:
                                    const Size(
                                  0,
                                  44,
                                ),
                                maximumSize:
                                    Size(
                                  editing
                                      ? 130
                                      : 115,
                                  44,
                                ),
                              ),
                              onPressed: () {
                                final userName =
                                    name.text
                                        .trim();

                                final userEmail =
                                    emailController
                                        .text
                                        .trim();

                                if (userName
                                    .isEmpty) {
                                  AppToast
                                      .error(
                                    context,
                                    'Please enter user name.',
                                    title:
                                        'Name Required',
                                  );
                                  return;
                                }

                                if (userEmail
                                        .isEmpty ||
                                    !userEmail
                                        .contains(
                                      '@',
                                    )) {
                                  AppToast
                                      .error(
                                    context,
                                    'Please enter a valid email address.',
                                    title:
                                        'Invalid Email',
                                  );
                                  return;
                                }

                                final data = {
                                  'id': user?[
                                          'id'] ??
                                      DateTime
                                          .now()
                                          .millisecondsSinceEpoch,
                                  'name':
                                      userName,
                                  'email':
                                      userEmail,
                                  'role': role,
                                  'status':
                                      status,
                                };

                                setState(() {
                                  if (!editing) {
                                    users.insert(
                                      0,
                                      data,
                                    );
                                  } else {
                                    final index =
                                        users
                                            .indexWhere(
                                      (item) =>
                                          item['id'] ==
                                          user[
                                              'id'],
                                    );

                                    if (index !=
                                        -1) {
                                      users[index] =
                                          data;
                                    }
                                  }
                                });

                                Navigator.pop(
                                  dialogContext,
                                );

                                AppToast.success(
                                  context,
                                  editing
                                      ? '$userName updated successfully.'
                                      : '$userName added successfully.',
                                  title: editing
                                      ? 'User Updated'
                                      : 'User Added',
                                );
                              },
                              child: Text(
                                editing
                                    ? 'Update User'
                                    : 'Add User',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    name.dispose();
    emailController.dispose();
  }

  Future<void> _deleteUser(
    Map<String, dynamic> user,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete User',
          ),
          content: Text(
            'Are you sure you want to delete ${user['name']}?',
          ),
          actions: [
            SizedBox(
              width: 90,
              height: 42,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text(
                  'Cancel',
                ),
              ),
            ),
            SizedBox(
              width: 95,
              height: 42,
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                  minimumSize:
                      const Size(0, 42),
                  maximumSize:
                      const Size(95, 42),
                  backgroundColor:
                      const Color(
                    0xFFEF4444,
                  ),
                  foregroundColor:
                      Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                child: const Text(
                  'Delete',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final userName =
        user['name'].toString();

    setState(() {
      users.removeWhere(
        (item) =>
            item['id'] == user['id'],
      );
    });

    if (!mounted) return;

    AppToast.success(
      context,
      '$userName deleted successfully.',
      title: 'User Deleted',
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _input(
    TextEditingController controller,
    String label,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
      ),
    );
  }

  Widget _formGrid(
    bool desktop,
    List<Widget> fields,
  ) {
    if (!desktop) {
      return Column(
        children: fields.map((field) {
          return Padding(
            padding:
                const EdgeInsets.only(
              bottom: 12,
            ),
            child: field,
          );
        }).toList(),
      );
    }

    return LayoutBuilder(
      builder: (_, constraints) {
        final width =
            (constraints.maxWidth - 14) /
                2;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: fields.map((field) {
            return SizedBox(
              width: width,
              child: field,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _toggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> changed,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 13,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color:
                        Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: changed,
          ),
        ],
      ),
    );
  }

  Widget _dialogInput({
    required TextEditingController
        controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(
              icon,
              size: 19,
              color: const Color(
                0xFF64748B,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(10),
              borderSide:
                  const BorderSide(
                color: Color(
                  0xFFE2E8F0,
                ),
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(10),
              borderSide:
                  const BorderSide(
                color: Color(
                  0xFF0284C7,
                ),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dialogDropdown({
    required String label,
    required String value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?>
        onChanged,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              size: 19,
              color: const Color(
                0xFF64748B,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(10),
              borderSide:
                  const BorderSide(
                color: Color(
                  0xFFE2E8F0,
                ),
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(10),
              borderSide:
                  const BorderSide(
                color: Color(
                  0xFF0284C7,
                ),
                width: 1.4,
              ),
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ===========================================================
// CARD DECORATION
// ===========================================================

BoxDecoration _settingsCard() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius:
        BorderRadius.circular(14),
    border: Border.all(
      color: const Color(0xFFE5E7EB),
    ),
  );
}

const TextStyle _settingsHeaderStyle =
    TextStyle(
  fontSize: 9.5,
  fontWeight: FontWeight.w700,
  color: Color(0xFF64748B),
  letterSpacing: 0.4,
);