import 'package:flutter/material.dart';
import '../../../../core/widgets/app_toast.dart';

class WhatsAppTemplatesTab extends StatefulWidget {
  const WhatsAppTemplatesTab({super.key});

  @override
  State<WhatsAppTemplatesTab> createState() => _WhatsAppTemplatesTabState();
}

class _WhatsAppTemplatesTabState extends State<WhatsAppTemplatesTab> {
  String search = '';
  String category = 'All';

  final searchController = TextEditingController();

  final List<Map<String, dynamic>> templates = [
    {
      'id': 1,
      'name': 'Welcome Message',
      'category': 'Franchise',
      'type': 'Utility',
      'status': 'Active',
      'message':
          'Namaste {{name}} 👋 Thank you for your interest in our Drinking Water Franchise. Our team will contact you shortly.',
    },
    {
      'id': 2,
      'name': 'Franchise Details',
      'category': 'Franchise',
      'type': 'Utility',
      'status': 'Active',
      'message':
          'Hello {{name}}, thank you for your interest. Here are the details of our franchise model.',
    },
    {
      'id': 3,
      'name': 'Investment Details',
      'category': 'Franchise',
      'type': 'Utility',
      'status': 'Active',
      'message':
          'Hello {{name}}, franchise investment depends on your city, location and selected business model.',
    },
    {
      'id': 4,
      'name': 'Digital Brochure',
      'category': 'Follow-up',
      'type': 'Utility',
      'status': 'Active',
      'message': 'Hello {{name}}, please find our franchise brochure attached.',
    },
    {
      'id': 5,
      'name': 'Success Story',
      'category': 'Follow-up',
      'type': 'Marketing',
      'status': 'Active',
      'message':
          'Hello {{name}}, we are sharing a success story from one of our franchise partners.',
    },
    {
      'id': 6,
      'name': 'Payment Reminder',
      'category': 'Payment',
      'type': 'Utility',
      'status': 'Active',
      'message':
          'Hello {{name}}, your outstanding payment of ₹{{amount}} is due on {{dueDate}}.',
    },
    {
      'id': 7,
      'name': 'Order Confirmation',
      'category': 'Order',
      'type': 'Utility',
      'status': 'Active',
      'message':
          'Hello {{name}}, your order {{orderNumber}} has been received successfully.',
    },
  ];

  List<Map<String, dynamic>> get filteredTemplates {
    final query = search.trim().toLowerCase();

    return templates.where((item) {
      final searchMatch =
          item['name'].toString().toLowerCase().contains(query) ||
          item['message'].toString().toLowerCase().contains(query);

      final categoryMatch = category == 'All' || item['category'] == category;

      return searchMatch && categoryMatch;
    }).toList();
  }

