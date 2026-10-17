import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final SessionService _sessionService = SessionService();
  final nameController = TextEditingController(text: 'Administrator');
  final emailController = TextEditingController(text: 'admin@shivnath.com');
  final phoneController = TextEditingController(text: '+91 98264 21818');

  UserModel? _currentUser;
  bool _isLoading = false;
  final String role = 'Super Administrator';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _sessionService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        if (user != null) {
          if (user.name.isNotEmpty) nameController.text = user.name;
          if (user.email.isNotEmpty) emailController.text = user.email;
          if (user.phone.isNotEmpty) phoneController.text = user.phone;
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  String get initials {
    final value = nameController.text.trim();
    if (value.isEmpty) return 'AD';

    final parts = value.split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    return value.length >= 2
        ? value.substring(0, 2).toUpperCase()
        : value.substring(0, 1).toUpperCase();
  }

  Future<void> _logout() async {
    await _sessionService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.roleSelection,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0284C7)),
      );
    }

    return LayoutBuilder(
      builder: (_, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF8FAFC),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Profile',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Manage your administrator account credentials and system privileges.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 22),
                    desktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 320,
                                child: _profileSummary(),
                              ),
                              const SizedBox(width: 18),
                              Expanded(child: _editProfile()),
                            ],
                          )
                        : Column(
                            children: [
                              _profileSummary(),
                              const SizedBox(height: 14),
                              _editProfile(),
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

  Widget _profileSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _profileDecoration(),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            nameController.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _summaryInfo(
            Icons.email_outlined,
            emailController.text,
          ),
          _summaryInfo(
            Icons.phone_outlined,
            phoneController.text,
          ),
          _summaryInfo(
            Icons.admin_panel_settings_outlined,
            'Full Platform Administration',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryInfo(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFFDC2626),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editProfile() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _profileDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Update your personal profile information',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: nameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: emailController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: phoneController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: role,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'System Privileges',
              prefixIcon: Icon(Icons.admin_panel_settings_outlined),
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 160,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveProfile,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Changes'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveProfile() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty) {
      AppToast.error(
        context,
        'Please enter your full name.',
        title: 'Name Required',
      );
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      AppToast.error(
        context,
        'Please enter a valid email address.',
        title: 'Invalid Email',
      );
      return;
    }

    if (_currentUser != null) {
      final updated = _currentUser!.copyWith(
        name: name,
        email: email,
        phone: phone,
      );
      await _sessionService.saveUser(updated);
      setState(() => _currentUser = updated);
    }

    AppToast.success(
      context,
      'Your administrator profile has been updated.',
      title: 'Profile Saved',
    );
  }
}

BoxDecoration _profileDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE2E8F0)),
  );
}