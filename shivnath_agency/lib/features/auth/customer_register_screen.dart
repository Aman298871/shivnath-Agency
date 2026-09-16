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
      TextEditingController();

  final districtController =
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

  Future<void> _register() async {
    if (!(formKey.currentState
            ?.validate() ??
        false)) {
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