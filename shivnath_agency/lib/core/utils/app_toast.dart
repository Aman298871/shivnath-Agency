import 'package:flutter/material.dart';
import '../widgets/app_toast.dart' as widget_toast;

class AppToast {
  static void success(BuildContext context, String message) {
    widget_toast.AppToast.success(context, message);
  }

  static void error(BuildContext context, String message) {
    widget_toast.AppToast.error(context, message);
  }

  static void info(BuildContext context, String message) {
    widget_toast.AppToast.info(context, message);
  }

  static void warning(BuildContext context, String message) {
    widget_toast.AppToast.warning(context, message);
  }
}