  List<String> get categories {
    final values = templates
        .map((item) => item['category'].toString())
        .toSet()
        .toList();

    return ['All', ...values];
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;

        return SingleChildScrollView(
          padding: EdgeInsets.all(desktop ? 28 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),

                  const SizedBox(height: 20),

                  _stats(desktop),

                  const SizedBox(height: 20),

                  Container(
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        _toolbar(desktop),
                        const Divider(height: 1),
                        desktop ? _desktopTable() : _mobileList(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _header() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Message Templates',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Create and manage WhatsApp messages used in automation.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                  ),
                  onPressed: () {
                    _openTemplateForm();
                  },
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('New Template'),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message Templates',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Create and manage WhatsApp messages used in automation.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 145,
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  maximumSize: const Size(145, 42),
                ),
                onPressed: () {
                  _openTemplateForm();
                },
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('New Template', maxLines: 1, softWrap: false),
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // STATS
  // =========================================================

  Widget _stats(bool desktop) {
    final active = templates.where((item) => item['status'] == 'Active').length;

    final cards = [
      {
        'title': 'Total Templates',
        'value': '${templates.length}',
        'icon': Icons.description_outlined,
      },
      {
        'title': 'Active',
        'value': '$active',
        'icon': Icons.check_circle_outline,
      },
    ];

    if (desktop) {
      return Row(
        children: [
          Expanded(child: _statCard(cards[0])),
          const SizedBox(width: 14),
          Expanded(child: _statCard(cards[1])),
        ],
      );
    }

    return Column(
      children: [
        _statCard(cards[0]),
        const SizedBox(height: 10),
        _statCard(cards[1]),
      ],
    );
  }

  Widget _statCard(Map<String, dynamic> item) {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
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
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['title'].toString(),
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 3),
              Text(
                item['value'].toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // TOOLBAR
  // =========================================================

  Widget _toolbar(bool desktop) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: desktop
          ? Row(
              children: [
                Expanded(child: _searchBox()),
                const SizedBox(width: 12),
                SizedBox(width: 180, child: _categoryDropdown()),
              ],
            )
          : Column(
              children: [
                _searchBox(),
                const SizedBox(height: 10),
                _categoryDropdown(),
              ],
            ),
    );
  }

  Widget _searchBox() {
    return TextField(
      controller: searchController,
      onChanged: (value) {
        setState(() {
          search = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search templates...',
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0284C7)),
        ),
      ),
    );
  }

  Widget _categoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: category,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      items: categories
          .map(
            (value) => DropdownMenuItem(
              value: value,
              child: Text(value, style: const TextStyle(fontSize: 11)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          category = value;
        });
      },
    );
  }

  // =========================================================
  // DESKTOP TABLE
  // =========================================================

  Widget _desktopTable() {
    if (filteredTemplates.isEmpty) {
      return _emptyState();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1100,
        child: Column(
          children: [
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('TEMPLATE', style: _tableHeader),
                  ),
                  Expanded(child: Text('CATEGORY', style: _tableHeader)),
                  Expanded(child: Text('TYPE', style: _tableHeader)),
                  Expanded(child: Text('STATUS', style: _tableHeader)),
                  Expanded(
                    flex: 3,
                    child: Text('MESSAGE PREVIEW', style: _tableHeader),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text('ACTION', style: _tableHeader),
                  ),
                ],
              ),
            ),
            ...filteredTemplates.map((item) => _templateRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _templateRow(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              item['name'].toString(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              item['category'].toString(),
              style: const TextStyle(fontSize: 10),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _typeBadge(item['type'].toString()),
            ),
          ),
          Expanded(child: _statusBadge(item['status'].toString())),
          Expanded(
            flex: 3,
            child: Text(
              item['message'].toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                height: 1.4,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Row(
              children: [
                _tableIconButton(
                  tooltip: 'Preview',
                  icon: Icons.visibility_outlined,
                  onPressed: () {
                    _preview(item);
                  },
                ),
                _tableIconButton(
                  tooltip: 'Edit',
                  icon: Icons.edit_outlined,
                  onPressed: () {
                    _openTemplateForm(template: item);
                  },
                ),
                _tableIconButton(
                  tooltip: 'Delete',
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  onPressed: () {
                    _deleteTemplate(item);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MOBILE LIST
  // =========================================================

  Widget _mobileList() {
    if (filteredTemplates.isEmpty) {
      return _emptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: filteredTemplates.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['name'].toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    _statusBadge(item['status'].toString()),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _smallChip(item['category'].toString()),
                    _typeBadge(item['type'].toString()),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item['message'].toString(),
                  style: const TextStyle(fontSize: 10, height: 1.5),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Preview',
                      onPressed: () {
                        _preview(item);
                      },
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () {
                        _openTemplateForm(template: item);
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () {
                        _deleteTemplate(item);
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // =========================================================
  // CREATE / EDIT TEMPLATE
  // =========================================================

  Future<void> _openTemplateForm({Map<String, dynamic>? template}) async {
    final bool editing = template != null;

    final nameController = TextEditingController(
      text: template?['name']?.toString() ?? '',
    );

    final messageController = TextEditingController(
      text: template?['message']?.toString() ?? '',
    );

    String selectedCategory = template?['category']?.toString() ?? 'Franchise';

    String selectedType = template?['type']?.toString() ?? 'Utility';

    String selectedStatus = template?['status']?.toString() ?? 'Active';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 22,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 650,
                  maxHeight: 760,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      // =======================================
                      // MODAL HEADER
                      // =======================================
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 18,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.message_outlined,
                                size: 20,
                                color: Color(0xFF0284C7),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    editing
                                        ? 'Edit Template'
                                        : 'Create Template',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Configure WhatsApp message content.',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            IconButton(
                              tooltip: 'Close',
                              onPressed: () {
                                Navigator.pop(dialogContext);
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // =======================================
                      // BODY
                      // =======================================
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _templateLabel('Template Name', required: true),

                              const SizedBox(height: 7),

                              TextField(
                                controller: nameController,
                                decoration: _modalInputDecoration(
                                  hint: 'e.g. Welcome Message',
                                  icon: Icons.title_rounded,
                                ),
                              ),

                              const SizedBox(height: 18),

                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final twoColumns =
                                      constraints.maxWidth >= 500;

                                  if (twoColumns) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _templateDropdown(
                                            label: 'Category',
                                            value: selectedCategory,
                                            items: const [
                                              'Franchise',
                                              'Follow-up',
                                              'Order',
                                              'Payment',
                                              'General',
                                            ],
                                            icon: Icons.folder_outlined,
                                            onChanged: (value) {
                                              setDialogState(() {
                                                selectedCategory = value;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _templateDropdown(
                                            label: 'Template Type',
                                            value: selectedType,
                                            items: const [
                                              'Utility',
                                              'Marketing',
                                              'Authentication',
                                            ],
                                            icon: Icons.category_outlined,
                                            onChanged: (value) {
                                              setDialogState(() {
                                                selectedType = value;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    children: [
                                      _templateDropdown(
                                        label: 'Category',
                                        value: selectedCategory,
                                        items: const [
                                          'Franchise',
                                          'Follow-up',
                                          'Order',
                                          'Payment',
                                          'General',
                                        ],
                                        icon: Icons.folder_outlined,
                                        onChanged: (value) {
                                          setDialogState(() {
                                            selectedCategory = value;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      _templateDropdown(
                                        label: 'Template Type',
                                        value: selectedType,
                                        items: const [
                                          'Utility',
                                          'Marketing',
                                          'Authentication',
                                        ],
                                        icon: Icons.category_outlined,
                                        onChanged: (value) {
                                          setDialogState(() {
                                            selectedType = value;
                                          });
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 18),

                              _templateDropdown(
                                label: 'Status',
                                value: selectedStatus,
                                items: const ['Active', 'Inactive'],
                                icon: Icons.toggle_on_outlined,
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedStatus = value;
                                  });
                                },
                              ),

                              const SizedBox(height: 18),

                              _templateLabel(
                                'WhatsApp Message',
                                required: true,
                              ),

                              const SizedBox(height: 7),

                              TextField(
                                controller: messageController,
                                minLines: 6,
                                maxLines: 8,
                                decoration: _modalInputDecoration(
                                  hint: 'Enter WhatsApp message...',
                                  icon: Icons.chat_bubble_outline_rounded,
                                  alignLabelWithHint: true,
                                ),
                              ),

                              const SizedBox(height: 12),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Available Variables',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 7,
                                      runSpacing: 7,
                                      children: [
                                        _VariableChip(
                                          text: '{{name}}',
                                          onTap: () {
                                            _insertVariable(
                                              messageController,
                                              '{{name}}',
                                            );
                                          },
                                        ),
                                        _VariableChip(
                                          text: '{{city}}',
                                          onTap: () {
                                            _insertVariable(
                                              messageController,
                                              '{{city}}',
                                            );
                                          },
                                        ),
                                        _VariableChip(
                                          text: '{{amount}}',
                                          onTap: () {
                                            _insertVariable(
                                              messageController,
                                              '{{amount}}',
                                            );
                                          },
                                        ),
                                        _VariableChip(
                                          text: '{{orderNumber}}',
                                          onTap: () {
                                            _insertVariable(
                                              messageController,
                                              '{{orderNumber}}',
                                            );
                                          },
                                        ),
                                        _VariableChip(
                                          text: '{{dueDate}}',
                                          onTap: () {
                                            _insertVariable(
                                              messageController,
                                              '{{dueDate}}',
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 7),
                                    const Text(
                                      'Click any variable to insert it into the message.',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // =======================================
                      // FOOTER
                      // =======================================
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(
                            top: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 100,
                              height: 42,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 42),
                                  maximumSize: const Size(100, 42),
                                ),
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                },
                                child: const Text('Cancel'),
                              ),
                            ),

                            const SizedBox(width: 10),

                            SizedBox(
                              width: editing ? 145 : 155,
                              height: 42,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 42),
                                  maximumSize: Size(editing ? 145 : 155, 42),
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  _saveTemplate(
                                    dialogContext: dialogContext,
                                    template: template,
                                    editing: editing,
                                    nameController: nameController,
                                    messageController: messageController,
                                    selectedCategory: selectedCategory,
                                    selectedType: selectedType,
                                    selectedStatus: selectedStatus,
                                  );
                                },
                                icon: Icon(
                                  editing
                                      ? Icons.save_outlined
                                      : Icons.add_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  editing
                                      ? 'Update Template'
                                      : 'Create Template',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 600), () {
      nameController.dispose();
      messageController.dispose();
    });
  }

  // =========================================================
  // SAVE TEMPLATE
  // =========================================================

  void _saveTemplate({
    required BuildContext dialogContext,
    required Map<String, dynamic>? template,
    required bool editing,
    required TextEditingController nameController,
    required TextEditingController messageController,
    required String selectedCategory,
    required String selectedType,
    required String selectedStatus,
  }) {
    final name = nameController.text.trim();
    final message = messageController.text.trim();

    if (name.isEmpty) {
      AppToast.error(
        context,
        'Template name is required.',
        title: 'Template Name Required',
      );
      return;
    }

    if (message.isEmpty) {
      AppToast.error(
        context,
        'WhatsApp message is required.',
        title: 'Message Required',
      );
      return;
    }

    setState(() {
      if (editing && template != null) {
        template['name'] = name;
        template['category'] = selectedCategory;
        template['type'] = selectedType;
        template['status'] = selectedStatus;
        template['message'] = message;
      } else {
        templates.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch,
          'name': name,
          'category': selectedCategory,
          'type': selectedType,
          'status': selectedStatus,
          'message': message,
        });
      }
    });

    Navigator.pop(dialogContext);

    AppToast.success(
      context,
      editing
          ? 'Template updated successfully.'
          : 'Template created successfully.',
      title: editing ? 'Template Updated' : 'Template Created',
    );
  }

  // =========================================================
  // VARIABLE INSERT
  // =========================================================

  void _insertVariable(TextEditingController controller, String variable) {
    final currentText = controller.text;
    final selection = controller.selection;

    if (selection.isValid) {
      final newText = currentText.replaceRange(
        selection.start,
        selection.end,
        variable,
      );

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + variable.length,
        ),
      );
    } else {
      controller.text = '$currentText$variable';

      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
  }

  // =========================================================
  // FORM HELPERS
  // =========================================================

  Widget _templateLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }

  Widget _templateDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _templateLabel(label),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: _modalInputDecoration(icon: icon),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 11)),
            );
          }).toList(),
          onChanged: (selected) {
            if (selected != null) {
              onChanged(selected);
            }
          },
        ),
      ],
    );
  }

  InputDecoration _modalInputDecoration({
    String? hint,
    IconData? icon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: icon != null ? Icon(icon, size: 18) : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
      ),
    );
  }

  // =========================================================
  // DELETE
  // =========================================================

  Future<void> _deleteTemplate(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Template?'),
          content: Text('Are you sure you want to delete "${item['name']}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      templates.remove(item);
    });

    if (!mounted) return;

    AppToast.success(
      context,
      'Template deleted successfully.',
      title: 'Template Deleted',
    );
  }

  // =========================================================
  // PREVIEW
  // =========================================================

  void _preview(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'].toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'WhatsApp message preview',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: 330,
                    color: const Color(0xFFEFEAE2),
                    padding: const EdgeInsets.all(20),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9FDD3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['message'].toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '10:30 AM ✓✓',
                                style: TextStyle(
                                  fontSize: 7.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // BADGES
  // =========================================================

  Widget _statusBadge(String status) {
    final active = status == 'Active';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFF15803D) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _typeBadge(String type) {
    Color background;
    Color foreground;

    if (type == 'Marketing') {
      background = const Color(0xFFF3E8FF);
      foreground = const Color(0xFF7C3AED);
    } else if (type == 'Authentication') {
      background = const Color(0xFFEFF6FF);
      foreground = const Color(0xFF2563EB);
    } else {
      background = const Color(0xFFE0F2FE);
      foreground = const Color(0xFF0284C7);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _smallChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _tableIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return IconButton(
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: 17, color: color),
    );
  }

  // =========================================================
  // EMPTY
  // =========================================================

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 55),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.message_outlined, size: 38, color: Color(0xFF94A3B8)),
            SizedBox(height: 10),
            Text(
              'No Templates Found',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4),
            Text(
              'Try another search or create a new template.',
              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // CARD
  // =========================================================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    );
  }
}

// ===========================================================
// VARIABLE CHIP
// ===========================================================

class _VariableChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _VariableChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE0F2FE),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF0284C7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

const TextStyle _tableHeader = TextStyle(
  fontSize: 8,
  fontWeight: FontWeight.w700,
  color: Color(0xFF64748B),
  letterSpacing: 0.35,
);
