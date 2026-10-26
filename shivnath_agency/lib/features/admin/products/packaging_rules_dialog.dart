import 'package:flutter/material.dart';
import '../../../core/services/packaging_service.dart';
import '../../../core/widgets/app_toast.dart';

class PackagingRulesDialog extends StatefulWidget {
  final List<Map<String, dynamic>> products;

  const PackagingRulesDialog({super.key, required this.products});

  static Future<void> show(BuildContext context, {required List<Map<String, dynamic>> products}) {
    return showDialog(
      context: context,
      builder: (_) => PackagingRulesDialog(products: products),
    );
  }

  @override
  State<PackagingRulesDialog> createState() => _PackagingRulesDialogState();
}

class _PackagingRulesDialogState extends State<PackagingRulesDialog> {
  final PackagingService _service = PackagingService();
  List<dynamic> _rules = [];
  bool _loading = true;
  bool _creating = false;

  // New Rule Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _minQtyCtrl = TextEditingController(text: '5');
  final _cartonSizeCtrl = TextEditingController(text: '24');
  final _maxFranchiseMoqCtrl = TextEditingController();
  int? _selectedProductId;
  String _channel = 'CUSTOMER';
  String _salesUnit = 'CARTON';
  bool _allowPartialCarton = false;
  bool _allowFranchiseOverride = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
    if (widget.products.isNotEmpty) {
      _selectedProductId = widget.products.first['id'] as int?;
      _applySmartDefaults(widget.products.first);
    }
  }

  void _applySmartDefaults(Map<String, dynamic> product) {
    final name = (product['name'] ?? '').toString().toUpperCase();
    final sku = (product['sku'] ?? '').toString().toUpperCase();
    final isJar = name.contains('JAR') || name.contains('20L') || sku.contains('JAR');
    if (isJar) {
      _salesUnit = 'JAR';
      _minQtyCtrl.text = '5';
      _cartonSizeCtrl.text = '1';
      _allowPartialCarton = true;
      _nameCtrl.text = '20L Water Jar Minimum 5 Jars Policy';
    } else {
      _salesUnit = 'CARTON';
      _minQtyCtrl.text = '5';
      final unitsPerCase = (product['units_per_case'] as int?) ?? 24;
      _cartonSizeCtrl.text = '$unitsPerCase';
      _allowPartialCarton = false;
      _nameCtrl.text = '${product['name'] ?? 'Packaged Water'} 5 Carton MOQ Policy';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _minQtyCtrl.dispose();
    _cartonSizeCtrl.dispose();
    _maxFranchiseMoqCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRules() async {
    setState(() => _loading = true);
    final res = await _service.getPackagingRules();
    if (mounted) {
      setState(() {
        _loading = false;
        if (res['success'] == true) {
          _rules = res['rules'] as List? ?? [];
        }
      });
    }
  }

  Future<void> _submitNewRule() async {
    if (!_formKey.currentState!.validate()) return;

    final minQty = int.tryParse(_minQtyCtrl.text.trim()) ?? 5;
    final cartonSize = int.tryParse(_cartonSizeCtrl.text.trim()) ?? 24;
    final maxFMoq = int.tryParse(_maxFranchiseMoqCtrl.text.trim());

    setState(() => _creating = true);
    final res = await _service.createPackagingRule({
      'name': _nameCtrl.text.trim(),
      'channel': _channel,
      'applies_to': _channel,
      'product_id': _selectedProductId,
      'product': _selectedProductId,
      'sales_unit': _salesUnit,
      'min_order_quantity': minQty,
      'carton_pack_size': cartonSize,
      'units_per_carton': cartonSize,
      'allow_partial_carton': _allowPartialCarton,
      'enforce_carton_multiples': !_allowPartialCarton,
      'allow_franchise_override': _allowFranchiseOverride,
      if (_allowFranchiseOverride && maxFMoq != null)
        'max_franchise_moq': maxFMoq,
      'is_active': _isActive,
    });

    if (mounted) {
      setState(() => _creating = false);
      if (res['success'] == true) {
        AppToast.success(context, 'Packaging & MOQ rule saved successfully');
        _loadRules();
      } else {
        AppToast.error(context, res['message']?.toString() ?? 'Failed to save rule');
      }
    }
  }

  Future<void> _toggleRuleActive(dynamic rule, bool active) async {
    final id = rule['id'] as int;
    final res = await _service.updatePackagingRule(id, {'is_active': active});
    if (mounted) {
      if (res['success'] == true) {
        AppToast.success(context, 'Rule updated successfully');
        _loadRules();
      } else {
        AppToast.error(context, 'Failed to update rule status');
      }
    }
  }

  Future<void> _deleteRule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Packaging Rule'),
        content: const Text('Are you sure you want to delete this packaging rule?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _service.deletePackagingRule(id);
      if (mounted) {
        if (res['success'] == true) {
          AppToast.success(context, 'Rule deleted');
          _loadRules();
        } else {
          AppToast.error(context, 'Failed to delete rule');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_rounded, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Minimum Order & Packaging Controls',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Configure product-specific carton pack sizes, minimum order quantities (MOQ), and multiple rules.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 28),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form Section
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Create / Edit Packaging Rule', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Rule Title *',
                                  hintText: 'e.g. 500ml Customer Case MOQ',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _channel,
                                decoration: const InputDecoration(
                                  labelText: 'Applicable Channel',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer Direct Orders')),
                                  DropdownMenuItem(value: 'FRANCHISE', child: Text('Wholesale Franchise / Dealer')),
                                  DropdownMenuItem(value: 'ALL', child: Text('All Channels')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _channel = val);
                                },
                              ),
                              const SizedBox(height: 12),
                               DropdownButtonFormField<int>(
                                initialValue: _selectedProductId,
                                decoration: const InputDecoration(
                                  labelText: 'Assigned Product',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: widget.products.map((p) {
                                  return DropdownMenuItem<int>(
                                    value: p['id'] as int?,
                                    child: Text(
                                      '${p['name']} (${p['sku'] ?? 'SKU'})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedProductId = val;
                                    if (val != null) {
                                      final p = widget.products.firstWhere((it) => it['id'] == val, orElse: () => {});
                                      if (p.isNotEmpty) _applySmartDefaults(p);
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _salesUnit,
                                decoration: const InputDecoration(
                                  labelText: 'Sales Packaging Unit',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'CARTON', child: Text('Carton / Peti Box')),
                                  DropdownMenuItem(value: 'JAR', child: Text('20L Water Jar')),
                                  DropdownMenuItem(value: 'BOTTLE', child: Text('Individual Bottle')),
                                  DropdownMenuItem(value: 'PACK', child: Text('Pack')),
                                  DropdownMenuItem(value: 'PIECE', child: Text('Piece')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _salesUnit = val);
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _minQtyCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Min Quantity (MOQ)',
                                        hintText: 'e.g. 5',
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                        helperText: _salesUnit == 'CARTON' ? 'in Boxes/Cartons' : 'in $_salesUnit units',
                                      ),
                                      validator: (v) {
                                        final n = int.tryParse(v ?? '');
                                        if (n == null || n < 1) return 'Must be >= 1';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cartonSizeCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Pack Size (Units/Box)',
                                        hintText: 'e.g. 24',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        helperText: 'Base bottles per box',
                                      ),
                                      validator: (v) {
                                        final n = int.tryParse(v ?? '');
                                        if (n == null || n < 1) return 'Must be >= 1';
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Allow Partial Cartons', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: const Text('Allow ordering partial quantities vs enforcing exact carton multiples', style: TextStyle(fontSize: 11)),
                                value: _allowPartialCarton,
                                onChanged: (v) => setState(() => _allowPartialCarton = v),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Allow Franchise Custom MOQ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: const Text('Franchises can set local MOQ above company baseline', style: TextStyle(fontSize: 11)),
                                value: _allowFranchiseOverride,
                                onChanged: (v) => setState(() => _allowFranchiseOverride = v),
                              ),
                              if (_allowFranchiseOverride) ...[
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _maxFranchiseMoqCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Max Franchise MOQ Limit (Optional)',
                                    hintText: 'e.g. 20',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ],
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Rule Active & Enforced', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                value: _isActive,
                                onChanged: (v) => setState(() => _isActive = v),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0284C7),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: _creating ? null : _submitNewRule,
                                  icon: _creating
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.save_rounded, size: 18),
                                  label: const Text('Save Packaging & MOQ Rule', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 32),
                    // Rules List Section
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Active Rules (${_rules.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded, size: 20),
                                onPressed: _loadRules,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _loading
                                ? const Center(child: CircularProgressIndicator())
                                : _rules.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFF94A3B8)),
                                            const SizedBox(height: 10),
                                            const Text('No packaging rules configured yet.', style: TextStyle(color: Color(0xFF64748B))),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Default 5 Jars & 5 Boxes MOQ applies automatically.',
                                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: _rules.length,
                                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                                        itemBuilder: (_, idx) {
                                          final r = _rules[idx];
                                          final name = r['name'] ?? 'Packaging Rule';
                                          final prodName = r['product_name'] ?? 'All Products';
                                          final salesUnit = r['sales_unit'] ?? 'CARTON';
                                          final minQty = r['min_order_quantity'] ?? 1;
                                          final packSize = r['units_per_carton'] ?? r['carton_pack_size'] ?? 1;
                                          final active = r['is_active'] == true;
                                          final allowPartial = r['allow_partial_carton'] == true;
                                          final allowOverride = r['allow_franchise_override'] == true;
                                          final channel = r['applies_to'] ?? r['channel'] ?? 'CUSTOMER';

                                          return Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: active ? Colors.white : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFCBD5E1)),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFE0F2FE),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              channel,
                                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text('Product: $prodName', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'MOQ: $minQty $salesUnit • Pack: $packSize units • ${allowPartial ? 'Partial Allowed' : 'Strict Multiples'} ${allowOverride ? '• Override: Allowed' : '• Override: Disabled'}',
                                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Switch(
                                                  value: active,
                                                  onChanged: (val) => _toggleRuleActive(r, val),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                                  onPressed: () => _deleteRule(r['id'] as int),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ],
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
  }
}
