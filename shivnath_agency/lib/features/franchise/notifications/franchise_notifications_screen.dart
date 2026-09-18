import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';

class FranchiseNotificationsScreen extends StatefulWidget {
  const FranchiseNotificationsScreen({super.key});

  @override
  State<FranchiseNotificationsScreen> createState() => _FranchiseNotificationsScreenState();
}

class _FranchiseNotificationsScreenState extends State<FranchiseNotificationsScreen> {
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final res = await _authService.getFranchiseNotifications();
    if (mounted) {
      List<Map<String, dynamic>> list = [];
      if (res['success'] == true && res['data'] != null && res['data']['notifications'] is List) {
        list = List<Map<String, dynamic>>.from(res['data']['notifications']);
      }
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(int? id) async {
    await _authService.markFranchiseNotificationsAsRead(id: id);
    _fetchNotifications();
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'new_customer':
        return Icons.person_add_alt_1_rounded;
      case 'order':
        return Icons.shopping_bag_rounded;
      case 'stock_alert':
        return Icons.warning_amber_rounded;
      case 'service_status':
        return Icons.pause_circle_outline_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getIconColor(String? type) {
    switch (type) {
      case 'new_customer':
        return const Color(0xFF0284C7);
      case 'order':
        return const Color(0xFF16A34A);
      case 'stock_alert':
        return const Color(0xFFE11D48);
      case 'service_status':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF0284C7);
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month]} ${dt.year}, $hour:$minute $ampm';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_notifications.any((n) => n['is_read'] != true))
            TextButton.icon(
              onPressed: () => _markAsRead(null),
              icon: const Icon(Icons.done_all, size: 16, color: Color(0xFF0284C7)),
              label: const Text('Mark all read', style: TextStyle(color: Color(0xFF0284C7), fontSize: 12)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: _notifications.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 60,
                              color: Color(0xFFCBD5E1),
                            ),
                            SizedBox(height: 14),
                            Text(
                              'No notifications yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Customer registrations, order assignments, and 7-day low stock alerts will appear here in real time.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _notifications[index];
                        final isRead = item['is_read'] == true;
                        final type = item['notification_type']?.toString();
                        final title = item['title']?.toString() ?? 'Update';
                        final message = item['message']?.toString() ?? '';
                        final time = _formatTime(item['created_at']?.toString());
                        final id = item['id'] as int?;

                        return InkWell(
                          onTap: isRead ? null : () => _markAsRead(id),
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isRead ? Colors.white : const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: isRead ? const Color(0xFFE5E7EB) : const Color(0xFFBAE6FD),
                                width: isRead ? 1 : 1.5,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: _getIconColor(type).withAlpha(25),
                                  child: Icon(
                                    _getIcon(type),
                                    color: _getIconColor(type),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                                fontSize: 14,
                                                color: isRead ? const Color(0xFF1E293B) : const Color(0xFF0369A1),
                                              ),
                                            ),
                                          ),
                                          if (!isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF0284C7),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        message,
                                        style: const TextStyle(
                                          color: Color(0xFF475569),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        time,
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}