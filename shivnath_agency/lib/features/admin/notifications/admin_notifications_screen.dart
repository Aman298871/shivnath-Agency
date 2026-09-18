import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/app_toast.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final AuthService _authService = AuthService();
  String tab = 'All';
  bool _isLoading = true;

  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final res = await _authService.getAdminNotifications();
    if (mounted) {
      List<Map<String, dynamic>> list = [];
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        if (data is Map<String, dynamic> && data['notifications'] is List) {
          list = List<Map<String, dynamic>>.from(data['notifications']);
        }
      }
      setState(() {
        notifications = list;
        _isLoading = false;
      });
    }
  }

  int get unreadCount =>
      notifications.where((e) => e['is_read'] == false || e['read'] == false).length;

  int get readCount =>
      notifications.where((e) => e['is_read'] == true || e['read'] == true).length;

  List<Map<String, dynamic>> get filtered {
    if (tab == 'Unread') {
      return notifications
          .where((e) => e['is_read'] == false || e['read'] == false)
          .toList();
    }
    if (tab == 'Read') {
      return notifications
          .where((e) => e['is_read'] == true || e['read'] == true)
          .toList();
    }

    return notifications;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF5F7FB),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(desktop),
                    const SizedBox(height: 22),
                    _stats(desktop),
                    const SizedBox(height: 18),
                    _notificationCard(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(bool desktop) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'View system alerts and updates',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        if (desktop && unreadCount > 0)
          SizedBox(
            width: 150,
            height: 42,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 42),
                maximumSize: const Size(150, 42),
              ),
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all),
              label: const Text('Mark All Read'),
            ),
          ),
      ],
    );
  }

  Widget _stats(bool desktop) {
    final data = [
      [
        'Total Notifications',
        '${notifications.length}',
        Icons.notifications_none_rounded,
        const Color(0xFF0284C7),
        'All',
      ],
      [
        'Unread Notifications',
        '$unreadCount',
        Icons.mark_email_unread_outlined,
        const Color(0xFFDC2626),
        'Unread',
      ],
      [
        'Read Notifications',
        '$readCount',
        Icons.done_all_rounded,
        const Color(0xFF16A34A),
        'Read',
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 720;

        if (isMobile) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.85,
            ),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final filterTab = data[index][4] as String;
              final isSelected = tab == filterTab;

              return _NotificationStat(
                title: data[index][0] as String,
                value: data[index][1] as String,
                icon: data[index][2] as IconData,
                color: data[index][3] as Color,
                selected: isSelected,
                onTap: () => setState(() => tab = filterTab),
              );
            },
          );
        }

        return Row(
          children: [
            for (int i = 0; i < data.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(
                child: _NotificationStat(
                  title: data[i][0] as String,
                  value: data[i][1] as String,
                  icon: data[i][2] as IconData,
                  color: data[i][3] as Color,
                  selected: tab == (data[i][4] as String),
                  onTap: () => setState(() => tab = data[i][4] as String),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _notificationCard() {
    return Container(
      width: double.infinity,
      decoration: _notificationDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 480;
                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _tabButton('All', notifications.length),
                            const SizedBox(width: 8),
                            _tabButton('Unread', unreadCount),
                            const SizedBox(width: 8),
                            _tabButton('Read', readCount),
                          ],
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _markAllRead,
                            icon: const Icon(Icons.done_all, size: 16),
                            label: const Text('Mark All Read', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    _tabButton('All', notifications.length),
                    const SizedBox(width: 8),
                    _tabButton('Unread', unreadCount),
                    const SizedBox(width: 8),
                    _tabButton('Read', readCount),
                    const Spacer(),
                    if (unreadCount > 0)
                      TextButton.icon(
                        onPressed: _markAllRead,
                        icon: const Icon(Icons.done_all, size: 17),
                        label: const Text('Mark All Read'),
                      ),
                  ],
                );
              },
            ),
          ),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 38,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No notifications',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'You\'re all caught up.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            ...filtered.map(_notificationItem),
        ],
      ),
    );
  }

  Widget _tabButton(String title, int count) {
    final selected = tab == title;

    return InkWell(
      onTap: () => setState(() => tab = title),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0284C7)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$title  $count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _notificationItem(Map<String, dynamic> item) {
    final unread = item['is_read'] == false || item['read'] == false;
    final type = (item['notification_type'] ?? item['type'] ?? 'general').toString();
    final time = (item['created_at'] ?? item['time'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      color: unread ? const Color(0xFFF8FAFF) : Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _typeColor(type).withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _typeIcon(type),
              size: 20,
              color: _typeColor(type),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item['title'] ?? 'Notification',
                        style: TextStyle(
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 7),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0284C7),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item['message'] ?? '',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              if (unread)
                TextButton(
                  onPressed: () async {
                    final notifId = item['id'] is int ? item['id'] as int : null;
                    setState(() {
                      item['is_read'] = true;
                      item['read'] = true;
                    });
                    if (notifId != null) {
                      await _authService.markNotificationsAsRead(id: notifId);
                    }
                    if (mounted) {
                      AppToast.success(
                        context,
                        'Notification marked as read.',
                        title: 'Notification Read',
                      );
                    }
                  },
                  child: const Text(
                    'Mark Read',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () {
                  final title = (item['title'] ?? 'Notification').toString();
                  setState(() {
                    notifications.removeWhere(
                      (e) => e['id'] == item['id'],
                    );
                  });
                  AppToast.success(
                    context,
                    '$title dismissed.',
                    title: 'Notification Dismissed',
                  );
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _markAllRead() async {
    if (unreadCount == 0) {
      AppToast.info(
        context,
        'There are no unread notifications.',
        title: 'All Caught Up',
      );
      return;
    }

    setState(() {
      for (final item in notifications) {
        item['is_read'] = true;
        item['read'] = true;
      }
    });

    await _authService.markNotificationsAsRead();

    if (mounted) {
      AppToast.success(
        context,
        'All notifications marked as read.',
        title: 'Notifications Updated',
      );
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'customer_registration':
      case 'customer':
        return Icons.person_add_alt_1_outlined;
      case 'franchise_registration':
      case 'franchise':
        return Icons.store_outlined;
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'inventory':
        return Icons.inventory_2_outlined;
      case 'payment':
        return Icons.currency_rupee;
      case 'followup':
        return Icons.schedule;
      default:
        return Icons.notifications_none;
    }
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'customer_registration':
      case 'customer':
        return const Color(0xFF0284C7);
      case 'franchise_registration':
      case 'franchise':
        return Colors.purple;
      case 'order':
        return Colors.amber.shade800;
      case 'inventory':
        return Colors.orange;
      case 'payment':
        return Colors.green;
      case 'followup':
        return Colors.blue;
      default:
        return const Color(0xFF0284C7);
    }
  }
}

class _NotificationStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;

  const _NotificationStat({
    required this.title,
    required this.value,
    this.icon,
    this.color,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? const Color(0xFF0284C7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? cardColor.withAlpha(20) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? cardColor : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: cardColor.withAlpha(35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? cardColor : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: selected ? cardColor : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: cardColor, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _notificationDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFFE5E7EB)),
  );
}