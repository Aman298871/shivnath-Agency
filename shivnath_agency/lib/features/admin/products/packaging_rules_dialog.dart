import 'package:flutter/material.dart';
import '../../../core/repositories/product_repository.dart';
import '../../../core/services/packaging_service.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../models/product_model.dart';

class PackagingRulesDialog extends StatefulWidget {
  final List<Map<String, dynamic>> products;

  const PackagingRulesDialog({super.key, this.products = const []});

  static Future<void> show(BuildContext context, {List<Map<String, dynamic>> products = const []}) {
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
  List<Map<String, dynamic>> _productList = [];
  bool _loading = true;
  bool _creating = false;
  bool _isRulesCached = false;
  String? _rulesError;
  int? _editingRuleId;

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
    _productList = List<Map<String, dynamic>>.from(widget.products);
    if (_productList.isEmpty && ProductRepository.cachedProducts.isNotEmpty) {
      _productList = ProductRepository.cachedProducts.map((p) => {
        'id': int.tryParse(p.id) ?? 0,
        'name': p.name,
        'sku': p.sku,
        'size': p.size,
        'units_per_case': p.unitsPerCase,
      }).toList();
    }
    _loadRules();
    if (_productList.isNotEmpty) {
      _selectedProductId = _productList.first['id'] as int?;
      _applySmartDefaults(_productList.first);
    }
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final res = await ProductRepository().getProducts();
      if (res['success'] == true) {
        List<Map<String, dynamic>> list = [];
        if (res['products'] is List) {
          list = (res['products'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (res['data'] is List) {
          list = (res['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (res['parsed_products'] is List) {
          for (final item in (res['parsed_products'] as List)) {
            if (item is Map) {
              list.add(Map<String, dynamic>.from(item));
            } else if (item is ProductModel) {
              list.add({
                'id': int.tryParse(item.id) ?? 0,
                'name': item.name,
                'sku': item.sku,
                'size': item.size,
                'units_per_case': item.unitsPerCase,
              });
            }
          }
        }
        if (mounted && list.isNotEmpty) {
          setState(() {
            _productList = list;
            if (_selectedProductId == null || !_productList.any((p) => p['id'] == _selectedProductId)) {
              _selectedProductId = _productList.first['id'] as int?;
              _applySmartDefaults(_productList.first);
            }
          });
        }
      }
    } catch (_) {}
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

  void _startEditRule(Map<String, dynamic> rule) {
    setState(() {
      _editingRuleId = rule['id'] as int?;
      _nameCtrl.text = rule['name']?.toString() ?? '';
      _channel = rule['applies_to']?.toString() ?? rule['channel']?.toString() ?? 'CUSTOMER';
      _salesUnit = rule['sales_unit']?.toString() ?? 'CARTON';
      _minQtyCtrl.text = (rule['min_order_quantity'] ?? 5).toString();
      _cartonSizeCtrl.text = (rule['units_per_carton'] ?? rule['carton_pack_size'] ?? 24).toString();
      _allowPartialCarton = rule['allow_partial_carton'] ?? false;
      _allowFranchiseOverride = rule['allow_franchise_override'] ?? false;
      _maxFranchiseMoqCtrl.text = rule['max_franchise_moq']?.toString() ?? '';
      _isActive = rule['is_active'] ?? true;
      final pid = rule['product'] ?? rule['product_id'];
      if (pid != null) {
        _selectedProductId = int.tryParse(pid.toString());
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingRuleId = null;
      _nameCtrl.clear();
      _minQtyCtrl.text = '5';
      _cartonSizeCtrl.text = '24';
      _maxFranchiseMoqCtrl.clear();
      _allowPartialCarton = false;
      _allowFranchiseOverride = false;
      _isActive = true;
      if (_productList.isNotEmpty) {
        _selectedProductId = _productList.first['id'] as int?;
        _applySmartDefaults(_productList.first);
      }
    });
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
    setState(() {
      _loading = true;
      _rulesError = null;
    });
    final res = await _service.getPackagingRules();
    if (mounted) {
      setState(() {
        _loading = false;
        _isRulesCached = res['is_cached'] == true;
        _rules = res['rules'] as List? ?? [];
        if (res['success'] == true) {
          _rulesError = null;
        } else {
          _rulesError = res['message']?.toString() ?? 'Failed to load packaging rules';
        }
      });
    }
  }

  Future<void> _submitNewRule() async {
    if (!_formKey.currentState!.validate()) {
      AppToast.warning(context, 'Please fill all required fields with valid values.');
      return;
    }

    if (_selectedProductId == null) {
      AppToast.error(context, 'Please select an assigned product for this packaging rule.');
      return;
    }

    final minQty = int.tryParse(_minQtyCtrl.text.trim()) ?? 5;
    final cartonSize = int.tryParse(_cartonSizeCtrl.text.trim()) ?? 24;
    final maxFMoq = int.tryParse(_maxFranchiseMoqCtrl.text.trim());

    setState(() => _creating = true);
    final payload = {
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
    };

    final Map<String, dynamic> res;
    if (_editingRuleId != null) {
      res = await _service.updatePackagingRule(_editingRuleId!, payload);
    } else {
      res = await _service.createPackagingRule(payload);
    }

    if (mounted) {
      setState(() => _creating = false);
      if (res['success'] == true) {
        AppToast.success(
          context,
          _editingRuleId != null
              ? 'Packaging & MOQ rule updated successfully'
              : 'Packaging & MOQ rule saved successfully',
        );
        _cancelEdit();
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
          AppToast.success(context, 'Rule deleted successfully');
          _loadRules();
        } else {
          AppToast.error(context, 'Failed to delete rule');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        final dialogWidth = isMobile ? constraints.maxWidth * 0.96 : 1050.0;
        final dialogHeight = isMobile ? constraints.maxHeight * 0.92 : 720.0;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 24,
            vertical: isMobile ? 16 : 24,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.transparent,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    if (isNarrow) {
                      return DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            TabBar(
                              labelColor: const Color(0xFF0284C7),
                              unselectedLabelColor: const Color(0xFF64748B),
                              indicatorColor: const Color(0xFF0284C7),
                              tabs: [
                                const Tab(text: 'Rule Form'),
                                Tab(text: 'Active Rules (${_rules.length})'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  SingleChildScrollView(child: _buildForm()),
                                  _buildRulesList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: SingleChildScrollView(child: _buildForm()),
                        ),
                        const VerticalDivider(width: 32),
                        Expanded(
                          flex: 6,
                          child: _buildRulesList(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
      },
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _editingRuleId != null ? 'Edit Packaging Rule #$_editingRuleId' : 'Create Packaging Rule',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              if (_editingRuleId != null)
                TextButton.icon(
                  onPressed: _cancelEdit,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Cancel Edit', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
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
            key: ValueKey('channel_$_channel'),
            initialValue: _channel,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Applicable Channel',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer Direct Orders', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'FRANCHISE', child: Text('Wholesale Franchise / Dealer', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'ALL', child: Text('All Channels', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _channel = val);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('prod_${_selectedProductId}_${_productList.length}'),
            initialValue: _productList.any((p) => p['id'] == _selectedProductId) ? _selectedProductId : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Assigned Product *',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _productList.map((p) {
              final id = p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString()) ?? 0;
              return DropdownMenuItem<int>(
                value: id,
                child: Text(
                  '${p['name']} (${p['size'] ?? p['sku'] ?? 'Standard'})',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedProductId = val;
                final prod = _productList.firstWhere((p) => p['id'] == val, orElse: () => {});
                if (prod.isNotEmpty) {
                  _applySmartDefaults(prod);
                }
              });
            },
            validator: (val) => val == null ? 'Please select a product' : null,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('unit_$_salesUnit'),
                  initialValue: _salesUnit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sales / Ordering Unit',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CARTON', child: Text('Carton / Box (Peti)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'JAR', child: Text('20L Water Jar', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'PIECE', child: Text('Individual Bottle', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _salesUnit = val;
                        if (val == 'JAR') {
                          _cartonSizeCtrl.text = '1';
                          _minQtyCtrl.text = '5';
                          _allowPartialCarton = true;
                        } else if (val == 'CARTON') {
                          if (_cartonSizeCtrl.text == '1') _cartonSizeCtrl.text = '24';
                          _allowPartialCarton = false;
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: _cartonSizeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _salesUnit == 'JAR' ? 'Units / Container *' : 'Bottles / Carton *',
                    hintText: _salesUnit == 'JAR' ? '1 for individual jar' : '24 or 12',
                    helperText: _salesUnit == 'JAR' ? '1 Jar per container' : 'Pack size per case',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Valid > 0 required';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _minQtyCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _salesUnit == 'JAR'
                  ? 'Minimum Jar Order Quantity (Jar MOQ) *'
                  : (_salesUnit == 'CARTON' ? 'Minimum Order Quantity (Cartons / Peti) *' : 'Minimum Order Quantity (Units) *'),
              hintText: _salesUnit == 'JAR' ? 'e.g. 5 Jars' : 'e.g. 5 Cartons',
              helperText: _salesUnit == 'JAR'
                  ? 'Minimum number of 20L jars required per order'
                  : (_salesUnit == 'CARTON' ? 'Minimum case packs required per order' : 'Minimum item units required per order'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Valid > 0 required';
              return null;
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _salesUnit == 'JAR' ? 'Allow Individual Jar Counts above MOQ' : 'Enforce Strict Carton Multiples',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _salesUnit == 'JAR'
                  ? 'Permits ordering any integer count (e.g. 5, 6, 7 jars) instead of crate/rack multiples'
                  : 'Disallows loose individual bottles (e.g. must buy multiples of 24)',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            value: _salesUnit == 'JAR' ? _allowPartialCarton : !_allowPartialCarton,
            onChanged: (v) => setState(() => _allowPartialCarton = _salesUnit == 'JAR' ? v : !v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow Franchise Override', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Permits approved franchise dealers to adjust local MOQ within limits', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            value: _allowFranchiseOverride,
            onChanged: (v) => setState(() => _allowFranchiseOverride = v),
          ),
          if (_allowFranchiseOverride) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _maxFranchiseMoqCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max Allowed Franchise MOQ Ceiling',
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
          Row(
            children: [
              if (_editingRuleId != null) ...[
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _cancelEdit,
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: SizedBox(
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
                    label: Text(
                      _editingRuleId != null ? 'Update Packaging Rule' : 'Save Packaging & MOQ Rule',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text('Active Rules (${_rules.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isRulesCached ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _isRulesCached ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isRulesCached ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                        size: 12,
                        color: _isRulesCached ? const Color(0xFFB45309) : const Color(0xFF15803D),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isRulesCached ? 'Local Cache (Offline)' : 'Server Synced',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _isRulesCached ? const Color(0xFFB45309) : const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _loadRules,
            ),
          ],
        ),
        if (_rulesError != null)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _rulesError!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                  ),
                ),
                TextButton(
                  onPressed: _loadRules,
                  child: const Text('Retry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                ),
              ],
            ),
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
                        final channel = r['applies_to'] ?? r['channel'] ?? 'ALL';
                        final bool active = r['is_active'] ?? true;
                        final bool enforceCarton = r['enforce_carton_multiples'] ?? !(r['allow_partial_carton'] ?? false);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: active ? Colors.white : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: active ? const Color(0xFF0F172A) : Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: active,
                                    activeThumbColor: const Color(0xFF0284C7),
                                    onChanged: (v) => _toggleRuleActive(r, v),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0284C7)),
                                    tooltip: 'Edit Rule',
                                    onPressed: () => _startEditRule(Map<String, dynamic>.from(r)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                    tooltip: 'Delete Rule',
                                    onPressed: () => _deleteRule(r['id'] as int),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      prodName,
                                      style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: channel == 'CUSTOMER' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      channel == 'CUSTOMER' ? 'Customer Direct' : (channel == 'FRANCHISE' ? 'Franchise Only' : 'All Channels'),
                                      style: TextStyle(
                                        color: channel == 'CUSTOMER' ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                salesUnit == 'JAR'
                                    ? '• Packaging: Individual 20L Returnable Container ($packSize unit/container)\n'
                                      '• Minimum Jar Order Quantity: $minQty Jars\n'
                                      '• Ordering Rule: ${enforceCarton ? 'Strict Crate Multiples' : 'Individual Jars Allowed (Min $minQty Jars)'}'
                                    : '• Case Pack Size: $packSize bottles/carton\n'
                                      '• Minimum Order Quantity: $minQty ${salesUnit == 'CARTON' ? 'Cartons (Peti)' : salesUnit} (${minQty * packSize} bottles)\n'
                                      '• Ordering Rule: ${enforceCarton ? 'Strict Carton Multiples Enforced' : 'Loose Bottles Allowed'}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.4),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
