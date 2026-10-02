import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';

class CustomerRegisterScreen extends StatefulWidget {
  const CustomerRegisterScreen({super.key});

  @override
  State<CustomerRegisterScreen> createState() => _CustomerRegisterScreenState();
}

class _CustomerRegisterScreenState extends State<CustomerRegisterScreen> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final cityController = TextEditingController(text: 'Raipur');
  final districtController = TextEditingController(text: 'Raipur');
  final addressController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final AuthService authService = AuthService();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  // Territory and Franchise state
  List<Map<String, dynamic>> territories = [];
  bool isLoadingTerritories = false;
  int? selectedTerritoryId;
  String? selectedTerritoryName;

  bool isLoadingFranchises = false;
  List<Map<String, dynamic>> exactFranchises = [];
  List<Map<String, dynamic>> fallbackFranchises = [];
  int? selectedFranchiseId;
  String? selectedFranchiseName;
  bool isFallbackFranchise = false;
  bool showFallbackList = false;
  String? supportContactPhone;

  final List<String> availableDistricts = [
    'Raipur',
    'Durg',
    'Bilaspur',
    'Rajnandgaon',
  ];

  @override
  void initState() {
    super.initState();
    _loadTerritories('Raipur');
  }

  Future<void> _loadTerritories(String district) async {
    setState(() {
      isLoadingTerritories = true;
      territories = [];
      selectedTerritoryId = null;
      selectedTerritoryName = null;
      exactFranchises = [];
      fallbackFranchises = [];
      selectedFranchiseId = null;
      selectedFranchiseName = null;
      isFallbackFranchise = false;
      showFallbackList = false;
    });

    final res = await authService.getTerritories(district: district);
    if (!mounted) return;

    if (res['success'] == true && res['data'] is Map) {
      final list = res['data']['territories'];
      if (list is List) {
        setState(() {
          territories = List<Map<String, dynamic>>.from(list);
          isLoadingTerritories = false;
        });
        return;
      }
    }

    setState(() {
      isLoadingTerritories = false;
    });
  }

  Future<void> _loadEligibleFranchises(int territoryId) async {
    setState(() {
      isLoadingFranchises = true;
      exactFranchises = [];
      fallbackFranchises = [];
      selectedFranchiseId = null;
      selectedFranchiseName = null;
      isFallbackFranchise = false;
      showFallbackList = false;
    });

    final res = await authService.getEligibleFranchises(
      territoryId: territoryId,
      district: districtController.text.trim(),
      city: cityController.text.trim(),
    );

    if (!mounted) return;

    if (res['success'] == true && res['data'] is Map) {
      final data = res['data'];
      final exact = data['exact_matches'] as List? ?? [];
      final fallbacks = data['available_franchises'] as List? ?? [];
      final supportPhone = data['support_contact']?.toString();

      setState(() {
        isLoadingFranchises = false;
        exactFranchises = List<Map<String, dynamic>>.from(exact);
        fallbackFranchises = List<Map<String, dynamic>>.from(fallbacks);
        supportContactPhone = supportPhone;

        if (exactFranchises.isNotEmpty) {
          selectedFranchiseId = exactFranchises.first['id'] as int?;
          selectedFranchiseName = exactFranchises.first['business_name']
              ?.toString();
          isFallbackFranchise = false;
        } else {
          isFallbackFranchise = true;
        }
      });
    } else {
      setState(() {
        isLoadingFranchises = false;
      });
    }
  }

  Future<void> _register() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (selectedTerritoryId == null) {
      _showMessage('Please select your delivery territory.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final result = await authService.registerCustomer(
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      email: emailController.text.trim(),
      city: cityController.text.trim(),
      district: districtController.text.trim(),
      zoneId: selectedTerritoryId!,
      franchiseId: selectedFranchiseId,
      address: addressController.text.trim(),
      password: passwordController.text,
      confirmPassword: confirmPasswordController.text,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (result['success'] != true) {
      _showMessage(result['message']?.toString() ?? 'Registration failed.');
      return;
    }

    _showMessage('Account created successfully. Please login.');

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    cityController.dispose();
    districtController.dispose();
    addressController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(height: 16),
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 32,
                    color: Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Create Customer Account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your details to register for pure water delivery',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                const SizedBox(height: 26),

                // Personal Details
                _field(
                  controller: nameController,
                  label: 'Full Name *',
                  icon: Icons.person_outline,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 14),
                _field(
                  controller: phoneController,
                  label: 'Mobile Number *',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.trim().length < 10) {
                      return 'Enter valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _field(
                  controller: emailController,
                  label: 'Email *',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || !val.trim().contains('@')) {
                      return 'Enter valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Location Details (City & District)
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        controller: cityController,
                        label: 'City *',
                        icon: Icons.location_city_outlined,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Enter city'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: availableDistricts.contains(
                                  districtController.text.trim(),
                                )
                            ? districtController.text.trim()
                            : availableDistricts.first,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'District *',
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                        items: availableDistricts.map((d) {
                          return DropdownMenuItem(
                            value: d,
                            child: Text(d, overflow: TextOverflow.ellipsis, maxLines: 1),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            districtController.text = val;
                            _loadTerritories(val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Territory Selection (Backend-driven)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.near_me_outlined,
                            size: 20,
                            color: Color(0xFF0284C7),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Select Your Territory *',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Delivery zones are dynamically mapped by our franchise network.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isLoadingTerritories)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Loading territories...',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (territories.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Color(0xFFD97706),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No active territories found for this district. Please contact support.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<int>(
                          initialValue: selectedTerritoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            hintText: 'Choose territory / service zone',
                            prefixIcon: Icon(Icons.explore_outlined),
                          ),
                          items: territories.map((t) {
                            return DropdownMenuItem<int>(
                              value: t['id'] as int,
                              child: Text(
                                t['name']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (id) {
                            if (id != null) {
                              final found = territories.firstWhere(
                                (t) => t['id'] == id,
                                orElse: () => {},
                              );
                              setState(() {
                                selectedTerritoryId = id;
                                selectedTerritoryName = found['name']
                                    ?.toString();
                              });
                              _loadEligibleFranchises(id);
                            }
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Franchise Selection Section
                if (selectedTerritoryId != null) ...[
                  if (isLoadingFranchises)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Checking authorized franchises...',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (exactFranchises.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF16A34A),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Authorized Territory Franchise',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Your orders will be fulfilled by an authorized local franchise partner:',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF166534),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...exactFranchises.map((f) {
                            final fId = f['id'] as int?;
                            final isSelected = selectedFranchiseId == fId;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFE2E8F0),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: RadioListTile<int?>(
                                value: fId,
                                groupValue: selectedFranchiseId,
                                activeColor: const Color(0xFF16A34A),
                                title: Text(
                                  f['business_name']?.toString() ??
                                      'Franchise Partner',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  'Territory: ${f['territory'] ?? selectedTerritoryName} • Phone: ${f['phone'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    selectedFranchiseId = val;
                                    selectedFranchiseName = f['business_name']
                                        ?.toString();
                                    isFallbackFranchise = false;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ] else ...[
                    // NO FRANCHISE IN TERRITORY
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFD97706),
                                size: 22,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No franchise is currently available in your selected territory',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            supportContactPhone != null
                                ? 'Our central team is expanding coverage here. For custom assistance call: $supportContactPhone'
                                : 'Our central team is expanding coverage in this territory.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!showFallbackList)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF92400E),
                                  side: const BorderSide(
                                    color: Color(0xFFD97706),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    showFallbackList = true;
                                    if (fallbackFranchises.isNotEmpty &&
                                        selectedFranchiseId == null) {
                                      selectedFranchiseId =
                                          fallbackFranchises.first['id']
                                              as int?;
                                      selectedFranchiseName = fallbackFranchises
                                          .first['business_name']
                                          ?.toString();
                                      isFallbackFranchise = true;
                                    }
                                  });
                                },
                                icon: const Icon(
                                  Icons.storefront_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'View Other Available Franchises',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            const Text(
                              'Available Outside-Territory Franchises (Fallback Assignment):',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...fallbackFranchises.map((f) {
                              final fId = f['id'] as int?;
                              final isSelected = selectedFranchiseId == fId;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: RadioListTile<int?>(
                                  value: fId,
                                  groupValue: selectedFranchiseId,
                                  activeColor: const Color(0xFFD97706),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          f['business_name']?.toString() ??
                                              'Franchise',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'Fallback',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF92400E),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Serving: ${f['city'] ?? ''} • ${f['phone'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      selectedFranchiseId = val;
                                      selectedFranchiseName = f['business_name']
                                          ?.toString();
                                      isFallbackFranchise = true;
                                    });
                                  },
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                ],

                // Delivery Address (Optional)
                _field(
                  controller: addressController,
                  label: 'Delivery Address / Landmark (Optional)',
                  icon: Icons.home_outlined,
                ),
                const SizedBox(height: 14),

                // Password Fields
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => obscurePassword = !obscurePassword),
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => obscureConfirmPassword = !obscureConfirmPassword,
                      ),
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isLoading ? null : _register,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Already have an account? Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: validator,
    );
  }
}
