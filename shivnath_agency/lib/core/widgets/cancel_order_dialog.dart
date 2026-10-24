import 'package:flutter/material.dart';
import '../theme/brand_colors.dart';
import '../theme/app_theme.dart';

/// Standardized, protected confirmation dialog for order cancellation across
/// Admin, Franchise, and Staff workflows.
///
/// Ensures explicit confirmation with exact required title, message, and buttons,
/// prevents dismissal via outside tap or back press during processing, and guards
/// against multiple concurrent requests.
class CancelOrderDialog extends StatefulWidget {
  final String orderCode;
  final Future<void> Function()? onConfirm;

  const CancelOrderDialog({
    super.key,
    required this.orderCode,
    this.onConfirm,
  });

  /// Displays the modal dialog. Returns `true` if cancellation was confirmed and succeeded.
  static Future<bool?> show(
    BuildContext context, {
    required String orderCode,
    Future<void> Function()? onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CancelOrderDialog(
        orderCode: orderCode,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<CancelOrderDialog> {
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _handleConfirm() async {
    if (_isProcessing) return;

    if (widget.onConfirm == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm!();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
        ),
        backgroundColor: BrandColors.surface,
        elevation: 8,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BrandColors.danger.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: BrandColors.danger,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Cancel Order?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: BrandColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Order Code Badge if available
              if (widget.orderCode.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: BrandColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: BrandColors.border),
                  ),
                  child: Text(
                    'Order ID: ${widget.orderCode}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BrandColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Required Message
              const Text(
                'Are you sure you want to cancel this order? This action may affect order processing and payment records.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: BrandColors.textSecondary,
                ),
              ),

              // Error display on failure (allowing safe retry)
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BrandColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BrandColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, size: 18, color: BrandColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: BrandColors.danger,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  // Go Back
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing
                          ? null
                          : () {
                              Navigator.of(context).pop(false);
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: BrandColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                        ),
                      ),
                      child: const Text(
                        'Go Back',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: BrandColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Yes, Cancel Order
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.danger,
                        foregroundColor: BrandColors.white,
                        disabledBackgroundColor: BrandColors.danger.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Yes, Cancel Order',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
