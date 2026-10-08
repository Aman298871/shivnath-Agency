import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/role_theme.dart';
import '../../core/widgets/shivnath_logo.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialRole;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
    this.initialRole,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailPhoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  final _requestFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  int _step = 1; // 1 = Request Code, 2 = Enter Code & Reset Password
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _targetIdentifier = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailPhoneController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailPhoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  RoleThemeConfig get roleConfig {
    final role = widget.initialRole ?? '';
    return RoleTheme.fromKey(role);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? BrandColors.red : BrandColors.greenDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  Future<void> _handleRequestResetCode() async {
    if (!(_requestFormKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final identifier = _emailPhoneController.text.trim();
    _targetIdentifier = identifier;

    final result = await _authService.forgotPassword(emailOrPhone: identifier);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final devCode = result['data']?['dev_reset_code'];
      if (devCode != null && devCode.toString().isNotEmpty) {
        _codeController.text = devCode.toString();
        _showMessage('Verification code generated. Please enter your new password.');
      } else {
        _showMessage('Verification instructions have been generated.');
      }

      setState(() {
        _step = 2;
      });
    } else {
      _showMessage(result['message']?.toString() ?? 'Failed to request password reset.', isError: true);
    }
  }

  Future<void> _handleResetPassword() async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final token = _codeController.text.trim();
    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final result = await _authService.resetPassword(
      emailOrPhone: _targetIdentifier.isNotEmpty ? _targetIdentifier : _emailPhoneController.text.trim(),
      token: token,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showMessage('Password reset successfully! You can now log in with your new password.');
      Navigator.pop(context, true);
    } else {
      _showMessage(result['message']?.toString() ?? 'Failed to reset password. Please check your verification code.', isError: true);
    }
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
          onPressed: _isLoading
              ? null
              : () {
                  if (_step == 2) {
                    setState(() => _step = 1);
                  } else {
                    Navigator.pop(context);
                  }
                },
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
          child: _step == 1 ? _buildRequestStep(primaryThemeColor) : _buildResetStep(primaryThemeColor),
        ),
      ),
    );
  }

  Widget _buildRequestStep(Color primaryColor) {
    return Form(
      key: _requestFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Header Icon
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Icon(
              Icons.lock_reset_rounded,
              size: 32,
              color: primaryColor,
            ),
          ),

          const SizedBox(height: 20),

          // Title
          const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: BrandColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Enter your registered email address or phone number to receive a secure password reset verification code.',
            style: TextStyle(
              fontSize: 14,
              color: BrandColors.textSecondary,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 32),

          // Email / Phone Field
          TextFormField(
            controller: _emailPhoneController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleRequestResetCode(),
            decoration: InputDecoration(
              labelText: 'Email Address or Mobile Number',
              hintText: 'e.g. name@example.com or 9876543210',
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: primaryColor,
                size: 20,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 1.8,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your registered email or phone';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isLoading ? null : _handleRequestResetCode,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Send Verification Code',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // Return to login
          Center(
            child: TextButton.icon(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text(
                'Back to Login',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep(Color primaryColor) {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Header Icon
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: BrandColors.greenSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: BrandColors.greenDark.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.password_rounded,
              size: 32,
              color: BrandColors.greenDark,
            ),
          ),

          const SizedBox(height: 20),

          // Title
          const Text(
            'Set New Password',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: BrandColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Enter the 6-digit verification code sent for ${_targetIdentifier.isNotEmpty ? _targetIdentifier : "your account"} and choose your new password.',
            style: const TextStyle(
              fontSize: 14,
              color: BrandColors.textSecondary,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 28),

          // Verification Code Field
          TextFormField(
            controller: _codeController,
            enabled: !_isLoading,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              labelText: '6-Digit Verification Code',
              counterText: '',
              prefixIcon: Icon(
                Icons.pin_outlined,
                color: primaryColor,
                size: 20,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 1.8,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().length < 6) {
                return 'Enter the 6-digit verification code';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // New Password Field
          TextFormField(
            controller: _passwordController,
            enabled: !_isLoading,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: primaryColor,
                size: 20,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 1.8,
                ),
              ),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: BrandColors.textSecondary,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Confirm Password Field
          TextFormField(
            controller: _confirmPasswordController,
            enabled: !_isLoading,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleResetPassword(),
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              prefixIcon: Icon(
                Icons.lock_reset_rounded,
                color: primaryColor,
                size: 20,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 1.8,
                ),
              ),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: BrandColors.textSecondary,
                ),
              ),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Submit Reset Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isLoading ? null : _handleResetPassword,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Reset Password & Login',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Change Email / Resend
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : () => setState(() => _step = 1),
              child: const Text(
                'Change Email / Request New Code',
                style: TextStyle(
                  color: BrandColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
