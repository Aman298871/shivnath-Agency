import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';

class CustomerRegisterScreen
    extends StatefulWidget {
  const CustomerRegisterScreen({
    super.key,
  });

  @override
  State<CustomerRegisterScreen>
      createState() =>
          _CustomerRegisterScreenState();
}

class _CustomerRegisterScreenState
    extends State<CustomerRegisterScreen> {
  final formKey =
      GlobalKey<FormState>();

  final nameController =
      TextEditingController();

  final phoneController =
      TextEditingController();

  final emailController =
      TextEditingController();

  final cityController =
      TextEditingController(text: 'Raipur');

  final districtController =
      TextEditingController(text: 'Raipur');

  final pincodeController =
      TextEditingController();

  final addressController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  final confirmPasswordController =
      TextEditingController();

  final AuthService authService =
      AuthService();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  // Zone Resolution State
  bool isResolvingZone = false;
  String? resolvedZoneName;
  int? resolvedZoneId;
  String? resolvedDistrict;
  String? resolvedLocality;
  bool isZoneConfirmed = false;
  String? zoneResolutionMessage;
  List<Map<String, dynamic>> ambiguousOptions = [];

  Future<void> _checkZone({String? locality}) async {
    final pincode = pincodeController.text.trim();
    final district = districtController.text.trim();
    if (pincode.length != 6) {
      setState(() {
        resolvedZoneName = null;
        resolvedZoneId = null;
        isZoneConfirmed = false;
        zoneResolutionMessage = null;
      });
      return;
    }

    setState(() {
      isResolvingZone = true;
      zoneResolutionMessage = null;
    });

    final res = await authService.resolveZone(
      district: district.isNotEmpty ? district : 'Raipur',
      pincode: pincode,
      locality: locality ?? resolvedLocality ?? '',
    );

    if (!mounted) return;

    setState(() {
      isResolvingZone = false;
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final status = data['status'];
        if (status == 'resolved') {
          resolvedZoneName = data['zone_name'];
          resolvedZoneId = data['zone_id'];
          resolvedDistrict = data['district'];
          resolvedLocality = locality ?? resolvedLocality;
          isZoneConfirmed = false;
          zoneResolutionMessage = data['message'];
          ambiguousOptions = [];
        } else if (status == 'ambiguous') {
          ambiguousOptions = List<Map<String, dynamic>>.from(data['options'] ?? []);
          _showLocalityPicker();
        } else {
          resolvedZoneName = null;
          resolvedZoneId = null;
          isZoneConfirmed = false;
          zoneResolutionMessage = data['message'] ?? 'Service area not found in current master list.';
        }
      } else {
        zoneResolutionMessage = res['message'] ?? 'Unable to resolve service zone.';
      }
    });
  }

  void _showLocalityPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Your Delivery Area / Locality',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your PIN code covers multiple service zones. Please choose your specific locality:',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ...ambiguousOptions.map((opt) {
                final loc = opt['locality']?.toString() ?? '';
                final zone = opt['zone_name']?.toString() ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on, color: Color(0xFF0284C7)),
                  title: Text(loc, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Zone: $zone', style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      resolvedLocality = loc;
                    });
                    _checkZone(locality: loc);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!(formKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    if (pincodeController.text.trim().length == 6 && resolvedZoneName != null && !isZoneConfirmed) {
      _showMessage('Please confirm your detected service zone before proceeding.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final result =
        await authService
            .registerCustomer(
      name:
          nameController.text.trim(),
      phone:
          phoneController.text.trim(),
      email:
          emailController.text.trim(),
      city:
          cityController.text.trim(),
      district:
          districtController.text.trim(),
      pincode:
          pincodeController.text.trim(),
      locality:
          resolvedLocality ?? '',
      zoneId:
          resolvedZoneId,
      address:
          addressController.text.trim(),
      password:
          passwordController.text,
      confirmPassword:
          confirmPasswordController
              .text,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (result['success'] != true) {
      _showMessage(
        result['message']
                ?.toString() ??
            'Registration failed.',
      );

      return;
    }

    _showMessage(
      'Account created successfully. Please login.',
    );

    await Future.delayed(
      const Duration(
        milliseconds: 600,
      ),
    );

    if (!mounted) return;

    Navigator.pop(context);
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    cityController.dispose();
    districtController.dispose();
    pincodeController.dispose();
    addressController.dispose();
    passwordController.dispose();
    confirmPasswordController
        .dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.all(
            22,
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                IconButton(
                  onPressed:
                      isLoading
                          ? null
                          : () =>
                              Navigator.pop(
                                context,
                              ),
                  icon: const Icon(
                    Icons
                        .arrow_back_rounded,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                const CircleAvatar(
                  radius: 34,
                  backgroundColor:
                      Color(
                    0xFFE0F2FE,
                  ),
                  child: Icon(
                    Icons
                        .person_add_alt_1_rounded,
                    size: 36,
                    color:
                        Color(
                      0xFF0284C7,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                const Text(
                  'Create Customer Account',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        Color(
                      0xFF0F172A,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                const Text(
                  'Enter your details to create your account',
                  style: TextStyle(
                    color:
                        Color(
                      0xFF64748B,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 30,
                ),

                _field(
                  controller:
                      nameController,
                  label:
                      'Full Name',
                  icon:
                      Icons.person_outline,
                  validator: (value) {
                    if (value == null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Enter your name';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 15,
                ),

                _field(
                  controller:
                      phoneController,
                  label:
                      'Mobile Number',
                  icon:
                      Icons.phone_outlined,
                  keyboardType:
                      TextInputType.phone,
                  validator: (value) {
                    if (value == null ||
                        value
                            .trim()
                            .length <
                            10) {
                      return 'Enter valid mobile number';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 15,
                ),

                _field(
                  controller:
                      emailController,
                  label: 'Email',
                  icon:
                      Icons.email_outlined,
                  keyboardType:
                      TextInputType
                          .emailAddress,
                  validator: (value) {
                    if (value == null ||
                        !value
                            .trim()
                            .contains(
                              '@',
                            )) {
                      return 'Enter valid email';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 15,
                ),

                Row(
                  children: [
                    Expanded(
                      child: _field(
                        controller:
                            cityController,
                        label: 'City',
                        icon:
                            Icons.location_city_outlined,
                        validator: (value) {
                          if (value == null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'Enter city';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: _field(
                        controller:
                            districtController,
                        label: 'District',
                        icon:
                            Icons.map_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 15,
                ),

                TextFormField(
                  controller: pincodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'PIN Code / Delivery Area',
                    prefixIcon: const Icon(Icons.pin_drop_outlined),
                    counterText: '',
                    suffixIcon: isResolvingZone
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (pincodeController.text.length == 6
                            ? IconButton(
                                icon: const Icon(Icons.refresh, color: Color(0xFF0284C7)),
                                onPressed: () => _checkZone(),
                              )
                            : null),
                  ),
                  onChanged: (val) {
                    if (val.trim().length == 6) {
                      _checkZone();
                    } else if (resolvedZoneName != null) {
                      setState(() {
                        resolvedZoneName = null;
                        resolvedZoneId = null;
                        isZoneConfirmed = false;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().length != 6) {
                      return 'Enter 6-digit delivery PIN code';
                    }
                    return null;
                  },
                ),

                if (isResolvingZone)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Detecting delivery service zone...',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                else if (resolvedZoneName != null)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isZoneConfirmed ? const Color(0xFFF0FDF4) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isZoneConfirmed ? const Color(0xFF22C55E) : const Color(0xFF0284C7),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isZoneConfirmed ? Icons.check_circle_rounded : Icons.location_on_rounded,
                              color: isZoneConfirmed ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isZoneConfirmed
                                    ? 'Service Zone Confirmed: $resolvedZoneName'
                                    : '📍 Your service zone appears to be $resolvedZoneName.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isZoneConfirmed ? const Color(0xFF15803D) : const Color(0xFF0369A1),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resolvedLocality != null && resolvedLocality!.isNotEmpty
                              ? 'Locality: $resolvedLocality ($resolvedDistrict)'
                              : 'Pure water delivery will be coordinated through authorized local franchises in $resolvedZoneName.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isZoneConfirmed ? const Color(0xFF166534) : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (!isZoneConfirmed)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0284C7),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    setState(() => isZoneConfirmed = true);
                                  },
                                  child: const Text('Confirm & Continue', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF64748B),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  setState(() {
                                    pincodeController.clear();
                                    resolvedZoneName = null;
                                    resolvedZoneId = null;
                                    resolvedLocality = null;
                                    isZoneConfirmed = false;
                                  });
                                },
                                child: const Text('Change Location'),
                              ),
                            ],
                          )
                        else
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() => isZoneConfirmed = false);
                              },
                              icon: const Icon(Icons.edit, size: 13),
                              label: const Text('Change Zone', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                      ],
                    ),
                  )
                else if (zoneResolutionMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      zoneResolutionMessage!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFE11D48)),
                    ),
                  ),

                const SizedBox(
                  height: 15,
                ),

                _field(
                  controller:
                      addressController,
                  label: 'Address / Landmark (Optional)',
                  icon:
                      Icons.home_outlined,
                ),

                const SizedBox(
                  height: 15,
                ),

                TextFormField(
                  controller:
                      passwordController,
                  obscureText:
                      obscurePassword,
                  decoration:
                      InputDecoration(
                    labelText:
                        'Password',
                    prefixIcon:
                        const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon:
                        IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword =
                              !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons
                                .visibility_outlined
                            : Icons
                                .visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 15,
                ),

                TextFormField(
                  controller:
                      confirmPasswordController,
                  obscureText:
                      obscureConfirmPassword,
                  decoration:
                      InputDecoration(
                    labelText:
                        'Confirm Password',
                    prefixIcon:
                        const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon:
                        IconButton(
                      onPressed: () {
                        setState(() {
                          obscureConfirmPassword =
                              !obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons
                                .visibility_outlined
                            : Icons
                                .visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value !=
                        passwordController
                            .text) {
                      return 'Passwords do not match';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 26,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      ElevatedButton(
                    onPressed:
                        isLoading
                            ? null
                            : _register,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    child: const Text(
                      'Already have an account? Login',
                    ),
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
    required
        TextEditingController
            controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)?
        validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration:
          InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }
}