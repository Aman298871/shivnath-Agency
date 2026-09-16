import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'product_service.dart';
import 'session_service.dart';

class ChatService {
  static const String outOfScopeMessage =
      'I can only help you with questions related to this application, its services, products, orders and account.';

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

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/chat/'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 8));

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
      // Graceful fallback to local reasoning engine if server unavailable
    }

    // Local Intelligent Reasoning Engine (Strictly scoped to application domain)
    final localReply = _generateLocalReasoning(message, appType);
    return {
      'success': true,
      'reply': localReply,
    };
  }

  Future<List<Map<String, dynamic>>> getAdminConversations() async {
    final token = await _sessionService.getAccessToken();
    if (token == null || token.isEmpty) return [];

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/chat/admin/conversations/'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        } else if (decoded is Map<String, dynamic> && decoded['conversations'] is List) {
          return List<Map<String, dynamic>>.from(decoded['conversations']);
        }
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> getAdminConversationDetail(int sessionId) async {
    final token = await _sessionService.getAccessToken();
    if (token == null || token.isEmpty) return null;

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/chat/admin/conversations/$sessionId/'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }


  String _generateLocalReasoning(String query, String appType) {
    final msg = query.trim().toLowerCase();
    final isAdmin = appType == 'admin';
    final isFranchise = appType == 'franchise';

    bool hasAny(List<String> patterns) {
      for (final p in patterns) {
        if (msg.contains(p)) return true;
      }
      return false;
    }

    // 1. Greetings & Identity
    if (msg == 'hi' ||
        msg == 'hello' ||
        msg == 'hey' ||
        msg == 'namaste' ||
        msg == 'halo' ||
        msg == 'hola' ||
        msg == 'pranam' ||
        msg == 'namaskar') {
      if (isAdmin) {
        return 'Namaste Admin! 👋\nI am your Pure Water AI Operations Assistant.\n\nI can assist you with:\n• CRM Leads & pipeline management\n• Franchise approvals & verification\n• Inventory stock levels & low-stock alerts\n• Supplier directory & purchase orders\n• Order tracking & live operational metrics\n\nHow can I assist you with operations today?';
      }
      if (isFranchise) {
        return 'Namaste Franchise Partner! 👋\nI am your Pure Water AI Operations Assistant. How can I help you with orders, inventory, dispatch, margins (12%), or franchise operations today?';
      }
      return 'Namaste! 🙏\nWelcome to Shivnath Pure Water. I can help you with product prices, home delivery, placing orders, and franchise information. How can I assist you today?';
    }

    if (hasAny(['who are you', 'what can you do', 'your name', 'aap kaun ho', 'kya kar sakte ho', 'help me', 'madad'])) {
      if (isAdmin) {
        return 'I am the Shivnath Pure Water AI Admin Assistant 💧.\n\nI assist administrators with:\n• Managing Leads, Follow-ups, and Franchise applications\n• Monitoring real-time inventory and supplier details\n• Tracking customer and franchise plant orders\n• Providing live system stats and navigation assistance across the Admin portal.';
      }
      if (isFranchise) {
        return 'I am the Shivnath Pure Water Franchise AI Assistant 💧.\n\nI assist franchise partners with:\n• Placing new plant orders and tracking approval/dispatch\n• Understanding franchise margin (12%) and 5 KM exclusive territory\n• Plant delivery schedules and invoice guidelines.';
      }
      return 'I am the official Pure Water AI Assistant for Shivnath Agency 💧.\n\nI can assist you with:\n• Product pricing & bottle sizes (20L jar, 500ml, 1L)\n• Purity standards (RO, UV, TDS 100-150 ppm)\n• Home & office doorstep delivery in Raipur\n• Franchise partnership terms (12% margins & 5 KM exclusive territory)\n• Order placement and status tracking.';
    }

    // 2. Application In-Scope Intents

    // A. Products & Pricing
    if (hasAny(['product', 'price', 'cost', 'rate', 'mrp', 'rupees', 'charges', 'paani', 'bottle', 'jar', 'can', 'catalog', 'size', 'available', '20l', '500ml', '1l'])) {
      final prods = ProductService.products;
      if (prods.isNotEmpty) {
        final lines = prods.map((p) => '• **${p.name}** (${p.size}): ₹${p.price.toStringAsFixed(2)}').join('\n');
        return '💧 *Live Product Pricing*:\n$lines\n\n*Free delivery on regular and bulk orders in Raipur!*';
      }
      return '💧 *Current Pricing*:\n• **Packaged Drinking Water 20L Jar**: ₹40.00\n• **Natural Mineral Water 500ml (Pack of 24)**: ₹240.00\n• **Pure Drinking Water 1L Bottle**: ₹20.00';
    }

    // B. Order Placement
    if (hasAny(['order', 'buy', 'purchase', 'place', 'cart', 'checkout', 'mangwa', 'kaise'])) {
      if (isFranchise) {
        return '📦 *Placing Franchise Plant Orders*:\n1. Open the **Orders** tab in Franchise portal.\n2. Tap **+ New Order**.\n3. Choose water size (e.g. 20L Jar / 500ml Box), quantity, and delivery instructions.\n4. Submit order — it enters **Plant Approval** and central dispatch within 24-48 hours.';
      }
      return '🛒 *How to Place an Order*:\n1. Tap the **Products** tab or browse on Home.\n2. Select your required water jars or bottle packs and tap **Add to Cart**.\n3. Go to **Cart**, enter your delivery address, select payment mode (Cash on Delivery or UPI), and tap **Place Order**.\n4. Track live delivery in the **My Orders** screen!';
    }

    // C. Order Tracking
    if (hasAny(['track', 'status', 'where is', 'previous', 'past', 'history', 'dispatch'])) {
      return '📍 You can track live dispatch and delivery stages of any order anytime under the **My Orders** screen.';
    }

    // D. Leads & CRM
    if (hasAny(['lead', 'crm', 'prospect', 'pipeline'])) {
      return '📋 *Lead Management*:\n• Navigate to the **Leads** tab to view your CRM pipeline.\n• Tap **+ Add Lead** to record prospective partners and update stages (Contacted -> Follow-up -> Interested -> Confirmed).';
    }

    // E. Franchise Information
    if (hasAny(['franchise', 'dealer', 'distributor', 'partner', 'margin', 'territory', 'commission', 'investment', '5 km', '5km'])) {
      return '🏢 *Shivnath Franchise Opportunity*:\n• **Exclusive Territory**: Guaranteed 5 KM radius exclusive sales zone.\n• **Profit Margins**: Attractive 12% operational commission on all plant deliveries.\n• **Investment Range**: ₹3 Lakh – ₹10 Lakh (includes refundable security deposit & initial stock).\n• **Company Support**: Branding, CRM software, marketing collateral, and guaranteed supply.\n• **How to Apply**: Tap "Apply for Franchise (Qualify Now)" in chat or fill the registration form on login.';
    }

    // F. Inventory & Stock
    if (hasAny(['inventory', 'stock', 'raw material', 'caps', 'preforms', 'labels'])) {
      return '📦 *Inventory Tracking*:\n• Go to the **Inventory** section to check current stock levels of raw materials (caps, preforms, labels) and finished jars.\n• Low-stock alerts highlight items below minimum thresholds.';
    }

    // G. Suppliers
    if (hasAny(['supplier', 'vendor', 'procurement'])) {
      return '🚚 *Supplier Management*:\n• Open the **Suppliers** tab to view verified vendors, contact details, GST, and categories.\n• Tap **+ Add Supplier** to register new material partners.';
    }

    // H. Follow-ups
    if (hasAny(['follow', 'schedule', 'reminder'])) {
      return '📅 *Follow-up Scheduling*:\n• Open **Follow-ups** tab to schedule calls and meetings with partner prospects.\n• Reminders are prioritized on the Dashboard.';
    }

    // I. Purity & Standards
    if (hasAny(['quality', 'tds', 'purif', 'ro', 'uv', 'clean', 'safe', 'mineral', 'pure', 'fssai', 'bis'])) {
      return '✨ *Shivnath Purity Standards*:\n• **Multi-Stage Filtration**: Sand Filtration -> Activated Carbon -> Reverse Osmosis (RO) -> Ultra Violet (UV) Treatment -> Ozonization.\n• **Optimal TDS**: Balanced between 100 - 150 ppm with essential calcium and magnesium electrolytes.\n• **Certifications**: BIS & FSSAI certified bottling plant ensuring 100% microbiological safety.';
    }

    // J. Delivery
    if (hasAny(['delivery', 'area', 'timing', 'raipur', 'doorstep'])) {
      return '🚚 *Delivery Details*:\n• **Service Areas**: Fast doorstep delivery across Raipur and surrounding franchise territories.\n• **Delivery Timing**: Same-day delivery for orders placed before 2:00 PM; within 24 hours for evening orders.\n• **Working Hours**: Monday to Saturday, 8:00 AM – 8:00 PM.';
    }

    // K. Payment
    if (hasAny(['payment', 'cod', 'cash', 'upi', 'gpay', 'phonepe', 'paytm', 'invoice', 'bill'])) {
      return '💳 *Accepted Payment Methods*:\n• **Cash on Delivery (COD)**: Pay cash when your water is delivered at your doorstep.\n• **UPI / QR Code**: Pay via Google Pay, PhonePe, or Paytm upon delivery.\n• **Franchise Billing**: Direct bank transfer & credit terms as per agreement.';
    }

    // L. Profile & Account
    if (hasAny(['profile', 'account', 'address', 'password', 'settings'])) {
      return '👤 *Account & Profile*:\n• Manage your name, contact phone, and delivery addresses from the **Profile** or **Settings** screen.';
    }

    // M. Contact & Support
    if (hasAny(['contact', 'support', 'phone', 'email', 'office', 'call', 'location'])) {
      return '📞 *Shivnath Agency Contact & Support*:\n• **Customer Care / WhatsApp**: +91 98062 47194\n• **Email**: info@pathideainfotech.com / support@shivnathagency.com\n• **Head Office**: H Block, 2nd Floor, Farishta Complex, Raipur, Chhattisgarh – 492001\n• **Hours**: 9:00 AM – 7:00 PM (Mon-Sat)';
    }

    // 3. Out-of-scope refusal
    return outOfScopeMessage;
  }
}
