import 'package:flutter/material.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/product_service.dart';
import '../../../models/product_model.dart';

class AdminChatbotManagementScreen extends StatefulWidget {
  const AdminChatbotManagementScreen({super.key});

  @override
  State<AdminChatbotManagementScreen> createState() =>
      _AdminChatbotManagementScreenState();
}

class _AdminChatbotManagementScreenState
    extends State<AdminChatbotManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChatService _chatService = ChatService();
  final ProductService _productService = ProductService();

  List<Map<String, dynamic>> _options = [];
  List<ProductModel> _products = [];
  List<Map<String, dynamic>> _quotations = [];
  bool _isLoading = true;
  String _selectedInquiryType = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final opts = await _chatService.getAdminChatbotOptions();
      await _productService.getProducts();
      final quotes = await _chatService.getQuotations();

      if (mounted) {
        setState(() {
          _options = opts;
          _products = ProductService.products;
          _quotations = quotes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditOptionDialog({Map<String, dynamic>? option, int? parentId}) {
    final titleCtrl = TextEditingController(
      text: option?['title']?.toString() ?? '',
    );
    final answerCtrl = TextEditingController(
      text: option?['answer_text']?.toString() ?? '',
    );
    final keywordsCtrl = TextEditingController(
      text: option?['keywords']?.toString() ?? '',
    );
    final orderCtrl = TextEditingController(
      text: (option?['order'] ?? 0).toString(),
    );

    String inquiryType = option?['inquiry_type']?.toString() ?? 'customer';
    int? selectedParentId = option?['parent'] != null
        ? (option!['parent'] is Map ? option['parent']['id'] : option['parent'])
        : parentId;
    int? selectedProductId = option?['product'] != null
        ? (option!['product'] is Map
              ? option['product']['id']
              : option['product'])
        : null;
    int? selectedQuotationId = option?['quotation'] != null
        ? (option!['quotation'] is Map
              ? option['quotation']['id']
              : option['quotation'])
        : null;
    bool isLeadTrigger = option?['is_lead_trigger'] == true;
    bool isActive = option?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            option == null ? 'Create Chatbot Option' : 'Edit Chatbot Option',
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Option Title / Question *',
                      hintText: 'e.g. 1 Litre Bottle, Investment Requirement',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: inquiryType,
                    decoration: const InputDecoration(
                      labelText: 'Target Audience / Inquiry Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'customer',
                        child: Text('Customer / Product'),
                      ),
                      DropdownMenuItem(
                        value: 'franchise',
                        child: Text('Franchise'),
                      ),
                      DropdownMenuItem(
                        value: 'both',
                        child: Text('Both (Universal)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => inquiryType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedParentId,
                    decoration: const InputDecoration(
                      labelText: 'Parent Option (Leave blank for Root)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('None (Root Level Menu)'),
                      ),
                      ..._options
                          .where(
                            (o) => option == null || o['id'] != option['id'],
                          )
                          .map((o) {
                            return DropdownMenuItem<int?>(
                              value: o['id'] as int,
                              child: Text(
                                '${o['inquiry_type'].toString().toUpperCase()}: ${o['title']}',
                              ),
                            );
                          }),
                    ],
                    onChanged: (val) =>
                        setDlgState(() => selectedParentId = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: answerCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Response / Answer Text (for leaf nodes)',
                      hintText:
                          'Answer displayed to user when this option is selected',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keywordsCtrl,
                    decoration: const InputDecoration(
                      labelText:
                          'Keywords (comma-separated for typed search matching)',
                      hintText: 'e.g. 1L, 1 litre, price, bottle cost',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedProductId,
                    decoration: const InputDecoration(
                      labelText: 'Link to Product (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ..._products.map(
                        (p) => DropdownMenuItem<int?>(
                          value: int.tryParse(p.id),
                          child: Text('${p.name} (₹${p.price})'),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setDlgState(() => selectedProductId = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedQuotationId,
                    decoration: const InputDecoration(
                      labelText: 'Link to Quotation (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ..._quotations.map(
                        (q) => DropdownMenuItem<int?>(
                          value: q['id'] as int?,
                          child: Text(
                            '${q['title']} (₹${q['total_price'] ?? q['unit_price']})',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setDlgState(() => selectedQuotationId = val),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: orderCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Display Order',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Active',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: isActive,
                          onChanged: (v) => setDlgState(() => isActive = v),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Triggers Lead Qualification Form',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Prompts user to enter contact details for CRM lead capture',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: isLeadTrigger,
                    onChanged: (v) => setDlgState(() => isLeadTrigger = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title is required')),
                  );
                  return;
                }

                final payload = {
                  'title': title,
                  'inquiry_type': inquiryType,
                  'parent': selectedParentId,
                  'answer_text': answerCtrl.text.trim(),
                  'keywords': keywordsCtrl.text.trim(),
                  'product': selectedProductId,
                  'quotation': selectedQuotationId,
                  'order': int.tryParse(orderCtrl.text.trim()) ?? 0,
                  'is_lead_trigger': isLeadTrigger,
                  'is_active': isActive,
                };

                Navigator.pop(ctx);
                if (option == null) {
                  await _chatService.createChatbotOption(payload);
                } else {
                  await _chatService.updateChatbotOption(
                    option['id'] as int,
                    payload,
                  );
                }
                _loadData();
              },
              child: const Text('Save Option'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteOption(int id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Option'),
        content: Text(
          'Are you sure you want to delete "$title"? Any nested sub-options will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _chatService.deleteChatbotOption(id);
              _loadData();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredOptions = _options.where((o) {
      if (_selectedInquiryType == 'all') return true;
      return o['inquiry_type'] == _selectedInquiryType ||
          o['inquiry_type'] == 'both';
    }).toList();

    final rootOptions = filteredOptions
        .where((o) => o['parent'] == null)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot Hierarchy & Options Builder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditOptionDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Option'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Audience Filter: ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('All Options'),
                    selected: _selectedInquiryType == 'all',
                    onSelected: (_) =>
                        setState(() => _selectedInquiryType = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Customer / Product'),
                    selected: _selectedInquiryType == 'customer',
                    onSelected: (_) =>
                        setState(() => _selectedInquiryType = 'customer'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Franchise'),
                    selected: _selectedInquiryType == 'franchise',
                    onSelected: (_) =>
                        setState(() => _selectedInquiryType = 'franchise'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : rootOptions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.account_tree_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No configured chatbot options found.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditOptionDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Create First Option'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: rootOptions.length,
                    itemBuilder: (context, index) {
                      final opt = rootOptions[index];
                      return _buildOptionTreeItem(opt, filteredOptions, 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTreeItem(
    Map<String, dynamic> opt,
    List<Map<String, dynamic>> allOptions,
    int depth,
  ) {
    final optId = opt['id'] as int;
    final children = allOptions.where((o) {
      final p = o['parent'];
      if (p is Map) return p['id'] == optId;
      return p == optId;
    }).toList();

    final hasChildren = children.isNotEmpty;
    final isLeadTrigger = opt['is_lead_trigger'] == true;
    final inqType = opt['inquiry_type']?.toString().toUpperCase() ?? 'CUSTOMER';

    return Card(
      margin: EdgeInsets.only(left: depth * 22.0, bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: depth == 0
              ? const Color(0xFF0284C7).withAlpha(80)
              : Colors.grey.shade300,
        ),
      ),
      child: ExpansionTile(
        key: Key('opt_${opt['id']}'),
        initiallyExpanded: depth == 0,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: inqType == 'FRANCHISE'
              ? Colors.orange.withAlpha(40)
              : const Color(0xFFE0F2FE),
          child: Icon(
            hasChildren
                ? Icons.folder_open_rounded
                : (isLeadTrigger
                      ? Icons.assignment_turned_in_rounded
                      : Icons.chat_bubble_outline),
            size: 18,
            color: inqType == 'FRANCHISE'
                ? Colors.orange
                : const Color(0xFF0284C7),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                opt['title']?.toString() ?? '',
                style: TextStyle(
                  fontWeight: depth == 0 ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: inqType == 'FRANCHISE'
                    ? Colors.orange.withAlpha(25)
                    : const Color(0xFF0284C7).withAlpha(25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                inqType,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: inqType == 'FRANCHISE'
                      ? Colors.orange
                      : const Color(0xFF0284C7),
                ),
              ),
            ),
            if (isLeadTrigger) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LEAD TRIGGER',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle:
            opt['answer_text'] != null &&
                opt['answer_text'].toString().isNotEmpty
            ? Text(
                opt['answer_text'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              )
            : (hasChildren
                  ? Text(
                      '${children.length} sub-options',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0284C7),
                      ),
                    )
                  : null),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFF0284C7),
                size: 20,
              ),
              tooltip: 'Add Sub-option',
              onPressed: () => _showAddEditOptionDialog(parentId: optId),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit Option',
              onPressed: () => _showAddEditOptionDialog(option: opt),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
              tooltip: 'Delete Option',
              onPressed: () =>
                  _deleteOption(optId, opt['title']?.toString() ?? ''),
            ),
          ],
        ),
        children: children
            .map((c) => _buildOptionTreeItem(c, allOptions, depth + 1))
            .toList(),
      ),
    );
  }
}
