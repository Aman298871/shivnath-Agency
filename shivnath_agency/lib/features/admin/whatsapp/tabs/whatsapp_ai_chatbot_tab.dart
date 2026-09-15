import 'package:flutter/material.dart';
import '../../../../core/widgets/app_toast.dart';

class WhatsAppAIChatbotTab extends StatefulWidget {
  const WhatsAppAIChatbotTab({
    super.key,
  });

  @override
  State<WhatsAppAIChatbotTab> createState() =>
      _WhatsAppAIChatbotTabState();
}

class _WhatsAppAIChatbotTabState
    extends State<WhatsAppAIChatbotTab> {
  bool enabled = true;
  bool autoReply = true;
  bool leadQualification = true;
  bool createCRMLead = true;
  bool humanHandover = true;

  final botNameController =
      TextEditingController(
    text: 'Pure Water Assistant',
  );

  final welcomeController =
      TextEditingController(
    text:
        'Namaste 👋 Thank you for your interest in our Drinking Water Franchise. How can I help you?',
  );

  final List<Map<String, dynamic>> knowledge = [
    {
      'id': 1,
      'title':
          'Franchise Details',
      'answer':
          'Our franchise model is designed for entrepreneurs who want to start a drinking water distribution business.',
    },
    {
      'id': 2,
      'title':
          'Investment Required',
      'answer':
          'Investment depends on location, infrastructure and selected franchise model. Our sales executive can provide the exact quotation.',
    },
    {
      'id': 3,
      'title':
          'Profit Margin',
      'answer':
          'Profit margin depends on product mix, monthly sales volume and distribution network.',
    },
    {
      'id': 4,
      'title':
          'Location Availability',
      'answer':
          'Location availability is checked based on city, district and existing franchise territory.',
    },
    {
      'id': 5,
      'title':
          'Talk to Sales Executive',
      'answer':
          'Sure. I can forward your enquiry to our sales team for personal assistance.',
    },
  ];

  @override
  void dispose() {
    botNameController.dispose();
    welcomeController.dispose();

    for (final item in knowledge) {
      final controller =
          item['controller'];

      if (controller
          is TextEditingController) {
        controller.dispose();
      }
    }

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    for (final item in knowledge) {
      item['controller'] =
          TextEditingController(
        text:
            item['answer'].toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final desktop =
            constraints.maxWidth >= 900;

        return SingleChildScrollView(
          padding: EdgeInsets.all(
            desktop ? 28 : 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 1300,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  _header(),

                  const SizedBox(
                    height: 20,
                  ),

                  _stats(desktop),

                  const SizedBox(
                    height: 20,
                  ),

                  if (desktop)
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Expanded(
                          child:
                              _settingsCard(),
                        ),
                        const SizedBox(
                          width: 18,
                        ),
                        Expanded(
                          child:
                              _previewCard(),
                        ),
                      ],
                    )
                  else ...[
                    _settingsCard(),
                    const SizedBox(
                      height: 16,
                    ),
                    _previewCard(),
                  ],

                  const SizedBox(
                    height: 20,
                  ),

                  _knowledgeCard(),

                  const SizedBox(
                    height: 30,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'AI Chatbot',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Configure AI responses and franchise enquiry handling.',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 150,
          height: 42,
          child:
              ElevatedButton.icon(
            style:
                ElevatedButton.styleFrom(
              minimumSize:
                  const Size(
                0,
                42,
              ),
              maximumSize:
                  const Size(
                150,
                42,
              ),
              backgroundColor: enabled
                  ? const Color(
                      0xFF7C3AED,
                    )
                  : const Color(
                      0xFF64748B,
                    ),
              foregroundColor:
                  Colors.white,
            ),
            onPressed: () {
              setState(() {
                enabled =
                    !enabled;
              });
            },
            icon: const Icon(
              Icons.smart_toy_outlined,
              size: 17,
            ),
            label: Text(
              enabled
                  ? 'AI Chatbot ON'
                  : 'AI Chatbot OFF',
              style:
                  const TextStyle(
                fontSize: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stats(bool desktop) {
    final data = [
      {
        'title': 'AI Status',
        'value':
            enabled ? 'Active' : 'Disabled',
        'icon':
            Icons.smart_toy_outlined,
      },
      {
        'title':
            'Quick Topics',
        'value':
            '${knowledge.length}',
        'icon':
            Icons.chat_bubble_outline,
      },
      {
        'title':
            'Lead Qualification',
        'value': leadQualification
            ? 'Enabled'
            : 'Disabled',
        'icon':
            Icons.psychology_outlined,
      },
    ];

    if (!desktop) {
      return Column(
        children: data
            .map(
              (item) => Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                child:
                    _statCard(item),
              ),
            )
            .toList(),
      );
    }

    return Row(
      children:
          List.generate(
        data.length,
        (index) {
          return Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(
                right: index ==
                        data.length -
                            1
                    ? 0
                    : 14,
              ),
              child:
                  _statCard(
                data[index],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(
    Map<String, dynamic> item,
  ) {
    return Container(
      height: 95,
      padding:
          const EdgeInsets.all(15),
      decoration:
          _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF3E8FF,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                10,
              ),
            ),
            child: Icon(
              item['icon']
                  as IconData,
              color:
                  const Color(
                0xFF7C3AED,
              ),
            ),
          ),
          const SizedBox(
            width: 11,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment
                      .center,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  item['title']
                      .toString(),
                  style:
                      const TextStyle(
                    fontSize: 10,
                    color:
                        Color(
                      0xFF64748B,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  item['value']
                      .toString(),
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard() {
    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration:
          _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.settings_outlined,
            'Chatbot Settings',
            'Control how AI handles incoming enquiries.',
          ),

          const SizedBox(height: 18),

          TextField(
            controller:
                botNameController,
            decoration:
                const InputDecoration(
              labelText: 'Bot Name',
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller:
                welcomeController,
            minLines: 4,
            maxLines: 6,
            decoration:
                const InputDecoration(
              labelText:
                  'Welcome Message',
              alignLabelWithHint:
                  true,
            ),
          ),

          const SizedBox(height: 16),

          _settingRow(
            Icons.chat_bubble_outline,
            'Automatic Reply',
            'AI automatically replies to incoming messages.',
            autoReply,
            (value) {
              setState(() {
                autoReply = value;
              });
            },
          ),

          _settingRow(
            Icons.auto_awesome_outlined,
            'Lead Qualification',
            'Collect customer information and calculate lead quality.',
            leadQualification,
            (value) {
              setState(() {
                leadQualification =
                    value;
              });
            },
          ),

          _settingRow(
            Icons.check_circle_outline,
            'Create CRM Lead',
            'Automatically create a CRM lead from WhatsApp enquiries.',
            createCRMLead,
            (value) {
              setState(() {
                createCRMLead =
                    value;
              });
            },
          ),

          _settingRow(
            Icons.support_agent_outlined,
            'Human Handover',
            'Allow chatbot to transfer conversation to a sales executive.',
            humanHandover,
            (value) {
              setState(() {
                humanHandover =
                    value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final investment =
        knowledge.firstWhere(
      (item) =>
          item['title'] ==
          'Investment Required',
    );

    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration:
          _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.smart_toy_outlined,
            'Chatbot Preview',
            'Example customer conversation.',
          ),

          const SizedBox(height: 18),

          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(
              14,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF3E8FF,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                10,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  botNameController
                      .text,
                  style:
                      const TextStyle(
                    fontSize: 9,
                    fontWeight:
                        FontWeight
                            .w700,
                    color:
                        Color(
                      0xFF7C3AED,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  welcomeController
                      .text,
                  style:
                      const TextStyle(
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Wrap(
            spacing: 7,
            runSpacing: 7,
            children:
                knowledge.map(
              (item) {
                return Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white,
                    borderRadius:
                        BorderRadius
                            .circular(
                      8,
                    ),
                    border:
                        Border.all(
                      color:
                          const Color(
                        0xFFE2E8F0,
                      ),
                    ),
                  ),
                  child:
                      Text(
                    item['title']
                        .toString(),
                    style:
                        const TextStyle(
                      fontSize:
                          9,
                    ),
                  ),
                );
              },
            ).toList(),
          ),

          const SizedBox(
            height: 16,
          ),

          Align(
            alignment:
                Alignment.centerRight,
            child: Container(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFD9FDD3,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  10,
                ),
              ),
              child:
                  const Text(
                'Investment kitna lagega?',
                style:
                    TextStyle(
                  fontSize: 10,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Container(
            padding:
                const EdgeInsets.all(
              12,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF3E8FF,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                10,
              ),
            ),
            child:
                Text(
              (investment['controller']
                      as TextEditingController)
                  .text,
              style:
                  const TextStyle(
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _knowledgeCard() {
    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration:
          _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.psychology_outlined,
            'AI Knowledge Base',
            'Define the information AI can use while answering franchise enquiries.',
          ),

          const SizedBox(height: 18),

          ...knowledge.map(
            (item) {
              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 14,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      item['title']
                          .toString(),
                      style:
                          const TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    TextField(
                      controller:
                          item['controller']
                              as TextEditingController,
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ],
                ),
              );
            },
          ),

          Align(
            alignment:
                Alignment.centerRight,
            child: SizedBox(
              width: 145,
              height: 42,
              child:
                  ElevatedButton.icon(
                style:
                    ElevatedButton
                        .styleFrom(
                  minimumSize:
                      const Size(
                    0,
                    42,
                  ),
                  maximumSize:
                      const Size(
                    145,
                    42,
                  ),
                ),
                onPressed:
                    _saveSettings,
                icon: const Icon(
                  Icons.save_outlined,
                  size: 16,
                ),
                label:
                    const Text(
                  'Save AI Settings',
                  style:
                      TextStyle(
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(
    IconData icon,
    String title,
    String description,
    bool value,
    ValueChanged<bool>
        onChanged,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 10,
      ),
      decoration:
          const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF3E8FF,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                9,
              ),
            ),
            child: Icon(
              icon,
              size: 17,
              color:
                  const Color(
                0xFF7C3AED,
              ),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),
                Text(
                  description,
                  style:
                      const TextStyle(
                    fontSize: 9,
                    color:
                        Color(
                      0xFF64748B,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged:
                onChanged,
          ),
        ],
      ),
    );
  }

  Widget _cardTitle(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color:
              const Color(
            0xFF7C3AED,
          ),
        ),
        const SizedBox(
          width: 9,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight
                          .w800,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                style:
                    const TextStyle(
                  fontSize: 10,
                  color:
                      Color(
                    0xFF64748B,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _saveSettings() {
    for (final item in knowledge) {
      final controller =
          item['controller']
              as TextEditingController;

      item['answer'] =
          controller.text.trim();
    }

    AppToast.success(
      context,
      'AI Chatbot settings saved successfully.',
      title:
          'AI Settings Saved',
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(
        14,
      ),
      border: Border.all(
        color:
            const Color(
          0xFFE5E7EB,
        ),
      ),
    );
  }
}