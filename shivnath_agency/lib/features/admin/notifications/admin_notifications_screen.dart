import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_toast.dart';
class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  String tab = 'All';

  final List<Map<String, dynamic>> notifications = [
    {
      'id': 1,
      'title': 'New Franchise Order',
      'message': 'Rahul Sharma placed order ORD-1001 worth ₹48,500.',
      'time': '5 min ago',
      'type': 'order',
      'read': false,
    },
    {
      'id': 2,
      'title': 'Low Stock Alert',
      'message': '20 Litre Water Jar stock has reached minimum level.',
      'time': '18 min ago',
      'type': 'inventory',
      'read': false,
    },
    {
      'id': 3,
      'title': 'Payment Received',
      'message': '₹20,000 payment received for invoice INV-2026-102.',
      'time': '35 min ago',
      'type': 'payment',
      'read': false,
    },
    {
      'id': 4,
      'title': 'Follow-up Reminder',
      'message': 'Follow-up with Amit Verma is scheduled today at 12:00 PM.',
      'time': '1 hour ago',
      'type': 'followup',
      'read': true,
    },
    {
      'id': 5,
      'title': 'Franchise Agreement',
      'message': 'Priya Singh franchise agreement document was uploaded.',
      'time': '2 hours ago',
      'type': 'franchise',
      'read': true,
    },
  ];

  int get unreadCount =>
      notifications.where((e) => e['read'] == false).length;

  List<Map<String, dynamic>> get filtered {
    if (tab == 'Unread') {
      return notifications.where((e) => e['read'] == false).toList();
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
      ['Total Notifications', '${notifications.length}'],
      ['Unread', '$unreadCount'],
      ['Read', '${notifications.length - unreadCount}'],
    ];

    if (desktop) {
      return Row(
        children: List.generate(
          data.length,
          (index) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == data.length - 1 ? 0 : 12,
              ),
              child: _NotificationStat(
                title: data[index][0],
                value: data[index][1],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: data
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _NotificationStat(
                title: e[0],
                value: e[1],
              ),
            ),
          )
          .toList(),
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
            child: Row(
              children: [
                _tabButton('All', notifications.length),
                const SizedBox(width: 8),
                _tabButton('Unread', unreadCount),
                const Spacer(),
                if (unreadCount > 0)
                  TextButton.icon(
                    onPressed: _markAllRead,
                    icon: const Icon(Icons.done_all, size: 17),
                    label: const Text('Mark All Read'),
                  ),
              ],
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
    final unread = item['read'] == false;

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
              color: _typeColor(item['type']).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _typeIcon(item['type']),
              size: 19,
              color: _typeColor(item['type']),
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
                        item['title'],
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
                  item['message'],
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['time'],
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              if (unread)
                TextButton(
                  onPressed: () {
  setState(() {
    item['read'] = true;
  });

  AppToast.success(
    context,
    'Notification marked as read.',
    title: 'Notification Read',
  );
},
                  child: const Text(
                    'Mark Read',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () {
  final title =
      item['title'].toString();

  setState(() {
    notifications.removeWhere(
      (e) => e['id'] == item['id'],
    );
  });

  AppToast.success(
    context,
    '$title deleted.',
    title: 'Notification Deleted',
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

  void _markAllRead() {
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
      item['read'] = true;
    }
  });

  AppToast.success(
    context,
    'All notifications marked as read.',
    title: 'Notifications Updated',
  );
}

  IconData _typeIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'inventory':
        return Icons.inventory_2_outlined;
      case 'payment':
        return Icons.currency_rupee;
      case 'followup':
        return Icons.schedule;
      case 'franchise':
        return Icons.store_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'inventory':
        return Colors.orange;
      case 'payment':
        return Colors.green;
      case 'followup':
        return Colors.blue;
      case 'franchise':
        return Colors.purple;
      default:
        return const Color(0xFF0284C7);
    }
  }
}

class _NotificationStat extends StatelessWidget {
  final String title;
  final String value;

  const _NotificationStat({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(16),
      decoration: _notificationDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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