import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../services/whatsapp_service.dart';

class AiChatbotModal extends StatefulWidget {
  final String appType;

  const AiChatbotModal({
    super.key,
    this.appType = 'customer',
  });

  static Future<void> show(BuildContext context, {String appType = 'customer'}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiChatbotModal(appType: appType),
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
  final String inquiryType;
  final List<_ChatOptionItem> children;

  _ChatOptionItem({
    this.id,
    required this.title,
    this.answerText,
    this.isLeadTrigger = false,
    this.isBackButton = false,
    this.isRootSelection = false,
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
  
  // Navigation stack for back button support
  final List<List<_ChatOptionItem>> _navStack = [];
  final Set<int> _consumedOptionIds = {};

  // Lead qualification flow state
  int _qualificationStep = 0;
  final Map<String, dynamic> _leadData = {};
  String? _activeSessionId;

  @override
  void initState() {
    super.initState();
    _initChatbot();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initChatbot() async {
    // 1. Initial greeting with the 2 required initial inquiry paths
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
          text: 'Namaste! 🙏 Welcome to Shivnath Pure Packaged Drinking Water.\n\nPlease select the nature of your inquiry below or type any question directly.',
          isUser: false,
          optionItems: initialOptions,
        ),
      );
    });

    // 2. Fetch dynamic trees from Backend in background
    try {
      final custRaw = await _chatService.getPublicOptions(inquiryType: 'customer', tree: true);
      final franRaw = await _chatService.getPublicOptions(inquiryType: 'franchise', tree: true);

      _customerTree = custRaw.map((m) => _ChatOptionItem.fromJson(m)).toList();
      _franchiseTree = franRaw.map((m) => _ChatOptionItem.fromJson(m)).toList();

      // If backend has no options seeded yet, prepare standard defaults
      if (_customerTree.isEmpty) {
        _customerTree = _getDefaultCustomerOptions();
      }
      if (_franchiseTree.isEmpty) {
        _franchiseTree = _getDefaultFranchiseOptions();
      }
    } catch (_) {
      _customerTree = _getDefaultCustomerOptions();
      _franchiseTree = _getDefaultFranchiseOptions();
    }
  }

  List<_ChatOptionItem> _getDefaultCustomerOptions() {
    return [
      _ChatOptionItem(
        title: 'Product Inquiry & Pricing',
        inquiryType: 'customer',
        children: [
          _ChatOptionItem(title: 'Water Bottles (250ml / 500ml / 1L / 2L)', answerText: '💧 *Shivnath Bottled Water*:\n• 250ml Pocket Bottle: ₹10\n• 500ml Pack of 24: ₹240\n• 1 Litre Bottle: ₹20\n• 2 Litre Family Pack: ₹30\n\nAll bottled in certified BIS/FSSAI facility with 7-stage RO+UV filtration.'),
          _ChatOptionItem(title: '20L Commercial Water Jar', answerText: '🚰 *20 Litre Water Jar*:\n• Refill Rate: ₹40 per jar\n• Security Deposit for New Jar: ₹150 (Refundable)\n• Free doorstep delivery available across Raipur city for daily & weekly subscriptions.'),
          _ChatOptionItem(title: 'Alkaline Water (High TDS / Essential Minerals)', answerText: '✨ *Shivnath Premium Alkaline Water*:\n• 1L Glass/PET Bottle: ₹25\n• Enriched with natural calcium, magnesium & balanced 8.5+ pH.'),
        ],
      ),
      _ChatOptionItem(
        title: 'Official Quotations & Bulk Orders',
        inquiryType: 'customer',
        children: [
          _ChatOptionItem(title: '50+ Jars Weekly Contract Quote', answerText: '📋 *Quotation for 50+ Jars*:\n• Rate: ₹35 per jar\n• Daily morning delivery schedule & automated billing support.'),
          _ChatOptionItem(title: 'Corporate / Event Bottle Bulk Quote', answerText: '📋 *Event & Corporate Bulk Quote*:\n• 100+ Boxes: ₹210 per box (12.5% discount)\n• Priority vehicle dispatch to event venue.'),
        ],
      ),
      _ChatOptionItem(
        title: 'Doorstep Delivery & Order Placement',
        inquiryType: 'customer',
        answerText: '🚚 *Doorstep Delivery Guide*:\n1. Add products to cart via the Products section.\n2. Enter delivery address and choose Cash on Delivery or Online Payment.\n3. Orders placed before 2:00 PM are delivered same-day in Raipur.',
      ),
      _ChatOptionItem(
        title: 'Talk to Sales & Support',
        inquiryType: 'customer',
        answerText: 'Connecting you to our customer support team.\nCall or WhatsApp: +91 98062 47194\nEmail: support@shivnathagency.com',
      ),
    ];
  }

