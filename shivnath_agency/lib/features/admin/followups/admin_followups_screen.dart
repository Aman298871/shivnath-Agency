import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/services/followup_service.dart';
import '../../../core/utils/contact_action_helper.dart';
import 'completed_followups_screen.dart';
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

    final followupResult = await _followupService.getFollowups();
    final statsResult = await _followupService.getStats();

    if (!mounted) return;

    if (followupResult["success"] == true) {
      final dynamic raw = followupResult["data"] is Map
          ? (followupResult["data"]["followups"] ?? followupResult["data"])
          : (followupResult["followups"]);
      if (raw is List) {
        followups = List<Map<String, dynamic>>.from(
          raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
      }
    }

    if (statsResult["success"] == true) {
      final dynamic raw = statsResult["data"] is Map
          ? (statsResult["data"]["stats"] ?? statsResult["data"])
          : (statsResult["stats"]);
      if (raw is Map) {
        stats = Map<String, dynamic>.from(raw);
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  String activeTab = 'Today';
  String search = '';

  String get _todayDateStr {
    final now = DateTime.now();
    return "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  List<Map<String, dynamic>> get filteredData {
    final today = _todayDateStr;
    return followups.where((item) {
      final keyword = search.trim().toLowerCase();

      final matchesSearch =
          keyword.isEmpty ||
          item['lead'].toString().toLowerCase().contains(keyword) ||
          item['phone'].toString().contains(keyword) ||
          item['city'].toString().toLowerCase().contains(keyword);

      if (!matchesSearch) return false;

      String date = item['date']?.toString() ?? '';
      if (date.isEmpty && item['followup_datetime'] != null) {
        try {
          final dt = DateTime.parse(item['followup_datetime'].toString()).toLocal();
          date = "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
        } catch (_) {}
      }

      final status = (item['status'] ?? 'Pending').toString();
      final isCompleted = status.toLowerCase() == 'completed';

      if (activeTab == 'Completed') {
        return isCompleted;
      }

      if (isCompleted) {
        return false;
      }

      if (activeTab == 'Today') {
        return date == today;
      }

      if (activeTab == 'Overdue') {
        return date.isNotEmpty && date.compareTo(today) < 0;
      }

      if (activeTab == 'Upcoming') {
        return date.isNotEmpty && date.compareTo(today) > 0;
      }

      return true;
    }).toList();
  }

  int countFor(String type) {
    int? val;
    switch (type) {
      case "Today":
        val = stats["today"];
        break;
      case "Overdue":
        val = stats["overdue"];
        break;
      case "Upcoming":
        val = stats["upcoming"];
        break;
      case "Completed":
        val = stats["completed"];
        break;
    }

    if (val != null && val > 0) return val;

    final today = _todayDateStr;
    if (type == "Today") {
      return followups.where((f) {
        final d = f['date']?.toString() ?? '';
        final s = (f['status'] ?? '').toString();
        return d == today && s.toLowerCase() != 'completed';
      }).length;
    }
    if (type == "Overdue") {
      return followups.where((f) {
        final d = f['date']?.toString() ?? '';
        final s = (f['status'] ?? '').toString();
        return d.isNotEmpty && d.compareTo(today) < 0 && s.toLowerCase() != 'completed';
      }).length;
    }
    if (type == "Upcoming") {
      return followups.where((f) {
        final d = f['date']?.toString() ?? '';
        final s = (f['status'] ?? '').toString();
        return d.isNotEmpty && d.compareTo(today) > 0 && s.toLowerCase() != 'completed';
      }).length;
    }
    if (type == "Completed") {
      return followups.where((f) {
        final s = (f['status'] ?? '').toString();
        return s.toLowerCase() == 'completed';
      }).length;
    }

    return val ?? 0;
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Follow-ups',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Manage lead follow-ups and scheduled actions',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text(
                            'Completed Follow-ups',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CompletedFollowupsScreen()),
                            );
                          },
                        ),
                      ],
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
            final title = items[index]['title'].toString();
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == items.length - 1 ? 0 : 14,
                ),
                child: _SummaryCard(
                  title: title,
                  value: items[index]['value'].toString(),
                  icon: items[index]['icon'] as IconData,
                  type: items[index]['type'].toString(),
                  isSelected: activeTab.toLowerCase() == title.toLowerCase(),
                  onTap: () {
                    setState(() {
                      activeTab = title;
                    });
                  },
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (_, index) {
        final title = items[index]['title'].toString();
        return _SummaryCard(
          title: title,
          value: items[index]['value'].toString(),
          icon: items[index]['icon'] as IconData,
          type: items[index]['type'].toString(),
          isSelected: activeTab.toLowerCase() == title.toLowerCase(),
          onTap: () {
            setState(() {
              activeTab = title;
            });
          },
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
            ContactActionHelper.makePhoneCall(context, item['phone']?.toString());
          },
        ),

        _actionIcon(
          icon: Icons.chat_outlined,
          tooltip: 'Chat / WhatsApp',
          onTap: () {
            ContactActionHelper.openMessagingChooser(
              context,
              phone: item['phone']?.toString(),
              contactName: item['lead']?.toString(),
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
            onPressed: () => _promptCompleteFollowup(item),
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

  Future<void> _promptCompleteFollowup(Map<String, dynamic> item) async {
    final outcomeController = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Complete Follow-up'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark follow-up for "${item['lead'] ?? 'Lead'}" as completed?',
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: outcomeController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Outcome / Notes (Optional)',
                  hintText: 'e.g. Discussed requirements, customer requested catalog.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final outcome = outcomeController.text.trim();
                final result = await _followupService.completeFollowup(
                  item["id"],
                  outcome: outcome.isNotEmpty ? outcome : 'Marked as completed',
                );

                if (result["success"] == true) {
                  AppToast.success(context, "Follow-up completed & archived.");
                  _loadData();
                } else {
                  AppToast.error(
                    context,
                    result["message"] ?? "Failed to complete follow-up.",
                  );
                }
              },
              child: const Text('Mark Complete'),
            ),
          ],
        );
      },
    );
    outcomeController.dispose();
  }

  Future<void> _reschedule(Map<String, dynamic> item) async {
    DateTime initialDt = DateTime.now();
    try {
      if (item['followup_datetime'] != null) {
        initialDt = DateTime.parse(item['followup_datetime'].toString()).toLocal();
      } else if (item['date'] != null) {
        final parsed = DateTime.tryParse(item['date'].toString());
        if (parsed != null) initialDt = parsed;
      }
    } catch (_) {}

    final now = DateTime.now();
    final firstDt = initialDt.isBefore(now)
        ? initialDt.subtract(const Duration(days: 30))
        : now.subtract(const Duration(days: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDt.isBefore(firstDt) ? firstDt : initialDt,
      firstDate: firstDt,
      lastDate: DateTime(2030),
      helpText: 'Select New Follow-up Date',
    );

    if (pickedDate == null) return;

    final targetDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 10, 0);

    final result = await _followupService.updateFollowup(
      id: item["id"],
      dateTime: targetDateTime,
      type: item["type"]?.toString() ?? "Phone Call",
      note: item["note"]?.toString() ?? "",
    );

    if (result["success"] == true) {
      AppToast.success(
        context,
        "Follow-up rescheduled to ${DateFormat('dd MMM yyyy').format(pickedDate)}.",
      );
      _loadData();
    } else {
      AppToast.error(
        context,
        result["message"] ?? "Failed to reschedule follow-up.",
      );
    }
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
  final bool isSelected;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.type,
    this.isSelected = false,
    this.onTap,
  });

  Color get iconColor {
    switch (type) {
      case 'overdue':
        return const Color(0xFFDC2626);

      case 'upcoming':
        return const Color(0xFFD97706);

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? iconColor : const Color(0xFFE2E8F0),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? iconColor : const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: iconColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}