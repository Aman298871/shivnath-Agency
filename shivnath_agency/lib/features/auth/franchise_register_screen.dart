import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/session_service.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';

class FranchiseRegisterScreen extends StatefulWidget {
  const FranchiseRegisterScreen({
    super.key,
  });

  @override
  State<FranchiseRegisterScreen> createState() =>
      _FranchiseRegisterScreenState();
}

class _FranchiseRegisterScreenState
    extends State<FranchiseRegisterScreen> {
  final formKey = GlobalKey<FormState>();

  final ownerController = TextEditingController();
  final businessController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final cityController = TextEditingController();
  final addressController = TextEditingController();

  final territoryController = TextEditingController();
  final gstController = TextEditingController();
  final panController = TextEditingController();
  final aadhaarController = TextEditingController();

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final AuthService authService = AuthService();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  Future<void> _register() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    final result = await authService.registerFranchise(
      ownerName: ownerController.text.trim(),
      businessName: businessController.text.trim(),
      phone: phoneController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text,
      confirmPassword: confirmPasswordController.text,
      city: cityController.text.trim(),
      address: addressController.text.trim(),
      territory: territoryController.text.trim(),
      gstNumber: gstController.text.trim(),
      panNumber: panController.text.trim(),
      aadhaarNumber: aadhaarController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (result['success'] != true) {
      _message(
        result['message']?.toString() ??
            'Registration failed.',
      );
      return;
    }

    final accessToken = result['access']?.toString() ?? '';
    final refreshToken = result['refresh']?.toString() ?? '';
    final userJson = result['user'];

    if (accessToken.isNotEmpty) {
      await SessionService().saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }

    if (userJson is Map<String, dynamic>) {
      final user = UserModel.fromJson(userJson);
      await SessionService().saveUser(user);
      await SessionService().saveRole(AppConstants.franchiseRole);
    }

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.franchiseDashboard,
      (_) => false,
    );
  }

  void _message(
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
    ownerController.dispose();
    businessController.dispose();
    phoneController.dispose();
    emailController.dispose();
    cityController.dispose();
    addressController.dispose();

    territoryController.dispose();
    gstController.dispose();
    panController.dispose();
    aadhaarController.dispose();

    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(
            22,
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.pop(
                            context,
                          ),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                const CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(
                    0xFFE0F2FE,
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 36,
                    color: Color(
                      0xFF0284C7,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                const Text(
                  'Franchise Registration',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight:
                        FontWeight.w800,
                    color: Color(
                      0xFF0F172A,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                const Text(
                  'Submit your franchise application for admin approval',
                  style: TextStyle(
                    color: Color(
                      0xFF64748B,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 28,
                ),

                _field(
                  ownerController,
                  'Owner Name',
                  Icons.person_outline,
                ),

                _space(),

                _field(
                  businessController,
                  'Business / Franchise Name',
                  Icons.storefront_outlined,
                ),

                _space(),

                _field(
                  phoneController,
                  'Mobile Number',
                  Icons.phone_outlined,
                  keyboard:
                      TextInputType.phone,
                ),

                _space(),

                _field(
                  emailController,
                  'Email',
                  Icons.email_outlined,
                  keyboard:
                      TextInputType
                          .emailAddress,
                  email: true,
                ),

                _space(),

                _field(
                  cityController,
                  'City',
                  Icons.location_city_outlined,
                ),

                _space(),

                TextFormField(
                  controller:
                      addressController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(
                      Icons
                          .location_on_outlined,
                    ),
                    alignLabelWithHint:
                        true,
                  ),
                  validator: (value) {
                    if (value == null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Enter address';
                    }

                    return null;
                  },
                ),

                _space(),

                TextFormField(
                  controller:
                      territoryController,
                  decoration:
                      const InputDecoration(
                    labelText: 'Territory',
                    prefixIcon: Icon(
                      Icons.map_outlined,
                    ),
                    hintText:
                        'Example: Raipur North',
                  ),
                ),

                _space(),

                TextFormField(
                  controller:
                      gstController,
                  textCapitalization:
                      TextCapitalization
                          .characters,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'GST Number (Optional)',
                    prefixIcon: Icon(
                      Icons
                          .receipt_long_outlined,
                    ),
                  ),
                ),

                _space(),

                TextFormField(
                  controller:
                      panController,
                  textCapitalization:
                      TextCapitalization
                          .characters,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'PAN Number (Optional)',
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                    ),
                  ),
                ),

                _space(),

                TextFormField(
                  controller:
                      aadhaarController,
                  keyboardType:
                      TextInputType.number,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Aadhaar Number (Optional)',
                    prefixIcon: Icon(
                      Icons
                          .credit_card_outlined,
                    ),
                  ),
                ),

                _space(),

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

                _space(),

                TextFormField(
                  controller:
                      confirmPasswordController,
                  obscureText:
                      obscureConfirm,
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
                          obscureConfirm =
                              !obscureConfirm;
                        });
                      },
                      icon: Icon(
                        obscureConfirm
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
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : _register,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Application',
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
                  height: 14,
                ),

                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(
                      context,
                    ),
                    child: const Text(
                      'Already registered? Login',
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

  Widget _space() =>
      const SizedBox(
        height: 15,
      );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    bool email = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: (value) {
        final text =
            value?.trim() ?? '';

        if (text.isEmpty) {
          return 'Enter $label';
        }

        if (email &&
            !text.contains('@')) {
          return 'Enter valid email';
        }

        if (label ==
                'Mobile Number' &&
            text.length < 10) {
          return 'Enter valid mobile number';
        }

        return null;
      },
    );
  }
}