import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../services/chat_service.dart';
import '../services/whatsapp_service.dart';

enum ChatbotMode {
  public,
  customer,
  franchise,
  admin
}

class AiChatbotModal extends StatefulWidget {
  final ChatbotMode mode;

  const AiChatbotModal({
    super.key,
    required this.mode,
  });

  static Future<void> show(BuildContext context, {required ChatbotMode mode}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiChatbotModal(mode: mode),
    );
  }

  @override
  State<AiChatbotModal> createState() => _AiChatbotModalState();
}

class _ChatOptionItem {
  final int? id;
  final String title;
  final String? answerText;
  final bool isLeadTrigger;
  final bool isBackButton;
  final bool isRootSelection;
  final bool isPdfDownload;
  final bool isStartNewEnquiry;
  final int? quotationId;
  final String inquiryType;
  final List<_ChatOptionItem> children;

  _ChatOptionItem({
    this.id,
    required this.title,
    this.answerText,
    this.isLeadTrigger = false,
    this.isBackButton = false,
    this.isRootSelection = false,
    this.isPdfDownload = false,
    this.isStartNewEnquiry = false,
    this.quotationId,
    this.inquiryType = 'customer',
    this.children = const [],
  });

  factory _ChatOptionItem.fromJson(Map<String, dynamic> json) {
    List<_ChatOptionItem> childList = [];
    if (json['children'] is List) {
      childList = (json['children'] as List)
          .whereType<Map>()
          .map((c) => _ChatOptionItem.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }
    return _ChatOptionItem(
      id: json['id'] as int?,
      title: json['title']?.toString() ?? '',
      answerText: json['answer_text']?.toString(),
      isLeadTrigger: json['is_lead_trigger'] == true,
      quotationId: json['quotation'] is int ? json['quotation'] as int : (json['quotation'] is Map ? json['quotation']['id'] as int? : null),
      inquiryType: json['inquiry_type']?.toString() ?? 'customer',
      children: childList,
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<_ChatOptionItem>? optionItems;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.optionItems,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _AiChatbotModalState extends State<AiChatbotModal> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  final ChatService _chatService = ChatService();
  bool _isTyping = false;
  String? _lockedInquiryType; // 'customer' or 'franchise' or 'admin'
  String? _currentInquiryType;
  bool _leadCaptureCompleted = false;

  // Dynamic Options Tree from Backend
  List<_ChatOptionItem> _customerTree = [];
  List<_ChatOptionItem> _franchiseTree = [];

  // Navigation stack and option consumption memory
  final List<List<_ChatOptionItem>> _navStack = [];
  final Set<int> _consumedOptionIds = {};
  final Set<String> _consumedOptionTitles = {};
  final List<String> _selectedOptionTrail = [];

  // Lead qualification flow state
  int _qualificationStep = 0;
  final Map<String, dynamic> _leadData = {};
  String? _activeSessionId;

  @override
  void initState() {
    super.initState();
    if (widget.mode != ChatbotMode.public) {
      _leadCaptureCompleted = true;
    }
    _customerTree = _getDefaultCustomerOptions();
    _franchiseTree = _getDefaultFranchiseOptions();
    _initChatbot();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initChatbot() async {
    if (widget.mode == ChatbotMode.public) {
      _lockedInquiryType = null;
      _leadCaptureCompleted = false;
      final initialOptions = [
        _ChatOptionItem(
          title: '1. Customer / Product Inquiry',
          inquiryType: 'customer',
          isRootSelection: true,
        ),
        _ChatOptionItem(
          title: '2. Franchise Inquiry',
          inquiryType: 'franchise',
          isRootSelection: true,
        ),
      ];

      setState(() {
        _messages.add(
          _ChatMessage(
            text:
                'Namaste! 🙏 Welcome to Shivnath Pure Packaged Drinking Water.\n\nPlease select the nature of your inquiry below or type any question directly.',
            isUser: false,
            optionItems: initialOptions,
          ),
        );
      });

      // Fetch dynamic trees from Backend in background
      try {
        final custRaw = await _chatService.getPublicOptions(inquiryType: 'customer', tree: true);
        final franRaw = await _chatService.getPublicOptions(inquiryType: 'franchise', tree: true);

        if (custRaw.isNotEmpty) {
          _customerTree = custRaw.map((m) => _ChatOptionItem.fromJson(m)).toList();
        }
        if (franRaw.isNotEmpty) {
          _franchiseTree = franRaw.map((m) => _ChatOptionItem.fromJson(m)).toList();
        }
      } catch (_) {}
    } else if (widget.mode == ChatbotMode.customer) {
      _lockedInquiryType = 'customer';
      _leadCaptureCompleted = true;
      _navStack.clear();
      _navStack.add(_customerTree);
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Welcome back! How can I assist you with your orders and products today?',
            isUser: false,
            optionItems: _customerTree,
          ),
        );
      });
      // Load dynamically
      try {
        final custRaw = await _chatService.getPublicOptions(inquiryType: 'customer', tree: true);
        if (custRaw.isNotEmpty) {
          setState(() {
            _customerTree = custRaw.map((m) => _ChatOptionItem.fromJson(m)).toList();
            if (_navStack.length == 1) {
              _navStack[0] = _customerTree;
              _messages.last = _ChatMessage(
                text: 'Welcome back! How can I assist you with your orders and products today?',
                isUser: false,
                optionItems: _customerTree,
              );
            }
          });
        }
      } catch (_) {}
    } else if (widget.mode == ChatbotMode.franchise) {
      _lockedInquiryType = 'franchise';
      _leadCaptureCompleted = true;
      _navStack.clear();
      _navStack.add(_franchiseTree);
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Welcome back, Partner! How can I assist you with your franchise operations?',
            isUser: false,
            optionItems: _franchiseTree,
          ),
        );
      });
      // Load dynamically
      try {
        final franRaw = await _chatService.getPublicOptions(inquiryType: 'franchise', tree: true);
        if (franRaw.isNotEmpty) {
          setState(() {
            _franchiseTree = franRaw.map((m) => _ChatOptionItem.fromJson(m)).toList();
            if (_navStack.length == 1) {
              _navStack[0] = _franchiseTree;
              _messages.last = _ChatMessage(
                text: 'Welcome back, Partner! How can I assist you with your franchise operations?',
                isUser: false,
                optionItems: _franchiseTree,
              );
            }
          });
        }
      } catch (_) {}
    } else if (widget.mode == ChatbotMode.admin) {
      _lockedInquiryType = 'admin';
      _leadCaptureCompleted = true;
      final adminTree = _getAdminOptions();
      _navStack.clear();
      _navStack.add(adminTree);
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Welcome Admin! How can I assist with your business and operational data?',
            isUser: false,
            optionItems: adminTree,
          ),
        );
      });
    }
  }

  List<_ChatOptionItem> _getAdminOptions() {
    return [
      _ChatOptionItem(
        title: '1. Leads & CRM',
        inquiryType: 'admin',
        children: [
          _ChatOptionItem(title: 'Total Leads', inquiryType: 'admin'),
          _ChatOptionItem(title: 'New Leads', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Hot Leads', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Warm Leads', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Cold Leads', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Leads Today', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Lead Pipeline', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Customer Leads', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Franchise Leads', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Recent Lead Activity', inquiryType: 'admin'),
        ],
      ),
      _ChatOptionItem(
        title: '2. Follow-ups',
        inquiryType: 'admin',
        children: [
          _ChatOptionItem(title: 'Follow-ups Today', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Pending Follow-ups', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Overdue Follow-ups', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Completed Follow-ups', inquiryType: 'admin'),
        ],
      ),
      _ChatOptionItem(
        title: '3. Customers',
        inquiryType: 'admin',
        children: [
          _ChatOptionItem(title: 'Total Customers', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Recent Customers', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Customer Enquiries', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Customer Orders', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Customer Chat Conversations', inquiryType: 'admin'),
        ],
      ),
      _ChatOptionItem(
        title: '4. Franchisees',
        inquiryType: 'admin',
        children: [
          _ChatOptionItem(title: 'Pending Franchise Approvals', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Approved Franchisees', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Franchise Applications', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Franchise Orders', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Franchise Details', inquiryType: 'admin'),
        ],
      ),
      _ChatOptionItem(
        title: '5. Orders',
        inquiryType: 'admin',
        children: [
          _ChatOptionItem(title: 'Today\'s Orders', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Customer Orders', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Franchise Orders', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Pending Orders', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Approved Orders', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Dispatched Orders', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Delivered Orders', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Payment Pending', inquiryType: 'admin'),
        ],
      ),
      _ChatOptionItem(
        title: '6. Products',
        inquiryType: 'admin',
        children: [
          _ChatOptionItem(title: 'Product Catalogue', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Product Prices', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Product Availability', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Product Sizes', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Compare Products', inquiryType: 'admin'),
        ],
      ),
      _ChatOptionItem(
        title: '7. Inventory',
        inquiryType: 'admin',
        children: [
          _ChatOptionItem(title: 'Current Stock', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Low Stock', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Out of Stock', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Raw Materials', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Finished Products', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Inventory Value', inquiryType: 'admin'),
        ],
      ),
      _ChatOptionItem(
        title: '8. Suppliers',
        inquiryType: 'admin',
        children: [
          _ChatOptionItem(title: 'Suppliers', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Supplier Products', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Purchase Information', inquiryType: 'admin'),
        ],
      ),
      _ChatOptionItem(
        title: '9. Quotations',
        inquiryType: 'admin',
        children: [
          _ChatOptionItem(title: 'Customer Quotations', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Franchise Quotations', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Active Quotations', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Expired Quotations', inquiryType: 'admin'),
        ],
      ),
      _ChatOptionItem(
        title: '10. Chat Conversations',
        inquiryType: 'admin',
        children: [
          _ChatOptionItem(title: 'Recent Conversations', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Customer Conversations', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Franchise Conversations', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Lead Conversations', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Unread Conversations', inquiryType: 'admin'),
        ],
      ),
      _ChatOptionItem(
        title: '11. Dashboard & Reports',
        inquiryType: 'admin',
        children: [
          _ChatOptionItem(title: 'Today\'s Leads', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Conversion Information', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Sales', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Pending Follow-ups', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Inventory Summary', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Outstanding Payments', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Franchise Summary', inquiryType: 'admin'),
        ],
      ),
      _ChatOptionItem(
        title: '12. Notifications',
        inquiryType: 'admin',
        children: [
          _ChatOptionItem(title: 'Total Notifications', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Unread Notifications', inquiryType: 'admin'),
          _ChatOptionItem(title: 'Read Notifications', inquiryType: 'admin'),
        ],
      ),
    ];
  }

  List<_ChatOptionItem> _getDefaultCustomerOptions() {
    return [
      _ChatOptionItem(
        title: '💧 Packaged Water Bottles',
        inquiryType: 'customer',
        children: [
          _ChatOptionItem(
            title: '2 Litre Family Pack',
            inquiryType: 'customer',
            children: [
              _ChatOptionItem(
                title: 'Price & Availability',
                answerText:
                    '💧 *Shivnath 2 Litre Packaged Drinking Water*:\n• Single Bottle: ₹30\n• Family Crate (9 Bottles): ₹260\n• Availability: In Stock\n• 7-Stage RO + UV + Ozonation purified.',
              ),
              _ChatOptionItem(
                title: 'Product Details & Quality',
                answerText:
                    '✨ *2 Litre Family Pack Details*:\n• BIS IS:14543 Certified & FSSAI Licensed\n• Natural minerals with balanced 7.2 pH\n• Heavy-duty tamper-evident seal and convenient carry handle.',
              ),
            ],
          ),
          _ChatOptionItem(
            title: '1 Litre Active Bottle',
            inquiryType: 'customer',
            children: [
              _ChatOptionItem(
                title: 'Price & Availability',
                answerText:
                    '💧 *Shivnath 1 Litre Packaged Water*:\n• Single Bottle: ₹20\n• Box of 12 bottles: ₹220\n• Availability: In Stock\n• Pure mineral-enriched water for daily active hydration.',
              ),
              _ChatOptionItem(
                title: 'Product Details & Quality',
                answerText:
                    '✨ *1 Litre Bottle Details*:\n• 100% food-grade virgin PET packaging\n• Certified pure at plant quality testing laboratory.',
              ),
            ],
          ),
          _ChatOptionItem(
            title: '500ml Travel Bottle',
            inquiryType: 'customer',
            children: [
              _ChatOptionItem(
                title: 'Price & Availability',
                answerText:
                    '💧 *Shivnath 500ml Travel Bottle*:\n• Single Bottle: ₹10\n• Box of 24 bottles: ₹220\n• Availability: In Stock.',
              ),
              _ChatOptionItem(
                title: 'Product Details',
                answerText:
                    '✨ *500ml Travel Size*:\n• Convenient pocket size for travel, dining, conferences, and active lifestyle.',
              ),
            ],
          ),
          _ChatOptionItem(
            title: '250ml Pocket Bottle',
            inquiryType: 'customer',
            children: [
              _ChatOptionItem(
                title: 'Price & Availability',
                answerText:
                    '💧 *Shivnath 250ml Pocket Bottle*:\n• Single Bottle: ₹6\n• Box of 30 bottles: ₹165\n• Availability: In Stock.',
              ),
              _ChatOptionItem(
                title: 'Product Details',
                answerText:
                    '✨ *250ml Mini Bottle*:\n• Ideal for corporate events, parties, catering, conferences, and institutional meetings.',
              ),
            ],
          ),
        ],
      ),
      _ChatOptionItem(
        title: '🚰 20 Litre Water Jar',
        inquiryType: 'customer',
        children: [
          _ChatOptionItem(
            title: 'Jar Price & Security Deposit',
            answerText:
                '🚰 *20 Litre Water Jar*:\n• Refill Rate: ₹60 per jar\n• First-time Refundable Security Deposit: ₹150 per jar\n• High-grade food safe dispenser jar with tamper-proof pull-tab seal.',
          ),
          _ChatOptionItem(
            title: 'Home & Office Daily Subscription',
            answerText:
                '🚚 *Daily Subscription Plan*:\n• Monthly contract: ₹50 per jar\n• Daily morning doorstep delivery across Raipur\n• Dedicated delivery vehicle on scheduled morning route.',
          ),
        ],
      ),
      _ChatOptionItem(
        title: '📦 Orders & Delivery Tracking',
        inquiryType: 'customer',
        children: [
          _ChatOptionItem(
            title: 'How to Track My Orders',
            answerText:
                '📦 *Order Tracking*:\n• You can view live order status under "Recent Orders" on the Home tab.\n• Stages: Placed → Plant Approved → In Transit → Delivered.',
          ),
          _ChatOptionItem(
            title: 'Delivery Timings & Zones',
            answerText:
                '🚚 *Doorstep Delivery Hours*:\n• 7:00 AM to 6:00 PM (All 7 Days)\n• Express delivery across Raipur, Durg-Bhilai, and Rajnandgaon.',
          ),
        ],
      ),
      _ChatOptionItem(
        title: '💳 Payment & Billing',
        inquiryType: 'customer',
        children: [
          _ChatOptionItem(
            title: 'Accepted Payment Methods',
            answerText:
                '💳 *Payment Modes*:\n• Cash on Delivery (COD)\n• UPI (GPay, PhonePe, Paytm, BHIM)\n• Net Banking / Cards on Delivery.',
          ),
          _ChatOptionItem(
            title: 'GST Tax Invoices',
            answerText:
                '📄 *Official Invoices*:\n• GST-compliant invoices are automatically generated for every order.\n• Download directly from your order receipts in the app.',
          ),
        ],
      ),
      _ChatOptionItem(
        title: '📞 Customer Support Desk',
        inquiryType: 'customer',
        children: [
          _ChatOptionItem(
            title: 'Call Support Helpline',
            answerText:
                '📞 *Shivnath Customer Helpline*:\n• Phone: +91 98062 47194\n• Hours: 9:00 AM – 7:00 PM (Monday to Saturday)\n• Head Office: H Block, Farishta Complex, Raipur, CG.',
          ),
          _ChatOptionItem(
            title: 'WhatsApp Customer Desk',
            answerText:
                '💬 Opening official WhatsApp customer support desk at +91 98062 47194. You can also continue typing here.',
          ),
        ],
      ),
    ];
  }

  List<_ChatOptionItem> _getDefaultFranchiseOptions() {
    return [
      _ChatOptionItem(
        title: '🏢 Territory Model & Availability',
        inquiryType: 'franchise',
        children: [
          _ChatOptionItem(
            title: 'Territory Model Details',
            answerText:
                '🏢 *Exclusive Territory Model*:\n• Protected 5 KM geographic radius\n• Zero intra-brand competition\n• Direct plant dispatch and ERP distributor billing.',
          ),
          _ChatOptionItem(
            title: 'Check Territory Availability',
            answerText:
                '📍 *Territories Open for Allocation*:\n• Raipur (North & South zones)\n• Bilaspur, Durg-Bhilai, Korba, Rajnandgaon\n• Submit your desired territory name in the chat to check live availability.',
          ),
        ],
      ),
      _ChatOptionItem(
        title: '💼 Investment & Requirements',
        inquiryType: 'franchise',
        children: [
          _ChatOptionItem(
            title: 'Space & Vehicle Requirements',
            answerText:
                '🏬 *Space & Infrastructure*:\n• Space: 500 – 1200 sq.ft commercial storage/shop\n• Vehicle: 1 delivery 3-wheeler or mini-truck for daily local dispatch.',
          ),
          _ChatOptionItem(
            title: 'Territory Allocation Criteria',
            answerText:
                '📍 *Territory Criteria*:\n• Minimum 5 KM radius protected territory\n• Direct plant dispatch & dedicated distributor margin\n• Exclusive rights with zero intra-brand competition.',
          ),
          _ChatOptionItem(
            title: '💰 Investment Package & Feasibility',
            inquiryType: 'franchise',
            answerText:
                '💰 *Franchise Investment Structure*:\n'
                '• Investment Range: ₹2 Lakh – ₹7.5 Lakh\n'
                '• Includes: Initial product inventory stock, security deposit, dispenser stands, display banners & marketing collateral.\n'
                '• Direct factory dispatch with 25%–35% gross profit margin.\n\n'
                'Would you like to review the official Franchise Rate & Investment Quotation?',
            children: [
              _ChatOptionItem(
                title: '✅ Yes, show quotation',
                inquiryType: 'franchise',
              ),
              _ChatOptionItem(
                title: '❌ No, maybe later',
                inquiryType: 'franchise',
              ),
            ],
          ),
        ],
      ),
      _ChatOptionItem(
        title: '📈 Profit Margins & ROI',
        inquiryType: 'franchise',
        children: [
          _ChatOptionItem(
            title: 'Margin & ROI Calculation',
            answerText:
                '📈 *Profitability & Margins*:\n• Packaged Bottles: 25% to 35% gross profit margin\n• 20L Water Jars: Up to 50% margin\n• Average ROI: 6 to 9 months based on territory sales density.',
          ),
          _ChatOptionItem(
            title: 'Expected Monthly Volume',
            answerText:
                '📊 *Monthly Distribution Targets*:\n• Tier 1 Territory: 1200 – 2000 crates/month\n• Tier 2 Territory: 600 – 1000 crates/month\n• Priority dispatch access guaranteed for network partners.',
          ),
        ],
      ),
      _ChatOptionItem(
        title: '🚚 Operations & Supply Chain',
        inquiryType: 'franchise',
        children: [
          _ChatOptionItem(
            title: 'Plant Priority Replenishment',
            answerText:
                '🏭 *Plant Operations*:\n• 24 to 48 hours replenishment dispatch from Raipur plant\n• Real-time stock status monitoring in distributor dashboard.',
          ),
          _ChatOptionItem(
            title: 'Branding & Marketing Support',
            answerText:
                '📢 *Marketing Package*:\n• Store signboards, vinyl wall branding, and glow signs provided\n• Local newspaper inserts and promotional campaigns supported.',
          ),
        ],
      ),
      _ChatOptionItem(
        title: '📞 Contact Franchise Desk',
        inquiryType: 'franchise',
        answerText:
            'Direct Franchise Desk: +91 98062 47194\nHead Office: H Block, Farishta Complex, Raipur, CG.\nEmail: franchise@shivnathagency.com',
      ),
    ];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Map<String, String>> _getHistory() {
    return _messages
        .take(_messages.length)
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();
  }

  Future<void> _downloadQuotationPdf({int? quotationId, String? qType}) async {
    final baseUrl = AppConstants.apiBaseUrl;
    final query = quotationId != null
        ? '$baseUrl/api/chat/quotations/$quotationId/pdf/'
        : '$baseUrl/api/chat/quotations/pdf/${qType != null && qType.isNotEmpty ? '?type=$qType' : ''}';
    final uri = Uri.parse(query);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📄 Opening Official Shivnath Quotation PDF...'),
            backgroundColor: Color(0xFF0284C7),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onOptionSelected(_ChatOptionItem option) {
    if (option.isStartNewEnquiry) {
      _startNewEnquiry();
      return;
    }

    if (option.isBackButton) {
      _handleBackNavigation();
      return;
    }

    if (option.isPdfDownload) {
      _downloadQuotationPdf(quotationId: option.quotationId, qType: option.inquiryType);
      return;
    }

    // Intercept qualification chip clicks immediately!
    if (_qualificationStep > 0) {
      setState(() {
        _messages.add(_ChatMessage(text: option.title, isUser: true));
      });
      _scrollToBottom();
      _processQualificationAnswer(option.title);
      return;
    }

    // =========================================================
    // MANDATORY LEAD CAPTURE UPFRONT BEFORE SHOWING OPTIONS
    // (APPLIES ONLY TO PUBLIC MODE & ONLY ONCE PER SESSION)
    // =========================================================
    if (option.isRootSelection && widget.mode == ChatbotMode.public) {
      _currentInquiryType = option.inquiryType;
      _lockedInquiryType = option.inquiryType;
      _navStack.clear();
      _consumedOptionIds.clear();
      _consumedOptionTitles.clear();
      _selectedOptionTrail.clear();
      _selectedOptionTrail.add(option.title);

      setState(() {
        _messages.add(_ChatMessage(text: option.title, isUser: true));
      });
      _scrollToBottom();

      // If lead capture was already completed in this session, do NOT re-ask!
      if (_leadCaptureCompleted) {
        final rootList = option.inquiryType == 'franchise'
            ? (_franchiseTree.isNotEmpty ? _franchiseTree : _getDefaultFranchiseOptions())
            : (_customerTree.isNotEmpty ? _customerTree : _getDefaultCustomerOptions());
        _navStack.add(rootList);
        _respond(
          'Please select from the options below:',
          options: _buildOptionListWithBack(rootList, canGoBack: false, isRootLevel: true),
        );
        return;
      }

      // Immediately start qualification without showing products/franchise options
      if (option.inquiryType == 'franchise') {
        _startFranchiseQualification();
      } else {
        _startCustomerQualification();
      }
      return;
    }

    // Record user choice in consumption memory & trail
    setState(() {
      _messages.add(_ChatMessage(text: option.title, isUser: true));
      if (option.id != null) {
        _consumedOptionIds.add(option.id!);
      }
      _consumedOptionTitles.add(option.title);
      _selectedOptionTrail.add(option.title);
    });
    _scrollToBottom();

    // =========================================================
    // INTERCEPT QUOTATION CONFIRMATION UX (DEEP FRANCHISE ONLY)
    // =========================================================
    if (option.title.contains('Yes, show quotation')) {
      final summary = '📄 **Official Shivnath Franchise Investment & Rate Quotation**\n\n'
          '• **Investment Package**: ₹2,00,000 - ₹5,00,000 (Unit) / ₹15,00,000+ (Master)\n'
          '• **Expected Net Margin**: 28% - 35% on packaged pure water supply\n'
          '• **Product Range**: 20L Water Jars, 250ml/500ml/1L Bottled Water\n'
          '• **Company Support**: Marketing signage, vinyl boards, and supply logistics.\n\n'
          'Click the button below to view or download the official PDF quotation document:';

      setState(() {
        _messages.add(
          _ChatMessage(
            text: summary,
            isUser: false,
            optionItems: _buildOptionListWithBack(
              [],
              canGoBack: true,
              includePdfDownload: true,
              quotationId: option.quotationId,
            ),
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    if (option.title.contains('No, maybe later')) {
      final currentLevel = _navStack.isNotEmpty ? _navStack.last : <_ChatOptionItem>[];
      final remaining = currentLevel.where((c) {
        final idMatches = c.id != null && _consumedOptionIds.contains(c.id);
        final titleMatches = _consumedOptionTitles.contains(c.title);
        return !idMatches && !titleMatches;
      }).toList();

      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Understood. You can review the quotation whenever you are ready. Let\'s continue with franchise details:',
            isUser: false,
            optionItems: _buildOptionListWithBack(
              remaining.isNotEmpty ? remaining : currentLevel,
              canGoBack: _navStack.isNotEmpty,
            ),
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    // Check if this node has children
    if (option.children.isNotEmpty) {
      _navStack.add(option.children);
      final unconsumedChildren = option.children.where((c) {
        final idMatches = c.id != null && _consumedOptionIds.contains(c.id);
        final titleMatches = _consumedOptionTitles.contains(c.title);
        return !idMatches && !titleMatches;
      }).toList();

      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Please select from the available options:',
            isUser: false,
            optionItems: _buildOptionListWithBack(
              unconsumedChildren.isNotEmpty ? unconsumedChildren : option.children,
              canGoBack: true,
            ),
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    // Leaf node: check if quotation PDF or dynamic query is required
    final isCustomerMode = widget.mode == ChatbotMode.customer || _lockedInquiryType == 'customer';
    final isQuotationNode = !isCustomerMode && (
        option.title.toLowerCase().contains('quotation') ||
        option.title.toLowerCase().contains('quote') ||
        option.title.toLowerCase().contains('bulk') ||
        option.title.toLowerCase().contains('subscription') ||
        option.title.toLowerCase().contains('franchise'));

    if (option.answerText != null && option.answerText!.trim().isNotEmpty) {
      final answer = option.answerText!;

      // Informational leaf node - Show answer and remaining unconsumed siblings
      final currentLevel = _navStack.isNotEmpty ? _navStack.last : <_ChatOptionItem>[];
      final remaining = currentLevel.where((c) {
        final idMatches = c.id != null && _consumedOptionIds.contains(c.id);
        final titleMatches = _consumedOptionTitles.contains(c.title);
        return !idMatches && !titleMatches;
      }).toList();

      final optionChips = _buildOptionListWithBack(
        remaining,
        canGoBack: _navStack.isNotEmpty,
        includePdfDownload: isQuotationNode,
        quotationId: option.quotationId,
      );

      setState(() {
        _messages.add(
          _ChatMessage(
            text: answer,
            isUser: false,
            optionItems: optionChips,
          ),
        );
      });
      _scrollToBottom();

      // If it's a lead trigger in public mode and NOT yet completed, initiate qualification
      if (option.isLeadTrigger && widget.mode == ChatbotMode.public && !_leadCaptureCompleted) {
        if (_lockedInquiryType == 'franchise' || option.inquiryType == 'franchise') {
          _startFranchiseQualification();
        } else {
          _startCustomerQualification();
        }
      }
    } else {
      // Dynamic API message query
      _sendMessage(option.title, optionId: option.id);
    }
  }

  void _handleBackNavigation() {
    if (_qualificationStep > 0) {
      _qualificationStep = 0;
      _leadData.clear();
    }

    if (_selectedOptionTrail.isNotEmpty) {
      _selectedOptionTrail.removeLast();
    }

    if (_navStack.length > 1) {
      _navStack.removeLast();
      final parentList = _navStack.last;
      final remaining = parentList.where((c) {
        final idMatches = c.id != null && _consumedOptionIds.contains(c.id);
        final titleMatches = _consumedOptionTitles.contains(c.title);
        return !idMatches && !titleMatches;
      }).toList();

      setState(() {
        _messages.add(_ChatMessage(text: '← Back', isUser: true));
        _messages.add(
          _ChatMessage(
            text: 'Navigated back to previous options:',
            isUser: false,
            optionItems: _buildOptionListWithBack(
              remaining.isNotEmpty ? remaining : parentList,
              canGoBack: _navStack.length > 1,
            ),
          ),
        );
      });
    } else {
      // At root level of current branch
      if (widget.mode == ChatbotMode.public) {
        final isFranchise = (_lockedInquiryType ?? _currentInquiryType) == 'franchise';
        final rootList = isFranchise
            ? (_franchiseTree.isNotEmpty ? _franchiseTree : _getDefaultFranchiseOptions())
            : (_customerTree.isNotEmpty ? _customerTree : _getDefaultCustomerOptions());

        setState(() {
          _messages.add(_ChatMessage(text: '← Back to Menu', isUser: true));
          _messages.add(
            _ChatMessage(
              text: 'You are at the main ${isFranchise ? 'Franchise' : 'Customer'} menu. Would you like to explore other options or start a new enquiry?',
              isUser: false,
              optionItems: [
                ...rootList,
                _ChatOptionItem(
                  title: '🔄 Start New Enquiry',
                  isStartNewEnquiry: true,
                ),
              ],
            ),
          );
        });
      } else {
        final rootOptions = widget.mode == ChatbotMode.admin
            ? _getAdminOptions()
            : (widget.mode == ChatbotMode.franchise ? _franchiseTree : _customerTree);
        setState(() {
          _messages.add(_ChatMessage(text: '← Back to Main Menu', isUser: true));
          _messages.add(
            _ChatMessage(
              text: 'Here are the options:',
              isUser: false,
              optionItems: rootOptions,
            ),
          );
        });
      }
    }
    _scrollToBottom();
  }

  void _startNewEnquiry() {
    setState(() {
      _lockedInquiryType = null;
      _currentInquiryType = null;
      _leadCaptureCompleted = false;
      _qualificationStep = 0;
      _leadData.clear();
      _navStack.clear();
      _consumedOptionIds.clear();
      _consumedOptionTitles.clear();
      _selectedOptionTrail.clear();

      _messages.add(_ChatMessage(text: '🔄 Start New Enquiry', isUser: true));
      _messages.add(
        _ChatMessage(
          text: 'Welcome to Shivnath Agency! How can we assist you today? Please choose your inquiry path:',
          isUser: false,
          optionItems: [
            _ChatOptionItem(title: '1. Customer / Product Inquiry', inquiryType: 'customer', isRootSelection: true),
            _ChatOptionItem(title: '2. Franchise Inquiry', inquiryType: 'franchise', isRootSelection: true),
          ],
        ),
      );
    });
    _scrollToBottom();
  }

  List<_ChatOptionItem> _buildOptionListWithBack(
    List<_ChatOptionItem> items, {
    bool canGoBack = true,
    bool isRootLevel = false,
    bool includePdfDownload = false,
    int? quotationId,
  }) {
    final list = List<_ChatOptionItem>.from(items);

    // Customer mode must NEVER have a quotation PDF download option
    final isCustomerMode = widget.mode == ChatbotMode.customer || _lockedInquiryType == 'customer';
    if (includePdfDownload && !isCustomerMode) {
      list.add(
        _ChatOptionItem(
          title: '📄 Download Official Quotation PDF',
          isPdfDownload: true,
          quotationId: quotationId,
          inquiryType: _lockedInquiryType ?? _currentInquiryType ?? 'franchise',
        ),
      );
    }

    if (canGoBack) {
      list.add(
        _ChatOptionItem(
          title: isRootLevel ? '← Back to Main Menu' : '← Back',
          isBackButton: true,
        ),
      );
    }
    return list;
  }

  Future<void> _sendMessage(String text, {int? optionId}) async {
    if (text.trim().isEmpty) return;
    final trimmed = text.trim();

    setState(() {
      if (optionId == null) {
        _messages.add(_ChatMessage(text: trimmed, isUser: true));
      }
      _textCtrl.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    // Qualification flow interception
    if (_qualificationStep > 0) {
      _processQualificationAnswer(trimmed);
      return;
    }

    final lower = trimmed.toLowerCase();
    if (lower == 'talk to sales' || lower == 'contact support' || lower == 'whatsapp support') {
      WhatsAppService.openWhatsApp(
        phone: WhatsAppService.officialSupportPhone,
        message: 'Namaste Shivnath Team,\nInquiry from Shivnath Pure Water App.',
      );
      _respond('Connecting you to our official WhatsApp support at +91 98062 47194. You can also continue asking questions here!');
      return;
    }

    final isCustomer = widget.mode == ChatbotMode.customer || _lockedInquiryType == 'customer';

    if (lower.contains('download quotation') || lower.contains('quotation pdf') || lower.contains('download quote') || lower.contains('pdf quotation')) {
      if (isCustomer) {
        _respond('As a valued customer, you can view our transparent retail and wholesale product prices directly in the Products menu! For corporate orders, call +91 98062 47194.');
        return;
      }
      _downloadQuotationPdf(qType: _lockedInquiryType ?? _currentInquiryType ?? 'franchise');
      _respond('Generating your official Shivnath Agency quotation PDF. Please check your browser/downloads window!');
      return;
    }

    // Call Real Backend AI API
    final history = _getHistory();
    final String apiAppType = widget.mode.name; // Use mode explicitly for backend context

    final res = await _chatService.sendMessage(
      message: trimmed,
      appType: apiAppType,
      optionId: optionId,
      sessionId: _activeSessionId,
      history: history,
      chatbotMode: widget.mode.name,
      inquiryType: _lockedInquiryType ?? _currentInquiryType,
      leadCaptureCompleted: _leadCaptureCompleted,
    );

    if (!mounted) return;

    if (res['session_id'] != null) {
      _activeSessionId = res['session_id']?.toString();
    }

    final reply = res['reply']?.toString() ??
        'Thank you for your inquiry. For direct assistance, call +91 98062 47194.';

    final hasQuotationIntent = !isCustomer && (
        lower.contains('quotation') ||
        lower.contains('quote') ||
        lower.contains('bulk') ||
        lower.contains('rate list') ||
        lower.contains('pricing'));

    if (res['is_lead_trigger'] == true && widget.mode == ChatbotMode.public && !_leadCaptureCompleted) {
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(text: reply, isUser: false));
      });
      _scrollToBottom();

      if ((_lockedInquiryType ?? _currentInquiryType) == 'franchise') {
        _startFranchiseQualification();
      } else {
        _startCustomerQualification();
      }
      return;
    }

    final currentLevel = _navStack.isNotEmpty ? _navStack.last : <_ChatOptionItem>[];
    final remaining = currentLevel.where((c) {
      final idMatches = c.id != null && _consumedOptionIds.contains(c.id);
      final titleMatches = _consumedOptionTitles.contains(c.title);
      return !idMatches && !titleMatches;
    }).toList();

    _respond(
      reply,
      options: _buildOptionListWithBack(
        remaining,
        canGoBack: _navStack.isNotEmpty,
        includePdfDownload: hasQuotationIntent,
      ),
    );
  }

  // =========================================================
  // CUSTOMER LEAD CAPTURE FLOW (Steps 101 - 106)
  // =========================================================
  void _startCustomerQualification() {
    _qualificationStep = 101;
    _leadData.clear();
    _respond(
      '📝 *Customer Inquiry & Delivery Desk*\n\nTo connect you with pure water supply and your territory franchise, please share your details:\n\n👉 **Step 1/6: What is your Full Name?**\n*(2 to 30 characters, letters only)*',
    );
  }

  // =========================================================
  // FRANCHISE LEAD QUALIFICATION FLOW (Steps 201 - 210)
  // =========================================================
  void _startFranchiseQualification() {
    _qualificationStep = 201;
    _leadData.clear();
    _respond(
      '🏢 *Franchise Pre-Qualification & Territory Feasibility*\n\nTo evaluate territory availability and ROI margins, please answer these quick questions:\n\n👉 **Step 1/9: What is your Full Name?**\n*(2 to 30 characters, letters only)*',
    );
  }

  void _processQualificationAnswer(String answer) {
    final trimmed = answer.trim();

    // --- CUSTOMER FLOW ---
    if (_qualificationStep >= 101 && _qualificationStep <= 106 || _qualificationStep == 1045) {
      switch (_qualificationStep) {
        case 101:
          final nameRegex = RegExp(r"^[a-zA-Z\s.']+$");
          if (trimmed.length < 2 || trimmed.length > 30 || !nameRegex.hasMatch(trimmed)) {
            _respond('⚠️ Please enter a valid name (2 to 30 characters, letters only, e.g. Rahul Sharma):');
            return;
          }
          _leadData['name'] = trimmed;
          _qualificationStep = 102;
          _respond('Nice to meet you, $trimmed! 👋\n\n👉 **Step 2/6: Please enter your 10-digit Mobile Number:**\n*(Must be exactly 10 digits starting with 6, 7, 8, or 9)*');
          break;

        case 102:
          final phoneRegex = RegExp(r'^[6-9]\d{9}$');
          if (!phoneRegex.hasMatch(trimmed)) {
            _respond('⚠️ Please enter a valid 10-digit Indian mobile number starting with 6, 7, 8, or 9 (e.g. 9876543210):');
            return;
          }
          _leadData['phone'] = trimmed;
          _qualificationStep = 103;
          _respond(
            '👉 **Step 3/6: What is your Email Address?**\n*(Required for order confirmations and invoices)*',
          );
          break;

        case 103:
          final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
          if (!emailRegex.hasMatch(trimmed)) {
            _respond('⚠️ Please enter a valid email address (e.g. name@example.com):');
            return;
          }
          _leadData['email'] = trimmed;
          _qualificationStep = 104;
          _respond(
            '👉 **Step 4/6: What is your District?**\n*(Select your district or tap Others)*',
            options: [
              _ChatOptionItem(title: 'Raipur'),
              _ChatOptionItem(title: 'Durg'),
              _ChatOptionItem(title: 'Bilaspur'),
              _ChatOptionItem(title: 'Rajnandgaon'),
              _ChatOptionItem(title: 'Others'),
            ],
          );
          break;

        case 104:
          if (trimmed.toLowerCase() == 'others' || trimmed.toLowerCase() == 'other') {
            _qualificationStep = 1045;
            _respond('👉 Please type the name of your District below:');
            return;
          }
          _leadData['district'] = trimmed;
          _qualificationStep = 105;
          _respond(
            '👉 **Step 5/6: What is your City / Location?**\n*(Please type your city, town or locality below)*',
          );
          break;

        case 1045:
          if (trimmed.isEmpty) {
            _respond('⚠️ Please type your District name below:');
            return;
          }
          _leadData['district'] = trimmed;
          _qualificationStep = 105;
          _respond(
            '👉 **Step 5/6: What is your City / Location?**\n*(Please type your city, town or locality below)*',
          );
          break;

        case 105:
          if (trimmed.isEmpty) {
            _respond('⚠️ Please enter your City or Location:');
            return;
          }
          _leadData['city'] = trimmed;
          _qualificationStep = 106;
          _respond(
            '👉 **Step 6/6: What is your Territory / Area?**\n*(e.g., North Raipur, Pandri, Shankar Nagar, Tatibandh)*\n*(Please type your territory or area below)*',
          );
          break;

        case 106:
          if (trimmed.isEmpty) {
            _respond('⚠️ Please enter your Territory or Area (e.g., North Raipur, Pandri, Shankar Nagar):');
            return;
          }
          _leadData['territory'] = trimmed;
          _qualificationStep = 0;
          _finalizeCustomerLead();
          break;
      }
      return;
    }

    // --- FRANCHISE FLOW ---
    if ((_qualificationStep >= 201 && _qualificationStep <= 210) || _qualificationStep == 2045) {
      switch (_qualificationStep) {
        case 201:
          final nameRegex = RegExp(r"^[a-zA-Z\s.']+$");
          if (trimmed.length < 2 || trimmed.length > 30 || !nameRegex.hasMatch(trimmed)) {
            _respond('⚠️ Please enter a valid name (2 to 30 characters, letters only, e.g. Rahul Sharma):');
            return;
          }
          _leadData['name'] = trimmed;
          _qualificationStep = 202;
          _respond('Nice to meet you, $trimmed! 👋\n\n👉 **Step 2/9: Please enter your 10-digit Mobile Number:**\n*(Must be exactly 10 digits starting with 6, 7, 8, or 9)*');
          break;

        case 202:
          final phoneRegex = RegExp(r'^[6-9]\d{9}$');
          if (!phoneRegex.hasMatch(trimmed)) {
            _respond('⚠️ Please enter a valid 10-digit Indian mobile number starting with 6, 7, 8, or 9 (e.g. 9876543210):');
            return;
          }
          _leadData['phone'] = trimmed;
          _qualificationStep = 203;
          _respond(
            '👉 **Step 3/9: What is your Email Address?**\n*(Required for franchise proposal and feasibility reports)*',
          );
          break;

        case 203:
          final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
          if (!emailRegex.hasMatch(trimmed)) {
            _respond('⚠️ Please enter a valid email address (e.g. partner@example.com):');
            return;
          }
          _leadData['email'] = trimmed;
          _qualificationStep = 204;
          _respond(
            '👉 **Step 4/9: What is your District?**\n*(Select your district or tap Others)*',
            options: [
              _ChatOptionItem(title: 'Raipur'),
              _ChatOptionItem(title: 'Durg'),
              _ChatOptionItem(title: 'Bilaspur'),
              _ChatOptionItem(title: 'Rajnandgaon'),
              _ChatOptionItem(title: 'Others'),
            ],
          );
          break;

        case 204:
          if (trimmed.toLowerCase() == 'others' || trimmed.toLowerCase() == 'other') {
            _qualificationStep = 2045;
            _respond('👉 Please type the name of your District below:');
            return;
          }
          _leadData['district'] = trimmed;
          _qualificationStep = 205;
          _respond(
            '👉 **Step 5/9: What is your City / Town?**\n*(Please type your city or town below)*',
          );
          break;

        case 2045:
          if (trimmed.isEmpty) {
            _respond('⚠️ Please type your District name below:');
            return;
          }
          _leadData['district'] = trimmed;
          _qualificationStep = 205;
          _respond(
            '👉 **Step 5/9: What is your City / Town?**\n*(Please type your city or town below)*',
          );
          break;

        case 205:
          if (trimmed.isEmpty) {
            _respond('⚠️ Please enter your City or Town:');
            return;
          }
          _leadData['city'] = trimmed;
          _qualificationStep = 206;
          _respond(
            '👉 **Step 6/9: What is your Preferred Territory / Area?**\n*(e.g., North Raipur, Pandri, Shankar Nagar, Tatibandh)*\n*(Please type your territory below)*',
          );
          break;

        case 206:
          if (trimmed.isEmpty) {
            _respond('⚠️ Please enter your Preferred Territory (e.g., North Raipur, Pandri, Shankar Nagar):');
            return;
          }
          _leadData['location'] = trimmed;
          _leadData['territory'] = trimmed;
          _qualificationStep = 207;
          _respond(
            '👉 **Step 7/9: What is your estimated Investment Budget?**',
            options: [
              _ChatOptionItem(title: '₹2 Lakh - ₹3 Lakh'),
              _ChatOptionItem(title: '₹3 Lakh - ₹5 Lakh'),
              _ChatOptionItem(title: '₹5 Lakh - ₹10 Lakh'),
              _ChatOptionItem(title: '₹10 Lakh - ₹20 Lakh'),
              _ChatOptionItem(title: '₹20 Lakh+ (Master Franchise)'),
            ],
          );
          break;

        case 207:
          _leadData['budget'] = trimmed;
          _qualificationStep = 208;
          _respond(
            '👉 **Step 8/9: Do you already have commercial space or a shop available?**',
            options: [
              _ChatOptionItem(title: 'Yes (Ready to setup)'),
              _ChatOptionItem(title: 'No (Will rent on approval)'),
              _ChatOptionItem(title: 'Searching in progress'),
            ],
          );
          break;

        case 208:
          _leadData['space'] = trimmed;
          _qualificationStep = 209;
          _respond(
            '👉 **Step 9/9: Do you have previous business or distribution experience?**',
            options: [
              _ChatOptionItem(title: 'Yes (FMCG / Water distribution)'),
              _ChatOptionItem(title: 'Yes (Other business)'),
              _ChatOptionItem(title: 'First-time entrepreneur'),
            ],
          );
          break;

        case 209:
          _leadData['experience'] = trimmed;
          _qualificationStep = 0;
          _finalizeFranchiseLead();
          break;
      }
    }
  }

  Future<void> _finalizeCustomerLead() async {
    final name = _leadData['name']?.toString() ?? 'Customer';
    final phone = _leadData['phone']?.toString() ?? '';
    final email = _leadData['email']?.toString() ?? '';
    final district = _leadData['district']?.toString() ?? 'Raipur';
    final city = _leadData['city']?.toString() ?? 'Raipur';
    final territory = _leadData['territory']?.toString() ?? '';
    final trailStr = _selectedOptionTrail.join(' -> ');

    setState(() => _isTyping = true);

    final res = await _chatService.submitPublicLead({
      'name': name,
      'phone': phone,
      'email': email,
      'district': district,
      'city': city,
      'territory': territory,
      'location': territory.isNotEmpty ? territory : city,
      'inquiry_type': 'customer',
      'selected_options': _selectedOptionTrail,
      'notes': 'Customer Inquiry: $trailStr | Territory: $territory, City: $city, District: $district',
      'conversation_history': _getHistory(),
    });

    final isExisting = res['is_duplicate'] == true;

    _leadCaptureCompleted = true;
    _lockedInquiryType = 'customer';
    _currentInquiryType = 'customer';

    final rootList = _customerTree.isNotEmpty ? _customerTree : _getDefaultCustomerOptions();
    _navStack.clear();
    _navStack.add(rootList);

    final locationDisplay = territory.isNotEmpty ? '$territory, $city (District: $district)' : '$city, $district';

    final summary = isExisting
        ? '✅ *Welcome back, $name!*\n\n'
            '• *Mobile*: $phone\n'
            '• *Area / Territory*: $locationDisplay\n\n'
            'Your customer inquiry has been linked in our Admin CRM and routed to your territory franchise. Please select from our products and pricing options below:'
        : '🎉 *Customer Details Verified!*\n\n'
            '• *Name*: $name\n'
            '• *Mobile*: $phone\n'
            '• *Area / Territory*: $locationDisplay\n\n'
            'Your lead has been recorded in the Admin CRM and routed to your nearest territory franchise. Please select from our packaged water products, pricing, and order support options below:';

    _respond(
      summary,
      options: _buildOptionListWithBack(rootList, canGoBack: false, isRootLevel: true),
    );
  }

  Future<void> _finalizeFranchiseLead() async {
    final name = _leadData['name']?.toString() ?? 'Franchise Prospect';
    final phone = _leadData['phone']?.toString() ?? '';
    final email = _leadData['email']?.toString() ?? '';
    final district = _leadData['district']?.toString() ?? 'Raipur';
    final city = _leadData['city']?.toString() ?? 'Raipur';
    final loc = _leadData['location']?.toString() ?? city;
    final budget = _leadData['budget']?.toString() ?? '₹5 Lakh';
    final space = _leadData['space']?.toString() ?? 'Yes';
    final exp = _leadData['experience']?.toString() ?? 'None';
    final trailStr = _selectedOptionTrail.join(' -> ');

    setState(() => _isTyping = true);

    final res = await _chatService.submitPublicLead({
      'name': name,
      'phone': phone,
      'email': email,
      'district': district,
      'city': city,
      'territory': loc,
      'budget': budget,
      'space': space,
      'experience': exp,
      'location': loc,
      'inquiry_type': 'franchise',
      'selected_options': _selectedOptionTrail,
      'notes': 'Franchise Inquiry: $trailStr | Territory: $loc, City: $city, District: $district | Budget: $budget | Space: $space | Experience: $exp',
      'conversation_history': _getHistory(),
    });

    final isExisting = res['is_duplicate'] == true;

    _leadCaptureCompleted = true;
    _lockedInquiryType = 'franchise';
    _currentInquiryType = 'franchise';

    final rootList = _franchiseTree.isNotEmpty ? _franchiseTree : _getDefaultFranchiseOptions();
    _navStack.clear();
    _navStack.add(rootList);

    final summary = isExisting
        ? '✅ *Franchise Details Updated!*\n\n'
            '• *Prospect*: $name\n'
            '• *Mobile*: $phone\n'
            '• *Territory*: $loc, $city (District: $district)\n'
            '• *Budget*: $budget\n\n'
            'Your inquiry is updated in our Admin CRM and routed to the territory team. Please explore our territory models, margins, and franchise investment options below:'
        : '🎉 *Franchise Pre-Qualification Submitted!*\n\n'
            '• *Prospect*: $name\n'
            '• *Mobile*: $phone\n'
            '• *Territory*: $loc, $city (District: $district)\n'
            '• *Budget*: $budget\n\n'
            'Your franchise inquiry has been logged in our Admin CRM and routed to the territory team. Please explore our models, margins, and investment details below:';

    _respond(
      summary,
      options: _buildOptionListWithBack(rootList, canGoBack: false, isRootLevel: true),
    );
  }

  void _respond(String text, {List<_ChatOptionItem>? options}) {
    setState(() {
      _isTyping = false;
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: false,
          optionItems: options,
        ),
      );
    });
    _scrollToBottom();
  }

  String _cleanFormattedText(String text) {
    return text
        .replaceAll(r'**', '')
        .replaceAll(r'###', '')
        .replaceAll(r'##', '')
        .replaceAll(r'# ', '')
        .replaceAll(r'`', '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isFranchise = widget.mode == ChatbotMode.franchise;
    final isAdmin = widget.mode == ChatbotMode.admin;

    String headerTitle = 'Shivnath Pure Water Assistant';
    String headerSubtitle = 'Instant Product, Price & Franchise Guide';
    String inputHint = 'Type a question or select an option below...';

    if (isAdmin) {
      headerTitle = 'Admin AI Assistant';
      headerSubtitle = 'Real-time Operations & System Insights';
    } else if (isFranchise) {
      headerTitle = 'Franchise AI Assistant';
      headerSubtitle = 'Operations, Margins & Territory Guide';
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 8),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF0284C7), size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        headerSubtitle,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Chat messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                          ),
                          SizedBox(width: 8),
                          Text('Checking pure water records...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                return _buildMessageItem(msg, theme);
              },
            ),
          ),

          // Bottom text input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (t) => _sendMessage(t),
                      decoration: InputDecoration(
                        hintText: inputHint,
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF0284C7),
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(_textCtrl.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(_ChatMessage msg, ThemeData theme) {
    final isUser = msg.isUser;
    final cleanedText = _cleanFormattedText(msg.text);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                const CircleAvatar(
                  radius: 15,
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(Icons.smart_toy_rounded, color: Color(0xFF0284C7), size: 17),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                      bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    cleanedText,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isUser ? Colors.white : const Color(0xFF1E293B),
                      height: 1.38,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Render selectable dynamic option chips
          if (msg.optionItems != null && msg.optionItems!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: msg.optionItems!.map((opt) {
                  final isBack = opt.isBackButton;
                  final isPdf = opt.isPdfDownload;

                  Color bgColor = const Color(0xFFE0F2FE);
                  Color borderColor = const Color(0xFFBAE6FD);
                  Color textColor = const Color(0xFF0369A1);
                  Widget? avatar;

                  if (isBack) {
                    bgColor = const Color(0xFFF1F5F9);
                    borderColor = const Color(0xFFCBD5E1);
                    textColor = const Color(0xFF475569);
                    avatar = const Icon(Icons.arrow_back, size: 14, color: Color(0xFF475569));
                  } else if (isPdf) {
                    bgColor = const Color(0xFFFEF3C7);
                    borderColor = const Color(0xFFFDE68A);
                    textColor = const Color(0xFFB45309);
                    avatar = const Icon(Icons.picture_as_pdf_rounded, size: 15, color: Color(0xFFB45309));
                  } else if (opt.isStartNewEnquiry) {
                    bgColor = const Color(0xFFFEF2F2);
                    borderColor = const Color(0xFFFECACA);
                    textColor = const Color(0xFFDC2626);
                    avatar = const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFDC2626));
                  }

                  return ActionChip(
                    backgroundColor: bgColor,
                    side: BorderSide(color: borderColor),
                    avatar: avatar,
                    label: Text(
                      opt.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    onPressed: () => _onOptionSelected(opt),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
