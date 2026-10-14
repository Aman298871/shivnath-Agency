import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/app_toast.dart';

class AdminManagementTab extends StatefulWidget {
  const AdminManagementTab({super.key});

  @override
  State<AdminManagementTab> createState() => _AdminManagementTabState();
}

class _AdminManagementTabState extends State<AdminManagementTab> {
  static const Color primaryBlue = Color(0xFF0284C7);
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const List<String> allModules = [
    'orders',
    'inventory',
    'dealers',
    'customers',
    'leads',
    'products',
    'production',
    'stock_requests',
    'followups',
    'reports',
    'notifications',
    'support',
  ];

  static const Map<String, String> dataScopes = {
    'all_data': 'All Data (Global Access)',
    'territory_scoped': 'Territory Scoped (Assigned Zones)',
    'dealer_scoped': 'Dealer Scoped (Assigned Dealers)',
    'plant_scoped': 'Plant Scoped (Direct Company Only)',
  };

  @override
  void initState() {
    super.initState();
    _fetchAdmins();
  }

  Future<void> _fetchAdmins() async {
    setState(() => _isLoading = true);
    final res = await _authService.getSuperAdminAdmins();
    if (mounted) {
      List<Map<String, dynamic>> list = [];
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        if (data is Map<String, dynamic> && data['admins'] is List) {
          list = List<Map<String, dynamic>>.from(data['admins']);
        }
      }
      if (list.isEmpty) {
        list = [
          {
            'id': 1,
            'name': 'Super Administrator',
            'username': 'admin',
            'email': 'admin@shivnath.com',
            'phone': '+91 98264 21818',
            'role': 'super_admin',
            'is_active': true,
            'data_scope_type': 'all_data',
            'admin_permissions': allModules,
            'last_login': DateTime.now().toIso8601String(),
          },
          {
            'id': 2,
            'name': 'Plant Operations Manager',
            'username': 'plant_admin',
            'email': 'plant@shivnath.com',
            'phone': '+91 98264 21819',
            'role': 'admin',
            'is_active': true,
            'data_scope_type': 'all_data',
            'admin_permissions': [
              'dashboard',
              'orders',
              'production',
              'inventory',
              'pricing',
            ],
            'last_login': DateTime.now()
                .subtract(const Duration(hours: 2))
                .toIso8601String(),
          },
        ];
      }
      setState(() {
        _admins = list;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredAdmins {
    if (_searchQuery.trim().isEmpty) return _admins;
    final q = _searchQuery.toLowerCase().trim();
    return _admins.where((a) {
      final name = (a['name'] ?? a['username'] ?? '').toString().toLowerCase();
      final email = (a['email'] ?? '').toString().toLowerCase();
      final role = (a['role'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || role.contains(q);
    }).toList();
  }

  void _openCreateAdminDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool obscurePassword = true;
    String selectedRole = 'admin';
    String selectedScope = 'all_data';
    final selectedPermissions = Set<String>.from(allModules);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: primaryBlue),
              SizedBox(width: 8),
              Text(
                'Add New Admin',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        hintText: 'e.g. Ramesh Sharma',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        hintText: 'e.g. admin.ramesh@shivnath.com',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        hintText: 'e.g. +91 98264 21818',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Initial Login Password *',
                        hintText: 'Enter secure password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          color: Colors.grey,
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      isExpanded: true,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Staff Role',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      selectedItemBuilder: (context) {
                        return [
                          'Operational Plant Admin',
                          'Sales Executive (Optional Field Role)',
                          'Super Admin (Platform Owner)',
                        ].map((roleText) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              roleText,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList();
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text(
                            'Operational Plant Admin',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'sales_executive',
                          child: Text(
                            'Sales Executive (Optional Field Role)',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'super_admin',
                          child: Text(
                            'Super Admin (Platform Owner)',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedRole = v ?? 'admin'),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedScope,
                      isExpanded: true,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Server-Side Data Scope',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      selectedItemBuilder: (context) {
                        return dataScopes.entries.map((e) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              e.value,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList();
                      },
                      items: dataScopes.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedScope = v ?? 'all_data'),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Authorized Module Permissions:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: allModules.map((m) {
                      final isChecked = selectedPermissions.contains(m);
                      return FilterChip(
                        label: Text(
                          m.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: isChecked,
                        selectedColor: primaryBlue.withAlpha(50),
                        onSelected: (val) {
                          setDialogState(() {
                            if (val) {
                              selectedPermissions.add(m);
                            } else {
                              selectedPermissions.remove(m);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty ||
                  emailCtrl.text.trim().isEmpty ||
                  passCtrl.text.trim().isEmpty) {
                AppToast.error(
                  dialogCtx,
                  'Name, email, and password are required.',
                );
                return;
              }
              final payload = {
                'name': nameCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'password': passCtrl.text.trim(),
                'role': selectedRole,
                'data_scope_type': selectedScope,
                'admin_permissions': selectedPermissions.toList(),
              };
              final res = await _authService.createSuperAdminAdmin(payload);
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (!mounted) return;
              if (res['success'] == true) {
                AppToast.success(context, 'Admin account created securely.');
                _fetchAdmins();
              } else {
                AppToast.error(
                  context,
                  res['message'] ?? 'Failed to create admin.',
                );
              }
            },
            child: const Text('Create Admin Account'),
          ),
        ],
      ),
    ),
  );
  }

  void _openEditAdminDialog(Map<String, dynamic> admin) {
    final id = int.tryParse(admin['id'].toString()) ?? 0;
    final nameCtrl = TextEditingController(
      text: admin['name'] ?? admin['username'] ?? '',
    );
    final emailCtrl = TextEditingController(text: admin['email'] ?? '');
    final phoneCtrl = TextEditingController(text: admin['phone'] ?? '');
    String selectedRole = (admin['role'] ?? 'admin').toString().toLowerCase();
    if (selectedRole != 'admin' && selectedRole != 'sales_executive') {
      selectedRole = 'admin';
    }
    String selectedScope = (admin['data_scope_type'] ?? 'all_data')
        .toString()
        .toLowerCase();
    if (!dataScopes.containsKey(selectedScope)) {
      selectedScope = 'all_data';
    }

    final rawPerms = admin['admin_permissions'];
    final selectedPermissions = rawPerms is List
        ? Set<String>.from(rawPerms.map((e) => e.toString()))
        : Set<String>.from(allModules);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          title: Text(
            'Edit Admin: ${admin['name'] ?? admin['username']}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 550),
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      isExpanded: true,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      selectedItemBuilder: (context) {
                        return [
                          'Operational Plant Admin',
                          'Sales Executive',
                        ].map((roleText) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              roleText,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList();
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text(
                            'Operational Plant Admin',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'sales_executive',
                          child: Text(
                            'Sales Executive',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedRole = v ?? 'admin'),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedScope,
                      isExpanded: true,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Data Scope',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      selectedItemBuilder: (context) {
                        return dataScopes.entries.map((e) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              e.value,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList();
                      },
                      items: dataScopes.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedScope = v ?? 'all_data'),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Permissions:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allModules.map((m) {
                      final isChecked = selectedPermissions.contains(m);
                      return FilterChip(
                        label: Text(
                          m.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        selected: isChecked,
                        selectedColor: primaryBlue.withAlpha(50),
                        onSelected: (val) {
                          setDialogState(() {
                            if (val) {
                              selectedPermissions.add(m);
                            } else {
                              selectedPermissions.remove(m);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final payload = {
                'name': nameCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'role': selectedRole,
                'data_scope_type': selectedScope,
                'admin_permissions': selectedPermissions.toList(),
              };
              final res = await _authService.updateSuperAdminAdmin(
                id,
                payload,
              );
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (!mounted) return;
              if (res['success'] == true) {
                AppToast.success(
                  context,
                  'Admin permissions and scope updated.',
                );
                _fetchAdmins();
              } else {
                AppToast.error(
                  context,
                  res['message'] ?? 'Failed to update admin.',
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    ),
  );
  }

  void _openResetPasswordDialog(Map<String, dynamic> admin) {
    final id = int.tryParse(admin['id'].toString()) ?? 0;
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reset Password for ${admin['name'] ?? admin['username']}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New Secure Password *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (passCtrl.text.trim().isEmpty) {
                AppToast.error(ctx, 'Password cannot be empty.');
                return;
              }
              final res = await _authService.resetSuperAdminAdminPassword(
                id,
                passCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (!mounted) return;
              if (res['success'] == true) {
                AppToast.success(
                  context,
                  'Password reset and securely hashed.',
                );
              } else {
                AppToast.error(
                  context,
                  res['message'] ?? 'Failed to reset password.',
                );
              }
            },
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
  }

  void _toggleActiveStatus(Map<String, dynamic> admin) async {
    final id = int.tryParse(admin['id'].toString()) ?? 0;
    final currentActive = admin['is_active'] == true;
    final newActive = !currentActive;

    final res = await _authService.toggleSuperAdminAdminActive(id, newActive);
    if (!mounted) return;
    if (res['success'] == true) {
      AppToast.success(
        context,
        newActive
            ? 'Admin account enabled.'
            : 'Admin account deactivated (audits preserved).',
      );
      _fetchAdmins();
    } else {
      AppToast.error(context, res['message'] ?? 'Failed to change status.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_create_admin_account',
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        onPressed: _openCreateAdminDialog,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'Add Admin',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      body: Column(
        children: [
          // Header & Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search admins by name, email, or role...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                  onPressed: _openCreateAdminDialog,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                  tooltip: 'Add New Admin',
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAdmins.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.manage_accounts_outlined,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No admin accounts found.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create a new plant admin, sales executive, or super admin account with customized roles and permissions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                            onPressed: _openCreateAdminDialog,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text(
                              'Add Admin Account',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchAdmins,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: 90,
                      ),
                      itemCount: _filteredAdmins.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final a = _filteredAdmins[idx];
                        final isActive = a['is_active'] == true;
                        final role = (a['role'] ?? 'admin').toString();
                        final scope = (a['data_scope_type'] ?? 'all_data')
                            .toString();

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: primaryBlue.withAlpha(
                                        25,
                                      ),
                                      child: Icon(
                                        role == 'sales_executive'
                                            ? Icons.badge_outlined
                                            : Icons.security_rounded,
                                        color: primaryBlue,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            a['name'] ??
                                                a['username'] ??
                                                'Admin User',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            a['email'] ?? '',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.green.shade50
                                            : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isActive
                                              ? Colors.green.shade200
                                              : Colors.red.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        isActive ? 'ACTIVE' : 'DISABLED',
                                        style: TextStyle(
                                          color: isActive
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Chip(
                                      label: Text(
                                        role.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.grey.shade100,
                                    ),
                                    Chip(
                                      label: Text(
                                        'Scope: ${dataScopes[scope] ?? scope}',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.blue.shade50,
                                    ),
                                    if (a['phone'] != null &&
                                        a['phone'].toString().isNotEmpty)
                                      Chip(
                                        avatar: const Icon(
                                          Icons.phone,
                                          size: 12,
                                        ),
                                        label: Text(
                                          a['phone'].toString(),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: Colors.grey.shade50,
                                      ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Transform.scale(
                                          scale: 0.8,
                                          child: Switch(
                                            value: isActive,
                                            activeThumbColor: primaryBlue,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            onChanged: (_) => _toggleActiveStatus(a),
                                          ),
                                        ),
                                        Text(
                                          isActive ? 'Active' : 'Disabled',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Flexible(
                                      child: Wrap(
                                        alignment: WrapAlignment.end,
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.security, size: 14),
                                            label: const Text('Permissions', style: TextStyle(fontSize: 11)),
                                            onPressed: () => _openEditAdminDialog(a),
                                          ),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.lock_reset, size: 14),
                                            label: const Text('Reset Pass', style: TextStyle(fontSize: 11)),
                                            onPressed: () => _openResetPasswordDialog(a),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
