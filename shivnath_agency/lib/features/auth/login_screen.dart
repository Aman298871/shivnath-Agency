import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/session_service.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/role_theme.dart';
import '../../core/widgets/shivnath_logo.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final SessionService _sessionService = SessionService();
  final AuthService _authService = AuthService();
  final formKey = GlobalKey<FormState>();

  bool obscurePassword = true;
  bool isLoading = false;
  String role = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      role = args;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<RoleThemeProvider>(context, listen: false).setRole(role);
        }
      });
    }
  }

  RoleThemeConfig get roleConfig => RoleTheme.fromKey(role);

  String get roleTitle {
    switch (role) {
      case AppConstants.customerRole:
        return 'Customer Login';
      case AppConstants.franchiseRole:
        return 'Franchise Login';
      case AppConstants.adminRole:
        return 'Admin Login';
      default:
        return 'Login';
    }
  }

  IconData get roleIcon => roleConfig.icon;

  Future<void> _login() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (role.isEmpty) {
      _showMessage('Please select an account type first.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final email = emailController.text.trim();
    final password = passwordController.text;

    final result = await _authService.login(
      email: email,
      password: password,
      role: role,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        isLoading = false;
      });
      _showMessage(result['message']?.toString() ?? 'Login failed.');
      return;
    }

    try {
      final rawData = result['data'];
      final Map<String, dynamic> response = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};

      final accessToken = response['access']?.toString() ?? '';
      final refreshToken = response['refresh']?.toString() ?? '';
      final rawUser = response['user'];

      final Map<String, dynamic> userJson = rawUser is Map
          ? Map<String, dynamic>.from(rawUser)
          : <String, dynamic>{};

      if (accessToken.isEmpty || userJson.isEmpty) {
        throw Exception('Server returned incomplete login data');
      }

      final user = UserModel.fromJson(userJson);

      // Flexible role validation supporting super_admin, admin, sales_executive
      bool hasAccess = false;
      if (role.isEmpty) {
        hasAccess = true;
      } else if (role == AppConstants.adminRole) {
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
          'This account is registered as ${user.roleDisplay}. Please log in using the correct portal.',
        );
        return;
      }

      // Save JWT & User Session
      await _sessionService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken.isNotEmpty ? refreshToken : accessToken,
      );
      await _sessionService.saveUser(user);
      await _sessionService.saveRole(user.role);

      // Non-fatal FCM token registration
      try {
        await NotificationService().registerDeviceTokenWithBackend(force: true);
      } catch (fcmErr) {
        debugPrint('FCM token registration warning: $fcmErr');
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _openDashboard(user.role);
    } catch (e) {
      debugPrint('Login processing error: $e');
      setState(() {
        isLoading = false;
      });
      _showMessage('Login error: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }

  void _openDashboard(String userRole) {
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

    _showMessage('Unknown account role: $userRole');
  }

  void _openCustomerRegistration() {
    Navigator.pushNamed(context, AppRoutes.customerRegister);
  }

  void _openFranchiseRegistration() {
    Navigator.pushNamed(context, AppRoutes.franchiseRegister);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = roleConfig;
    final primaryThemeColor = cfg.primary;

    return Scaffold(
      backgroundColor: BrandColors.white,
      appBar: AppBar(
        backgroundColor: BrandColors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: BrandColors.textPrimary),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18.0),
            child: ShivnathLogo.horizontal(size: 32),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Role Icon Badge
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: cfg.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: primaryThemeColor.withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        roleIcon,
                        size: 32,
                        color: primaryThemeColor,
                      ),
                    ),
                    if (cfg.isAdmin) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: BrandColors.redSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: BrandColors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'SECURITY & CONTROL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: BrandColors.redDark,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  roleTitle,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: BrandColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Enter your credentials to access your portal',
                  style: TextStyle(
                    fontSize: 14,
                    color: BrandColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                // Email
                TextFormField(
                  controller: emailController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: primaryThemeColor,
                      size: 20,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: primaryThemeColor,
                        width: 1.8,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter registered email address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // Password
                TextFormField(
                  controller: passwordController,
                  enabled: !isLoading,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: primaryThemeColor,
                      size: 20,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: primaryThemeColor,
                        width: 1.8,
                      ),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: BrandColors.textSecondary,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter password';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 10),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.forgotPassword,
                              arguments: {
                                'email': emailController.text.trim(),
                                'role': role,
                              },
                            );
                          },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: primaryThemeColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryThemeColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isLoading ? null : _login,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Registration Link for Customer
                if (role == AppConstants.customerRole)
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: BrandColors.textSecondary),
                        ),
                        TextButton(
                          onPressed: isLoading ? null : _openCustomerRegistration,
                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                              color: BrandColors.primaryBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Registration Link for Franchise
                if (role == AppConstants.franchiseRole)
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.center,
                      children: [
                        const Text(
                          'New Franchise Partner? ',
                          style: TextStyle(color: BrandColors.textSecondary),
                        ),
                        TextButton(
                          onPressed: isLoading ? null : _openFranchiseRegistration,
                          child: const Text(
                            'Register Now',
                            style: TextStyle(
                              color: BrandColors.greenDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Info Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BrandColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BrandColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: primaryThemeColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _getInfoText(),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: BrandColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
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
    if (role == AppConstants.customerRole) {
      return 'Customer Portal: Sign in with your registered email or create a new account to order packaged drinking water.';
    }
    if (role == AppConstants.franchiseRole) {
      return 'Franchise Portal: Authorized partners can manage inventory, place bulk orders, and review billing.';
    }
    if (role == AppConstants.adminRole) {
      return 'Admin Control Panel: Reserved for Super Admin, Plant Operations, and authorized personnel.';
    }
    return 'Use your registered email and password to access your WaterNow account.';
  }
}