import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactActionHelper {
  /// Cleans phone number by removing spaces, dashes, brackets, etc.
  static String cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '').trim();
  }

  /// Normalizes Indian 10-digit number to +91XXXXXXXXXX for WhatsApp
  static String formatForWhatsApp(String phone) {
    String cleaned = cleanPhoneNumber(phone);
    if (cleaned.startsWith('+')) {
      return cleaned.substring(1);
    }
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      return cleaned;
    }
    if (cleaned.length == 10) {
      return '91$cleaned';
    }
    return cleaned;
  }

  /// Opens the system dialer with the phone number pre-filled.
  /// Does NOT auto-dial. The user initiates the call.
  static Future<void> makePhoneCall(BuildContext context, String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid contact number available to call.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final cleaned = cleanPhoneNumber(phone);
    if (cleaned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid contact number format.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open phone dialer for $phone.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening dialer: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Opens SMS messaging app with pre-filled number and optional text
  static Future<bool> sendSMS(BuildContext context, String phone, {String? body}) async {
    final cleaned = cleanPhoneNumber(phone);
    if (cleaned.isEmpty) return false;

    final Uri uri = Uri(
      scheme: 'sms',
      path: cleaned,
      queryParameters: body != null && body.isNotEmpty ? {'body': body} : null,
    );

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Opens WhatsApp chat with pre-filled number and optional text
  static Future<bool> openWhatsApp(BuildContext context, String phone, {String? body}) async {
    final waNumber = formatForWhatsApp(phone);
    if (waNumber.isEmpty) return false;

    // Try native whatsapp:// scheme first
    final textParam = body != null && body.isNotEmpty ? Uri.encodeComponent(body) : '';
    final nativeUri = Uri.parse(
      'whatsapp://send?phone=$waNumber${textParam.isNotEmpty ? '&text=$textParam' : ''}',
    );

    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // Fallback to https://wa.me
    final webUri = Uri.parse(
      'https://wa.me/$waNumber${textParam.isNotEmpty ? '?text=$textParam' : ''}',
    );
    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Shows chooser bottom sheet with WhatsApp and SMS options
  static void openMessagingChooser(
    BuildContext context, {
    required String? phone,
    String? contactName,
    String? defaultMessage,
  }) {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No contact number available to message.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final cleaned = cleanPhoneNumber(phone);
    final displayName = contactName?.trim().isNotEmpty == true ? contactName!.trim() : cleaned;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_outlined, color: Color(0xFF0F172A), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Message $displayName',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  phone,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat, color: Color(0xFF25D366)),
                  ),
                  title: const Text('WhatsApp Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Start WhatsApp conversation'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final success = await openWhatsApp(context, phone, body: defaultMessage);
                    if (!success && context.mounted) {
                      // Fallback to SMS if WhatsApp fails
                      final smsOk = await sendSMS(context, phone, body: defaultMessage);
                      if (!smsOk && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not open messaging for $phone.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sms_outlined, color: Colors.blue),
                  ),
                  title: const Text('SMS Message', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Open default messaging app'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final success = await sendSMS(context, phone, body: defaultMessage);
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not open SMS app for $phone.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
