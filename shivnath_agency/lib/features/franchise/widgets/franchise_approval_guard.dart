import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';

class FranchiseApprovalGuard extends StatefulWidget {
  final Widget child;
  final UserModel? user;
  final VoidCallback? onRefreshStatus;

  const FranchiseApprovalGuard({
    super.key,
    required this.child,
    this.user,
    this.onRefreshStatus,
  });

  @override
  State<FranchiseApprovalGuard> createState() => _FranchiseApprovalGuardState();
}

class _FranchiseApprovalGuardState extends State<FranchiseApprovalGuard> {
  bool _isChecking = false;

  Future<void> _logout() async {
    await SessionService().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.roleSelection,
      (_) => false,
    );
  }

  Future<void> _checkLatestStatus() async {
    setState(() => _isChecking = true);
    if (widget.onRefreshStatus != null) {
      widget.onRefreshStatus!();
    }
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isPending = user?.isPending == true;
    final isRejected = user?.isRejected == true;

    if (!isPending && !isRejected) {
      return widget.child;
    }

    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          // Background actual app content (disabled & blurred)
          IgnorePointer(
            ignoring: true,
            child: widget.child,
          ),

          // Blur & dark overlay filter
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: Container(
                color: Colors.black.withValues(alpha: 0.52),
              ),
            ),
          ),

          // Foreground Non-Dismissible Dialog
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Material(
                  color: Colors.white,
                  elevation: 16,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon header
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: isRejected
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFFFFBEB),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isRejected
                                ? Icons.cancel_rounded
                                : Icons.hourglass_top_rounded,
                            size: 36,
                            color: isRejected
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        Text(
                          isRejected
                              ? 'Wholesale Dealership Rejected'
                              : 'Account Verification Pending',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Body message
                        Text(
                          isRejected
                              ? (user?.rejectionReason.isNotEmpty == true
                                  ? 'Your wholesale dealership application has not been approved by the administrator.\n\nReason: ${user!.rejectionReason}\n\nPlease contact support for more information.'
                                  : 'Your wholesale dealership application has not been approved by the administrator. Please contact support for more information.')
                              : 'Your profile has been submitted successfully. Your details have been sent to the admin for verification and confirmation. You will be able to access the full portal once your account is approved.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF475569),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Status refresh button (for pending)
                        if (isPending) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isChecking ? null : _checkLatestStatus,
                              icon: _isChecking
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded, size: 20),
                              label: Text(
                                _isChecking ? 'Checking...' : 'Check Approval Status',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Logout button
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFDC2626)),
                              foregroundColor: const Color(0xFFDC2626),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _logout,
                            icon: const Icon(Icons.logout_rounded, size: 20),
                            label: const Text(
                              'Logout',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
