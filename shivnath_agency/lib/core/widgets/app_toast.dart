import 'package:flutter/material.dart';

enum AppToastType {
  success,
  error,
  warning,
  info,
}

class AppToast {
  static OverlayEntry? _currentToast;

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
    BuildContext context, {
    required String title,
    required String message,
    required AppToastType type,
  }) {
    _currentToast?.remove();
    _currentToast = null;

    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) {
        return _AppToastWidget(
          title: title,
          message: message,
          type: type,
          onClose: () {
            if (entry.mounted) {
              entry.remove();
            }

            if (_currentToast == entry) {
              _currentToast = null;
            }
          },
        );
      },
    );

    _currentToast = entry;
    overlay.insert(entry);

    Future.delayed(
      const Duration(seconds: 3),
      () {
        if (entry.mounted) {
          entry.remove();
        }

        if (_currentToast == entry) {
          _currentToast = null;
        }
      },
    );
  }
}

class _AppToastWidget extends StatefulWidget {
  final String title;
  final String message;
  final AppToastType type;
  final VoidCallback onClose;

  const _AppToastWidget({
    required this.title,
    required this.message,
    required this.type,
    required this.onClose,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get color {
    switch (widget.type) {
      case AppToastType.success:
        return const Color(0xFF16A34A);

      case AppToastType.error:
        return const Color(0xFFDC2626);

      case AppToastType.warning:
        return const Color(0xFFF59E0B);

      case AppToastType.info:
        return const Color(0xFF2563EB);
    }
  }

  IconData get icon {
    switch (widget.type) {
      case AppToastType.success:
        return Icons.check_circle_rounded;

      case AppToastType.error:
        return Icons.error_rounded;

      case AppToastType.warning:
        return Icons.warning_amber_rounded;

      case AppToastType.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Positioned(
      top: screenWidth >= 800 ? 24 : 16,
      right: screenWidth >= 800 ? 24 : 16,
      left: screenWidth < 500 ? 16 : null,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: screenWidth < 500 ? null : 360,
              constraints: const BoxConstraints(
                maxWidth: 380,
              ),
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
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
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
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          widget.message,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(
                        Icons.close,
                        size: 17,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}