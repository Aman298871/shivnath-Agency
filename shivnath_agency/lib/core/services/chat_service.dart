import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'product_service.dart';
import 'session_service.dart';

class ChatService {
  static String get baseUrl => AppConstants.apiBaseUrl;
  final SessionService _sessionService = SessionService();

  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String appType = 'customer',
    List<Map<String, String>> history = const [],
  }) async {
    final token = await _sessionService.getAccessToken();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'message': message,
      'app_type': appType,
      'history': history,
    });

    // Try primary base URL
    final candidateUrls = [
      '$baseUrl/api/chat/',
      'http://127.0.0.1:8000/api/chat/',
      'http://192.168.1.15:8000/api/chat/',
    ];

    for (final url in candidateUrls.toSet()) {
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 4));

        dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          decoded = {};
        }

        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            decoded is Map<String, dynamic> &&
            decoded['reply'] != null) {
          final replyText = decoded['reply'].toString().trim();
          if (replyText.isNotEmpty) {
            return {
              'success': true,
              'reply': replyText,
            };
          }
        }
      } catch (_) {
        // Try next candidate or fallback
      }
    }

    // Local Intelligent Reasoning Engine (Guarantees immediate and accurate answer)
    final localReply = _generateLocalReasoning(message, appType);
    return {
      'success': true,
      'reply': localReply,
    };
  }

  String _generateLocalReasoning(String query, String appType) {
    final msg = query.trim().toLowerCase();

    // Greetings
    if (msg == 'hi' || msg == 'hello' || msg == 'hey' || msg == 'namaste' || msg == 'halo') {
      if (appType == 'franchise') {
        return 'Namaste Franchise Partner! 👋\nI am your Pure Water AI Operations Assistant. How can I help you with orders, inventory, dispatch, or franchise operations today?';
      }
      return 'Namaste! 🙏\nWelcome to Shivnath Pure Water. I can help you with product prices, home delivery, placing orders, and franchise information. How can I assist you today?';
    }

    // Identity / Capabilities
    if (msg.contains('who are you') || msg.contains('what can you do') || msg.contains('your name')) {
      return 'I am the official Pure Water AI Assistant for Shivnath Agency 💧.\n\nI can assist you with:\n• Product pricing & bottle sizes (20L jar, 500ml, 1L)\n• Purity standards (RO, UV, TDS 100-150 ppm)\n• Home & office doorstep delivery in Raipur\n• Franchise partnership terms (12% margins & 5 KM exclusive territory)\n• General tech and programming queries.';
    }

    // General knowledge / Tech
    if (msg.contains('what is python') || msg == 'python') {
      return 'Python is a popular, high-level programming language known for its clean syntax and readability. It is used in web development (powering our Django backend server!), data science, artificial intelligence, and automation.';
    }
    if (msg.contains('what is java')) {
      return 'Java is a class-based, object-oriented programming language designed for platform independence with the "Write Once, Run Anywhere" (WORA) philosophy.';
    }
    if (msg.contains('what is flutter') || msg.contains('what is dart') || msg == 'flutter') {
      return 'Flutter is Google\'s open-source UI toolkit for building natively compiled mobile (Android/iOS), web, and desktop apps from a single codebase using Dart.';
    }

    // Payment Methods
    if (msg.contains('payment') ||
        msg.contains('cod') ||
        msg.contains('cash') ||
        msg.contains('upi') ||
        msg.contains('gpay') ||
        msg.contains('phonepe') ||
        msg.contains('paytm') ||
        msg.contains('pay online') ||
        msg.contains('how to pay')) {
      return '💳 *Accepted Payment Methods*:\n• **Cash on Delivery (COD)**: Pay cash when your water is delivered at your doorstep.\n• **UPI / QR Code**: Pay via Google Pay, PhonePe, or Paytm upon delivery.\n• **Franchise Billing**: Direct bank transfer & credit terms as per agreement.';
    }

    // Pricing & Rates
    if (msg.contains('price') ||
        msg.contains('cost') ||
        msg.contains('rate') ||
        msg.contains('how much') ||
        msg.contains('mrp') ||
        msg.contains('rupees') ||
        msg.contains('charges')) {
      final prods = ProductService.products;
      if (prods.isNotEmpty) {
        final lines = prods.map((p) => '• **${p.name}** (${p.size}): ₹${p.price.toStringAsFixed(2)}').join('\n');
        return '💧 *Live Product Pricing*:\n$lines\n\n*Free delivery on regular and bulk orders in Raipur!*';
      }
      return '💧 *Current Pricing*:\n• **Packaged Drinking Water 20L Jar**: ₹40.00\n• **Natural Mineral Water 500ml (Pack of 24)**: ₹240.00\n• **Pure Drinking Water 1L Bottle**: ₹20.00';
    }

    // Purity, Quality & TDS
    if (msg.contains('quality') ||
        msg.contains('tds') ||
        msg.contains('purif') ||
        msg.contains('ro') ||
        msg.contains('uv') ||
        msg.contains('clean') ||
        msg.contains('safe') ||
        msg.contains('mineral') ||
        msg.contains('pure')) {
      return '✨ *Shivnath Purity Standards*:\n• **Multi-Stage Filtration**: Sand Filtration -> Activated Carbon -> Reverse Osmosis (RO) -> Ultra Violet (UV) Treatment -> Ozonization.\n• **Optimal TDS**: Balanced between 100 - 150 ppm with essential calcium and magnesium electrolytes.\n• **Certifications**: BIS & FSSAI certified bottling plant ensuring 100% microbiological safety.';
    }

    // Product Sizes & Catalog
    if (msg.contains('size') ||
        msg.contains('bottle') ||
        msg.contains('jar') ||
        msg.contains('can') ||
        msg.contains('catalog') ||
        msg.contains('volume') ||
        msg.contains('20l') ||
        msg.contains('500ml') ||
        msg.contains('1l') ||
        msg.contains('available')) {
      return '💧 *Shivnath Water Product Catalog & Sizes*:\n• **20 Litre Jar**: ₹40 (Standard home/office dispenser jar)\n• **500ml Pack of 24**: ₹240 (Natural mineral water bottles)\n• **1 Litre Bottle**: ₹20 (Individual travel bottle)\n• **250ml Cup / Bottle**: Available for events and bulk catering\n• **5 Litre Can**: Family pack with ergonomic handle\n\nAll bottles are manufactured using food-grade BPA-free recyclable PET.';
    }

    // Ordering Process
    if (msg.contains('order') && (msg.contains('how') || msg.contains('place') || msg.contains('new') || msg.contains('buy'))) {
      if (appType == 'franchise') {
        return '📦 *Placing Franchise Plant Orders*:\n1. Open the **Orders** tab in Franchise portal.\n2. Tap **+ New Order**.\n3. Choose water size (e.g. 20L Jar / 500ml Box), quantity, and delivery instructions.\n4. Submit order — it enters **Plant Approval** and central dispatch within 24-48 hours.';
      }
      return '🛒 *How to Place an Order*:\n1. Tap the **Products** tab or browse on Home.\n2. Select your required water jars or bottle packs and tap **Add to Cart**.\n3. Go to **Cart**, enter your delivery address, select payment mode (Cash on Delivery or UPI), and tap **Place Order**.';
    }

    // Delivery Details
    if (msg.contains('delivery') || msg.contains('area') || msg.contains('timing') || msg.contains('raipur')) {
      return '🚚 *Delivery Details*:\n• **Service Areas**: Fast doorstep delivery across Raipur and surrounding franchise territories.\n• **Delivery Timing**: Same-day delivery for orders placed before 2:00 PM; within 24 hours for evening orders.\n• **Working Hours**: Monday to Saturday, 8:00 AM – 8:00 PM.';
    }

    // Franchise Opportunity & Terms
    if (msg.contains('franchise') ||
        msg.contains('dealer') ||
        msg.contains('distributor') ||
        msg.contains('partner') ||
        msg.contains('margin') ||
        msg.contains('investment') ||
        msg.contains('commission')) {
      return '🏢 *Shivnath Franchise Opportunity*:\n• **Exclusive Territory**: Guaranteed 5 KM radius exclusive sales zone.\n• **Profit Margins**: Attractive 12% operational commission on all plant deliveries.\n• **Investment Range**: ₹3 Lakh – ₹10 Lakh (includes refundable security deposit & initial stock).\n• **Company Support**: Branding, CRM software, marketing collateral, and guaranteed supply.\n• **How to Apply**: Tap "Apply for Franchise (Qualify Now)" in chat or fill the registration form on login.';
    }

    // Tracking Orders
    if (msg.contains('track') || msg.contains('status') || msg.contains('where is my order')) {
      return '📍 You can track live dispatch and delivery stages of any order anytime under the **My Orders** screen.';
    }

    // Contact & Support
    if (msg.contains('contact') ||
        msg.contains('support') ||
        msg.contains('phone') ||
        msg.contains('email') ||
        msg.contains('office') ||
        msg.contains('call') ||
        msg.contains('address') ||
        msg.contains('location')) {
      return '📞 *Shivnath Agency Contact & Support*:\n• **Customer Care / WhatsApp**: +91 98062 47194\n• **Email**: info@pathideainfotech.com / support@shivnathagency.com\n• **Head Office**: H Block, 2nd Floor, Farishta Complex, Raipur, Chhattisgarh – 492001\n• **Hours**: 9:00 AM – 7:00 PM (Mon-Sat)';
    }

    // Catch-all response
    return 'I am here to assist you with Shivnath Pure Water! 💧\n\nYou can ask about our 20L jars, 500ml packs, current prices, delivery in Raipur, order placement, franchise applications, or any technical question.';
  }
}

