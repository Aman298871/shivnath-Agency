import 'package:flutter/material.dart';
import '../../../../core/widgets/app_toast.dart';

class WhatsAppAutomationTab extends StatefulWidget {
  const WhatsAppAutomationTab({super.key});

  @override
  State<WhatsAppAutomationTab> createState() =>
      _WhatsAppAutomationTabState();
}

class _WhatsAppAutomationTabState
    extends State<WhatsAppAutomationTab> {
  final List<Map<String, dynamic>> automations = [
    {
      'id': 1,
      'day': 1,
      'title': 'Welcome Message',
      'description':
          'Send welcome message immediately after a new lead is created.',
      'type': 'Message',
      'enabled': true,
      'message':
          'Namaste 👋 Thank you for your interest in our Drinking Water Franchise. Our team will contact you shortly.',
    },
    {
      'id': 2,
      'day': 3,
      'title': 'Digital Brochure',
      'description':
          'Automatically send franchise brochure to the prospect.',
      'type': 'Document',
      'enabled': true,
      'message':
          'Hello {{name}}, please find our Drinking Water Franchise brochure attached. Let us know if you have any questions.',
    },
    {
      'id': 3,
      'day': 5,
      'title': 'Success Story',
      'description':
          'Share franchise success story to build trust.',
      'type': 'Message',
      'enabled': true,
      'message':
          'Hello {{name}}, here is a success story from one of our franchise partners.',
    },
    {
      'id': 4,
      'day': 7,
      'title': 'Product & Plant Video',
      'description':
          'Share product and manufacturing plant video.',
      'type': 'Video',
      'enabled': true,
      'message':
          'Hello {{name}}, take a look at our product range and manufacturing plant.',
    },
    {
      'id': 5,
      'day': 10,
      'title': 'Call Reminder',
      'description':
          'Remind sales executive to call the prospect.',
      'type': 'Reminder',
      'enabled': true,
      'message':
          'Follow-up reminder: Please contact {{name}} regarding the franchise enquiry.',
    },
    {
      'id': 6,
      'day': 15,
      'title': 'Limited-Time Franchise Offer',
      'description':
          'Send limited-time offer to inactive/interested leads.',
      'type': 'Message',
      'enabled': true,
      'message':
          'Hello {{name}}, we currently have a limited-time franchise opportunity available. Reply YES to know more.',
    },
  ];

  int get activeCount {
    return automations
        .where(
          (item) => item['enabled'] == true,
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          padding: EdgeInsets.all(
            desktop ? 28 : 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1300,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pageHeader(),

                  const SizedBox(height: 20),

                  _summary(desktop),

                  const SizedBox(height: 20),

                  _journeyCard(),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pageHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WhatsApp Automation',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage automatic WhatsApp follow-ups for franchise leads.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(width: 6),
              Text(
                '$activeCount Automations Active',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15803D),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summary(bool desktop) {
    final items = [
      {
        'title': 'Active Automations',
        'value': '$activeCount',
        'icon': Icons.play_circle_outline,
      },
      {
        'title': 'Follow-up Journey',
        'value': '15 Days',
        'icon': Icons.calendar_month_outlined,
      },
      {
        'title': 'Automation Type',
        'value': 'WhatsApp',
        'icon': Icons.smart_toy_outlined,
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
                child: _summaryCard(
                  items[index],
                ),
              ),
            );
          },
        ),
      );
    }

    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: _summaryCard(item),
            ),
          )
          .toList(),
    );
  }

  Widget _summaryCard(
    Map<String, dynamic> item,
  ) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: const Color(0xFF0284C7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'].toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item['value'].toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _journeyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Franchise Lead Follow-up Journey',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Messages are automatically triggered based on lead age.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 22),
          ...List.generate(
            automations.length,
            (index) {
              final item = automations[index];
              final last = index == automations.length - 1;

              return _automationItem(
                item,
                last,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _automationItem(
    Map<String, dynamic> item,
    bool last,
  ) {
    final enabled =
        item['enabled'] as bool;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0xFF0284C7)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _typeIcon(
                  item['type'].toString(),
                ),
                size: 19,
                color: enabled
                    ? Colors.white
                    : const Color(0xFF64748B),
              ),
            ),
            if (!last)
              Container(
                width: 2,
                height: 125,
                color: enabled
                    ? const Color(0xFFBAE6FD)
                    : const Color(0xFFE2E8F0),
              ),
          ],
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Container(
            margin: const EdgeInsets.only(
              bottom: 15,
            ),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Day ${item['day']}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item['title'].toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item['description'].toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      width: 85,
                      height: 36,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          maximumSize: const Size(85, 36),
                        ),
                        onPressed: () {
                          _editAutomation(item);
                        },
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 14,
                        ),
                        label: const Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Switch(
                      value: enabled,
                      onChanged: (value) {
                        setState(() {
                          item['enabled'] = value;
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['message'].toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 14,
                  runSpacing: 7,
                  children: [
                    _meta(
                      Icons.schedule,
                      'Trigger: Day ${item['day']}',
                    ),
                    _meta(
                      Icons.description_outlined,
                      'Type: ${item['type']}',
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: enabled
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFF1F5F9),
                        borderRadius:
                            BorderRadius.circular(15),
                      ),
                      child: Text(
                        enabled
                            ? 'Active'
                            : 'Inactive',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: enabled
                              ? const Color(0xFF15803D)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _meta(
    IconData icon,
    String value,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: const Color(0xFF64748B),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  IconData _typeIcon(
    String type,
  ) {
    switch (type) {
      case 'Document':
        return Icons.description_outlined;
      case 'Video':
        return Icons.videocam_outlined;
      case 'Image':
        return Icons.image_outlined;
      case 'Reminder':
        return Icons.schedule;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  Future<void> _editAutomation(
    Map<String, dynamic> item,
  ) async {
    final titleController = TextEditingController(
      text: item['title'].toString(),
    );

    final dayController = TextEditingController(
      text: item['day'].toString(),
    );

    final messageController = TextEditingController(
      text: item['message'].toString(),
    );

    String type =
        item['type'].toString();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Automation',
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Configure WhatsApp follow-up message',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: titleController,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Automation Title',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: dayController,
                        keyboardType:
                            TextInputType.number,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Trigger Day',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Message Type',
                        ),
                        items: const [
                          'Message',
                          'Document',
                          'Video',
                          'Image',
                          'Reminder',
                        ].map(
                          (value) {
                            return DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            );
                          },
                        ).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            type = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller:
                            messageController,
                        minLines: 5,
                        maxLines: 8,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'WhatsApp Message',
                          alignLabelWithHint:
                              true,
                          helperText:
                              'Variables: {{name}}, {{city}}',
                        ),
                      ),
                    ],
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
                  child:
                      const Text('Cancel'),
                ),
                SizedBox(
                  width: 130,
                  height: 42,
                  child:
                      ElevatedButton.icon(
                    style:
                        ElevatedButton.styleFrom(
                      minimumSize:
                          const Size(0, 42),
                      maximumSize:
                          const Size(130, 42),
                    ),
                    onPressed: () {
                      final title =
                          titleController.text
                              .trim();

                      final message =
                          messageController.text
                              .trim();

                      final day =
                          int.tryParse(
                        dayController.text
                            .trim(),
                      );

                      if (title.isEmpty ||
                          message.isEmpty ||
                          day == null) {
                        AppToast.error(
                          context,
                          'Title, trigger day and message are required.',
                          title:
                              'Validation Error',
                        );
                        return;
                      }

                      setState(() {
                        item['title'] =
                            title;
                        item['day'] =
                            day;
                        item['type'] =
                            type;
                        item['message'] =
                            message;
                      });

                      Navigator.pop(
                        dialogContext,
                      );

                      AppToast.success(
                        context,
                        'Automation updated successfully.',
                        title:
                            'Automation Updated',
                      );
                    },
                    icon: const Icon(
                      Icons.save_outlined,
                      size: 16,
                    ),
                    label: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    dayController.dispose();
    messageController.dispose();
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: const Color(0xFFE5E7EB),
      ),
    );
  }
}