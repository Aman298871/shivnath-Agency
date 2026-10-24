import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'session_service.dart';
import '../../models/user_model.dart';

class SupportContactInfo {
  final int? id;
  final String role;
  final String roleDisplay;
  final String name;
  final String phone;
  final String email;
  final String messageTemplate;
  final String target;
  final String? ownerName;

  SupportContactInfo({
    this.id,
    this.role = '',
    this.roleDisplay = '',
    required this.name,
    required this.phone,
    this.email = '',
    this.messageTemplate = '',
    this.target = 'central',
    this.ownerName,
  });

  factory SupportContactInfo.fromJson(Map<String, dynamic> json) {
    return SupportContactInfo(
      id: json['id'] is int ? json['id'] : null,
      role: json['role']?.toString() ?? '',
      roleDisplay: json['role_display']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Shivnath Agency Support',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      messageTemplate: json['message_template']?.toString() ?? '',
      target: json['target']?.toString() ?? 'central',
      ownerName: json['owner_name']?.toString(),
    );
  }
}

class SupportDeskService {
  static final AuthService _authService = AuthService();
  static final SessionService _sessionService = SessionService();

  /// Formats phone number by removing spaces, hyphens and special chars.
  static String formatCleanPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    String digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length == 10) {
      return '+91$digitsOnly';
    }
    return cleaned;
  }

  /// Formats phone number for WhatsApp wa.me link (without '+' symbol)
  static String formatWhatsAppPhone(String phone) {
    String digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length == 10) {
      return '91$digitsOnly';
    }
    return digitsOnly;
  }

  static const String adminPhone = '+91 98264 21818';

  static SupportContactInfo get adminContact => SupportContactInfo(
    id: 1,
    name: 'Admin Support Desk',
    phone: adminPhone,
    email: 'admin@shivnath.com',
    role: 'admin',
    roleDisplay: 'Central Admin Support Desk',
    messageTemplate:
        'Namaste Admin Support,\nI require operational assistance regarding Shivnath Agency.',
    target: 'admin',
  );

  static SupportContactInfo get defaultContact => SupportContactInfo(
    id: 2,
    name: 'Admin Support Desk',
    phone: adminPhone,
    email: 'support@shivnath.com',
    role: 'admin',
    roleDisplay: 'Central Customer Helpline & Admin Desk',
    messageTemplate:
        'Namaste Shivnath Support,\nI require assistance with my drinking water supply.',
    target: 'central',
  );

  static List<SupportContactInfo> get defaultAllContacts => [
    adminContact,
    SupportContactInfo(
      id: 2,
      role: 'customer',
      roleDisplay: 'Customer Support Desk',
      name: 'Shivnath Agency Support Desk',
      phone: adminPhone,
      email: 'support@shivnath.com',
      messageTemplate:
          'Namaste Shivnath Support,\nI require assistance with my drinking water supply.',
      target: 'central',
    ),
    SupportContactInfo(
      id: 3,
      role: 'franchise',
      roleDisplay: 'Franchise Partner Desk',
      name: 'Franchise Operations Desk',
      phone: adminPhone,
      email: 'franchise@shivnath.com',
      messageTemplate:
          'Namaste Shivnath Franchise Desk,\nI have an enquiry regarding franchise operations.',
      target: 'central',
    ),
  ];

  /// Fetches contextual support contact from backend DB.
  static Future<SupportContactInfo> fetchSupportContact({
    String? role,
    String? inquiryType,
  }) async {
    final effectiveRole = (role ?? inquiryType ?? '').toLowerCase();
    try {
      final res = await _authService.getSupportContact(
        role: role,
        inquiryType: inquiryType,
      );

      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final contact = SupportContactInfo.fromJson(
          res['data'] as Map<String, dynamic>,
        );
        if (contact.phone.isNotEmpty) {
          return contact;
        }
      }
    } catch (_) {}

    return effectiveRole == 'admin' ? adminContact : defaultContact;
  }

  /// Fetches all configured support contacts (Admin only)
  static Future<List<SupportContactInfo>> fetchAllSupportContacts() async {
    try {
      final res = await _authService.getSupportContact(fetchAll: true);
      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final list = res['data']['contacts'];
        if (list is List && list.isNotEmpty) {
          final contacts = list
              .whereType<Map>()
              .map(
                (item) => SupportContactInfo.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();

          // Ensure admin contact is available in the list with 9826421818
          if (!contacts.any((c) => c.role.toLowerCase() == 'admin')) {
            contacts.insert(0, adminContact);
          }
          return contacts;
        }
      }
    } catch (_) {}

    return defaultAllContacts;
  }

  /// Updates a support contact record (Admin only)
  static Future<Map<String, dynamic>> updateSupportContact({
    required String role,
    required String name,
    required String phone,
    String email = '',
    String messageTemplate = '',
  }) async {
    return await _authService.updateSupportContact(
      role: role,
      name: name,
      phone: phone,
      email: email,
      messageTemplate: messageTemplate,
    );
  }

  /// Builds context-aware enquiry message template without null/undefined fields.
  static Future<String> buildContextAwareMessage({
    String? name,
    String? mobile,
    String? email,
    String? role,
    String? initialEnquiry,
  }) async {
    UserModel? currentUser = await _sessionService.getUser();

    final resolvedName =
        (name ?? currentUser?.name ?? currentUser?.businessName ?? '').trim();
    final resolvedMobile = (mobile ?? currentUser?.phone ?? '').trim();
    final resolvedEmail = (email ?? currentUser?.email ?? '').trim();

    String resolvedRole = (role ?? '').trim();
    if (resolvedRole.isEmpty && currentUser != null) {
      if (currentUser.role.toLowerCase() == 'customer') {
        resolvedRole = 'Customer';
      } else if (currentUser.role.toLowerCase() == 'franchise') {
        resolvedRole = 'Franchise';
      } else if (currentUser.role.toLowerCase() == 'admin') {
        resolvedRole = 'Administrator';
      } else {
        resolvedRole = currentUser.role;
      }
    }
    if (resolvedRole.isEmpty) {
      resolvedRole = 'Customer Inquiry';
    }

    final greetingName = resolvedName.isNotEmpty ? resolvedName : 'User';

    final buffer = StringBuffer();
    buffer.writeln('Namaste, my name is $greetingName.');
    buffer.writeln(
      'I am contacting Shivnath Agency Support regarding an enquiry.',
    );
    buffer.writeln();
    buffer.writeln('My details:');
    if (resolvedName.isNotEmpty) {
      buffer.writeln('Name: $resolvedName');
    }
    if (resolvedMobile.isNotEmpty) {
      buffer.writeln('Mobile: $resolvedMobile');
    }
    if (resolvedEmail.isNotEmpty) {
      buffer.writeln('Email: $resolvedEmail');
    }
    if (resolvedRole.isNotEmpty) {
      buffer.writeln('Role: $resolvedRole');
    }
    buffer.writeln();
    buffer.writeln('I would like to enquire about:');
    if (initialEnquiry != null && initialEnquiry.trim().isNotEmpty) {
      buffer.writeln(initialEnquiry.trim());
    }

    return buffer.toString().trim();
  }

  /// Shows the Contact Support action dialog (Call / Chat).
  static Future<void> showContactActionSheet(
    BuildContext context, {
    required String phone,
    String? supportName,
    String? userName,
    String? userMobile,
    String? userEmail,
    String? userRole,
    String? initialEnquiry,
  }) async {
    final cleanDisplayPhone = phone.trim();
    if (cleanDisplayPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support phone number is not configured.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.contact_phone_rounded,
                      color: Color(0xFF0284C7),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contact Support',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          supportName != null && supportName.isNotEmpty
                              ? '$supportName • $cleanDisplayPhone'
                              : cleanDisplayPhone,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.phone_rounded, size: 20),
                label: const Text(
                  'Call Support Number',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  initiateCall(context, cleanDisplayPhone);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                label: const Text(
                  'Chat with Support',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  showChatAppChooser(
                    context,
                    phone: cleanDisplayPhone,
                    userName: userName,
                    userMobile: userMobile,
                    userEmail: userEmail,
                    userRole: userRole,
                    initialEnquiry: initialEnquiry,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Initiates a phone call via system intent / URL launcher.
  static Future<void> initiateCall(BuildContext context, String phone) async {
    final cleanPhone = formatCleanPhone(phone);
    final Uri callUri = Uri.parse('tel:$cleanPhone');

    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri, mode: LaunchMode.externalApplication);
      } else {
        final launched = await launchUrl(
          callUri,
          mode: LaunchMode.platformDefault,
        );
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No phone or calling application available on this device.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open phone dialer. Please dial manually.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Shows available chat applications (WhatsApp / SMS) with context pre-filled message.
  static Future<void> showChatAppChooser(
    BuildContext context, {
    required String phone,
    String? userName,
    String? userMobile,
    String? userEmail,
    String? userRole,
    String? initialEnquiry,
  }) async {
    final prefilledMessage = await buildContextAwareMessage(
      name: userName,
      mobile: userMobile,
      email: userEmail,
      role: userRole,
      initialEnquiry: initialEnquiry,
    );

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Select Chat Application',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enquiry will be pre-filled. You can edit before sending.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),

              // WhatsApp Option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.green.shade200, width: 1.5),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF25D366),
                    size: 24,
                  ),
                ),
                title: const Text(
                  'WhatsApp',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: const Text('Chat instantly on WhatsApp'),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  launchWhatsApp(
                    context,
                    phone: phone,
                    message: prefilledMessage,
                  );
                },
              ),

              const SizedBox(height: 12),

              // SMS Option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.blue.shade200, width: 1.5),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sms_outlined,
                    color: Color(0xFF0284C7),
                    size: 24,
                  ),
                ),
                title: const Text(
                  'SMS Message',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: const Text('Send standard text message (SMS)'),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  launchSMS(context, phone: phone, message: prefilledMessage);
                },
              ),

              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Launches WhatsApp with pre-filled enquiry message.
  static Future<void> launchWhatsApp(
    BuildContext context, {
    required String phone,
    required String message,
  }) async {
    final cleanPhone = formatWhatsAppPhone(phone);
    final encodedMessage = Uri.encodeComponent(message);

    final Uri waMeUri = Uri.parse(
      'https://wa.me/$cleanPhone?text=$encodedMessage',
    );
    final Uri waNativeUri = Uri.parse(
      'whatsapp://send?phone=$cleanPhone&text=$encodedMessage',
    );

    try {
      if (await canLaunchUrl(waNativeUri)) {
        await launchUrl(waNativeUri, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(waMeUri)) {
        await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
        return;
      }

      // Fallback
      final launched = await launchUrl(
        waMeUri,
        mode: LaunchMode.platformDefault,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'WhatsApp is not available on your device. Launching SMS instead...',
            ),
            action: SnackBarAction(
              label: 'Open SMS',
              textColor: Colors.amber,
              onPressed: () =>
                  launchSMS(context, phone: phone, message: message),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp is not available on your device.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    }
  }

  /// Launches SMS app with pre-filled enquiry message.
  static Future<void> launchSMS(
    BuildContext context, {
    required String phone,
    required String message,
  }) async {
    final cleanPhone = formatCleanPhone(phone);
    final encoded = Uri.encodeComponent(message);

    final Uri smsUri = Uri.parse('sms:$cleanPhone?body=$encoded');

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } else {
        final launched = await launchUrl(
          smsUri,
          mode: LaunchMode.platformDefault,
        );
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No supported SMS application available on this device.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not launch SMS app. Please send an SMS manually.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
