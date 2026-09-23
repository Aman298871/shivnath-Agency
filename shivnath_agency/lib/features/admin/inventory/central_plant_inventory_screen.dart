import 'package:flutter/material.dart';

import '../../../core/services/InventoryService.dart';
import '../../../core/services/product_service.dart';
import '../../../models/product_model.dart';

/// Central Plant Inventory & Production Batch Operations Screen
/// For Plant Admins: Manages finished production batches,
/// raw materials stock, and dispatches to authorized wholesale dealers.
class CentralPlantInventoryScreen extends StatefulWidget {
  final int initialTab;
  const CentralPlantInventoryScreen({super.key, this.initialTab = 0});

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
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
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
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Production Batches'),
            Tab(text: 'Raw Materials'),
            Tab(text: 'Dealer Dispatches'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        icon: const Icon(
          Icons.precision_manufacturing_rounded,
          color: Colors.white,
        ),
        label: const Text(
          'Produce Batch',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        onPressed: _openCreateBatchDialog,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
            )
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
        final bId = b['id'] is int
            ? b['id'] as int
            : int.tryParse(b['id']?.toString() ?? '0') ?? 0;
        final bNum = b['batch_number']?.toString() ?? 'BATCH';
        final pName = b['product_name'] ?? 'Packaged Drinking Water';
        final sku = b['product_sku'] ?? b['sku'] ?? '';
        final clientName = b['client_name']?.toString() ?? '';
        final orderCode = b['linked_order_code']?.toString() ?? '';
        final labelReq = b['label_requirement']?.toString() ?? '';
        final printingReq = b['printing_requirement']?.toString() ?? '';
        final brandingReq = b['branding_requirement']?.toString() ?? '';

        final produced =
            int.tryParse(b['quantity_produced_units']?.toString() ?? '0') ?? 0;
        final taken =
            int.tryParse(
              (b['quantity_taken'] ?? b['quantity_dispatched'])?.toString() ??
                  '0',
            ) ??
            0;
        final remaining =
            int.tryParse(
              (b['quantity_remaining_company'] ??
                          b['dynamic_remaining_company'])
                      ?.toString() ??
                  '0',
            ) ??
            (produced - taken);
        final shelfDays = b['shelf_life_days']?.toString() ?? '';
        final mfgDate = b['manufacture_date']?.toString() ?? '';
        final expiry = b['expiry_date']?.toString() ?? '';
        final unitCost =
            double.tryParse(b['unit_production_cost']?.toString() ?? '0') ??
            0.0;
        final isExpired = b['is_expired'] == true;
        final isDepleted = remaining <= 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 1.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: isDepleted
                          ? Colors.grey.shade200
                          : (isExpired
                                ? Colors.red.shade100
                                : const Color(0xFFE0F2FE)),
                      child: Icon(
                        isDepleted
                            ? Icons.check_circle_outline_rounded
                            : Icons.water_drop_rounded,
                        color: isDepleted
                            ? Colors.grey.shade600
                            : (isExpired
                                  ? Colors.red
                                  : const Color(0xFF0284C7)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  bNum,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x1A0284C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sku,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDepleted
                            ? Colors.grey.shade100
                            : (isExpired
                                  ? Colors.red.shade50
                                  : const Color(0xFFECFDF5)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDepleted
                              ? Colors.grey.shade300
                              : (isExpired
                                    ? Colors.red.shade200
                                    : const Color(0xFFA7F3D0)),
                        ),
                      ),
                      child: Text(
                        isDepleted
                            ? 'DEPLETED'
                            : (isExpired ? 'EXPIRED' : 'ACTIVE IN STOCK'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: isDepleted
                              ? Colors.grey.shade700
                              : (isExpired
                                    ? Colors.red.shade700
                                    : const Color(0xFF047857)),
                        ),
                      ),
                    ),
                  ],
                ),

                // Customer / Client Bulk Order Badges
                if (clientName.isNotEmpty ||
                    orderCode.isNotEmpty ||
                    labelReq.isNotEmpty ||
                    printingReq.isNotEmpty ||
                    brandingReq.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (clientName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.business_rounded,
                                size: 12,
                                color: Color(0xFF1D4ED8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Customer: $clientName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (orderCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFDDD6FE)),
                          ),
                          child: Text(
                            'Order: $orderCode',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: Color(0xFF6D28D9),
                            ),
                          ),
                        ),
                      if (labelReq.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            'Label: $labelReq',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      if (printingReq.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Text(
                            'Print: $printingReq',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // 3-Metric Stock Breakdown Grid (Produced, Taken, Pending Company Stock)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      // Produced
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PRODUCED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$produced',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Text(
                              'Units Manufactured',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(width: 8),
                      // Taken / Collected
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TAKEN / DELIVERED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$taken',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const Text(
                              'Collected by Client',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(width: 8),
                      // Pending in Company Stock
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PENDING STOCK',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$remaining',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: remaining > 0
                                    ? const Color(0xFF16A34A)
                                    : Colors.grey,
                              ),
                            ),
                            const Text(
                              'Still in Central Plant',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Expiry & Production metadata line
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Mfg: $mfgDate | Shelf Life: ${shelfDays.isNotEmpty ? '$shelfDays Days' : 'Configured'}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Exp: $expiry',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isExpired ? Colors.red : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Bottom Action Button
                if (remaining > 0)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.local_shipping_outlined, size: 18),
                      label: const Text(
                        'Dispatch / Record Customer Collection',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () => _openBatchCollectionDialog(b),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Colors.green,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Entire Batch Stock Cleared & Collected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
            final stock =
                double.tryParse(rm['current_stock']?.toString() ?? '0') ?? 0.0;
            final reorder =
                double.tryParse(rm['reorder_level']?.toString() ?? '0') ?? 0.0;
            final uom = rm['unit_of_measure']?.toString() ?? 'pcs';
            final unitCost =
                double.tryParse(rm['unit_cost']?.toString() ?? '0') ?? 0.0;
            final isLow = stock <= reorder;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isLow
                      ? Colors.orange.shade100
                      : const Color(0xFFF1F5F9),
                  child: Icon(
                    Icons.science_outlined,
                    color: isLow
                        ? Colors.orange.shade800
                        : const Color(0xFF64748B),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '($code)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'Category: $category | Unit Cost: INR ${unitCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${stock.toStringAsFixed(0)} $uom',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isLow
                            ? Colors.red.shade700
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    if (isLow)
                      const Text(
                        'REORDER REQUIRED',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          color: Colors.red,
                        ),
                      ),
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
        final dealerName = req['dealer_name'] ?? 'Franchise';
        final rawItems = req['items'];
        final List<Map<String, dynamic>> items = [];
        if (rawItems is List) {
          for (final it in rawItems) {
            if (it is Map<String, dynamic>) {
              items.add(it);
            } else if (it is Map) {
              items.add(Map<String, dynamic>.from(it));
            }
          }
        }
        if (items.isEmpty) {
          items.add({
            'id': req['id'] ?? 0,
            'product_sku':
                req['product_sku'] ?? req['product_name'] ?? 'Finished Product',
            'quantity_cases':
                req['requested_quantity'] ?? req['quantity_cases'] ?? 0,
            'fulfilled_cases':
                req['dispatched_quantity'] ?? req['fulfilled_cases'] ?? 0,
          });
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      reqNum,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'READY FOR DISPATCH',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Dealer: $dealerName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Items Requested:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 4),
                ...items.map((it) {
                  final sku = it['product_sku'] ?? 'SKU';
                  final cases = it['quantity_cases'] ?? 0;
                  final fulfilled = it['fulfilled_cases'] ?? 0;
                  return Text(
                    '• $sku: $cases Cases (Dispatched so far: $fulfilled)',
                    style: const TextStyle(fontSize: 12),
                  );
                }),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.local_shipping_rounded),
                    label: const Text(
                      'Allocate Batches & Dispatch',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
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

  void _openCreateBatchDialog({
    ProductModel? preselectedProduct,
    String? prefillClientName,
    int? prefillQuantity,
    String? prefillLabel,
    String? prefillPrint,
    String? prefillBranding,
    int? prefillOrderId,
    int? prefillShelfDays,
  }) {
    ProductModel? selectedProduct =
        preselectedProduct ?? (_products.isNotEmpty ? _products.first : null);
    final batchNumCtrl = TextEditingController(
      text:
          'BATCH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final qtyCtrl = TextEditingController(
      text: (prefillQuantity ?? 5000).toString(),
    );
    final clientNameCtrl = TextEditingController(text: prefillClientName ?? '');
    final shelfDaysCtrl = TextEditingController(
      text: (prefillShelfDays ?? selectedProduct?.shelfLifeDays ?? 180)
          .toString(),
    );
    final labelCtrl = TextEditingController(text: prefillLabel ?? '');
    final printCtrl = TextEditingController(text: prefillPrint ?? '');
    final brandingCtrl = TextEditingController(text: prefillBranding ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final int days = int.tryParse(shelfDaysCtrl.text.trim()) ?? 180;
          final dynamicExpiry = DateTime.now()
              .add(Duration(days: days))
              .toIso8601String()
              .split('T')
              .first;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.precision_manufacturing_rounded,
                  color: Color(0xFF0284C7),
                ),
                SizedBox(width: 8),
                Text(
                  'Produce Factory Batch',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<ProductModel>(
                    initialValue: selectedProduct,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Manufactured Product Variant *',
                      helperText:
                          '200 ML, 250 ML, 500 ML, 1 Litre, or 20 Litre Jar',
                    ),
                    items: _products
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              '${p.name} (${p.size})',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    selectedItemBuilder: (context) {
                      return _products.map((p) {
                        return Text(
                          '${p.name} (${p.size})',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                      }).toList();
                    },
                    onChanged: (val) {
                      setDlgState(() {
                        selectedProduct = val;
                        if (val != null) {
                          shelfDaysCtrl.text = val.shelfLifeDays.toString();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: clientNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Customer / Client Name (Bulk Order)',
                      hintText: 'e.g. Digital Marketing Wala',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: batchNumCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Batch Number *',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity to Produce (Bottles/Jars) *',
                      hintText: 'e.g. 5000',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: shelfDaysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Configurable Shelf-Life (Days) *',
                      helperText:
                          'Dynamic Expiry: $dynamicExpiry (Mfg + $days Days)',
                      helperStyle: const TextStyle(
                        color: Color(0xFF0284C7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Label / Sticker Requirement',
                      hintText: 'e.g. Custom 250ml Waterproof Glossy Sticker',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: printCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Printing / Branding Requirement',
                      hintText: 'e.g. Front Brand Logo & Back Compliance Info',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: brandingCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Packaging & Special Instructions',
                      hintText:
                          'e.g. Shrink-wrap cartons of 24 units, inspect caps',
                    ),
                  ),
                ],
              ),
            ),
          ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (selectedProduct == null) return;
                        final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Quantity must be greater than zero.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDlgState(() => isSaving = true);
                        final res = await _invService.createProductionBatch({
                          'product_id': selectedProduct!.id,
                          'batch_number': batchNumCtrl.text.trim(),
                          'quantity_produced_units': qty,
                          'shelf_life_days': days,
                          'expiry_date': dynamicExpiry,
                          'client_name': clientNameCtrl.text.trim(),
                          'linked_order': prefillOrderId,
                          'label_requirement': labelCtrl.text.trim(),
                          'printing_requirement': printCtrl.text.trim(),
                          'branding_requirement': brandingCtrl.text.trim(),
                        });
                        setDlgState(() => isSaving = false);

                        if (res['success'] == true) {
                          if (mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Production batch created! Finished stock added & raw materials deducted.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadData();
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res['message'] ??
                                      'Failed to create batch. Verify raw material stock.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Manufacture Batch',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openBatchCollectionDialog(Map<String, dynamic> batch) {
    final bId = batch['id'] is int
        ? batch['id'] as int
        : int.tryParse(batch['id']?.toString() ?? '0') ?? 0;
    final bNum = batch['batch_number']?.toString() ?? 'BATCH';
    final pName = batch['product_name'] ?? 'Packaged Drinking Water';
    final clientName = batch['client_name']?.toString() ?? '';
    final produced =
        int.tryParse(batch['quantity_produced_units']?.toString() ?? '0') ?? 0;
    final taken =
        int.tryParse(
          (batch['quantity_taken'] ?? batch['quantity_dispatched'])
                  ?.toString() ??
              '0',
        ) ??
        0;
    final remaining =
        int.tryParse(
          (batch['quantity_remaining_company'] ??
                      batch['dynamic_remaining_company'])
                  ?.toString() ??
              '0',
        ) ??
        (produced - taken);

    final qtyCtrl = TextEditingController(
      text: remaining.toString(),
    );
    final collectorCtrl = TextEditingController(text: clientName);
    final notesCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.local_shipping_rounded, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text(
                  'Record Customer Collection',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch: $bNum',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Product: $pName',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        if (clientName.isNotEmpty)
                          Text(
                            'Client: $clientName',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        const Divider(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Text(
                              'Produced: $produced',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Taken: $taken',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Available: $remaining',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity Collected / Taken (Units) *',
                      helperText:
                          'Max available in company stock: $remaining units',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: collectorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Collected By / Client Representative',
                      hintText: 'e.g. Digital Marketing Wala Rep',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dispatch / Pickup Notes',
                      hintText:
                          'e.g. Picked up by vehicle MH-12-AB-1234, remaining pending in company stock',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final takeQty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                        if (takeQty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Quantity collected must be greater than zero.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (takeQty > remaining) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cannot collect $takeQty units. Only $remaining available in company stock.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDlgState(() => isSaving = true);
                        final res = await _invService.recordBatchCollection(
                          batchId: bId,
                          quantityCollected: takeQty,
                          clientName: collectorCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                        );
                        setDlgState(() => isSaving = false);

                        if (res['success'] == true) {
                          if (mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res['message'] ??
                                      'Collection logged! Pending stock remains attached to batch.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadData();
                          }
                        } else {
                          if (mounted) {
                            final errMsg = res['message'] ?? res['error'] ?? 'Failed to log collection.';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errMsg.toString()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirm Collection',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
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
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Material Name *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Material Code (e.g. RM-PRF-20G) *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(
                        value: 'preform',
                        child: Text('Preform'),
                      ),
                      DropdownMenuItem(value: 'cap', child: Text('Cap')),
                      DropdownMenuItem(value: 'label', child: Text('Label')),
                      DropdownMenuItem(
                        value: 'box',
                        child: Text('Box / Carton'),
                      ),
                      DropdownMenuItem(
                        value: 'chemical',
                        child: Text('Chemical / Minerals'),
                      ),
                      DropdownMenuItem(
                        value: 'water',
                        child: Text('Raw Water'),
                      ),
                    ],
                    onChanged: (val) =>
                        setDlgState(() => category = val ?? category),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: uom,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Unit of Measure',
                    ),
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
                  TextField(
                    controller: costCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unit Cost (INR) *',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stockCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Initial Stock *',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reorderCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reorder Level *',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
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
                          'unit_cost':
                              double.tryParse(costCtrl.text.trim()) ?? 0.0,
                          'current_stock':
                              double.tryParse(stockCtrl.text.trim()) ?? 0.0,
                          'reorder_level':
                              double.tryParse(reorderCtrl.text.trim()) ?? 0.0,
                        });
                        setDlgState(() => isSaving = false);
                        if (res['success'] == true) {
                          if (mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Raw material registered!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadData();
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
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
    final rawItems = req['items'];
    final List<Map<String, dynamic>> items = [];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          items.add(it);
        } else if (it is Map) {
          items.add(Map<String, dynamic>.from(it));
        }
      }
    }
    if (items.isEmpty) {
      items.add({
        'id': req['id'] ?? 0,
        'product_sku':
            req['product_sku'] ?? req['product_name'] ?? 'Finished Product',
        'quantity_cases':
            req['requested_quantity'] ?? req['quantity_cases'] ?? 0,
        'fulfilled_cases':
            req['dispatched_quantity'] ?? req['fulfilled_cases'] ?? 0,
      });
    }

    final allocations = <int, TextEditingController>{};

    for (final it in items) {
      final itId = (it['id'] is int)
          ? (it['id'] as int)
          : (int.tryParse(it['id']?.toString() ?? '0') ?? 0);
      final neededCases =
          (int.tryParse(it['quantity_cases']?.toString() ?? '0') ?? 0) -
          (int.tryParse(it['fulfilled_cases']?.toString() ?? '0') ?? 0);
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
                          Expanded(
                            flex: 3,
                            child: Text(
                              sku,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: allocations[itId],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cases',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
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
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final itemsPayload = <Map<String, dynamic>>[];
                        for (final entry in allocations.entries) {
                          final c = int.tryParse(entry.value.text.trim()) ?? 0;
                          if (c > 0) {
                            itemsPayload.add({
                              'item_id': entry.key,
                              'cases_to_dispatch': c,
                            });
                          }
                        }

                        if (itemsPayload.isEmpty) return;
                        setDlgState(() => isSubmitting = true);
                        final res = await _invService
                            .dispatchDealerStockRequest(reqId, {
                              'items': itemsPayload,
                            });
                        setDlgState(() => isSubmitting = false);

                        if (res['success'] == true) {
                          if (mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Dispatch executed! Wholesale invoice created.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadData();
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res['message'] ??
                                      'Dispatch failed. Check stock availability.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Confirm Dispatch'),
              ),
            ],
          );
        },
      ),
    );
  }
}
