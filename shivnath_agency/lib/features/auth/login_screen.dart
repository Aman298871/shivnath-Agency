import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/session_service.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {
  final emailController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  final SessionService _sessionService =
      SessionService();

  final AuthService _authService =
      AuthService();

  final formKey =
      GlobalKey<FormState>();

  bool obscurePassword = true;
  bool isLoading = false;

  String role = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)
            ?.settings
            .arguments;

    if (args is String) {
      role = args;
    }
  }

  // --------------------------------------------------
  // ROLE TITLE
  // --------------------------------------------------

  String get roleTitle {
    switch (role) {
      case AppConstants.customerRole:
        return 'Customer Login';

      case AppConstants.franchiseRole:
        return 'Wholesale Dealer Login';

      case AppConstants.adminRole:
        return 'Company Staff / Admin Login';

      default:
        return 'Login';
    }
  }

  // --------------------------------------------------
  // ROLE ICON
  // --------------------------------------------------

  IconData get roleIcon {
    switch (role) {
      case AppConstants.customerRole:
        return Icons.person_rounded;

      case AppConstants.franchiseRole:
        return Icons.storefront_rounded;

      case AppConstants.adminRole:
        return Icons
            .admin_panel_settings_rounded;

      default:
        return Icons
            .water_drop_rounded;
    }
  }

  // --------------------------------------------------
  // LOGIN
  // --------------------------------------------------

  Future<void> _login() async {
    if (!(formKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    if (role.isEmpty) {
      _showMessage(
        'Please select an account type first.',
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    final email =
        emailController.text.trim();

    final password =
        passwordController.text;

    final result =
        await _authService.login(
      email: email,
      password: password,
      role: role,
    );

    if (!mounted) return;

    // Login Failed
    if (result['success'] != true) {
      setState(() {
        isLoading = false;
      });

      _showMessage(
        result['message']
                ?.toString() ??
            'Login failed.',
      );

      return;
    }

    try {
      final response =
          result['data']
              as Map<String, dynamic>;

      final accessToken =
          response['access']
                  ?.toString() ??
              '';

      final refreshToken =
          response['refresh']
                  ?.toString() ??
              '';

      final userJson =
          response['user'];

      if (accessToken.isEmpty ||
          refreshToken.isEmpty ||
          userJson
              is! Map<String, dynamic>) {
        throw Exception(
          'Invalid login response',
        );
      }

      final user =
          UserModel.fromJson(
        userJson,
      );

      // Flexible role validation supporting super_admin, admin, sales_executive
      bool hasAccess = false;
      if (role == AppConstants.adminRole) {
        hasAccess = user.isStaffOrAdmin;
      } else if (role == AppConstants.franchiseRole) {
        hasAccess = user.isDealer;
      } else if (role == AppConstants.customerRole) {
        hasAccess = user.isCustomer;
      } else {
        hasAccess = user.role.toLowerCase() == role.toLowerCase();
      }

      if (!hasAccess) {
        setState(() {
          isLoading = false;
        });

        _showMessage(
          'This account does not have access to ${AppConstants.getRoleDisplayName(role)}.',
        );

        return;
      }

      // Save JWT
      await _sessionService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      // Save user
      await _sessionService.saveUser(
        user,
      );

      // Save role
      await _sessionService.saveRole(
        user.role,
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      // Open correct dashboard based on actual authenticated user role
      _openDashboard(
        user.role,
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Unable to process login response.',
      );
    }
  }

  // --------------------------------------------------
  // DASHBOARD
  // --------------------------------------------------

  void _openDashboard(
    String userRole,
  ) {
    final r = userRole.toLowerCase();

    if (r == AppConstants.customerRole) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.customerDashboard,
        (_) => false,
      );

      return;
    }

    if (r == AppConstants.franchiseRole) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.franchiseDashboard,
        (_) => false,
      );

      return;
    }

    if (r == AppConstants.adminRole ||
        r == AppConstants.superAdminRole ||
        r == AppConstants.salesExecutiveRole) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.adminDashboard,
        (_) => false,
      );

      return;
    }

    _showMessage(
      'Unknown account role: $userRole',
    );
  }

  // --------------------------------------------------
  // CUSTOMER REGISTRATION
  // --------------------------------------------------

  void _openCustomerRegistration() {
    Navigator.pushNamed(
      context,
      AppRoutes.customerRegister,
    );
  }

  // --------------------------------------------------
  // FRANCHISE REGISTRATION
  // --------------------------------------------------

  void _openFranchiseRegistration() {
    Navigator.pushNamed(
      context,
      AppRoutes.franchiseRegister,
    );
  }

  // --------------------------------------------------
  // MESSAGE
  // --------------------------------------------------

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
        ),
      );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();

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
                // Back
                IconButton(
                  onPressed:
                      isLoading
                          ? null
                          : () {
                              Navigator.pop(
                                context,
                              );
                            },
                  icon: const Icon(
                    Icons
                        .arrow_back_rounded,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // Role Icon
                CircleAvatar(
                  radius: 34,
                  backgroundColor:
                      const Color(
                    0xFFE0F2FE,
                  ),
                  child: Icon(
                    roleIcon,
                    size: 38,
                    color:
                        const Color(
                      0xFF0284C7,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                // Title
                Text(
                  roleTitle,
                  style:
                      const TextStyle(
                    fontSize: 28,
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
                  'Enter your account details to continue',
                  style: TextStyle(
                    color:
                        Color(
                      0xFF64748B,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 32,
                ),

                // Email
                TextFormField(
                  controller:
                      emailController,
                  enabled: !isLoading,
                  keyboardType:
                      TextInputType
                          .emailAddress,
                  textInputAction:
                      TextInputAction
                          .next,
                  decoration:
                      const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(
                      Icons
                          .email_outlined,
                    ),
                  ),
                  validator: (value) {
                    final email =
                        value?.trim() ??
                            '';

                    if (email.isEmpty) {
                      return 'Enter your email';
                    }

                    if (!email
                        .contains('@')) {
                      return 'Enter a valid email';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 16,
                ),

                // Password
                TextFormField(
                  controller:
                      passwordController,
                  enabled: !isLoading,
                  obscureText:
                      obscurePassword,
                  textInputAction:
                      TextInputAction
                          .done,
                  onFieldSubmitted: (_) {
                    if (!isLoading) {
                      _login();
                    }
                  },
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
                        value.isEmpty) {
                      return 'Enter password';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 8,
                ),

                // Forgot Password
                Align(
                  alignment:
                      Alignment
                          .centerRight,
                  child: TextButton(
                    onPressed:
                        isLoading
                            ? null
                            : () {
                                _showMessage(
                                  'Forgot password will be available soon.',
                                );
                              },
                    child: const Text(
                      'Forgot Password?',
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                // Login Button
                SizedBox(
                  width:
                      double.infinity,
                  child:
                      ElevatedButton(
                    onPressed:
                        isLoading
                            ? null
                            : _login,
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
                            'Login',
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
                  height: 22,
                ),

                // --------------------------------------
                // CUSTOMER REGISTRATION
                // --------------------------------------

                if (role ==
                    AppConstants
                        .customerRole)
                  Center(
                    child: Wrap(
                      crossAxisAlignment:
                          WrapCrossAlignment
                              .center,
                      alignment:
                          WrapAlignment
                              .center,
                      children: [
                        const Text(
                          "Don't have an account?",
                          style:
                              TextStyle(
                            color:
                                Color(
                              0xFF64748B,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed:
                              isLoading
                                  ? null
                                  : _openCustomerRegistration,
                          child:
                              const Text(
                            'Create Account',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // --------------------------------------
                // FRANCHISE REGISTRATION
                // --------------------------------------

                if (role ==
                    AppConstants
                        .franchiseRole)
                  Center(
                    child: Wrap(
                      crossAxisAlignment:
                          WrapCrossAlignment
                              .center,
                      alignment:
                          WrapAlignment
                              .center,
                      children: [
                        const Text(
                          'New Wholesale Dealer?',
                          style:
                              TextStyle(
                            color:
                                Color(
                              0xFF64748B,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed:
                              isLoading
                                  ? null
                                  : _openFranchiseRegistration,
                          child:
                              const Text(
                            'Register Now',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // --------------------------------------
                // INFORMATION BOX
                // --------------------------------------

                const SizedBox(
                  height: 8,
                ),

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets
                          .all(14),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFF1F5F9,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                  child: Text(
                    _getInfoText(),
                    style:
                        const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color:
                          Color(
                        0xFF475569,
                      ),
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

  String _getInfoText() {
    if (role ==
        AppConstants.customerRole) {
      return 'Customer Account\nLogin with your registered email and password or create a new account.';
    }

    if (role ==
        AppConstants.franchiseRole) {
      return 'Wholesale Dealer Account\nNew dealership registrations require admin verification & approval.';
    }

    if (role ==
        AppConstants.adminRole) {
      return 'Company Staff / Admin Account\nAccess reserved for Super Admin, Plant Operations, and Sales Executives.';
    }

    return 'Use your registered email and password.';
  }
}