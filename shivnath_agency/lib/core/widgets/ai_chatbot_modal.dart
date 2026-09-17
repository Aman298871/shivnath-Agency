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
  String? _currentInquiryType; // 'customer' or 'franchise'

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
      _currentInquiryType = 'customer';
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
      _currentInquiryType = 'franchise';
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
      _currentInquiryType = 'admin';
      final adminTree = _getAdminOptions();
      _navStack.clear();
      _navStack.add(adminTree);
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'How can I help you manage the business?',
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
            title: '2 Litre Bottle',
            inquiryType: 'customer',
            children: [
              _ChatOptionItem(
                title: 'Price',
                answerText:
                    '💧 *Shivnath 2 Litre Packaged Drinking Water*:\n• Single Bottle: ₹30\n• Family Crate (9 Bottles): ₹260\n• 7-Stage RO + UV + Ozonation purified.',
              ),
              _ChatOptionItem(
                title: 'Product Details',
                isLeadTrigger: true,
                answerText:
                    '✨ *2 Litre Family Pack Details*:\n• BIS IS:14543 Certified\n• Natural minerals with balanced 7.2 pH\n• Heavy-duty tamper-evident seal and convenient handle.',
              ),
              _ChatOptionItem(
                title: 'Bulk Order / Quotation',
                isLeadTrigger: true,
                answerText:
                    '📋 *2 Litre Bulk Order Quote*:\n• 10+ Crates: ₹250 per crate\n• Free doorstep logistics across Raipur city.\n• Official PDF quotation available for download below.',
              ),
            ],
          ),
          _ChatOptionItem(
            title: '1 Litre Bottle',
            inquiryType: 'customer',
            children: [
              _ChatOptionItem(
                title: 'Price',
                answerText: '💧 *Shivnath 1 Litre Packaged Water*:\n• ₹20 per bottle\n• Box of 12 bottles: ₹220.',
              ),
              _ChatOptionItem(
                title: 'Product Details',
                isLeadTrigger: true,
                answerText:
                    '✨ *1 Litre Personal Hydration*:\n• Perfectly balanced mineral water for daily active hydration.\n• Certified pure at plant laboratory.',
              ),
              _ChatOptionItem(
                title: 'Bulk Order / Quotation',
                isLeadTrigger: true,
                answerText: '📋 *1L Bulk Quotation*:\n• 50+ Boxes: ₹195 per box (15% wholesale discount).\n• Download official PDF quotation below.',
              ),
            ],
          ),
          _ChatOptionItem(
            title: '500ml Bottle',
            inquiryType: 'customer',
            children: [
              _ChatOptionItem(
                title: 'Price',
                answerText: '💧 *Shivnath 500ml Bottle*:\n• ₹10 per bottle\n• Box of 24: ₹220.',
              ),
              _ChatOptionItem(
                title: 'Product Details',
                isLeadTrigger: true,
                answerText: '✨ *500ml Travel Size*:\n• Convenient pocket size for travel, dining, and meetings.',
              ),
            ],
          ),
          _ChatOptionItem(
            title: '250ml Pocket Bottle',
            inquiryType: 'customer',
            children: [
              _ChatOptionItem(
                title: 'Price',
                answerText: '💧 *Shivnath 250ml Pocket Bottle*:\n• ₹6 per bottle\n• Box of 30: ₹165.',
              ),
              _ChatOptionItem(
                title: 'Product Details',
                isLeadTrigger: true,
                answerText: '✨ *250ml Mini Bottle*:\n• Ideal for corporate events, parties, catering, and meetings.',
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
            title: 'Price & Security Deposit',
            answerText:
                '🚰 *20 Litre Water Jar*:\n• Refill Rate: ₹60 per jar\n• First-time Refundable Security Deposit: ₹150 per jar.',
          ),
          _ChatOptionItem(
            title: 'Home / Office Subscription',
            isLeadTrigger: true,
            answerText:
                '🚚 *Daily Subscription Plan*:\n• Monthly contract: ₹50 per jar\n• Daily morning doorstep delivery across Raipur.\n• Download formal rate quotation PDF below.',
          ),
        ],
      ),
      _ChatOptionItem(
        title: '📄 Official Quotation PDF',
        inquiryType: 'customer',
        isPdfDownload: true,
      ),
      _ChatOptionItem(
        title: '📝 Submit Customer Inquiry / Callback',
        inquiryType: 'customer',
        isLeadTrigger: true,
        answerText: 'Please share your details so our customer team can assist you with orders or inquiries.',
      ),
      _ChatOptionItem(
        title: '📞 Talk to Sales Executive',
        inquiryType: 'customer',
        isLeadTrigger: true,
        answerText:
            'Connecting you to our Sales Desk.\nDirect Hotline: +91 98062 47194\nEmail: sales@shivnathagency.com',
      ),
    ];
  }

  List<_ChatOptionItem> _getDefaultFranchiseOptions() {
    return [
      _ChatOptionItem(
        title: 'Territory Model & Availability',
        inquiryType: 'franchise',
        children: [
          _ChatOptionItem(
            title: 'Territory Model Details',
            answerText:
                '🏢 *Exclusive Territory Model*:\n• Protected 5 KM geographic radius\n• Zero intra-brand competition\n• Direct plant dispatch and ERP distributor billing.',
          ),
          _ChatOptionItem(
            title: 'Check Territory Availability',
            isLeadTrigger: true,
            answerText:
                '📍 *Territories Open for Allocation*:\n• Raipur (North & South zones)\n• Bilaspur, Durg-Bhilai, Korba, Rajnandgaon\n• Please submit your location to check exact availability.',
          ),
        ],
      ),
      _ChatOptionItem(
        title: 'Investment & Space Requirements',
        inquiryType: 'franchise',
        children: [
          _ChatOptionItem(
            title: 'Investment Breakdown',
            isLeadTrigger: true,
            answerText:
                '💰 *Investment Structure*:\n• Investment: ₹3.5 Lakh – ₹7.5 Lakh\n• Includes initial product stock inventory, security deposit & local branding.\n• Download complete franchise package PDF below.',
          ),
          _ChatOptionItem(
            title: 'Space & Vehicle Requirements',
            answerText:
                '🏬 *Space & Infrastructure*:\n• Space: 500 – 1200 sq.ft commercial storage/shop\n• Vehicle: 1 delivery 3-wheeler or mini-truck.',
          ),
        ],
      ),
      _ChatOptionItem(
        title: 'Profit Margins & ROI',
        inquiryType: 'franchise',
        children: [
          _ChatOptionItem(
            title: 'Margin & ROI Calculation',
            isLeadTrigger: true,
            answerText:
                '📈 *Profitability & Margins*:\n• Packaged Bottles: 25% to 35% gross profit margin\n• 20L Water Jars: Up to 50% margin\n• Average ROI: 6 to 9 months.',
          ),
        ],
      ),
      _ChatOptionItem(
        title: 'Apply for Franchise (Qualify Now)',
        inquiryType: 'franchise',
        isLeadTrigger: true,
        answerText: 'Let us capture your franchise qualification details and generate your feasibility report.',
      ),
      _ChatOptionItem(
        title: 'Contact Franchise Desk',
        inquiryType: 'franchise',
        isLeadTrigger: true,
        answerText:
            'Direct Franchise Hotline: +91 98062 47194\nHead Office: H Block, Farishta Complex, Raipur, CG.',
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
    // (APPLIES ONLY TO PUBLIC MODE)
    // =========================================================
    if (option.isRootSelection && widget.mode == ChatbotMode.public) {
      _currentInquiryType = option.inquiryType;
      _navStack.clear();
      _consumedOptionIds.clear();
      _consumedOptionTitles.clear();
      _selectedOptionTrail.clear();
      _selectedOptionTrail.add(option.title);

      setState(() {
        _messages.add(_ChatMessage(text: option.title, isUser: true));
      });
      _scrollToBottom();

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
    final isQuotationNode = option.title.toLowerCase().contains('quotation') ||
        option.title.toLowerCase().contains('quote') ||
        option.title.toLowerCase().contains('bulk') ||
        option.title.toLowerCase().contains('subscription') ||
        option.title.toLowerCase().contains('franchise');

    if (option.answerText != null && option.answerText!.trim().isNotEmpty) {
      final answer = option.answerText!;

      // Informational leaf node (e.g. Price, details) - Show answer and remaining unconsumed siblings
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

      // If it's a lead trigger in public mode, initiate qualification
      if (option.isLeadTrigger && widget.mode == ChatbotMode.public) {
        if (option.inquiryType == 'franchise') {
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
      if (widget.mode == ChatbotMode.public) {
        _currentInquiryType = null;
        setState(() {
          _messages.add(_ChatMessage(text: '← Back to Main Menu', isUser: true));
          _messages.add(
            _ChatMessage(
              text: 'Please select an inquiry path:',
              isUser: false,
              optionItems: [
                _ChatOptionItem(title: '1. Customer / Product Inquiry', inquiryType: 'customer', isRootSelection: true),
                _ChatOptionItem(title: '2. Franchise Inquiry', inquiryType: 'franchise', isRootSelection: true),
              ],
            ),
          );
        });
      } else {
        // Authenticated users shouldn't reach here since they start at length 1 (root), but just in case
        _navStack.add(widget.mode == ChatbotMode.admin ? _getAdminOptions() : (widget.mode == ChatbotMode.franchise ? _franchiseTree : _customerTree));
        setState(() {
          _messages.add(_ChatMessage(text: '← Back to Main Menu', isUser: true));
          _messages.add(
            _ChatMessage(
              text: 'Here are the options:',
              isUser: false,
              optionItems: _navStack.last,
            ),
          );
        });
      }
    }
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

    if (includePdfDownload) {
      list.add(
        _ChatOptionItem(
          title: '📄 Download Official Quotation PDF',
          isPdfDownload: true,
          quotationId: quotationId,
          inquiryType: _currentInquiryType ?? 'customer',
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

    if (lower.contains('download quotation') || lower.contains('quotation pdf') || lower.contains('download quote') || lower.contains('pdf quotation')) {
      _downloadQuotationPdf(qType: _currentInquiryType ?? 'customer');
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
    );

    if (!mounted) return;

    if (res['session_id'] != null) {
      _activeSessionId = res['session_id']?.toString();
    }

    final reply = res['reply']?.toString() ??
        'Thank you for your inquiry. For direct assistance, call +91 98062 47194.';

    final hasQuotationIntent = lower.contains('quotation') ||
        lower.contains('quote') ||
        lower.contains('bulk') ||
        lower.contains('rate list') ||
        lower.contains('pricing');

    if (res['is_lead_trigger'] == true) {
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(text: reply, isUser: false));
      });
      _scrollToBottom();

      if (widget.mode == ChatbotMode.public) {
        if (_currentInquiryType == 'franchise') {
          _startFranchiseQualification();
        } else {
          _startCustomerQualification();
        }
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
  // CUSTOMER LEAD CAPTURE FLOW (Steps 101 - 105)
  // =========================================================
  void _startCustomerQualification() {
    _qualificationStep = 101;
    _leadData.clear();
    _respond(
      '📝 *Customer Inquiry & Callback Desk*\n\nTo connect you with our Raipur sales desk, please share your details:\n\n👉 **Step 1/5: What is your Full Name?**\n*(Type your name below)*',
    );
  }

  // =========================================================
  // FRANCHISE LEAD QUALIFICATION FLOW (Steps 201 - 209)
  // =========================================================
  void _startFranchiseQualification() {
    _qualificationStep = 201;
    _leadData.clear();
    _respond(
      '🏢 *Franchise Pre-Qualification & Territory Feasibility*\n\nTo evaluate territory availability and ROI margins, please answer these quick questions:\n\n👉 **Step 1/9: What is your Full Name?**\n*(Type your name below)*',
    );
  }

  void _processQualificationAnswer(String answer) {
    // --- CUSTOMER FLOW ---
    if (_qualificationStep >= 101 && _qualificationStep <= 105) {
      switch (_qualificationStep) {
        case 101:
          _leadData['name'] = answer;
          _qualificationStep = 102;
          _respond('Nice to meet you, $answer! 👋\n\n👉 **Step 2/5: Please enter your 10-digit Mobile Number:**\n*(Type your phone number below)*');
          break;
        case 102:
          _leadData['phone'] = answer;
          _qualificationStep = 103;
          _respond(
            '👉 **Step 3/5: What is your Email Address?** (Optional):',
            options: [_ChatOptionItem(title: 'Skip Email')],
          );
          break;
        case 103:
          if (answer.toLowerCase() != 'skip' && answer.toLowerCase() != 'skip email') {
            _leadData['email'] = answer;
          }
          _qualificationStep = 104;
          _respond(
            '👉 **Step 4/5: What is your City / Location?**',
            options: [
              _ChatOptionItem(title: 'Raipur'),
              _ChatOptionItem(title: 'Durg'),
              _ChatOptionItem(title: 'Bhilai'),
              _ChatOptionItem(title: 'Bilaspur'),
              _ChatOptionItem(title: 'Rajnandgaon'),
            ],
          );
          break;
        case 104:
          _leadData['city'] = answer;
          _qualificationStep = 105;
          _respond(
            '👉 **Step 5/5: What is your District?**',
            options: [
              _ChatOptionItem(title: 'Raipur'),
              _ChatOptionItem(title: 'Durg'),
              _ChatOptionItem(title: 'Bilaspur'),
              _ChatOptionItem(title: 'Rajnandgaon'),
            ],
          );
          break;
        case 105:
          _leadData['district'] = answer;
          _qualificationStep = 0;
          _finalizeCustomerLead();
          break;
      }
      return;
    }

    // --- FRANCHISE FLOW ---
    if (_qualificationStep >= 201 && _qualificationStep <= 209) {
      switch (_qualificationStep) {
        case 201:
          _leadData['name'] = answer;
          _qualificationStep = 202;
          _respond('Nice to meet you, $answer! 👋\n\n👉 **Step 2/9: Please enter your 10-digit Mobile Number:**\n*(Type your phone number below)*');
          break;
        case 202:
          _leadData['phone'] = answer;
          _qualificationStep = 203;
          _respond(
            '👉 **Step 3/9: What is your Email Address?** (Optional):',
            options: [_ChatOptionItem(title: 'Skip Email')],
          );
          break;
        case 203:
          if (answer.toLowerCase() != 'skip' && answer.toLowerCase() != 'skip email') {
            _leadData['email'] = answer;
          }
          _qualificationStep = 204;
          _respond(
            '👉 **Step 4/9: What is your City?**',
            options: [
              _ChatOptionItem(title: 'Raipur'),
              _ChatOptionItem(title: 'Durg'),
              _ChatOptionItem(title: 'Bhilai'),
              _ChatOptionItem(title: 'Bilaspur'),
              _ChatOptionItem(title: 'Rajnandgaon'),
            ],
          );
          break;
        case 204:
          _leadData['city'] = answer;
          _qualificationStep = 205;
          _respond(
            '👉 **Step 5/9: What is your District?**',
            options: [
              _ChatOptionItem(title: 'Raipur'),
              _ChatOptionItem(title: 'Durg'),
              _ChatOptionItem(title: 'Bilaspur'),
              _ChatOptionItem(title: 'Rajnandgaon'),
            ],
          );
          break;
        case 205:
          _leadData['district'] = answer;
          _qualificationStep = 206;
          _respond(
            '👉 **Step 6/9: What is your estimated Investment Budget?**',
            options: [
              _ChatOptionItem(title: '₹3 Lakh - ₹5 Lakh'),
              _ChatOptionItem(title: '₹5 Lakh - ₹10 Lakh'),
              _ChatOptionItem(title: '₹10 Lakh - ₹20 Lakh'),
              _ChatOptionItem(title: '₹20 Lakh+ (Master Franchise)'),
            ],
          );
          break;
        case 206:
          _leadData['budget'] = answer;
          _qualificationStep = 207;
          _respond(
            '👉 **Step 7/9: Do you already have commercial space or a shop available?**',
            options: [
              _ChatOptionItem(title: 'Yes (Ready to setup)'),
              _ChatOptionItem(title: 'No (Will rent on approval)'),
              _ChatOptionItem(title: 'Searching in progress'),
            ],
          );
          break;
        case 207:
          _leadData['space'] = answer;
          _qualificationStep = 208;
          _respond(
            '👉 **Step 8/9: Do you have previous business or distribution experience?**',
            options: [
              _ChatOptionItem(title: 'Yes (FMCG / Water distribution)'),
              _ChatOptionItem(title: 'Yes (Other business)'),
              _ChatOptionItem(title: 'First-time entrepreneur'),
            ],
          );
          break;
        case 208:
          _leadData['experience'] = answer;
          _qualificationStep = 209;
          _respond(
            '👉 **Step 9/9: What is your Preferred Franchise Territory / Location?**',
            options: [
              _ChatOptionItem(title: 'Raipur Central / North'),
              _ChatOptionItem(title: 'Raipur South / Naya Raipur'),
              _ChatOptionItem(title: 'Durg-Bhilai'),
              _ChatOptionItem(title: 'Bilaspur City'),
              _ChatOptionItem(title: 'Korba'),
              _ChatOptionItem(title: 'Rajnandgaon'),
            ],
          );
          break;
        case 209:
          _leadData['location'] = answer;
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
    final city = _leadData['city']?.toString() ?? 'Raipur';
    final district = _leadData['district']?.toString() ?? 'Raipur';
    final trailStr = _selectedOptionTrail.join(' -> ');

    setState(() => _isTyping = true);

    final res = await _chatService.submitPublicLead({
      'name': name,
      'phone': phone,
      'email': email,
      'city': city,
      'district': district,
      'inquiry_type': 'customer',
      'selected_options': _selectedOptionTrail,
      'notes': 'Customer Inquiry: $trailStr',
      'conversation_history': _getHistory(),
    });

    final isExisting = res['is_duplicate'] == true;

    final rootList = _customerTree.isNotEmpty ? _customerTree : _getDefaultCustomerOptions();
    _navStack.clear();
    _navStack.add(rootList);

    final summary = isExisting
        ? '✅ *Welcome back, $name!*\n\n'
            '• *Mobile*: $phone\n'
            '• *Location*: $city, $district\n\n'
            'Your customer inquiry has been linked in our Admin CRM. Please select from our products and pricing options below:'
        : '🎉 *Customer Details Verified!*\n\n'
            '• *Name*: $name\n'
            '• *Mobile*: $phone\n'
            '• *Location*: $city, $district\n\n'
            'Your lead has been recorded in the Admin CRM. Please select from our packaged water products, pricing, and quotation options below:';

    _respond(
      summary,
      options: _buildOptionListWithBack(rootList, canGoBack: true, isRootLevel: true),
    );
  }

  Future<void> _finalizeFranchiseLead() async {
    final name = _leadData['name']?.toString() ?? 'Franchise Prospect';
    final phone = _leadData['phone']?.toString() ?? '';
    final email = _leadData['email']?.toString() ?? '';
    final city = _leadData['city']?.toString() ?? 'Raipur';
    final district = _leadData['district']?.toString() ?? 'Raipur';
    final budget = _leadData['budget']?.toString() ?? '₹5 Lakh';
    final space = _leadData['space']?.toString() ?? 'Yes';
    final exp = _leadData['experience']?.toString() ?? 'None';
    final loc = _leadData['location']?.toString() ?? city;
    final trailStr = _selectedOptionTrail.join(' -> ');

    setState(() => _isTyping = true);

    final res = await _chatService.submitPublicLead({
      'name': name,
      'phone': phone,
      'email': email,
      'city': city,
      'district': district,
      'budget': budget,
      'space': space,
      'experience': exp,
      'location': loc,
      'inquiry_type': 'franchise',
      'selected_options': _selectedOptionTrail,
      'notes': 'Franchise Inquiry: $trailStr | Budget: $budget | Space: $space | Experience: $exp | Location: $loc',
      'conversation_history': _getHistory(),
    });

    final isExisting = res['is_duplicate'] == true;

    final rootList = _franchiseTree.isNotEmpty ? _franchiseTree : _getDefaultFranchiseOptions();
    _navStack.clear();
    _navStack.add(rootList);

    final summary = isExisting
        ? '✅ *Franchise Details Updated!*\n\n'
            '• *Prospect*: $name\n'
            '• *Mobile*: $phone\n'
            '• *Territory*: $loc ($city)\n'
            '• *Budget*: $budget\n\n'
            'Your inquiry is updated in our Admin CRM. Please explore our territory models, margins, and franchise quotation options below:'
        : '🎉 *Franchise Pre-Qualification Submitted!*\n\n'
            '• *Prospect*: $name\n'
            '• *Mobile*: $phone\n'
            '• *Territory*: $loc ($city)\n'
            '• *Budget*: $budget\n\n'
            'Your franchise lead is now active in the Admin CRM. Please explore our territory models, margins, and franchise quotation options below:';

    _respond(
      summary,
      options: _buildOptionListWithBack(rootList, canGoBack: true, isRootLevel: true),
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
