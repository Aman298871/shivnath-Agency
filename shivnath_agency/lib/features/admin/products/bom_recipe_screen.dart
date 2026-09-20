import 'package:flutter/material.dart';

import '../../../core/services/InventoryService.dart';
import '../../../core/services/product_service.dart';
import '../../../models/product_model.dart';

/// Super Admin BOM (Bill of Materials) Recipe & Master Pricing Editor
/// Controls the exact formula for the 5 official variants,
/// assigns raw materials required per unit, and manages wholesale pricing.
class BomRecipeScreen extends StatefulWidget {
  const BomRecipeScreen({super.key});

  @override
  State<BomRecipeScreen> createState() => _BomRecipeScreenState();
}

class _BomRecipeScreenState extends State<BomRecipeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final InventoryService _invService = InventoryService();

  bool _loading = false;
  String? _error;

  List<ProductModel> _products = [];
  List<Map<String, dynamic>> _rawMaterials = [];
  ProductModel? _selectedProduct;

  Map<String, dynamic>? _currentBOM;
  List<Map<String, dynamic>> _bomItems = [];

  int get _selectedProductId => int.tryParse(_selectedProduct?.id ?? '0') ?? 0;

  // Controllers for Pricing & Thresholds
  final wholesalePriceCtrl = TextEditingController();
  final retailMrpCtrl = TextEditingController();
  final moqCtrl = TextEditingController();
  final thresholdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    wholesalePriceCtrl.dispose();
    retailMrpCtrl.dispose();
    moqCtrl.dispose();
    thresholdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Load products
      await ProductService().getProducts();
      _products = ProductService.products;

      // 2. Load raw materials
      final rmRes = await _invService.getRawMaterials();
      if (rmRes['success'] == true && rmRes['data'] is List) {
        _rawMaterials = List<Map<String, dynamic>>.from(rmRes['data']);
      }

      if (_products.isNotEmpty) {
        _selectedProduct = _products.first;
        await _loadBOMForProduct(_selectedProductId);
      }
    } catch (e) {
      _error = 'Failed to load BOM master data: $e';
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadBOMForProduct(int productId) async {
    try {
      final res = await _invService.getProductBOM(productId);
      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        _currentBOM = res['data'] as Map<String, dynamic>;
        _bomItems = List<Map<String, dynamic>>.from(_currentBOM?['items'] ?? []);

        final pricing = _currentBOM?['pricing'] as Map<String, dynamic>?;
        wholesalePriceCtrl.text = pricing?['dealer_wholesale_price']?.toString() ?? '0.00';
        retailMrpCtrl.text = pricing?['retail_mrp']?.toString() ?? '0.00';
        moqCtrl.text = pricing?['minimum_order_quantity_cases']?.toString() ?? '10';
        thresholdCtrl.text = _currentBOM?['minimum_stock_threshold']?.toString() ?? '500';
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'BOM Recipe Master & Pricing',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0284C7)),
            onPressed: _loadInitialData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0284C7),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0284C7),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'BOM Formula (Raw Materials)'),
            Tab(text: 'Master Pricing & Stock Rules'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    _buildProductSelectorHeader(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBOMFormulaTab(),
                          _buildPricingTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildProductSelectorHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          const Text(
            'Finished Product:',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: DropdownButtonFormField<ProductModel>(
              value: _selectedProduct,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(),
              ),
              items: _products.map((p) {
                return DropdownMenuItem<ProductModel>(
                  value: p,
                  child: Text(
                    '${p.name} (${p.category})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedProduct = val);
                  _loadBOMForProduct(int.tryParse(val.id) ?? 0);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: BOM FORMULA
  // =========================================================================

  Widget _buildBOMFormulaTab() {
    final totalUnitCost = double.tryParse(_currentBOM?['estimated_unit_cost']?.toString() ?? '0') ?? 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cost Overview Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimated Unit Production Cost',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'INR ${totalUnitCost.toStringAsFixed(2)} / unit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0284C7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Material', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: _openAddBOMItemDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Recipe Ingredients (Per 1 Finished Unit):',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 10),

        if (_bomItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No raw materials mapped to this finished product.\nTap "+ Add Raw Material" to define BOM.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          )
        else
          ..._bomItems.map((item) {
            final id = item['id'];
            final rmName = item['raw_material_name'] ?? item['raw_material']?['name'] ?? 'Material';
            final rmCategory = item['raw_material_category'] ?? item['raw_material']?['category'] ?? '';
            final qtyReq = item['quantity_required']?.toString() ?? '1';
            final uom = item['unit_of_measure'] ?? item['raw_material']?['unit_of_measure'] ?? 'pcs';
            final costBasis = double.tryParse(item['cost_basis']?.toString() ?? '0') ?? 0.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE0F2FE),
                  child: Icon(_getCategoryIcon(rmCategory), color: const Color(0xFF0284C7)),
                ),
                title: Text(
                  rmName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text(
                  'Req: $qtyReq $uom per bottle | Cost Basis: INR ${costBasis.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () => _deleteBOMItem(id),
                  tooltip: 'Remove from Recipe',
                ),
              ),
            );
          }),
      ],
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'preform':
        return Icons.water_drop_outlined;
      case 'cap':
        return Icons.adjust_rounded;
      case 'label':
        return Icons.label_outline_rounded;
      case 'box':
        return Icons.inventory_2_outlined;
      case 'chemical':
        return Icons.science_outlined;
      default:
        return Icons.layers_outlined;
    }
  }

  void _openAddBOMItemDialog() {
    if (_selectedProduct == null) return;

    Map<String, dynamic>? selectedRM;
    final qtyCtrl = TextEditingController(text: '1.0');
    final costCtrl = TextEditingController(text: '0.00');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Text('Add Raw Material to Recipe'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: const InputDecoration(labelText: 'Select Raw Material *'),
                    items: _rawMaterials.map((rm) {
                      return DropdownMenuItem(
                        value: rm,
                        child: Text('${rm['name']} (${rm['code'] ?? rm['category']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDlgState(() {
                        selectedRM = val;
                        costCtrl.text = val?['unit_cost']?.toString() ?? '0.00';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantity Required (per finished unit) *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cost Basis per unit (INR)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (selectedRM == null) return;
                        final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                        final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;

                        setDlgState(() => isSaving = true);
                        final res = await _invService.addProductBOMItem(_selectedProductId, {
                          'raw_material_id': selectedRM!['id'],
                          'quantity_required': qty,
                          'cost_basis': cost,
                        });
                        setDlgState(() => isSaving = false);

                        if (res['success'] == true) {
                          if (mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Item added to BOM!'), backgroundColor: Colors.green),
                            );
                            _loadBOMForProduct(_selectedProductId);
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add to BOM'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteBOMItem(int itemId) async {
    if (_selectedProduct == null) return;
    final res = await _invService.deleteProductBOMItem(_selectedProductId, itemId);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Raw material removed from BOM!'), backgroundColor: Colors.green),
      );
      _loadBOMForProduct(_selectedProductId);
    }
  }

  // =========================================================================
  // TAB 2: PRICING & SAFETY STOCK THRESHOLD
  // =========================================================================

  Widget _buildPricingTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.monetization_on_outlined, color: Color(0xFF0284C7)),
                  SizedBox(width: 8),
                  Text(
                    'Master Pricing Rules',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: wholesalePriceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Wholesale Transfer Price to Dealers (INR per unit) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: retailMrpCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Retail MRP (INR per unit) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_offer_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: moqCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Order Quantity (Cases) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.layers_outlined),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Update Pricing Rules', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: _savePricing,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.notifications_active_outlined, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Safety Stock Thresholds',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'When central plant stock falls below this threshold, automatic background alerts trigger to notify plant admins.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: thresholdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Safety Stock Alert (Units) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Save Stock Threshold', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: _saveThreshold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _savePricing() async {
    if (_selectedProduct == null) return;
    final wp = double.tryParse(wholesalePriceCtrl.text.trim()) ?? 0.0;
    final mrp = double.tryParse(retailMrpCtrl.text.trim()) ?? 0.0;
    final moq = int.tryParse(moqCtrl.text.trim()) ?? 10;

    final res = await _invService.updateProductPricing(_selectedProductId, {
      'dealer_wholesale_price': wp,
      'retail_mrp': mrp,
      'minimum_order_quantity_cases': moq,
    });

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pricing rules updated!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _saveThreshold() async {
    if (_selectedProduct == null) return;
    final th = int.tryParse(thresholdCtrl.text.trim()) ?? 500;

    final res = await _invService.updateProductStockThreshold(_selectedProductId, {
      'minimum_stock_threshold': th,
    });

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock threshold saved!'), backgroundColor: Colors.green),
      );
    }
  }
}