  List<_ChatOptionItem> _getDefaultFranchiseOptions() {
    return [
      _ChatOptionItem(
        title: 'Franchise Opportunity & Territory Model',
        inquiryType: 'franchise',
        answerText: '🏢 *Shivnath Agency Franchise Model*:\n• Exclusive 5 KM Radius Territory Protection.\n• Direct supply from automated bottling plant.\n• Guaranteed operational gross profit margin of 25% to 35% on volume sales.',
      ),
      _ChatOptionItem(
        title: 'Investment & Space Requirements',
        inquiryType: 'franchise',
        answerText: '💰 *Investment & Space Details*:\n• Investment: ₹3 Lakh – ₹10 Lakh depending on territory tier.\n• Space Required: 500 – 1200 sq.ft commercial storage.\n• Vehicle: 1 delivery vehicle (e.g. 3-wheeler or mini-truck).',
      ),
      _ChatOptionItem(
        title: 'Profit Margins & ROI',
        inquiryType: 'franchise',
        answerText: '📈 *Profitability & Margins*:\n• 20L Jar Plant Supply: ₹22-25 | Retail: ₹40 (Margin: ₹15-18 per jar)\n• Packaged Bottles: 20-30% margin on MRP.\n• Average ROI: 6 to 9 months with established local route.',
      ),
      _ChatOptionItem(
        title: 'Apply for Franchise (Qualify Now)',
        inquiryType: 'franchise',
        isLeadTrigger: true,
      ),
      _ChatOptionItem(
        title: 'Contact Executive / WhatsApp',
        inquiryType: 'franchise',
        answerText: 'Direct Franchise Desk: +91 98062 47194\nHead Office: H Block, Farishta Complex, Raipur, CG.',
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

  void _onOptionSelected(_ChatOptionItem option) {
    if (option.isBackButton) {
      _handleBackNavigation();
      return;
    }

    if (option.isRootSelection) {
      _currentInquiryType = option.inquiryType;
      _navStack.clear();
      final rootList = option.inquiryType == 'customer' ? _customerTree : _franchiseTree;
      _navStack.add(rootList);

      setState(() {
        _messages.add(_ChatMessage(text: option.title, isUser: true));
        _messages.add(
          _ChatMessage(
            text: option.inquiryType == 'customer'
                ? 'Here are the available options for Customer & Product inquiries. Please select an area:'
                : 'Here are the available options for Franchise & Distribution inquiries. Please select an area:',
            isUser: false,
            optionItems: _buildOptionListWithBack(rootList, canGoBack: true, isRootLevel: true),
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    // Record user choice
    setState(() {
      _messages.add(_ChatMessage(text: option.title, isUser: true));
      if (option.id != null) {
        _consumedOptionIds.add(option.id!);
      }
    });
    _scrollToBottom();

    // Check if lead qualification is triggered
    if (option.isLeadTrigger || option.title.toLowerCase().contains('qualify') || option.title.toLowerCase().contains('apply for franchise')) {
      _startQualification();
      return;
    }

    // If option has sub-options / children
    if (option.children.isNotEmpty) {
      final unconsumedChildren = option.children.where((c) => c.id == null || !_consumedOptionIds.contains(c.id)).toList();
      _navStack.add(option.children);

      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Please choose from the sub-options below:',
            isUser: false,
            optionItems: _buildOptionListWithBack(unconsumedChildren.isNotEmpty ? unconsumedChildren : option.children, canGoBack: true),
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    // Leaf node: return answer text or call API
    if (option.answerText != null && option.answerText!.trim().isNotEmpty) {
      final currentLevel = _navStack.isNotEmpty ? _navStack.last : <_ChatOptionItem>[];
      final remaining = currentLevel.where((c) => c.id == null || !_consumedOptionIds.contains(c.id)).toList();

      setState(() {
        _messages.add(
          _ChatMessage(
            text: option.answerText!,
            isUser: false,
            optionItems: _buildOptionListWithBack(remaining, canGoBack: _navStack.length > 1),
          ),
        );
      });
      _scrollToBottom();
    } else {
      // Fetch dynamic answer from API
      _sendMessage(option.title, optionId: option.id);
    }
  }

  void _handleBackNavigation() {
    if (_navStack.length > 1) {
      _navStack.removeLast();
      final parentList = _navStack.last;
      final remaining = parentList.where((c) => c.id == null || !_consumedOptionIds.contains(c.id)).toList();

      setState(() {
        _messages.add(_ChatMessage(text: '← Back', isUser: true));
        _messages.add(
          _ChatMessage(
            text: 'Navigated back to previous options:',
            isUser: false,
            optionItems: _buildOptionListWithBack(remaining.isNotEmpty ? remaining : parentList, canGoBack: _navStack.length > 1),
          ),
        );
      });
    } else {
      // Return to main root selection
      _navStack.clear();
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
    }
    _scrollToBottom();
  }

  List<_ChatOptionItem> _buildOptionListWithBack(List<_ChatOptionItem> items, {bool canGoBack = true, bool isRootLevel = false}) {
    final list = List<_ChatOptionItem>.from(items);
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

    // Check if user initiated qualification via typing
    final lower = trimmed.toLowerCase();
    if (_qualificationStep == 0 &&
        (lower.contains('apply for franchise') || lower.contains('franchise application') || lower.contains('qualify now') || lower.contains('franchise chahiye'))) {
      _startQualification();
      return;
    }

    // If inside qualification questionnaire
    if (_qualificationStep > 0) {
      _processQualificationAnswer(trimmed);
      return;
    }

    if (lower == 'talk to sales' || lower == 'contact support' || lower == 'whatsapp support') {
      WhatsAppService.openWhatsApp(
        phone: WhatsAppService.officialSupportPhone,
        message: 'Namaste Shivnath Team,\nInquiry from Shivnath Pure Water Mobile App.',
      );
      _respond('Connecting you to our official WhatsApp support at +91 98062 47194. You can also continue asking any questions here!');
      return;
    }

    // Call Real Backend AI API
    final history = _getHistory();
    final res = await _chatService.sendMessage(
      message: trimmed,
      appType: _currentInquiryType ?? widget.appType,
      optionId: optionId,
      sessionId: _activeSessionId,
      history: history,
    );

    if (!mounted) return;

    if (res['session_id'] != null) {
      _activeSessionId = res['session_id']?.toString();
    }

    final reply = res['reply']?.toString() ?? 'Thank you for your inquiry. For direct assistance, call +91 98062 47194.';

    // Check if response triggered lead qualification
    if (res['is_lead_trigger'] == true) {
      _startQualification();
      return;
    }

    final currentLevel = _navStack.isNotEmpty ? _navStack.last : <_ChatOptionItem>[];
    _respond(reply, options: _buildOptionListWithBack(currentLevel, canGoBack: _navStack.isNotEmpty));
  }

  void _startQualification() {
    _qualificationStep = 1;
    _leadData.clear();
    _respond('Great! Let\'s pre-qualify your inquiry in a few quick questions so our team can prepare your proposal.\n\n1. What is your Full Name?');
  }

  void _processQualificationAnswer(String answer) {
    switch (_qualificationStep) {
      case 1:
        _leadData['name'] = answer;
        _qualificationStep = 2;
        _respond('Nice to meet you, $answer! 👋\n\n2. Please provide your 10-digit Mobile Number:');
        break;
      case 2:
        _leadData['phone'] = answer;
        _qualificationStep = 3;
        _respond('3. What is your Email Address? (Optional - type "skip" if not available):');
        break;
      case 3:
        if (answer.toLowerCase() != 'skip') {
          _leadData['email'] = answer;
        }
        _qualificationStep = 4;
        _respond('4. What is your City / Preferred Location for the inquiry?');
        break;
      case 4:
        _leadData['city'] = answer;
        _qualificationStep = 5;
        _respond(
          '5. What is your estimated Investment Budget?',
          options: [
            _ChatOptionItem(title: '₹3 Lakh - ₹5 Lakh'),
            _ChatOptionItem(title: '₹5 Lakh - ₹10 Lakh'),
            _ChatOptionItem(title: '₹10 Lakh - ₹20 Lakh'),
            _ChatOptionItem(title: '₹20 Lakh+ (Master Franchise)'),
          ],
        );
        break;
      case 5:
        _leadData['budget'] = answer;
        _qualificationStep = 6;
        _respond(
          '6. Do you already have commercial space or a shop available?',
          options: [
            _ChatOptionItem(title: 'Yes (Ready to setup)'),
            _ChatOptionItem(title: 'No (Will rent on approval)'),
            _ChatOptionItem(title: 'Searching in progress'),
          ],
        );
        break;
      case 6:
        _leadData['space'] = answer;
        _qualificationStep = 7;
        _respond(
          '7. Do you have previous business or distribution experience?',
          options: [
            _ChatOptionItem(title: 'Yes (FMCG / Water distribution)'),
            _ChatOptionItem(title: 'Yes (Other business)'),
            _ChatOptionItem(title: 'First-time entrepreneur'),
          ],
        );
        break;
      case 7:
        _leadData['experience'] = answer;
        _qualificationStep = 0; // Finished
        _finalizeQualification();
        break;
    }
  }

  Future<void> _finalizeQualification() async {
    final name = _leadData['name']?.toString() ?? 'Prospect';
    final phone = _leadData['phone']?.toString() ?? '';
    final email = _leadData['email']?.toString() ?? '';
    final city = _leadData['city']?.toString() ?? 'Raipur';
    final budget = _leadData['budget']?.toString() ?? '₹5 Lakh';
    final space = _leadData['space']?.toString() ?? 'Yes';
    final exp = _leadData['experience']?.toString() ?? 'None';

    // Submit lead to backend PostgreSQL with duplicate prevention
    final res = await _chatService.submitPublicLead({
      'name': name,
      'phone': phone,
      'email': email,
      'city': city,
      'budget': budget,
      'space': space,
      'experience': exp,
      'inquiry_type': _currentInquiryType ?? 'franchise',
      'notes': 'Chatbot Qualified Lead. Budget: $budget | Space: $space | Experience: $exp',
      'conversation_history': _getHistory(),
    });

    final isExisting = res['is_duplicate'] == true;

    final summary = isExisting
        ? '✅ *Inquiry Received & Linked to Existing Profile!*\n\n'
            '• *Name*: $name\n'
            '• *Contact*: $phone\n'
            '• *Location*: $city\n'
            '• *Budget Tier*: $budget\n\n'
            'Your updated inquiry has been recorded in our CRM. Our sales desk will call you shortly.'
        : '🎉 *Application Received & Pre-Qualified!*\n\n'
            '• *Name*: $name\n'
            '• *Contact*: $phone\n'
            '• *Location*: $city\n'
            '• *Budget Tier*: $budget\n\n'
            'Your new lead profile is now active in the Admin CRM. A dedicated Executive will connect with you within 24 hours.';

    _respond(
      summary,
      options: [
        _ChatOptionItem(title: 'Talk to Sales Executive on WhatsApp'),
        _ChatOptionItem(title: '← Back to Main Menu', isBackButton: true),
      ],
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
    // Sanitizes raw markdown asterisks and symbols while keeping clean bullet points
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
    final isFranchise = (_currentInquiryType ?? widget.appType) == 'franchise';
    final isAdmin = widget.appType == 'admin';

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
                  return ActionChip(
                    backgroundColor: isBack ? const Color(0xFFF1F5F9) : const Color(0xFFE0F2FE),
                    side: BorderSide(color: isBack ? const Color(0xFFCBD5E1) : const Color(0xFFBAE6FD)),
                    avatar: isBack ? const Icon(Icons.arrow_back, size: 14, color: Color(0xFF475569)) : null,
                    label: Text(
                      opt.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isBack ? const Color(0xFF475569) : const Color(0xFF0369A1),
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
