import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

enum AppToastType {
  success,
  error,
  warning,
  info,
}

class AppToast {
  static void success(
    BuildContext context,
    String message, {
    String title = 'Success',
  }) {
    _show(
      context,
      title: title,
      message: message,
      type: AppToastType.success,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    String title = 'Error',
  }) {
    _show(
      context,
      title: title,
      message: message,
      type: AppToastType.error,
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    String title = 'Warning',
  }) {
    _show(
      context,
      title: title,
      message: message,
      type: AppToastType.warning,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    String title = 'Information',
  }) {
    _show(
      context,
      title: title,
      message: message,
      type: AppToastType.info,
    );
  }

  static void _show(
    BuildContext? context, {
    required String title,
    required String message,
    required AppToastType type,
  }) {
    ScaffoldMessengerState? messenger;
    if (context != null && context.mounted) {
      messenger = ScaffoldMessenger.maybeOf(context);
    }
    messenger ??= rootScaffoldMessengerKey.currentState;

    if (messenger == null) return;

    Color color;
    IconData icon;
    switch (type) {
      case AppToastType.success:
        color = const Color(0xFF16A34A);
        icon = Icons.check_circle_rounded;
        break;
      case AppToastType.error:
        color = const Color(0xFFDC2626);
        icon = Icons.error_rounded;
        break;
      case AppToastType.warning:
        color = const Color(0xFFF59E0B);
        icon = Icons.warning_amber_rounded;
        break;
      case AppToastType.info:
        color = const Color(0xFF2563EB);
        icon = Icons.info_rounded;
        break;
    }

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: EdgeInsets.zero,
        duration: const Duration(seconds: 3),
        content: Align(
          alignment: Alignment.bottomRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: Color(0xFF64748B),
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
}