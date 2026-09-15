import 'package:flutter/material.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/services/followup_service.dart';
class AdminFollowupsScreen extends StatefulWidget {
  const AdminFollowupsScreen({super.key});

  @override
  State<AdminFollowupsScreen> createState() =>
      _AdminFollowupsScreenState();
}

class _AdminFollowupsScreenState extends State<AdminFollowupsScreen> {
  final FollowupService _followupService =
    FollowupService();

List<Map<String, dynamic>> followups = [];

Map<String, dynamic> stats = {
  "today": 0,
  "overdue": 0,
  "upcoming": 0,
  "completed": 0,
};

bool isLoading = true;
@override
void initState() {
  super.initState();

  _loadData();
}
Future<void> _loadData() async {

  setState(() {
    isLoading = true;
  });

  final followupResult =
      await _followupService.getFollowups();

  final statsResult =
      await _followupService.getStats();

  if (!mounted) return;

  if (followupResult["success"] == true) {

    followups =
        List<Map<String, dynamic>>.from(
      followupResult["data"]["followups"],
    );
  }

  if (statsResult["success"] == true) {

    stats = Map<String, dynamic>.from(
      statsResult["data"]["stats"],
    );
  }

  setState(() {
    isLoading = false;
  });
}

  String activeTab = 'Today';
  String search = '';

  final String today = '2026-09-03';

  List<Map<String, dynamic>> get filteredData {
    return followups.where((item) {
      final keyword = search.trim().toLowerCase();

      final matchesSearch =
          keyword.isEmpty ||
          item['lead'].toString().toLowerCase().contains(keyword) ||
          item['phone'].toString().contains(keyword) ||
          item['city'].toString().toLowerCase().contains(keyword);

      if (!matchesSearch) return false;

      final date = item['date'].toString();
      final status = item['status'].toString();

      if (activeTab == 'Today') {
        return date == today && status == 'Pending';
      }

      if (activeTab == 'Overdue') {
        return date.compareTo(today) < 0 && status == 'Pending';
      }

      if (activeTab == 'Upcoming') {
        return date.compareTo(today) > 0 && status == 'Pending';
      }

      if (activeTab == 'Completed') {
        return status == 'Completed';
      }

      return true;
    }).toList();
  }

 int countFor(String type) {

  switch (type) {

    case "Today":
      return stats["today"] ?? 0;

    case "Overdue":
      return stats["overdue"] ?? 0;

    case "Upcoming":
      return stats["upcoming"] ?? 0;

    case "Completed":
      return stats["completed"] ?? 0;

    default:
      return 0;

  }

}

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF5F7FB),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1350,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Follow-ups',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Manage lead follow-ups and scheduled actions',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 22),

                    _summary(desktop),

                    const SizedBox(height: 20),
if (isLoading)
  const Center(
    child: Padding(
      padding: EdgeInsets.all(80),
      child: CircularProgressIndicator(),
    ),
  )
