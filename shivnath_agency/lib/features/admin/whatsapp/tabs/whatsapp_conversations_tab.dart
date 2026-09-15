import 'package:flutter/material.dart';

class WhatsAppConversationsTab extends StatefulWidget {
  const WhatsAppConversationsTab({super.key});

  @override
  State<WhatsAppConversationsTab> createState() =>
      _WhatsAppConversationsTabState();
}

class _WhatsAppConversationsTabState
    extends State<WhatsAppConversationsTab> {
  final searchController = TextEditingController();
  final messageController = TextEditingController();
  final messageScrollController = ScrollController();

  int selectedId = 1;
  bool mobileChatOpen = false;
  String search = '';

  final List<Map<String, dynamic>> conversations = [
    {
      'id': 1,
      'name': 'Rahul Sharma',
      'mobile': '+91 98765 43210',
      'city': 'Raipur',
      'temperature': 'Hot',
      'lastMessage': 'Mujhe Raipur me franchise chahiye.',
      'time': '2 min ago',
      'unread': 2,
      'aiEnabled': true,
      'messages': [
        {
          'id': 1,
          'sender': 'customer',
          'text':
              'Namaste, mujhe Raipur me drinking water franchise chahiye.',
          'time': '10:31 AM',
        },
        {
          'id': 2,
          'sender': 'bot',
          'text':
              'Namaste Rahul ji 👋 Drinking Water Franchise me interest dikhane ke liye thank you. Aap Franchise Details, Investment Required, Profit Margin, Location Availability ya Sales Executive se baat kar sakte hain.',
          'time': '10:31 AM',
        },
        {
          'id': 3,
          'sender': 'customer',
          'text': 'Investment kitna lagega?',
          'time': '10:32 AM',
        },
      ],
    },
    {
      'id': 2,
      'name': 'Amit Verma',
      'mobile': '+91 98261 23456',
      'city': 'Bilaspur',
      'temperature': 'Warm',
      'lastMessage': 'Profit margin ke bare me bataye.',
      'time': '15 min ago',
      'unread': 0,
      'aiEnabled': true,
      'messages': [
        {
          'id': 1,
          'sender': 'customer',
          'text': 'Profit margin ke bare me bataye.',
          'time': '10:15 AM',
        },
        {
          'id': 2,
          'sender': 'bot',
          'text':
              'Bilkul. Main aapko franchise profit margin ki details bata sakta hoon.',
          'time': '10:15 AM',
        },
      ],
    },
    {
      'id': 3,
      'name': 'Suresh Patel',
      'mobile': '+91 97555 44556',
      'city': 'Durg',
      'temperature': 'Cold',
      'lastMessage': 'Details WhatsApp kar dijiye.',
      'time': '1 hr ago',
      'unread': 0,
      'aiEnabled': false,
      'messages': [
        {
          'id': 1,
          'sender': 'customer',
          'text': 'Details WhatsApp kar dijiye.',
          'time': '9:25 AM',
        },
      ],
    },
  ];

  Map<String, dynamic>? get selectedConversation {
    try {
      return conversations.firstWhere(
        (item) => item['id'] == selectedId,
      );
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get filteredConversations {
    final query = search.trim().toLowerCase();

    if (query.isEmpty) {
      return conversations;
    }

    return conversations.where((item) {
      return item['name']
              .toString()
              .toLowerCase()
              .contains(query) ||
          item['mobile']
              .toString()
              .toLowerCase()
              .contains(query) ||
          item['city']
              .toString()
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    messageController.dispose();
    messageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 850;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF5F7FB),
          padding: EdgeInsets.fromLTRB(
            desktop ? 28 : 14,
            desktop ? 24 : 14,
            desktop ? 28 : 14,
            desktop ? 22 : 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pageHeader(desktop),

              const SizedBox(height: 16),

              Expanded(
                child: desktop
                    ? _desktopInbox()
                    : _mobileInbox(),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // PAGE HEADER
  // =========================================================

  Widget _pageHeader(bool desktop) {
    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WhatsApp Conversations',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage franchise enquiries and customer conversations.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          _connectionBadge(),
        ],
      );
    }

    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WhatsApp Conversations',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage franchise enquiries and customer conversations.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        _connectionBadge(),
      ],
    );
  }

  Widget _connectionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 4,
            backgroundColor: Color(0xFF16A34A),
          ),
          SizedBox(width: 6),
          Text(
            'WhatsApp Connected',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF15803D),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DESKTOP INBOX
  // =========================================================

  Widget _desktopInbox() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 340,
            child: _conversationList(),
          ),
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: Color(0xFFE5E7EB),
          ),
          Expanded(
            child: _chatPanel(),
          ),
        ],
      ),
    );
  }

  Widget _mobileInbox() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: mobileChatOpen
          ? _chatPanel(
              showBack: true,
            )
          : _conversationList(),
    );
  }

  // =========================================================
  // LEFT LIST
  // =========================================================

  Widget _conversationList() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              17,
              18,
              17,
              10,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conversations',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${conversations.length} active conversations',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              0,
              14,
              14,
            ),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: searchController,
                onChanged: (value) {
                  setState(() {
                    search = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 17,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Divider(
            height: 1,
            color: Color(0xFFE5E7EB),
          ),

          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: filteredConversations.length,
              itemBuilder: (context, index) {
                return _conversationTile(
                  filteredConversations[index],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _conversationTile(
    Map<String, dynamic> conversation,
  ) {
    final selected =
        conversation['id'] == selectedId;

    final unread =
        conversation['unread'] as int;

    return Material(
      color: selected
          ? const Color(0xFFE0F2FE)
          : Colors.white,
      child: InkWell(
        onTap: () {
          setState(() {
            selectedId =
                conversation['id'] as int;

            conversation['unread'] = 0;
            mobileChatOpen = true;
          });

          _scrollToBottom();
        },
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 85,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
         decoration: BoxDecoration(
  color: selected
      ? const Color(0xFFE0F2FE)
      : Colors.white,
  border: Border(
    left: BorderSide(
      color: selected
          ? const Color(0xFF0284C7)
          : Colors.transparent,
      width: 3,
    ),
    bottom: const BorderSide(
      color: Color(0xFFF1F5F9),
      width: 1,
    ),
  ),
),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _avatar(
                conversation['name'].toString(),
                selected: selected,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation['name']
                                .toString(),
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w700,
                              color: Color(
                                0xFF111827,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          conversation['time']
                              .toString(),
                          style: const TextStyle(
                            fontSize: 7.5,
                            color: Color(
                              0xFF94A3B8,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Text(
                          conversation['city']
                              .toString(),
                          style: const TextStyle(
                            fontSize: 8,
                            color: Color(
                              0xFF64748B,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _temperatureBadge(
                          conversation['temperature']
                              .toString(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation['lastMessage']
                                .toString(),
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 8.5,
                              color: Color(
                                0xFF64748B,
                              ),
                            ),
                          ),
                        ),

                        if (unread > 0) ...[
                          const SizedBox(width: 7),
                          Container(
                            width: 19,
                            height: 19,
                            alignment:
                                Alignment.center,
                            decoration:
                                const BoxDecoration(
                              color: Color(
                                0xFF16A34A,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // CHAT PANEL
  // =========================================================

  Widget _chatPanel({
    bool showBack = false,
  }) {
    final conversation =
        selectedConversation;

    if (conversation == null) {
      return const Center(
        child: Text(
          'Select a conversation',
        ),
      );
    }

    final messages =
        conversation['messages']
            as List<dynamic>;

    return Column(
      children: [
        _chatHeader(
          conversation,
          showBack,
        ),

        _aiStrip(
          conversation,
        ),

        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: ListView.builder(
              controller:
                  messageScrollController,
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16,
              ),
              itemCount:
                  messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding:
                        EdgeInsets.only(
                      bottom: 16,
                    ),
                    child: Center(
                      child: _DateChip(
                        text: 'Today',
                      ),
                    ),
                  );
                }

                return _messageBubble(
                  conversation,
                  messages[index - 1]
                      as Map<String,
                          dynamic>,
                );
              },
            ),
          ),
        ),

        _messageComposer(),
      ],
    );
  }

  Widget _chatHeader(
    Map<String, dynamic> conversation,
    bool showBack,
  ) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            IconButton(
              onPressed: () {
                setState(() {
                  mobileChatOpen = false;
                });
              },
              icon: const Icon(
                Icons.arrow_back_rounded,
              ),
            ),
            const SizedBox(width: 4),
          ],

          _avatar(
            conversation['name'].toString(),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        conversation['name']
                            .toString(),
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w800,
                          color: Color(
                            0xFF111827,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    _leadBadge(
                      conversation['temperature']
                          .toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${conversation['mobile']} • ${conversation['city']}',
                  style: const TextStyle(
                    fontSize: 8,
                    color:
                        Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          _iconButton(
            icon:
                Icons.phone_outlined,
            tooltip: 'Call',
            onTap: () {},
          ),

          const SizedBox(width: 8),

          _iconButton(
            icon:
                Icons.more_vert_rounded,
            tooltip: 'More',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _aiStrip(
    Map<String, dynamic> conversation,
  ) {
    final enabled =
        conversation['aiEnabled'] as bool;

    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
      ),
      color: const Color(0xFFF5F3FF),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius:
                  BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              size: 15,
              color: Color(0xFF7C3AED),
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Auto Reply',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                Text(
                  enabled
                      ? 'AI is responding automatically'
                      : 'Manual conversation mode',
                  style: const TextStyle(
                    fontSize: 7.5,
                    color:
                        Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          InkWell(
            borderRadius:
                BorderRadius.circular(18),
            onTap: () {
              setState(() {
                conversation['aiEnabled'] =
                    !enabled;
              });
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(
                        0xFF0284C7,
                      )
                    : const Color(
                        0xFFE2E8F0,
                      ),
                borderRadius:
                    BorderRadius.circular(18),
              ),
              child: Text(
                enabled ? 'AI ON' : 'AI OFF',
                style: TextStyle(
                  color: enabled
                      ? Colors.white
                      : const Color(
                          0xFF64748B,
                        ),
                  fontSize: 8.5,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(
    Map<String, dynamic> conversation,
    Map<String, dynamic> message,
  ) {
    final sender =
        message['sender'].toString();

    final isAdmin =
        sender == 'admin';

    final isBot =
        sender == 'bot';

    final alignment = isAdmin
        ? Alignment.centerRight
        : Alignment.centerLeft;

    Color bubbleColor;

    if (isAdmin) {
      bubbleColor =
          const Color(0xFFD9FDD3);
    } else if (isBot) {
      bubbleColor =
          const Color(0xFFEDE9FE);
    } else {
      bubbleColor = Colors.white;
    }

    String senderName;

    if (isAdmin) {
      senderName = 'You';
    } else if (isBot) {
      senderName = 'AI Assistant';
    } else {
      senderName =
          conversation['name'].toString();
    }

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 470,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 12,
        ),
        padding:
            const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          8,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius:
              BorderRadius.circular(11),
          border: isAdmin || isBot
              ? null
              : Border.all(
                  color: const Color(
                    0xFFE5E7EB,
                  ),
                ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isBot) ...[
                  const Icon(
                    Icons.smart_toy_outlined,
                    size: 11,
                    color:
                        Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight:
                        FontWeight.w700,
                    color: isBot
                        ? const Color(
                            0xFF7C3AED,
                          )
                        : const Color(
                            0xFF64748B,
                          ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 5),

            Text(
              message['text'].toString(),
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.45,
                color: Color(0xFF111827),
              ),
            ),

            const SizedBox(height: 5),

            Align(
              alignment:
                  Alignment.centerRight,
              child: Text(
                message['time'].toString(),
                style: const TextStyle(
                  fontSize: 7,
                  color:
                      Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // COMPOSER
  // =========================================================

  Widget _messageComposer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Attachment',
            onPressed: () {},
            icon: const Icon(
              Icons.attach_file_rounded,
              color: Color(0xFF64748B),
            ),
          ),

          const SizedBox(width: 5),

          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller:
                    messageController,
                onSubmitted: (_) {
                  _sendMessage();
                },
                decoration:
                    InputDecoration(
                  hintText:
                      'Type your message...',
                  hintStyle:
                      const TextStyle(
                    fontSize: 12,
                    color:
                        Color(0xFF64748B),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 0,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    borderSide:
                        const BorderSide(
                      color:
                          Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    borderSide:
                        const BorderSide(
                      color:
                          Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    borderSide:
                        const BorderSide(
                      color:
                          Color(0xFF0284C7),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 88,
            height: 44,
            child: ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                minimumSize:
                    const Size(0, 44),
                maximumSize:
                    const Size(88, 44),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                ),
              ),
              onPressed:
                  _sendMessage,
              child: const Row(
                mainAxisSize:
                    MainAxisSize.min,
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.send_rounded,
                    size: 15,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Send',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w700,
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

  void _sendMessage() {
    final text =
        messageController.text.trim();

    final conversation =
        selectedConversation;

    if (text.isEmpty ||
        conversation == null) {
      return;
    }

    setState(() {
      final messages =
          conversation['messages']
              as List<dynamic>;

      messages.add({
        'id': DateTime.now()
            .millisecondsSinceEpoch,
        'sender': 'admin',
        'text': text,
        'time': _currentTime(),
      });

      conversation['lastMessage'] =
          text;

      conversation['time'] =
          'Just now';

      conversation['unread'] = 0;
    });

    messageController.clear();

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!messageScrollController
            .hasClients) {
          return;
        }

        messageScrollController.animateTo(
          messageScrollController
              .position.maxScrollExtent,
          duration:
              const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      },
    );
  }

  String _currentTime() {
    final now = DateTime.now();

    int hour = now.hour;

    final minute =
        now.minute.toString().padLeft(
              2,
              '0',
            );

    final period =
        hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    return '$hour:$minute $period';
  }

  // =========================================================
  // HELPERS
  // =========================================================

  Widget _avatar(
    String name, {
    bool selected = false,
  }) {
    final parts = name
        .trim()
        .split(' ')
        .where(
          (item) => item.isNotEmpty,
        )
        .toList();

    String initials = '';

    if (parts.isNotEmpty) {
      initials =
          parts.first.substring(0, 1);

      if (parts.length > 1) {
        initials +=
            parts.last.substring(0, 1);
      }
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: selected
          ? const Color(0xFFE0F2FE)
          : const Color(0xFF0284C7),
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: selected
              ? const Color(
                  0xFF0284C7,
                )
              : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _temperatureBadge(
    String temperature,
  ) {
    Color background;
    Color foreground;

    switch (temperature) {
      case 'Hot':
        background =
            const Color(0xFFFEF2F2);
        foreground =
            const Color(0xFFDC2626);
        break;

      case 'Warm':
        background =
            const Color(0xFFFFF7ED);
        foreground =
            const Color(0xFFEA580C);
        break;

      default:
        background =
            const Color(0xFFEFF6FF);
        foreground =
            const Color(0xFF2563EB);
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Text(
        temperature,
        style: TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _leadBadge(
    String temperature,
  ) {
    Color background;
    Color foreground;

    if (temperature == 'Hot') {
      background =
          const Color(0xFFFEF2F2);
      foreground =
          const Color(0xFFDC2626);
    } else if (temperature == 'Warm') {
      background =
          const Color(0xFFFFF7ED);
      foreground =
          const Color(0xFFEA580C);
    } else {
      background =
          const Color(0xFFEFF6FF);
      foreground =
          const Color(0xFF2563EB);
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Text(
        '$temperature Lead',
        style: TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 38,
      height: 38,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize:
              const Size(38, 38),
          maximumSize:
              const Size(38, 38),
          padding: EdgeInsets.zero,
          side: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(9),
          ),
        ),
        onPressed: onTap,
        child: Icon(
          icon,
          size: 17,
          color:
              const Color(0xFF475569),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String text;

  const _DateChip({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 7.5,
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}