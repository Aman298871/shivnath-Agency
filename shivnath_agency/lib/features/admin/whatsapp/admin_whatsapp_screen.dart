import 'package:flutter/material.dart';

import 'tabs/whatsapp_automation_tab.dart';
import 'tabs/whatsapp_conversations_tab.dart';
import 'tabs/whatsapp_ai_chatbot_tab.dart';
import 'tabs/whatsapp_templates_tab.dart';
import 'tabs/whatsapp_lead_qualification_tab.dart';

class AdminWhatsAppScreen extends StatefulWidget {
  const AdminWhatsAppScreen({super.key});

  @override
  State<AdminWhatsAppScreen> createState() =>
      _AdminWhatsAppScreenState();
}

class _AdminWhatsAppScreenState
    extends State<AdminWhatsAppScreen> {
  int selectedTab = 0;

  final List<_WhatsAppTabItem> tabs = const [
    _WhatsAppTabItem(
      title: 'Automation',
      icon: Icons.auto_awesome_outlined,
    ),
    _WhatsAppTabItem(
      title: 'Conversations',
      icon: Icons.chat_bubble_outline_rounded,
    ),
    _WhatsAppTabItem(
      title: 'AI Chatbot',
      icon: Icons.smart_toy_outlined,
    ),
    _WhatsAppTabItem(
      title: 'Message Templates',
      icon: Icons.description_outlined,
    ),
    _WhatsAppTabItem(
      title: 'Lead Qualification',
      icon: Icons.psychology_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF5F7FB),
          child: Column(
            children: [
              // =================================================
              // HEADER + TABS
              // =================================================

              Container(
                width: double.infinity,
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(
                  desktop ? 28 : 16,
                  22,
                  desktop ? 28 : 16,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WhatsApp Settings',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'Manage WhatsApp automation, conversations, AI chatbot, templates and lead qualification',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),

                    const SizedBox(height: 22),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          tabs.length,
                          (index) {
                            final item = tabs[index];
                            final selected = selectedTab == index;

                            return InkWell(
                              borderRadius:
                                  const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              onTap: () {
                                setState(() {
                                  selectedTab = index;
                                });
                              },
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 17,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: selected
                                          ? const Color(0xFF0284C7)
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 17,
                                      color: selected
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFF64748B),
                                    ),

                                    const SizedBox(width: 7),

                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected
                                            ? const Color(0xFF0284C7)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // =================================================
              // CURRENT TAB
              // =================================================

              Expanded(
                child: _currentTab(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _currentTab() {
    switch (selectedTab) {
      case 0:
        return const WhatsAppAutomationTab();

      case 1:
        return const WhatsAppConversationsTab();

      case 2:
        return const WhatsAppAIChatbotTab();

      case 3:
        return const WhatsAppTemplatesTab();

      case 4:
        return const WhatsAppLeadQualificationTab();

      default:
        return const SizedBox();
    }
  }
}

class _WhatsAppTabItem {
  final String title;
  final IconData icon;

  const _WhatsAppTabItem({
    required this.title,
    required this.icon,
  });
}