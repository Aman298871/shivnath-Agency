import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/product_service.dart';
import '../../../models/product_model.dart';

class AdminQuotationsScreen extends StatefulWidget {
  const AdminQuotationsScreen({super.key});

  @override
  State<AdminQuotationsScreen> createState() => _AdminQuotationsScreenState();
}

class _AdminQuotationsScreenState extends State<AdminQuotationsScreen> {
  final ChatService _chatService = ChatService();
  final ProductService _productService = ProductService();

  List<Map<String, dynamic>> _quotations = [];
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String _targetFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final quotes = await _chatService.getQuotations();
      await _productService.getProducts();

      if (mounted) {
        setState(() {
          _quotations = quotes;
          _products = ProductService.products;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditQuotationDialog([Map<String, dynamic>? quotation]) {
    final titleCtrl = TextEditingController(text: quotation?['title']?.toString() ?? '');
    final tierCtrl = TextEditingController(text: quotation?['quantity_tier']?.toString() ?? '50+ Units');
    final unitPriceCtrl = TextEditingController(text: (quotation?['unit_price'] ?? 0).toString());
    final totalPriceCtrl = TextEditingController(text: (quotation?['total_price'] ?? 0).toString());
    final termsCtrl = TextEditingController(text: quotation?['applicable_terms']?.toString() ?? 'Standard delivery and purity warranty terms apply.');
    final notesCtrl = TextEditingController(text: quotation?['notes']?.toString() ?? '');
    final validityCtrl = TextEditingController(text: quotation?['validity']?.toString() ?? 'Valid for 30 days from generation');

    String quotationType = quotation?['quotation_type']?.toString() ?? 'customer';
    String targetAudience = quotation?['target_audience']?.toString() ?? 'customer';
    int? selectedProductId = quotation?['product'] != null ? (quotation!['product'] is Map ? quotation!['product']['id'] : quotation!['product']) : null;
    bool isActive = quotation?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(quotation == null ? 'Create Quotation' : 'Edit Quotation'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quotation Title *',
                      hintText: 'e.g. 50+ Jars Commercial Rate, Bulk 500ml Bottle Tier',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: quotationType,
                          decoration: const InputDecoration(
                            labelText: 'Quotation Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'customer', child: Text('Customer Quotation')),
                            DropdownMenuItem(value: 'bottle', child: Text('Bottle Quotation')),
                            DropdownMenuItem(value: 'jar', child: Text('Jar Quotation')),
                            DropdownMenuItem(value: 'franchise', child: Text('Franchise Quotation')),
                            DropdownMenuItem(value: 'bulk', child: Text('Bulk Quantity Quotation')),
                            DropdownMenuItem(value: 'custom', child: Text('Custom Quotation')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => quotationType = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: targetAudience,
                          decoration: const InputDecoration(
                            labelText: 'Target Audience',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'customer', child: Text('Customer')),
                            DropdownMenuItem(value: 'franchise', child: Text('Franchise')),
                            DropdownMenuItem(value: 'both', child: Text('Both')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => targetAudience = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: selectedProductId,
                    decoration: const InputDecoration(
                      labelText: 'Related Product (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('None (General / Bulk Tier)')),
                      ..._products.map((p) => DropdownMenuItem<int?>(
                            value: int.tryParse(p.id),
                            child: Text('${p.name} (${p.size}) - Regular: ₹${p.price}'),
                          )),
                    ],
                    onChanged: (val) => setDlgState(() => selectedProductId = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tierCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantity Tier / Volume Requirement *',
                      hintText: 'e.g. 50+ Jars, 100+ Boxes, 500+ Units',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: unitPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Unit Price (₹)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: totalPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Total Price / Package Rate (₹)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: validityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Validity Period',
                      hintText: 'e.g. Valid for 30 days',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: termsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Applicable Terms & Delivery Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Internal Admin Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active Quotation (Visible to Chatbot & Inquiries)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    value: isActive,
                    onChanged: (v) => setDlgState(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
                  return;
                }

                final payload = {
                  'title': title,
                  'quotation_type': quotationType,
                  'target_audience': targetAudience,
                  'product': selectedProductId,
                  'quantity_tier': tierCtrl.text.trim(),
                  'unit_price': double.tryParse(unitPriceCtrl.text.trim()) ?? 0.0,
                  'total_price': double.tryParse(totalPriceCtrl.text.trim()) ?? 0.0,
                  'validity': validityCtrl.text.trim(),
                  'applicable_terms': termsCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                  'is_active': isActive,
                };

                Navigator.pop(ctx);
                if (quotation == null) {
                  await _chatService.createQuotation(payload);
                } else {
                  await _chatService.updateQuotation(quotation['id'] as int, payload);
                }
                _loadData();
              },
              child: const Text('Save Quotation'),
            ),
          ],
        ),
      ),
    );
  }

  void _downloadPdf(int id) async {
    final pdfUrl = '${AppConstants.apiBaseUrl}/api/chat/quotations/$id/pdf/';
    try {
      final uri = Uri.parse(pdfUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open PDF URL: $pdfUrl')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching PDF: $e')),
        );
      }
    }
  }

  void _deleteQuotation(int id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: Text('Are you sure you want to delete quotation "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _chatService.deleteQuotation(id);
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

    final filteredQuotes = _quotations.where((q) {
      if (_targetFilter == 'all') return true;
      return q['target_audience'] == _targetFilter || q['target_audience'] == 'both';
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotation & Rate Tier Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditQuotationDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Create Quotation'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Text('Audience Filter: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All Quotations'),
                  selected: _targetFilter == 'all',
                  onSelected: (_) => setState(() => _targetFilter = 'all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Customer Tiers'),
                  selected: _targetFilter == 'customer',
                  onSelected: (_) => setState(() => _targetFilter = 'customer'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Franchise Tiers'),
                  selected: _targetFilter == 'franchise',
                  onSelected: (_) => setState(() => _targetFilter = 'franchise'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredQuotes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.request_quote_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text('No quotations configured.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _showAddEditQuotationDialog(),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Quotation Template'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: filteredQuotes.length,
                        itemBuilder: (context, index) {
                          final q = filteredQuotes[index];
                          final qId = q['id'] as int;
                          final audience = q['target_audience']?.toString().toUpperCase() ?? 'CUSTOMER';
                          final unitP = q['unit_price'] ?? 0;
                          final totalP = q['total_price'] ?? 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.request_quote_rounded, color: Color(0xFF0284C7), size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              q['title']?.toString() ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            Text(
                                              'Type: ${q['quotation_type']} • Tier: ${q['quantity_tier']}',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: audience == 'FRANCHISE' ? Colors.orange.withAlpha(25) : const Color(0xFF0284C7).withAlpha(25),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          audience,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: audience == 'FRANCHISE' ? Colors.orange : const Color(0xFF0284C7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Unit Rate', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          Text('₹$unitP', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0284C7))),
                                        ],
                                      ),
                                      if (totalP > 0)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Package Rate', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                            Text('₹$totalP', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.green)),
                                          ],
                                        ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Validity', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          Text(q['validity']?.toString() ?? '30 Days', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (q['applicable_terms'] != null && q['applicable_terms'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('Terms: ${q['applicable_terms']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        label: const Text('Edit'),
                                        onPressed: () => _showAddEditQuotationDialog(q),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                        onPressed: () => _deleteQuotation(qId, q['title']?.toString() ?? ''),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
