import 'package:flutter/material.dart';
import '../../../core/services/chat_service.dart';

class AdminChatConversationsScreen extends StatefulWidget {
  const AdminChatConversationsScreen({super.key});

  @override
  State<AdminChatConversationsScreen> createState() =>
      _AdminChatConversationsScreenState();
}

class _AdminChatConversationsScreenState
    extends State<AdminChatConversationsScreen> {
  static const Color primaryBlue = Color(0xFF0284C7);
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterRole = 'all';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    final data = await _chatService.getAdminConversations();
    if (mounted) {
      setState(() {
        _conversations = data;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredConversations {
    return _conversations.where((conv) {
      final appType = (conv['app_type'] ?? '').toString().toLowerCase();
      if (_filterRole != 'all' && appType != _filterRole) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final name = (conv['customer_name'] ?? '').toString().toLowerCase();
      final phone = (conv['customer_phone'] ?? '').toString().toLowerCase();
      final email = (conv['customer_email'] ?? '').toString().toLowerCase();
      final lastMsg = (conv['last_message'] ?? '').toString().toLowerCase();
      final user = (conv['user_username'] ?? '').toString().toLowerCase();
      return name.contains(query) ||
          phone.contains(query) ||
          email.contains(query) ||
          lastMsg.contains(query) ||
          user.contains(query);
    }).toList();
  }

  void _openConversationDetail(Map<String, dynamic> conv) async {
    final sessionId = conv['id'] as int;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConversationDetailSheet(
        sessionId: sessionId,
        summary: conv,
        chatService: _chatService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Inquiries & Chat Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConversations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by customer, phone, or message...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Channels', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Customer App', 'customer'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Franchise App', 'franchise'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Admin App', 'admin'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredConversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 56,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No conversation logs found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Inquiries and chatbot dialogues will appear here live.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadConversations,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filteredConversations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final c = _filteredConversations[idx];
                        final appType = (c['app_type'] ?? 'customer')
                            .toString()
                            .toUpperCase();
                        final name =
                            (c['customer_name'] ??
                                    c['user_name'] ??
                                    c['user_username'] ??
                                    'Guest User')
                                .toString();
                        final phone = (c['customer_phone'] ?? '').toString();
                        final lastMsg = (c['last_message'] ?? 'No messages yet')
                            .toString();
                        final msgCount = c['message_count'] ?? 0;
                        final updatedAt = (c['updated_at'] ?? '').toString();

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openConversationDetail(c),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: primaryBlue
                                                .withAlpha(30),
                                            child: Icon(
                                              appType == 'FRANCHISE'
                                                  ? Icons.store
                                                  : Icons.person,
                                              color: primaryBlue,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              if (phone.isNotEmpty)
                                                Text(
                                                  phone,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white60
                                                        : Colors.black54,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(
                                            appType,
                                          ).withAlpha(38),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          appType,
                                          style: TextStyle(
                                            color: _getRoleColor(appType),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    lastMsg,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$msgCount messages',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                      if (updatedAt.isNotEmpty)
                                        Text(
                                          _formatTimestamp(updatedAt),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterRole == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterRole = value),
      selectedColor: primaryBlue.withAlpha(50),
      labelStyle: TextStyle(
        color: isSelected ? primaryBlue : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Color _getRoleColor(String appType) {
    switch (appType.toLowerCase()) {
      case 'franchise':
        return Colors.orange;
      case 'admin':
        return Colors.purple;
      case 'customer':
      default:
        return primaryBlue;
    }
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }
}

class _ConversationDetailSheet extends StatefulWidget {
  final int sessionId;
  final Map<String, dynamic> summary;
  final ChatService chatService;

  const _ConversationDetailSheet({
    required this.sessionId,
    required this.summary,
    required this.chatService,
  });

  @override
  State<_ConversationDetailSheet> createState() =>
      _ConversationDetailSheetState();
}

class _ConversationDetailSheetState extends State<_ConversationDetailSheet> {
  static const Color primaryBlue = Color(0xFF0284C7);
  Map<String, dynamic>? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final res = await widget.chatService.getAdminConversationDetail(
      widget.sessionId,
    );
    if (mounted) {
      setState(() {
        _detail = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name =
        (widget.summary['customer_name'] ??
                widget.summary['user_name'] ??
                widget.summary['user_username'] ??
                'Guest User')
            .toString();
    final phone = (widget.summary['customer_phone'] ?? '').toString();
    final email = (widget.summary['customer_email'] ?? '').toString();
    final messages =
        (_detail?['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (phone.isNotEmpty || email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (phone.isNotEmpty) phone,
                            if (email.isNotEmpty) email,
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? const Center(child: Text('No messages recorded.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (ctx, idx) {
                      final msg = messages[idx];
                      final isBot = msg['sender'] == 'bot';
                      final text = (msg['message'] ?? '').toString();
                      final ts = (msg['created_at'] ?? '').toString();

                      return Align(
                        alignment: isBot
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          decoration: BoxDecoration(
                            color: isBot
                                ? (isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9))
                                : primaryBlue,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: isBot
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.end,
                            children: [
                              Text(
                                text,
                                style: TextStyle(
                                  color: isBot
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              if (ts.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(ts),
                                  style: TextStyle(
                                    color: isBot
                                        ? (isDark
                                              ? Colors.white38
                                              : Colors.black38)
                                        : Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
