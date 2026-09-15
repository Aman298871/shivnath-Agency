import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../services/lead_service.dart';
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

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<String>? options;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.options,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _AiChatbotModalState extends State<AiChatbotModal> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  final ChatService _chatService = ChatService();
  bool _isTyping = false;

  // Lead qualification flow state
  int _qualificationStep = 0;
  final Map<String, dynamic> _leadData = {};

  List<String> get _quickOptions {
    if (widget.appType == 'franchise') {
      return [
        'How to place franchise order?',
        'What are profit margins?',
        'How does plant approval work?',
        'Exclusive territory rules',
        'Contact Support / Admin',
      ];
    }
    return [
      'What products are available?',
      'How do I place an order?',
      'Franchise Details & Investment',
      'Apply for Franchise (Qualify Now)',
      'Talk to Sales Executive',
    ];
  }

  @override
  void initState() {
    super.initState();
    final welcomeText = widget.appType == 'franchise'
        ? 'Namaste Franchise Partner 👋\nI am your Pure Water AI Operations Assistant.\n\nAsk me anything about placing orders, stock dispatch, invoices, commission margins, territory policies, or general questions!'
        : 'Namaste 👋\nThank you for choosing Shivnath Pure Water.\n\nI am your AI Assistant. How can I help you today with our products, home delivery, or franchise opportunities?';

    _messages.add(
      _ChatMessage(
        text: welcomeText,
        isUser: false,
        options: _quickOptions,
      ),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final trimmed = text.trim();

    setState(() {
      _messages.add(_ChatMessage(text: trimmed, isUser: true));
      _textCtrl.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    // Check if user initiated franchise qualification flow
    final lower = trimmed.toLowerCase();
    if (lower.contains('apply for franchise') ||
        lower.contains('start qualification') ||
        lower.contains('qualify now')) {
      _qualificationStep = 1;
      _respond('Great! Let\'s pre-qualify your franchise application in 6 quick questions.\n\n1. What is your Full Name?');
      return;
    }

    // If inside qualification questionnaire
    if (_qualificationStep > 0) {
      _processQualificationAnswer(trimmed);
      return;
    }

    if (lower == 'talk to sales executive' || lower == 'contact support / admin') {
      WhatsAppService.openWhatsApp(
        phone: WhatsAppService.officialSupportPhone,
        message: 'Namaste Shivnath Team,\nFranchise / Order inquiry from mobile app.',
      );
      _respond(
        'Connecting you to our official support team on WhatsApp at +91 98062 47194.\n\nFeel free to also ask me any questions directly here!',
        options: _quickOptions,
      );
      return;
    }

    // Call Real Backend AI API
    final history = _getHistory();
    final res = await _chatService.sendMessage(
      message: trimmed,
      appType: widget.appType,
      history: history,
    );

    if (!mounted) return;

    final reply = res['reply']?.toString() ??
        'Thank you for your message. How can I assist you further?';

    _respond(reply, options: _quickOptions);
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
        _respond('3. What is your City / Preferred District for the franchise?');
        break;
      case 3:
        _leadData['city'] = answer;
        _qualificationStep = 4;
        _respond(
          '4. What is your estimated Investment Budget?',
          options: ['₹3 Lakh - ₹5 Lakh', '₹5 Lakh - ₹10 Lakh', '₹10 Lakh - ₹20 Lakh', '₹20 Lakh+'],
        );
        break;
      case 4:
        _leadData['budget'] = answer;
        _qualificationStep = 5;
        _respond(
          '5. Do you already have commercial space or a shop available?',
          options: ['Yes (Ready to setup)', 'No (Will rent on approval)', 'Searching in progress'],
        );
        break;
      case 5:
        _leadData['space'] = answer;
        _qualificationStep = 6;
        _respond(
          '6. Do you have previous business or distribution experience?',
          options: ['Yes (Distribution / Retail)', 'Yes (Other business)', 'No (First-time entrepreneur)'],
        );
        break;
      case 6:
        _leadData['experience'] = answer;
        _qualificationStep = 0; // Completed
        _finalizeQualification();
        break;
    }
  }

  void _respond(String text, {List<String>? options}) {
    setState(() {
      _isTyping = false;
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: false,
          options: options,
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _finalizeQualification() async {
    final name = _leadData['name']?.toString() ?? 'Franchise Prospect';
    final phone = _leadData['phone']?.toString() ?? '';
    final city = _leadData['city']?.toString() ?? 'Raipur';
    final budget = _leadData['budget']?.toString() ?? '₹10 Lakh';
    final space = _leadData['space']?.toString() ?? 'Yes';

    int score = 50;
    if (budget.contains('10 Lakh') || budget.contains('20 Lakh')) score += 30;
    if (space.contains('Yes')) score += 15;
    final temp = score >= 75 ? '🔥 Hot Lead' : '⚡ Warm Lead';

    // Save lead to backend CRM
    await LeadService().createLead({
      'name': name,
      'phone': phone,
      'email': '${name.toLowerCase().replaceAll(' ', '')}@franchiseprospect.com',
      'city': city,
      'source': 'AI Chatbot',
      'notes': 'AI Lead Qualified. Budget: $budget | Space: $space | Score: $score ($temp)',
    });

    final summary =
        '🎉 *Application Received & Pre-Qualified!*\n\n'
        '• *Lead Classification*: $temp (Score: $score/100)\n'
        '• *Name*: $name\n'
        '• *Location*: $city\n'
        '• *Budget Tier*: $budget\n\n'
        'Your profile has been prioritized in our CRM. A dedicated Sales Executive will connect with you shortly.';

    _respond(summary, options: ['Chat on WhatsApp with Executive', 'Back to Main Menu']);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isFranchise = widget.appType == 'franchise';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
          const SizedBox(height: 10),

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
                        isFranchise
                            ? 'Franchise AI Assistant'
                            : 'Pure Water AI Assistant',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        isFranchise
                            ? 'Real-time Operations & Guidelines'
                            : 'Instant Product & Franchise Guidance',
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
                          Text('AI Assistant is typing...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: isFranchise
                            ? 'Ask about orders, dispatch, margins, territory...'
                            : 'Ask about products, delivery, pricing, Python...',
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
                    msg.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isUser ? Colors.white : const Color(0xFF1E293B),
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Render selectable chips / options if present
          if (msg.options != null && msg.options!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: msg.options!.map((opt) {
                  return ActionChip(
                    backgroundColor: const Color(0xFFE0F2FE),
                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                    label: Text(
                      opt,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                    onPressed: () => _sendMessage(opt),
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
