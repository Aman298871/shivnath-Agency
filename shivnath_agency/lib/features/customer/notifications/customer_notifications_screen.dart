import 'package:flutter/material.dart';
import '../../../core/services/stock_service.dart';

class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  State<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends State<CustomerNotificationsScreen> {
  final StockService _stockService = StockService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final res = await _stockService.getCustomerNotifications();
    if (!mounted) return;

    if (res['success'] == true && res['data'] is Map<String, dynamic>) {
      final list = res['data']['notifications'] as List? ?? [];
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(list);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int? id) async {
    setState(() {
      if (id != null) {
        for (var n in _notifications) {
          if (n['id'] == id) n['is_read'] = true;
        }
      } else {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      }
    });
    await _stockService.markCustomerNotificationsAsRead(id: id);
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'low_stock':
        return Icons.warning_amber_rounded;
      case 'order':
      case 'order_update':
      case 'order_status':
        return Icons.shopping_bag_rounded;
      case 'service_status':
        return Icons.pause_circle_outline_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getIconColor(String? type) {
    switch (type) {
      case 'low_stock':
        return const Color(0xFFD97706);
      case 'order':
      case 'order_update':
      case 'order_status':
        return const Color(0xFF0284C7);
      case 'service_status':
        return const Color(0xFF9333EA);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => n['is_read'] != true);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (hasUnread)
            TextButton.icon(
              onPressed: () => _markAsRead(null),
              icon: const Icon(Icons.done_all, size: 16, color: Color(0xFF0284C7)),
              label: const Text(
                'Mark all read',
                style: TextStyle(
                  color: Color(0xFF0284C7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchNotifications();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: _notifications.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No notifications',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Updates on your stock, daily deliveries, and orders will appear here.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _notifications[index];
                        final isRead = item['is_read'] == true;
                        final notifType = item['notification_type']?.toString();
                        final title = item['title']?.toString() ?? 'Notification';
                        final message = item['message']?.toString() ?? '';
                        final createdAt = item['created_at']?.toString() ?? '';
                        final iconColor = _getIconColor(notifType);

                        return Card(
                          elevation: isRead ? 0 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isRead
                                  ? const Color(0xFFE2E8F0)
                                  : iconColor.withValues(alpha: 0.4),
                              width: isRead ? 1 : 1.5,
                            ),
                          ),
                          color: isRead ? Colors.white : const Color(0xFFFFFBEB),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: CircleAvatar(
                              backgroundColor: iconColor.withValues(alpha: 0.12),
                              child: Icon(_getIcon(notifType), color: iconColor),
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  if (createdAt.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      createdAt,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            trailing: !isRead
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      size: 20,
                                      color: Color(0xFF16A34A),
                                    ),
                                    tooltip: 'Mark as read',
                                    onPressed: () => _markAsRead(item['id']),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
