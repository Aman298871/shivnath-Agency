import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static const String brandName = 'Shivnath Drinking Water';
  static const String officialSupportPhone = '+919806247194';

  /// Cleans and formats phone number for WhatsApp wa.me URL.
  static String formatPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 10) {
      cleaned = '91$cleaned';
    }
    return cleaned;
  }

  /// Opens WhatsApp with a pre-filled message.
  static Future<bool> openWhatsApp({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = formatPhone(phone);
    final encodedMessage = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      return false;
    }
  }

  /// 1. Instant Welcome Message Template (Page 2 of PDF)
  static String getWelcomeMessage({required String leadName}) {
    return 'Namaste $leadName 👋\n\n'
        'Thank you for your interest in our $brandName Franchise.\n\n'
        'Our team will contact you shortly. Meanwhile, please select one of the options below:\n'
        '1️⃣ Franchise Details\n'
        '2️⃣ Investment Required\n'
        '3️⃣ Profit Margin\n'
        '4️⃣ Location Availability\n'
        '5️⃣ Talk to Sales Executive\n\n'
        '- Shivnath Agency Automation Team';
  }

  /// 2. 15-Day Automated Follow-up Journey Templates (Page 4 of PDF)
  static String getFollowUpTemplate(int day, {required String leadName}) {
    switch (day) {
      case 1:
        return getWelcomeMessage(leadName: leadName);

      case 3:
        return 'Namaste $leadName 👋\n\n'
            'Here is the complete *Digital Brochure* for the $brandName Franchise opportunity.\n'
            'Learn about our manufacturing standards, product range (250ml to 20L jars), and high-return ROI model.\n\n'
            'Would you like a quick 5-minute call today to discuss your city allocation?';

      case 5:
        return 'Namaste $leadName 👋\n\n'
            '🌟 *Success Story Spotlight*:\n'
            'Discover how our franchise partners scale to 1,000+ daily jars in under 90 days with our digital ordering and route management platform.\n\n'
            'Reply "YES" to connect with our territory manager.';

      case 7:
        return 'Namaste $leadName 👋\n\n'
            '🎥 *Plant & Quality Showcase*:\n'
            'Take a virtual tour of our state-of-the-art RO + UV + Ozonation manufacturing unit and high-speed automated bottling lines.\n\n'
            'Pure water delivered with trust.';

      case 10:
        return 'Namaste $leadName 👋\n\n'
            '📞 *Call Reminder*:\n'
            'Our Senior Franchise Executive would like to schedule your territory visit and commercial viability assessment.\n\n'
            'What time today works best for you?';

      case 15:
        return 'Namaste $leadName 👋\n\n'
            '🎁 *Limited-Time Franchise Offer*:\n'
            'Special incentive on initial inventory and zero marketing fee for new territory bookings this month.\n\n'
            'Let us know if you would like to secure your preferred location!';

      default:
        return 'Namaste $leadName 👋\n\n'
            'Checking in from $brandName regarding your franchise inquiry. How can we assist you today?';
    }
  }

  /// Customer Order Confirmation Template
  static String getOrderConfirmationMessage({
    required String customerName,
    required String orderId,
    required String amount,
  }) {
    return 'Namaste $customerName,\n\n'
        'Your $brandName order #$orderId (Amount: ₹$amount) has been confirmed!\n'
        'Our delivery team will arrive with fresh pure drinking water shortly.\n\n'
        'Track orders live inside the Shivnath Agency App.';
  }
}
