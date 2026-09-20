import 'package:flutter/material.dart';

import '../../../core/services/InventoryService.dart';
import '../../../core/services/product_service.dart';
import '../../../models/product_model.dart';

/// Central Plant Inventory & Production Batch Operations Screen
/// For Plant Admins: Manages finished production batches,
/// raw materials stock, and dispatches to authorized wholesale dealers.
class CentralPlantInventoryScreen extends StatefulWidget {
  const CentralPlantInventoryScreen({super.key});

  @override
  State<CentralPlantInventoryScreen> createState() =>
      _CentralPlantInventoryScreenState();
}

class _CentralPlantInventoryScreenState
    extends State<CentralPlantInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final InventoryService _invService = InventoryService();

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _productionBatches = [];
  List<Map<String, dynamic>> _rawMaterials = [];
  List<Map<String, dynamic>> _dealerRequests = [];
  List<ProductModel> _products = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Batches
      final bRes = await _invService.getProductionBatches();
      if (bRes['success'] == true && bRes['data'] is List) {
        _productionBatches = List<Map<String, dynamic>>.from(bRes['data']);
      }

      // 2. Raw materials
      final rmRes = await _invService.getRawMaterials();
      if (rmRes['success'] == true && rmRes['data'] is List) {
        _rawMaterials = List<Map<String, dynamic>>.from(rmRes['data']);
      }

      // 3. Dealer Stock Requests
      final reqRes = await _invService.getDealerStockRequests();
      if (reqRes['success'] == true && reqRes['data'] is List) {
        _dealerRequests = List<Map<String, dynamic>>.from(reqRes['data']);
      }

      // 4. Products
      await ProductService().getProducts();
      _products = ProductService.products;
    } catch (e) {
      _error = 'Failed to load central plant data: $e';
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Central Plant Inventory & Dispatch',
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
            onPressed: _loadData,
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
            Tab(text: 'Production Batches'),
            Tab(text: 'Raw Materials'),
            Tab(text: 'Dealer Dispatches'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        icon: const Icon(Icons.precision_manufacturing_rounded, color: Colors.white),
        label: const Text('Produce Batch', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        onPressed: _openCreateBatchDialog,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProductionBatchesTab(),
                    _buildRawMaterialsTab(),
                    _buildDealerDispatchesTab(),
                  ],
                ),
    );
  }

  // =========================================================================
  // TAB 1: PRODUCTION BATCHES
  // =========================================================================

  Widget _buildProductionBatchesTab() {
    if (_productionBatches.isEmpty) {
      return const Center(
        child: Text(
          'No production batches found.\nTap "+ Produce Batch" to manufacture a new batch using BOM formula.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _productionBatches.length,
      itemBuilder: (context, idx) {
        final b = _productionBatches[idx];
        final bNum = b['batch_number']?.toString() ?? 'BATCH';
        final sku = b['product_sku'] ?? b['sku'] ?? '';
        final produced = b['quantity_produced_units']?.toString() ?? '0';
        final remaining = b['quantity_remaining_company']?.toString() ?? '0';
        final expiry = b['expiry_date']?.toString() ?? '';
        final unitCost = double.tryParse(b['unit_production_cost']?.toString() ?? '0') ?? 0.0;
        final isQuarantined = b['is_quarantined'] == true;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isQuarantined ? Colors.red.shade100 : const Color(0xFFE0F2FE),
              child: Icon(
                isQuarantined ? Icons.block_rounded : Icons.water_drop_rounded,
                color: isQuarantined ? Colors.red : const Color(0xFF0284C7),
              ),
            ),
            title: Row(
              children: [
                Text(bNum, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(sku, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF0284C7))),
                ),
                if (isQuarantined) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                    child: const Text('QUARANTINED', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 9, color: Colors.red)),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Available Company Stock: $remaining / $produced units',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 12)),
                const SizedBox(height: 2),
                Text('Unit Cost: INR ${unitCost.toStringAsFixed(2)} | Expiry: $expiry',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 2: RAW MATERIALS STOCK
  // =========================================================================

  Widget _buildRawMaterialsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Raw Materials Inventory',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Material'),
              onPressed: _openCreateRawMaterialDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_rawMaterials.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No raw materials found.')),
          )
        else
          ..._rawMaterials.map((rm) {
            final name = rm['name']?.toString() ?? 'Material';
            final code = rm['code']?.toString() ?? '';
            final category = rm['category']?.toString() ?? '';
            final stock = double.tryParse(rm['current_stock']?.toString() ?? '0') ?? 0.0;
            final reorder = double.tryParse(rm['reorder_level']?.toString() ?? '0') ?? 0.0;
            final uom = rm['unit_of_measure']?.toString() ?? 'pcs';
            final unitCost = double.tryParse(rm['unit_cost']?.toString() ?? '0') ?? 0.0;
            final isLow = stock <= reorder;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isLow ? Colors.orange.shade100 : const Color(0xFFF1F5F9),
                  child: Icon(Icons.science_outlined, color: isLow ? Colors.orange.shade800 : const Color(0xFF64748B)),
                ),
                title: Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(width: 8),
                    Text('($code)', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
                subtitle: Text('Category: $category | Unit Cost: INR ${unitCost.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${stock.toStringAsFixed(0)} $uom',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isLow ? Colors.red.shade700 : const Color(0xFF0F172A),
                        )),
                    if (isLow)
                      const Text('REORDER REQUIRED',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 9, color: Colors.red)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // =========================================================================
  // TAB 3: DEALER DISPATCHES (MULTI-BATCH ALLOCATION)
  // =========================================================================

  Widget _buildDealerDispatchesTab() {
    final pending = _dealerRequests.where((r) {
      final s = (r['status'] ?? '').toString().toUpperCase();
      return s == 'PENDING' || s == 'PARTIALLY_DISPATCHED';
    }).toList();

    if (pending.isEmpty) {
      return const Center(
        child: Text(
          'No pending dealer stock requests to dispatch.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, idx) {
        final req = pending[idx];
        final id = req['id'];
        final reqNum = req['request_number'] ?? 'REQ-$id';
        final dealerName = req['dealer_name'] ?? 'Wholesale Dealer';
        final items = (req['items'] as List?) ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(reqNum, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Text('READY FOR DISPATCH',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: Colors.orange)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Dealer: $dealerName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 10),
                const Text('Items Requested:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 4),
                ...items.map((it) {
                  final sku = it['product_sku'] ?? 'SKU';
                  final cases = it['quantity_cases'] ?? 0;
                  final fulfilled = it['fulfilled_cases'] ?? 0;
                  return Text('• $sku: $cases Cases (Dispatched so far: $fulfilled)', style: const TextStyle(fontSize: 12));
                }),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.local_shipping_rounded),
                    label: const Text('Allocate Batches & Dispatch', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => _openDispatchDialog(req),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // ACTIONS
  // =========================================================================

  void _openCreateBatchDialog() {
    ProductModel? selectedProduct = _products.isNotEmpty ? _products.first : null;
    final batchNumCtrl = TextEditingController(text: 'BATCH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final qtyCtrl = TextEditingController(text: '500');
    final shelfDaysCtrl = TextEditingController(text: '180');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Text('Manufacture Production Batch'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<ProductModel>(
                    value: selectedProduct,
                    decoration: const InputDecoration(labelText: 'Finished Product Variant *'),
                    items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (val) => setDlgState(() => selectedProduct = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: batchNumCtrl, decoration: const InputDecoration(labelText: 'Batch Number *')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity to Produce (Bottles/Jars) *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: shelfDaysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Shelf Life (Days) *'),
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
                        if (selectedProduct == null) return;
                        final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                        final days = int.tryParse(shelfDaysCtrl.text.trim()) ?? 180;
                        final expiry = DateTime.now().add(Duration(days: days)).toIso8601String().split('T').first;

                        setDlgState(() => isSaving = true);
                        final res = await _invService.createProductionBatch({
                          'product_id': selectedProduct!.id,
                          'batch_number': batchNumCtrl.text.trim(),
                          'quantity_produced_units': qty,
                          'expiry_date': expiry,
                        });
                        setDlgState(() => isSaving = false);

                        if (res['success'] == true) {
                          if (mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Production batch created and raw materials consumed!'), backgroundColor: Colors.green),
                            );
                            _loadData();
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res['message'] ?? 'Failed to create batch. Check raw material stock.'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Produce Batch'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openCreateRawMaterialDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final costCtrl = TextEditingController(text: '1.00');
    final stockCtrl = TextEditingController(text: '1000');
    final reorderCtrl = TextEditingController(text: '200');
    String category = 'preform';
    String uom = 'pcs';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Text('Add Raw Material Master'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Material Name *')),
                  const SizedBox(height: 10),
                  TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Material Code (e.g. RM-PRF-20G) *')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(value: 'preform', child: Text('Preform')),
                      DropdownMenuItem(value: 'cap', child: Text('Cap')),
                      DropdownMenuItem(value: 'label', child: Text('Label')),
                      DropdownMenuItem(value: 'box', child: Text('Box / Carton')),
                      DropdownMenuItem(value: 'chemical', child: Text('Chemical / Minerals')),
                      DropdownMenuItem(value: 'water', child: Text('Raw Water')),
                    ],
                    onChanged: (val) => setDlgState(() => category = val ?? category),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: uom,
                    decoration: const InputDecoration(labelText: 'Unit of Measure'),
                    items: const [
                      DropdownMenuItem(value: 'pcs', child: Text('Pcs')),
                      DropdownMenuItem(value: 'litres', child: Text('Litres')),
                      DropdownMenuItem(value: 'rolls', child: Text('Rolls')),
                      DropdownMenuItem(value: 'boxes', child: Text('Boxes')),
                      DropdownMenuItem(value: 'kg', child: Text('Kg')),
                    ],
                    onChanged: (val) => setDlgState(() => uom = val ?? uom),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Unit Cost (INR) *'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 10),
                  TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Initial Stock *'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 10),
                  TextField(controller: reorderCtrl, decoration: const InputDecoration(labelText: 'Reorder Level *'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setDlgState(() => isSaving = true);
                        final res = await _invService.createRawMaterial({
                          'name': nameCtrl.text.trim(),
                          'code': codeCtrl.text.trim(),
                          'category': category,
                          'unit_of_measure': uom,
                          'unit_cost': double.tryParse(costCtrl.text.trim()) ?? 0.0,
                          'current_stock': double.tryParse(stockCtrl.text.trim()) ?? 0.0,
                          'reorder_level': double.tryParse(reorderCtrl.text.trim()) ?? 0.0,
                        });
                        setDlgState(() => isSaving = false);
                        if (res['success'] == true) {
                          if (mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Raw material registered!'), backgroundColor: Colors.green),
                            );
                            _loadData();
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Register Material'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openDispatchDialog(Map<String, dynamic> req) {
    final reqId = req['id'];
    final items = (req['items'] as List?) ?? [];
    final allocations = <int, TextEditingController>{};

    for (final it in items) {
      final itId = it['id'];
      final neededCases = (it['quantity_cases'] ?? 0) - (it['fulfilled_cases'] ?? 0);
      allocations[itId] = TextEditingController(text: neededCases.toString());
    }

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Text('Dispatch Dealer Request'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Specify cases to dispatch for each item. Central stock will be reserved and deducted from oldest FEFO batches:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  ...items.map((it) {
                    final itId = it['id'];
                    final sku = it['product_sku'] ?? 'SKU';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(sku, style: const TextStyle(fontWeight: FontWeight.w700))),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: allocations[itId],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Cases', isDense: true, border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final itemsPayload = <Map<String, dynamic>>[];
                        for (final entry in allocations.entries) {
                          final c = int.tryParse(entry.value.text.trim()) ?? 0;
                          if (c > 0) {
                            itemsPayload.add({'item_id': entry.key, 'cases_to_dispatch': c});
                          }
                        }

                        if (itemsPayload.isEmpty) return;
                        setDlgState(() => isSubmitting = true);
                        final res = await _invService.dispatchDealerStockRequest(reqId, {'items': itemsPayload});
                        setDlgState(() => isSubmitting = false);

                        if (res['success'] == true) {
                          if (mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Dispatch executed! Wholesale invoice created.'), backgroundColor: Colors.green),
                            );
                            _loadData();
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(res['message'] ?? 'Dispatch failed. Check stock availability.'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirm Dispatch'),
              ),
            ],
          );
        },
      ),
    );
  }
}