else
                    _mainCard(desktop),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summary(bool desktop) {
    final items = [
      {
        'title': 'Today',
        'value': countFor('Today'),
        'icon': Icons.calendar_month_outlined,
        'type': 'today',
      },
      {
        'title': 'Overdue',
        'value': countFor('Overdue'),
        'icon': Icons.error_outline,
        'type': 'overdue',
      },
      {
        'title': 'Upcoming',
        'value': countFor('Upcoming'),
        'icon': Icons.access_time,
        'type': 'upcoming',
      },
      {
        'title': 'Completed',
        'value': countFor('Completed'),
        'icon': Icons.check_circle_outline,
        'type': 'completed',
      },
    ];

    if (desktop) {
      return Row(
        children: List.generate(
          items.length,
          (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == items.length - 1 ? 0 : 14,
                ),
                child: _SummaryCard(
                  title: items[index]['title'].toString(),
                  value: items[index]['value'].toString(),
                  icon: items[index]['icon'] as IconData,
                  type: items[index]['type'].toString(),
                ),
              ),
            );
          },
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (_, index) {
        return _SummaryCard(
          title: items[index]['title'].toString(),
          value: items[index]['value'].toString(),
          icon: items[index]['icon'] as IconData,
          type: items[index]['type'].toString(),
        );
      },
    );
  }

  Widget _mainCard(bool desktop) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: desktop
                ? Row(
                    children: [
                      Expanded(
                        child: _tabs(),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 310,
                        child: _searchBox(),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _tabs(),
                      ),
                      const SizedBox(height: 12),
                      _searchBox(),
                    ],
                  ),
          ),

          const Divider(height: 1),

          if (filteredData.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 60,
              ),
              child: Text(
                'No ${activeTab.toLowerCase()} follow-ups found.',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            )
          else
            ...filteredData.map(
              (item) => _followupRow(
                item,
                desktop,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        'Today',
        'Overdue',
        'Upcoming',
        'Completed',
      ].map((tab) {
        final selected = activeTab == tab;

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              activeTab = tab;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFE0F2FE)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? const Color(0xFFBAE6FD)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tab,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${countFor(tab)}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _searchBox() {
    return TextField(
      onChanged: (value) {
        setState(() {
          search = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search lead, phone or city...',
        hintStyle: const TextStyle(
          fontSize: 12,
        ),
        prefixIcon: const Icon(
          Icons.search,
          size: 19,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
    );
  }

  Widget _followupRow(
    Map<String, dynamic> item,
    bool desktop,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 105,
                  child: _dateBox(item),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _mainInfo(item),
                ),
                const SizedBox(width: 20),
                _actions(item),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dateBox(item),
                const SizedBox(height: 14),
                _mainInfo(item),
                const SizedBox(height: 16),
                _actions(item),
              ],
            ),
    );
  }

  Widget _dateBox(
    Map<String, dynamic> item,
  ) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Text(
            _formatDate(
              item['date'].toString(),
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _formatTime(
              item['time'].toString(),
            ),
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainInfo(
    Map<String, dynamic> item,
  ) {
    final whatsapp =
        item['type'] == 'WhatsApp';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['lead'].toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['phone']} • ${item['city']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: whatsapp
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    whatsapp
                        ? Icons.chat_outlined
                        : Icons.phone_outlined,
                    size: 13,
                    color: whatsapp
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    item['type'].toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: whatsapp
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 11),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item['note'].toString(),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF475569),
            ),
          ),
        ),

        const SizedBox(height: 9),

        Text.rich(
          TextSpan(
            text: 'Assigned to: ',
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
            ),
            children: [
              TextSpan(
                text: item['executive'].toString(),
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actions(
    Map<String, dynamic> item,
  ) {
    if (item['status'] == 'Completed') {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 17,
              color: Color(0xFF16A34A),
            ),
            SizedBox(width: 6),
            Text(
              'Completed',
              style: TextStyle(
                color: Color(0xFF16A34A),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionIcon(
          icon: Icons.phone_outlined,
          tooltip: 'Call',
          onTap: () {
            AppToast.info(
              context,
              'Calling ${item['lead']}...',
              title: 'Call',
            );
          },
        ),

        _actionIcon(
          icon: Icons.chat_outlined,
          tooltip: 'WhatsApp',
          onTap: () {
            AppToast.info(
              context,
              'Opening WhatsApp for ${item['lead']}.',
              title: 'WhatsApp',
            );
          },
        ),

        _actionIcon(
          icon: Icons.calendar_month_outlined,
          tooltip: 'Reschedule',
          onTap: () {
            _reschedule(item);
          },
        ),

        SizedBox(
          width: 115,
          height: 38,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 38),
              maximumSize: const Size(115, 38),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
              ),
            ),
            onPressed: ()async {
             final result =
    await _followupService
        .completeFollowup(
  item["id"],
);

if (result["success"] == true) {

  AppToast.success(
    context,
    "Follow-up completed.",
  );

  _loadData();

}
else {

  AppToast.error(
    context,
    result["message"],
  );

}

              
            },
            icon: const Icon(
              Icons.check_circle_outline,
              size: 16,
            ),
            label: const Text(
              'Complete',
              style: TextStyle(
                fontSize: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Future<void> _reschedule(
    Map<String, dynamic> item,
  ) async {
    final controller = TextEditingController(
      text: item['date'].toString(),
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Reschedule Follow-up',
          ),
          content: SizedBox(
            width: 380,
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'New Date',
                hintText: 'YYYY-MM-DD',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('Cancel'),
            ),

            SizedBox(
              width: 100,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  maximumSize: const Size(100, 42),
                ),
                onPressed: ()async {
                  final value =
                      controller.text.trim();

                  if (!_validDate(value)) {
                    AppToast.error(
                      context,
                      'Enter date in YYYY-MM-DD format.',
                      title: 'Invalid Date',
                    );
                    return;
                  }

                  final result =
    await _followupService
        .updateFollowup(

  id: item["id"],

  dateTime: DateTime.parse(
      "$value ${item['time']}:00"),

  type: item["type"],

  note: item["note"],

);

if(result["success"]==true){

    Navigator.pop(dialogContext);

    AppToast.success(
      context,
      "Follow-up updated.",
    );

    _loadData();

}else{

    AppToast.error(
      context,
      result["message"],
    );

}

                  
                },
                child: const Text(
                  'Update',
                ),
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  bool _validDate(String value) {
    final regex = RegExp(
      r'^\d{4}-\d{2}-\d{2}$',
    );

    if (!regex.hasMatch(value)) {
      return false;
    }

    return DateTime.tryParse(value) != null;
  }

  String _formatDate(String value) {
    final date =
        DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final day =
        date.day.toString().padLeft(2, '0');

    return '$day ${months[date.month - 1]}';
  }

  String _formatTime(String value) {
    final parts = value.split(':');

    if (parts.length != 2) {
      return value;
    }

    final hour =
        int.tryParse(parts[0]) ?? 0;

    final minute = parts[1];

    final period =
        hour >= 12 ? 'PM' : 'AM';

    var displayHour = hour % 12;

    if (displayHour == 0) {
      displayHour = 12;
    }

    return '${displayHour.toString().padLeft(2, '0')}:$minute $period';
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String type;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.type,
  });

  Color get iconColor {
    switch (type) {
      case 'overdue':
        return const Color(0xFFDC2626);

      case 'upcoming':
        return const Color(0xFFF59E0B);

      case 'completed':
        return const Color(0xFF16A34A);

      default:
        return const Color(0xFF0284C7);
    }
  }

  Color get backgroundColor {
    switch (type) {
      case 'overdue':
        return const Color(0xFFFEF2F2);

      case 'upcoming':
        return const Color(0xFFFFFBEB);

      case 'completed':
        return const Color(0xFFECFDF5);

      default:
        return const Color(0xFFE0F2FE);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}