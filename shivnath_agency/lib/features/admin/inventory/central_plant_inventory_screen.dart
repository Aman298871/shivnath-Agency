import 'package:flutter/material.dart';

import '../../../core/repositories/app_repositories.dart';
import '../../../models/product_model.dart';
import '../../../core/widgets/cancel_order_dialog.dart';
import 'dealer_stock_request_fulfillment_screen.dart';

/// Central Plant Inventory & Production Batch Operations Screen
/// For Plant Admins: Manages finished production batches,
/// raw materials stock, and dispatches to authorized wholesale dealers.
class CentralPlantInventoryScreen extends StatefulWidget {
  final int initialTab;
  final String? highlightBatchNumber;
  final String? preselectedProductSku;
  final int? preselectedProductId;
  final bool openManufactureDialogOnLoad;

  const CentralPlantInventoryScreen({
    super.key,
    this.initialTab = 0,
    this.highlightBatchNumber,
    this.preselectedProductSku,
    this.preselectedProductId,
    this.openManufactureDialogOnLoad = false,
  });

  @override
  State<CentralPlantInventoryScreen> createState() =>
      _CentralPlantInventoryScreenState();
}

class _CentralPlantInventoryScreenState
    extends State<CentralPlantInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final InventoryRepository _invService = InventoryRepository();
  final ProductRepository _productRepository = ProductRepository();

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _productionBatches = [];
  List<Map<String, dynamic>> _rawMaterials = [];
  List<Map<String, dynamic>> _dealerRequests = [];
  List<ProductModel> _products = [];

  List<ProductModel> get _officialFallbackProducts => [
    const ProductModel(
      id: '2',
      name: 'Shivnath 200ml Event Bottle',
      sku: 'SHV-200',
      category: 'Water Bottles',
      size: '200 ML',
      price: 5.0,
      unit: 'Bottle',
      image: '',
      stock: 500,
      description: '200ml packaged pure drinking water',
      shelfLifeDays: 180,
      status: 'Active',
    ),
    const ProductModel(
      id: '3',
      name: 'Shivnath 250ml Mini Bottle',
      sku: 'SHV-250',
      category: 'Water Bottles',
      size: '250 ML',
      price: 6.0,
      unit: 'Bottle',
      image: '',
      stock: 500,
      description: '250ml packaged drinking water',
      shelfLifeDays: 180,
      status: 'Active',
    ),
    const ProductModel(
      id: '4',
      name: 'Shivnath 500ml Travel Bottle',
      sku: 'SHV-500',
      category: 'Water Bottles',
      size: '500 ML',
      price: 10.0,
      unit: 'Bottle',
      image: '',
      stock: 500,
      description: '500ml pure natural mineral water bottle',
      shelfLifeDays: 180,
      status: 'Active',
    ),
    const ProductModel(
      id: '5',
      name: 'Shivnath 1 Litre Premium Mineral Bottle',
      sku: 'SHV-1L',
      category: 'Water Bottles',
      size: '1 Litre',
      price: 20.0,
      unit: 'Bottle',
      image: '',
      stock: 500,
      description: '1 Litre table water bottle with 7-stage RO + UV',
      shelfLifeDays: 180,
      status: 'Active',
    ),
    const ProductModel(
      id: '6',
      name: 'Shivnath 20 Litre Dispenser Jar',
      sku: 'SHV-20L',
      category: 'Water Jars',
      size: '20 Litre Jar',
      price: 60.0,
      unit: 'Jar',
      image: '',
      stock: 500,
      description: '20 Litre purified packaged drinking water jar',
      shelfLifeDays: 45,
      status: 'Active',
    ),
  ];

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
        if (widget.highlightBatchNumber != null && widget.highlightBatchNumber!.isNotEmpty) {
          final target = widget.highlightBatchNumber!.toLowerCase();
          _productionBatches.sort((a, b) {
            final aMatch = a['batch_number']?.toString().toLowerCase().contains(target) == true;
            final bMatch = b['batch_number']?.toString().toLowerCase().contains(target) == true;
            if (aMatch && !bMatch) return -1;
            if (!aMatch && bMatch) return 1;
            return 0;
          });
        }
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

      // 4. Products - fetch active products directly from Product Master
      final pRes = await _productRepository.getProducts(activeOnly: true, status: 'Active');
      List<ProductModel> fetchedList = [];
      if (pRes['parsed_products'] is List<ProductModel> && (pRes['parsed_products'] as List).isNotEmpty) {
        fetchedList = List<ProductModel>.from(pRes['parsed_products']);
      } else {
        fetchedList = ProductRepository.cachedProducts.where((p) => p.status.toLowerCase() == 'active').toList();
      }

      const officialSkus = {'SHV-200', 'SHV-250', 'SHV-500', 'SHV-1L', 'SHV-20L'};
      final Map<String, ProductModel> uniqueMap = {};
      for (final p in fetchedList) {
        final sku = p.sku.toUpperCase();
        if (officialSkus.contains(sku) && !uniqueMap.containsKey(sku)) {
          uniqueMap[sku] = p;
        }
      }
      for (final fallback in _officialFallbackProducts) {
        final sku = fallback.sku.toUpperCase();
        if (!uniqueMap.containsKey(sku)) {
          uniqueMap[sku] = fallback;
        }
      }

      final List<ProductModel> finalList = uniqueMap.values.toList();
      const skuRank = {
        'SHV-200': 1,
        'SHV-250': 2,
        'SHV-500': 3,
        'SHV-1L': 4,
        'SHV-20L': 5,
      };
      finalList.sort((a, b) {
        final rA = skuRank[a.sku.toUpperCase()] ?? 99;
        final rB = skuRank[b.sku.toUpperCase()] ?? 99;
        return rA.compareTo(rB);
      });
      _products = finalList;

      if (widget.openManufactureDialogOnLoad && _products.isNotEmpty) {
        ProductModel? preselected;
        if (widget.preselectedProductSku != null && widget.preselectedProductSku!.isNotEmpty) {
          preselected = _products.firstWhere(
            (p) => p.sku.toUpperCase() == widget.preselectedProductSku!.toUpperCase(),
            orElse: () => _products.first,
          );
        } else if (widget.preselectedProductId != null) {
          preselected = _products.firstWhere(
            (p) => p.id == widget.preselectedProductId.toString(),
            orElse: () => _products.first,
          );
        } else {
          preselected = _products.first;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _openCreateBatchDialog(preselectedProduct: preselected);
          }
        });
      }
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
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
            Tab(text: 'Dealer Stock Requests'),
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
        final bNum = b['batch_number']?.toString() ?? 'BATCH';
        final pName = b['product_name'] ?? 'Packaged Drinking Water';
        final sku = b['product_sku'] ?? b['sku'] ?? '';
        final clientName = (b['client_name'] ?? '').toString().trim();
        final rawLinkedOrder = b['linked_order'];
        final orderDetails = b['order_details'] is Map ? Map<String, dynamic>.from(b['order_details'] as Map) : null;

        String rawOrdNum = (b['order_number'] ??
                b['linked_order_code'] ??
                (orderDetails != null ? orderDetails['order_code'] : null) ??
                (rawLinkedOrder is Map ? rawLinkedOrder['order_code'] : null))
            ?.toString()
            .trim() ?? '';

        if (rawOrdNum.isEmpty && rawLinkedOrder != null && rawLinkedOrder.toString() != 'null') {
          final idVal = rawLinkedOrder is Map ? rawLinkedOrder['id'] : rawLinkedOrder;
          if (idVal != null && int.tryParse(idVal.toString()) != null) {
            rawOrdNum = 'ORD-${1000 + int.parse(idVal.toString())}';
          } else if (rawLinkedOrder.toString().isNotEmpty) {
            rawOrdNum = rawLinkedOrder.toString();
          }
        }
        final orderNumber = rawOrdNum;

        String rawOrdName = (b['order_name'] ??
                (orderDetails != null ? orderDetails['client_name'] : null) ??
                (rawLinkedOrder is Map ? rawLinkedOrder['client_name'] : null) ??
                clientName)
            ?.toString()
            .trim() ?? '';
        final orderName = rawOrdName;

        final linkedOrderId = rawLinkedOrder is int
            ? rawLinkedOrder
            : (rawLinkedOrder is Map && rawLinkedOrder['id'] is int
                ? rawLinkedOrder['id'] as int
                : (orderDetails != null && orderDetails['id'] is int
                    ? orderDetails['id'] as int
                    : int.tryParse(rawLinkedOrder?.toString() ?? '')));

        final orderStatus = (orderDetails != null
                ? orderDetails['status']?.toString()
                : (rawLinkedOrder is Map ? rawLinkedOrder['status']?.toString() : null)) ??
            b['order_status']?.toString();

        final labelReq = b['label_requirement']?.toString() ?? '';
        final printingReq = b['printing_requirement']?.toString() ?? '';
        final brandingReq = b['branding_requirement']?.toString() ?? '';
        final notes = b['notes']?.toString() ?? '';

        final hasOrder = orderNumber.isNotEmpty ||
            orderName.isNotEmpty ||
            clientName.isNotEmpty ||
            linkedOrderId != null;

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
        final isExpired = b['is_expired'] == true;
        final isDepleted = remaining <= 0;
        final isHighlighted = widget.highlightBatchNumber != null &&
            bNum.toLowerCase().contains(widget.highlightBatchNumber!.toLowerCase());

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isHighlighted
                ? const BorderSide(color: Color(0xFF0284C7), width: 2)
                : BorderSide(color: Colors.grey.shade200),
          ),
          color: isHighlighted ? const Color(0xFFF0F9FF) : Colors.white,
          elevation: isHighlighted ? 3 : 1.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isHighlighted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'TARGETED ALERT BATCH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Top Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isDepleted
                          ? Colors.grey.shade200
                          : (isExpired
                                ? Colors.red.shade100
                                : const Color(0xFFE0F2FE)),
                      child: Icon(
                        isDepleted
                            ? Icons.check_circle_outline_rounded
                            : Icons.water_drop_rounded,
                        size: 22,
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SelectableText(
                                bNum,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              if (sku.isNotEmpty)
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isDepleted
                                      ? Colors.grey.shade100
                                      : (isExpired
                                            ? Colors.red.shade50
                                            : const Color(0xFFECFDF5)),
                                  borderRadius: BorderRadius.circular(6),
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
                          const SizedBox(height: 3),
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
                  ],
                ),

                // Linked Order & Client Full Information Card
                if (hasOrder ||
                    labelReq.isNotEmpty ||
                    printingReq.isNotEmpty ||
                    brandingReq.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (orderNumber.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.receipt_long_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 5),
                                    SelectableText(
                                      'ORDER #$orderNumber',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (orderStatus != null && orderStatus.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: orderStatus.toLowerCase() == 'delivered'
                                      ? const Color(0xFFECFDF5)
                                      : (orderStatus.toLowerCase() == 'dispatch'
                                          ? const Color(0xFFEFF6FF)
                                          : const Color(0xFFFFFBEB)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: orderStatus.toLowerCase() == 'delivered'
                                        ? const Color(0xFFA7F3D0)
                                        : (orderStatus.toLowerCase() == 'dispatch'
                                            ? const Color(0xFFBFDBFE)
                                            : const Color(0xFFFDE68A)),
                                  ),
                                ),
                                child: Text(
                                  'Status: ${orderStatus.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: orderStatus.toLowerCase() == 'delivered'
                                        ? const Color(0xFF047857)
                                        : (orderStatus.toLowerCase() == 'dispatch'
                                            ? const Color(0xFF1D4ED8)
                                            : const Color(0xFFB45309)),
                                  ),
                                ),
                              ),
                            if (linkedOrderId != null)
                              InkWell(
                                onTap: () => _openUpdateOrderStatusDialog(
                                  orderId: linkedOrderId,
                                  currentStatus: orderStatus ?? 'dispatch',
                                  orderCode: orderNumber,
                                  clientName: orderName.isNotEmpty ? orderName : clientName,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFDDD6FE)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF6D28D9)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Update Status',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF6D28D9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Full Order Name & Client
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.business_rounded,
                                size: 15,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                orderName.isNotEmpty
                                    ? 'Order Name: $orderName'
                                    : (clientName.isNotEmpty ? 'Customer: $clientName' : 'Bulk Requirement'),
                                softWrap: true,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (clientName.isNotEmpty && orderName.isNotEmpty && clientName != orderName) ...[
                          const SizedBox(height: 3),
                          Padding(
                            padding: const EdgeInsets.only(left: 21),
                            child: Text(
                              'Client: $clientName',
                              softWrap: true,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                        // Custom Requirements
                        if (labelReq.isNotEmpty || printingReq.isNotEmpty || brandingReq.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (labelReq.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Text(
                                    'Label: $labelReq',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10.5,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              if (printingReq.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: Text(
                                    'Print: $printingReq',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10.5,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                ),
                              if (brandingReq.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    'Branding: $brandingReq',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10.5,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              if (notes.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    'Notes: $notes',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10.5,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF64748B)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Central Plant Buffer Stock • Available for Dealer & Client Dispatch',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.local_shipping_rounded, size: 18),
                      label: Text(
                        orderNumber.isNotEmpty
                            ? 'Dispatch Pending Stock for #$orderNumber ($remaining Units)'
                            : 'Dispatch Pending Stock ($remaining Units)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
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
            final sku = rm['sku']?.toString() ?? '';
            final categoryKey = rm['category']?.toString() ?? '';
            final categoryDisplay = rm['category_display']?.toString() ?? _categoryLabel(categoryKey);
            final stock =
                double.tryParse(rm['current_stock']?.toString() ?? '0') ?? 0.0;
            final reorder =
                double.tryParse(rm['reorder_level']?.toString() ?? '0') ?? 0.0;
            final uom = rm['unit_of_measure']?.toString() ?? 'pcs';
            final unitCost =
                double.tryParse(rm['unit_cost']?.toString() ?? '0') ?? 0.0;
            final createdAt = rm['created_at']?.toString() ?? '';
            final updatedAt = rm['updated_at']?.toString() ?? '';
            final isLow = stock <= reorder;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isLow
                              ? Colors.orange.shade100
                              : const Color(0xFFF1F5F9),
                          child: Icon(
                            Icons.science_outlined,
                            size: 18,
                            color: isLow
                                ? Colors.orange.shade800
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (sku.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'SKU: $sku',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isLow
                                    ? Colors.red.shade50
                                    : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isLow
                                      ? Colors.red.shade200
                                      : const Color(0xFFBBF7D0),
                                ),
                              ),
                              child: Text(
                                '${stock.toStringAsFixed(0)} $uom',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: isLow
                                      ? Colors.red.shade700
                                      : const Color(0xFF166534),
                                ),
                              ),
                            ),
                            if (isLow) ...[
                              const SizedBox(height: 4),
                              Text(
                                'LOW STOCK',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _rmChip(Icons.category_outlined, categoryDisplay, const Color(0xFF6366F1)),
                        _rmChip(Icons.attach_money_rounded, '₹${unitCost.toStringAsFixed(2)}/unit', const Color(0xFF0284C7)),
                        _rmChip(Icons.warning_amber_rounded, 'Reorder ≤ ${reorder.toStringAsFixed(0)} $uom',
                            isLow ? Colors.red : const Color(0xFF94A3B8)),
                        if (createdAt.isNotEmpty)
                          _rmChip(Icons.schedule_rounded, 'Added: ${_fmtDateTime(createdAt)}', const Color(0xFF64748B)),
                        if (updatedAt.isNotEmpty && updatedAt != createdAt)
                          _rmChip(Icons.edit_calendar_rounded, 'Updated: ${_fmtDateTime(updatedAt)}', const Color(0xFF64748B)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  /// Returns allowed UoM options for a given category
  List<String> _uomForCategory(String cat) {
    switch (cat) {
      case 'raw_water':
        return ['litres'];
      case 'chemical':
        return ['kg', 'litres'];
      case 'bottle':
      case 'jar':
      case 'preform':
      case 'cap':
        return ['pcs'];
      case 'label':
        return ['rolls', 'pcs'];
      case 'packaging':
        return ['boxes', 'pcs'];
      default:
        return ['pcs', 'litres', 'rolls', 'boxes', 'kg'];
    }
  }

  String _categoryLabel(String key) {
    const map = {
      'raw_water': 'Raw Water',
      'bottle': 'Bottle / Empty Pet Bottle',
      'jar': 'Jar / Water Jar (20L)',
      'preform': 'Bottle Preform',
      'cap': 'Cap / Closure',
      'label': 'Label / Sticker',
      'packaging': 'Box / Carton / Packaging',
      'chemical': 'Chemical / Minerals',
    };
    return map[key] ?? key;
  }

  String _uomLabel(String key) {
    const map = {
      'pcs': 'Pieces (Pcs)',
      'litres': 'Litres (L)',
      'rolls': 'Rolls',
      'boxes': 'Boxes / Cartons',
      'kg': 'Kilograms (Kg)',
    };
    return map[key] ?? key;
  }

  String _fmtDateTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month]} ${dt.year}, $h:$m';
    } catch (_) {
      return raw;
    }
  }

  Widget _rmChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // =========================================================================
  // TAB 3: DEALER DISPATCHES (MULTI-BATCH ALLOCATION)
  // =========================================================================

  Widget _buildDealerDispatchesTab() {
    final activeRequests = _dealerRequests.where((r) {
      final s = (r['status'] ?? '').toString().toUpperCase();
      return s != 'CANCELLED' && s != 'REJECTED';
    }).toList();

    final displayList = activeRequests.isNotEmpty ? activeRequests : _dealerRequests;

    if (displayList.isEmpty) {
      return const Center(
        child: Text(
          'No dealer stock requests found.\nWhen franchises request stock, requests appear here for batch allocation and dispatch.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    final pendingCount = displayList.where((r) {
      final s = (r['status'] ?? '').toString().toUpperCase();
      return s != 'COMPLETED' && s != 'RECEIVED';
    }).length;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayList.length + 1,
      itemBuilder: (context, idx) {
        if (idx == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pendingCount > 0
                            ? '$pendingCount Requests Pending'
                            : 'All Dealer Requests Fulfilled',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        pendingCount > 0
                            ? 'One-click auto produce & dispatch all'
                            : 'All franchise requests up to date',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (pendingCount > 0)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text('Fulfill All', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    onPressed: _handleFulfillAll,
                  ),
              ],
            ),
          );
        }

        final req = displayList[idx - 1];
        final id = req['id'];
        final reqNum = req['request_number'] ?? 'REQ-$id';
        final dealerName = req['dealer_name'] ?? 'Franchise';
        final rawStatus = (req['status'] ?? 'REQUESTED').toString().toUpperCase();
        final statusDisplay = rawStatus.replaceAll('_', ' ');
        final isDispatched = rawStatus == 'DISPATCHED' || rawStatus == 'RECEIVED';
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
                        color: isDispatched
                            ? const Color(0xFFDCFCE7)
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusDisplay,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: isDispatched
                              ? const Color(0xFF166534)
                              : Colors.orange.shade800,
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0284C7),
                          side: const BorderSide(color: Color(0xFF0284C7)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.analytics_outlined, size: 16),
                        label: const Text(
                          'Live Tracker',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DealerStockRequestFulfillmentScreen(
                                requestId: id is int ? id : int.tryParse('$id') ?? 0,
                                initialRequest: req,
                              ),
                            ),
                          ).then((_) => _loadData());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.local_shipping_rounded, size: 16),
                        label: const Text(
                          'Dispatch',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        onPressed: () => _openDispatchDialog(req),
                      ),
                    ),
                  ],
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

  Future<void> _handleFulfillAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Expanded(
              child: Text('Fulfill All Requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
          ],
        ),
        content: const Text(
          'This will automatically verify stock, manufacture required batches if needed, allocate, dispatch with wholesale invoice, and confirm delivery for all pending requests in one atomic operation.\n\nProceed?',
          style: TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Fulfill All Now'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final res = await _invService.fulfillAllStockRequests();
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'All requests fulfilled successfully!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Fulfill all failed'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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

    String generateBatchNumber(ProductModel? p) {
      final skuPart = p?.sku.isNotEmpty == true ? p!.sku : 'PROD';
      final now = DateTime.now();
      final monthStr = '${now.year}${now.month.toString().padLeft(2, '0')}';
      return 'PB-$monthStr-$skuPart-${now.millisecondsSinceEpoch.toString().substring(8)}';
    }

    final batchNumCtrl = TextEditingController(
      text: generateBatchNumber(selectedProduct),
    );
    final qtyCtrl = TextEditingController(
      text: (prefillQuantity ?? 5000).toString(),
    );
    final clientNameCtrl = TextEditingController(text: prefillClientName ?? '');
    final orderIdCtrl = TextEditingController(
      text: prefillOrderId != null ? prefillOrderId.toString() : '',
    );
    final shelfDaysCtrl = TextEditingController(
      text: (prefillShelfDays ?? selectedProduct?.shelfLifeDays ?? 180)
          .toString(),
    );
    final labelCtrl = TextEditingController(text: prefillLabel ?? '');
    final printCtrl = TextEditingController(text: prefillPrint ?? '');
    final brandingCtrl = TextEditingController(text: prefillBranding ?? '');

    bool isSaving = false;
    bool isLoadingBOM = false;
    bool isBomConfigured = false;
    String? bomErrorMessage;
    Map<String, dynamic>? currentBOM;
    List<Map<String, dynamic>> bomItems = [];

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          // Initialize BOM fetching for selected product if not yet loaded
          void fetchBOM(ProductModel? p) async {
            if (p == null) {
              setDlgState(() {
                currentBOM = null;
                bomItems = [];
                isBomConfigured = false;
                bomErrorMessage = 'No product selected.';
                isLoadingBOM = false;
              });
              return;
            }

            final pId = int.tryParse(p.id) ?? 0;
            if (pId <= 0) {
              setDlgState(() {
                currentBOM = null;
                bomItems = [];
                isBomConfigured = false;
                bomErrorMessage = 'Invalid product ID.';
                isLoadingBOM = false;
              });
              return;
            }

            setDlgState(() {
              isLoadingBOM = true;
              bomErrorMessage = null;
            });

            try {
              final res = await _invService.getProductBOM(pId);
              if (res['success'] == true && res['data'] != null) {
                final decoded = res['data'];
                final bomMap = (decoded is Map && decoded['bom'] is Map)
                    ? decoded['bom'] as Map<String, dynamic>
                    : (decoded is Map && decoded['data'] is Map)
                        ? decoded['data'] as Map<String, dynamic>
                        : (decoded is Map ? decoded as Map<String, dynamic> : <String, dynamic>{});

                final rawItems = bomMap['items'] ?? (decoded is Map ? decoded['items'] : null);
                final List<Map<String, dynamic>> itemsList = [];
                if (rawItems is List) {
                  for (var it in rawItems) {
                    if (it is Map) itemsList.add(Map<String, dynamic>.from(it));
                  }
                }

                final bool configured = itemsList.isNotEmpty;
                setDlgState(() {
                  currentBOM = bomMap;
                  bomItems = itemsList;
                  isBomConfigured = configured;
                  bomErrorMessage = configured
                      ? null
                      : 'BOM is not configured for this product (${p.name} — SKU: ${p.sku}). Please configure the Bill of Materials recipe before manufacturing.';
                  isLoadingBOM = false;
                });
              } else {
                setDlgState(() {
                  currentBOM = null;
                  bomItems = [];
                  isBomConfigured = false;
                  bomErrorMessage = res['message'] ??
                      'BOM is not configured for this product (${p.name} — SKU: ${p.sku}).';
                  isLoadingBOM = false;
                });
              }
            } catch (e) {
              setDlgState(() {
                currentBOM = null;
                bomItems = [];
                isBomConfigured = false;
                bomErrorMessage = 'Failed to load BOM: $e';
                isLoadingBOM = false;
              });
            }
          }

          // Trigger initial BOM fetch on first build
          if (currentBOM == null && !isLoadingBOM && bomErrorMessage == null && selectedProduct != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              fetchBOM(selectedProduct);
            });
          }

          final int days = int.tryParse(shelfDaysCtrl.text.trim()) ?? 180;
          final dynamicExpiry = DateTime.now()
              .add(Duration(days: days))
              .toIso8601String()
              .split('T')
              .first;

          final int enteredQty = int.tryParse(qtyCtrl.text.trim()) ?? 0;

          // Helper to format product display: "500 ML — SHV-500"
          String formatProductTitle(ProductModel p) {
            final skuUpper = p.sku.trim().toUpperCase();
            const canonicalSizes = {
              'SHV-200': '200 ML',
              'SHV-250': '250 ML',
              'SHV-500': '500 ML',
              'SHV-1L': '1 Litre',
              'SHV-20L': '20 Litre Jar',
            };
            if (canonicalSizes.containsKey(skuUpper)) {
              return '${canonicalSizes[skuUpper]} — ${p.sku.trim()}';
            }
            final size = p.size.trim();
            final sku = p.sku.trim();
            if (size.isNotEmpty && sku.isNotEmpty) {
              return '$size — $sku';
            } else if (sku.isNotEmpty) {
              return '${p.name} — $sku';
            }
            return '${p.name} (${p.size})';
          }

          // Calculate shortages
          int totalShortageCount = 0;
          if (isBomConfigured && enteredQty > 0) {
            for (var item in bomItems) {
              final rmSku = item['raw_material_sku']?.toString() ?? '';
              final perUnit = double.tryParse(item['quantity_required_per_unit']?.toString() ?? '0') ?? 0.0;
              final totalReq = perUnit * enteredQty;
              final matchingRM = _rawMaterials.firstWhere(
                (r) => (r['id']?.toString() == item['raw_material']?.toString() ||
                    r['sku']?.toString().toUpperCase() == rmSku.toUpperCase()),
                orElse: () => <String, dynamic>{},
              );
              final currentStock = double.tryParse(matchingRM['current_stock']?.toString() ?? '0') ?? 0.0;
              if (currentStock < totalReq) {
                totalShortageCount++;
              }
            }
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.precision_manufacturing_rounded,
                  color: Color(0xFF0284C7),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Manufacture Product Batch',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
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
                    // Product Master Selection Dropdown
                    DropdownButtonFormField<ProductModel>(
                      initialValue: selectedProduct,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Product to Manufacture *',
                        helperText: 'Source of Truth: Active Product Master SKUs',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _products
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    formatProductTitle(p),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${p.name} | Stock: ${p.stock} units',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      selectedItemBuilder: (context) {
                        return _products.map((p) {
                          return Text(
                            formatProductTitle(p),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF0284C7),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          );
                        }).toList();
                      },
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() {
                            selectedProduct = val;
                            shelfDaysCtrl.text = val.shelfLifeDays.toString();
                            batchNumCtrl.text = generateBatchNumber(val);
                          });
                          fetchBOM(val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Prominent Selected Product Information Card
                    if (selectedProduct != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatProductTitle(selectedProduct!),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        selectedProduct!.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isLoadingBOM
                                        ? const Color(0xFFE2E8F0)
                                        : (isBomConfigured
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFFEE2E2)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isLoadingBOM
                                            ? Icons.hourglass_top_rounded
                                            : (isBomConfigured
                                                ? Icons.check_circle_rounded
                                                : Icons.cancel_rounded),
                                        size: 14,
                                        color: isLoadingBOM
                                            ? const Color(0xFF64748B)
                                            : (isBomConfigured
                                                ? const Color(0xFF166534)
                                                : const Color(0xFF991B1B)),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isLoadingBOM
                                            ? 'Checking BOM...'
                                            : (isBomConfigured ? 'BOM: Configured' : 'BOM: Missing'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isLoadingBOM
                                              ? const Color(0xFF475569)
                                              : (isBomConfigured
                                                  ? const Color(0xFF166534)
                                                  : const Color(0xFF991B1B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Current Finished Stock: ${selectedProduct!.stock} units',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Shelf-Life: ${selectedProduct!.shelfLifeDays} Days',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    // BOM Warning / Error Banner
                    if (isLoadingBOM) ...[
                      const LinearProgressIndicator(color: Color(0xFF0284C7)),
                      const SizedBox(height: 12),
                    ] else if (!isBomConfigured) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF87171)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'BOM is not configured for this product.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF991B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    bomErrorMessage ??
                                        'Please configure the Bill of Materials (BOM) in Product Master before manufacturing this SKU.',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Production Quantity & Batch Details
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity to Produce (Units) *',
                        hintText: 'e.g. 5000',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calculate_outlined),
                          onPressed: () => setDlgState(() {}),
                        ),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Live BOM Raw Material Consumption & Shortage Table
                    if (isBomConfigured && bomItems.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: totalShortageCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.view_in_ar_rounded,
                                  size: 16,
                                  color: totalShortageCount > 0 ? const Color(0xFFD97706) : const Color(0xFF0284C7),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Raw Material Requirement (for $enteredQty units):',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                if (totalShortageCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$totalShortageCount Shortage',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...bomItems.map((item) {
                              final rmName = item['raw_material_name']?.toString() ?? 'Raw Material';
                              final rmSku = item['raw_material_sku']?.toString() ?? '';
                              final unit = item['raw_material_unit']?.toString() ?? '';
                              final perUnit = double.tryParse(item['quantity_required_per_unit']?.toString() ?? '0') ?? 0.0;
                              final totalReq = perUnit * enteredQty;

                              final matchingRM = _rawMaterials.firstWhere(
                                (r) => (r['id']?.toString() == item['raw_material']?.toString() ||
                                    r['sku']?.toString().toUpperCase() == rmSku.toUpperCase()),
                                orElse: () => <String, dynamic>{},
                              );
                              final currentStock = double.tryParse(matchingRM['current_stock']?.toString() ?? '0') ?? 0.0;
                              final bool hasShortage = enteredQty > 0 && currentStock < totalReq;
                              final shortageQty = hasShortage ? (totalReq - currentStock) : 0.0;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$rmName ($rmSku)',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            'Required: ${totalReq.toStringAsFixed(totalReq.truncateToDouble() == totalReq ? 0 : 2)} $unit (${perUnit.toStringAsFixed(3)} / unit)',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Stock: ${currentStock.toStringAsFixed(currentStock.truncateToDouble() == currentStock ? 0 : 1)} $unit',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: hasShortage ? Colors.red : const Color(0xFF166534),
                                          ),
                                        ),
                                        if (hasShortage)
                                          Text(
                                            'Short: -${shortageQty.toStringAsFixed(shortageQty.truncateToDouble() == shortageQty ? 0 : 2)}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.red,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      controller: batchNumCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Batch Number *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: shelfDaysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Configurable Shelf-Life (Days) *',
                        helperText: 'Dynamic Expiry: $dynamicExpiry (Mfg + $days Days)',
                        border: const OutlineInputBorder(),
                        helperStyle: const TextStyle(
                          color: Color(0xFF0284C7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: clientNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Customer / Client Name (Bulk Order)',
                        hintText: 'e.g. Digital Marketing Wala',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: orderIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Linked Order Code / ID (Optional)',
                        hintText: 'e.g. ORD-1001 or 1001',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Label / Sticker Requirement',
                        hintText: 'e.g. Custom 250ml Waterproof Glossy Sticker',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: printCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Printing / Branding Requirement',
                        hintText: 'e.g. Front Brand Logo & Back Compliance Info',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: brandingCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Packaging & Special Instructions',
                        hintText: 'e.g. Shrink-wrap cartons of 24 units, inspect caps',
                        border: OutlineInputBorder(),
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
                  backgroundColor: !isBomConfigured ? Colors.grey : const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onPressed: (isSaving || isLoadingBOM)
                    ? null
                    : () async {
                        if (selectedProduct == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a product variant.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (!isBomConfigured) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'BOM is not configured for ${selectedProduct!.name} (${selectedProduct!.sku}). Please configure BOM first.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Quantity must be greater than zero.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDlgState(() => isSaving = true);
                        final res = await _invService.createProductionBatch({
                          'product_id': int.tryParse(selectedProduct!.id) ?? selectedProduct!.id,
                          'sku': selectedProduct!.sku,
                          'batch_number': batchNumCtrl.text.trim(),
                          'quantity_produced_units': qty,
                          'shelf_life_days': days,
                          'expiry_date': dynamicExpiry,
                          'client_name': clientNameCtrl.text.trim(),
                          'linked_order': orderIdCtrl.text.trim().isNotEmpty
                              ? orderIdCtrl.text.trim()
                              : prefillOrderId,
                          'label_requirement': labelCtrl.text.trim(),
                          'printing_requirement': printCtrl.text.trim(),
                          'branding_requirement': brandingCtrl.text.trim(),
                        });
                        setDlgState(() => isSaving = false);

                        if (res['success'] == true) {
                          if (mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Production batch created! Stock added for ${selectedProduct!.name} (${selectedProduct!.sku}) & raw materials consumed.',
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
                    : Text(
                        !isBomConfigured ? 'BOM Not Configured' : 'Manufacture Batch',
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
    final clientName = (batch['client_name'] ?? '').toString().trim();
    final orderNumber = (batch['order_number'] ?? batch['linked_order_code'] ?? '').toString().trim();
    final orderName = (batch['order_name'] ?? clientName).toString().trim();
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

    final unitPrice =
        double.tryParse(batch['product_mrp']?.toString() ??
                batch['unit_price']?.toString() ??
                '20.0') ??
            20.0;

    final initialQty = remaining > 0 ? remaining : 0;
    final qtyCtrl = TextEditingController(text: initialQty.toString());
    final collectorCtrl = TextEditingController(text: clientName);
    final notesCtrl = TextEditingController();
    final refCtrl = TextEditingController();

    String deliveryStatus = (remaining <= initialQty) ? 'delivered' : 'dispatch';
    String paymentStatus = 'FULL'; // FULL, PARTIAL, UNPAID
    String paymentMethod = 'CASH'; // CASH, ONLINE

    final initialDue = initialQty * unitPrice;
    final amountDueCtrl = TextEditingController(text: initialDue.toStringAsFixed(2));
    final amountPaidCtrl = TextEditingController(text: initialDue.toStringAsFixed(2));
    double remainingDue = 0.0;

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          void updateAmounts() {
            final q = int.tryParse(qtyCtrl.text.trim()) ?? 0;
            final due = q * unitPrice;
            amountDueCtrl.text = due.toStringAsFixed(2);
            if (paymentStatus == 'FULL') {
              amountPaidCtrl.text = due.toStringAsFixed(2);
              remainingDue = 0.0;
            } else if (paymentStatus == 'UNPAID') {
              amountPaidCtrl.text = '0.00';
              remainingDue = due;
            } else {
              final paid = double.tryParse(amountPaidCtrl.text.trim()) ?? 0.0;
              remainingDue = (due - paid).clamp(0.0, double.infinity);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.local_shipping_rounded, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Record Customer Collection',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 480,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
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
                          if (orderNumber.isNotEmpty || orderName.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: Row(
                                children: [
                                  if (orderNumber.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'ORDER #$orderNumber',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      orderName.isNotEmpty ? orderName : clientName,
                                      softWrap: true,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: Color(0xFF5B21B6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (clientName.isNotEmpty && (orderName.isEmpty || clientName != orderName))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Client: $clientName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          const Divider(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              Text('Produced: $produced', style: const TextStyle(fontSize: 12)),
                              Text('Taken: $taken', style: const TextStyle(fontSize: 12)),
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
                        helperText: 'Max available in company stock: $remaining units',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDlgState(updateAmounts),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: collectorCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Collected By / Client Representative',
                        hintText: 'e.g. Digital Marketing Wala Rep',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dispatch / Pickup Notes',
                        hintText: 'e.g. Vehicle MH-12-AB-1234',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Delivery & Fulfillment Status Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: deliveryStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Fulfillment & Delivery Status *',
                        helperText: 'Updates customer order & plant stock status',
                        isDense: true,
                        border: OutlineInputBorder(),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'delivered',
                          child: Text(
                            'DELIVERED (Complete Handover to Customer)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'dispatch',
                          child: Text(
                            'DISPATCH / IN TRANSIT (Dispatched from Plant)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'preparing',
                          child: Text(
                            'PREPARING / PARTIAL (Partially Prepared/Dispatched)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ready_for_pickup',
                          child: Text(
                            'READY FOR PICKUP (Waiting at Plant/Warehouse)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDlgState(() => deliveryStatus = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    // Payment Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.payments_outlined, size: 18, color: Color(0xFF0F172A)),
                              SizedBox(width: 6),
                              Text(
                                'Collection Payment Details',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Payment Status Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: paymentStatus,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Payment Status',
                              isDense: true,
                              border: OutlineInputBorder(),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'FULL',
                                child: Text(
                                  'FULL PAYMENT (Paid in Full)',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'PARTIAL',
                                child: Text(
                                  'PARTIAL PAYMENT (Balance Remaining)',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'UNPAID',
                                child: Text(
                                  'UNPAID (Full Amount Outstanding)',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setDlgState(() {
                                paymentStatus = v;
                                updateAmounts();
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          // Payment Method Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: paymentMethod,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Payment Method',
                              isDense: true,
                              border: OutlineInputBorder(),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'CASH',
                                child: Text('CASH', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'ONLINE',
                                child: Text('UPI / ONLINE', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'BANK_TRANSFER',
                                child: Text(
                                  'BANK TRANSFER (NEFT/RTGS)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'CHEQUE',
                                child: Text('CHEQUE', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'OTHER',
                                child: Text('OTHER', overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setDlgState(() => paymentMethod = v);
                            },
                          ),
                          if (paymentMethod != 'CASH') ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: refCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Transaction Ref / UTR / Reference ID *',
                                hintText: 'e.g. UPI-9876543210',
                                isDense: true,
                                border: OutlineInputBorder(),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          // Amount Due & Amount Paid
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: amountDueCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Total Due (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    fillColor: Colors.white,
                                    filled: true,
                                  ),
                                  onChanged: (_) {
                                    setDlgState(() {
                                      final due = double.tryParse(amountDueCtrl.text.trim()) ?? 0.0;
                                      if (paymentStatus == 'FULL') {
                                        amountPaidCtrl.text = due.toStringAsFixed(2);
                                        remainingDue = 0.0;
                                      } else if (paymentStatus == 'UNPAID') {
                                        remainingDue = due;
                                      } else {
                                        final paid = double.tryParse(amountPaidCtrl.text.trim()) ?? 0.0;
                                        remainingDue = (due - paid).clamp(0.0, double.infinity);
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: amountPaidCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  enabled: paymentStatus == 'PARTIAL',
                                  decoration: InputDecoration(
                                    labelText: 'Amount Paid (₹)',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                    fillColor: paymentStatus == 'PARTIAL' ? Colors.white : const Color(0xFFF1F5F9),
                                    filled: true,
                                  ),
                                  onChanged: (_) {
                                    setDlgState(() {
                                      final due = double.tryParse(amountDueCtrl.text.trim()) ?? 0.0;
                                      final paid = double.tryParse(amountPaidCtrl.text.trim()) ?? 0.0;
                                      remainingDue = (due - paid).clamp(0.0, double.infinity);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Remaining Amount Display
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: remainingDue > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: remainingDue > 0 ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Remaining Outstanding:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '₹ ${remainingDue.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: remainingDue > 0 ? Colors.red.shade700 : const Color(0xFF047857),
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
            actions: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(dlgCtx),
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
                                  content: Text('Quantity collected must be greater than zero.'),
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

                            final due = double.tryParse(amountDueCtrl.text.trim()) ?? 0.0;
                            final paid = double.tryParse(amountPaidCtrl.text.trim()) ?? 0.0;

                            if (paid > due) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Amount paid cannot exceed total amount due.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (paymentStatus == 'PARTIAL' && (paid <= 0 || paid >= due)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('For partial payment, amount paid must be greater than 0 and less than due amount.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (paymentMethod == 'ONLINE' && refCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter reference / transaction ID for online payment.'),
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
                              paymentStatus: paymentStatus,
                              paymentMethod: paymentMethod,
                              referenceNumber: refCtrl.text.trim(),
                              amountDue: due,
                              amountPaid: paid,
                              deliveryStatus: deliveryStatus,
                            );
                            setDlgState(() => isSaving = false);

                            if (res['success'] == true) {
                              if (mounted) {
                                Navigator.pop(dlgCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      res['message'] ??
                                          'Collection & Payment logged! Pending stock and ledger updated.',
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
                            'Confirm Collection & Payment',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _openUpdateOrderStatusDialog({
    required int orderId,
    required String currentStatus,
    required String orderCode,
    required String clientName,
  }) {
    final cleanCurrent = currentStatus.toLowerCase().trim();
    final allStatusLabels = {
      'order_placement': 'Order Placement (New Order)',
      'plant_approval': 'Plant Approval / Admin Approved',
      'invoice_generated': 'Invoice Generated',
      'preparing': 'Preparing / Bottling',
      'dispatch': 'Dispatch / In Transit',
      'delivered': 'Delivered (Complete Handover)',
      'cancelled': 'Cancelled',
    };

    final allowedTransitionsMap = {
      'order_placement': ['plant_approval', 'cancelled'],
      'plant_approval': ['invoice_generated', 'preparing', 'cancelled'],
      'invoice_generated': ['preparing', 'dispatch', 'cancelled'],
      'preparing': ['invoice_generated', 'dispatch', 'cancelled'],
      'dispatch': ['delivered', 'cancelled'],
      'delivered': <String>[],
      'cancelled': <String>[],
    };

    final allowedTargets = allowedTransitionsMap[cleanCurrent] ?? <String>[];
    // Candidate statuses include current status plus allowed next transitions
    final candidateVals = <String>{cleanCurrent, ...allowedTargets}.toList();
    final validStatuses = candidateVals.map((val) {
      return {'val': val, 'label': allStatusLabels[val] ?? val};
    }).toList();

    String selectedStatus = cleanCurrent;
    bool isUpdating = false;
    String? dialogErrorMessage;

    showDialog(
      context: context,
      barrierDismissible: !isUpdating,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.sync_alt_rounded, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Update Order Status ($orderCode)',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (clientName.isNotEmpty) ...[
                    Text(
                      'Order Name: $clientName',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      const Text('Current Status: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cleanCurrent.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: validStatuses.any((s) => s['val'] == selectedStatus)
                        ? selectedStatus
                        : validStatuses.first['val'],
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Next Target Status *',
                      border: OutlineInputBorder(),
                    ),
                    items: validStatuses.map((s) {
                      return DropdownMenuItem(
                        value: s['val']!,
                        child: Text(s['label']!, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: isUpdating
                        ? null
                        : (v) {
                            if (v != null) {
                              setDlgState(() {
                                selectedStatus = v;
                                dialogErrorMessage = null;
                              });
                            }
                          },
                  ),
                  if (dialogErrorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dialogErrorMessage!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w600, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUpdating ? null : () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                ),
                onPressed: (isUpdating || selectedStatus == cleanCurrent)
                    ? null
                    : () async {
                        if (selectedStatus.toLowerCase() == 'cancelled') {
                          final confirmed = await CancelOrderDialog.show(
                            context,
                            orderCode: orderCode.isNotEmpty ? orderCode : 'ORD-$orderId',
                          );
                          if (confirmed != true) {
                            return;
                          }
                        }

                        setDlgState(() {
                          isUpdating = true;
                          dialogErrorMessage = null;
                        });
                        final res = await OrderRepository().updateOrderStatus(orderId, selectedStatus);
                        if (res['success'] == true) {
                          if (mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Order status updated to ${selectedStatus.toUpperCase()}!'),
                                backgroundColor: const Color(0xFF16A34A),
                              ),
                            );
                            _loadData();
                          }
                        } else {
                          setDlgState(() {
                            isUpdating = false;
                            dialogErrorMessage = res['message']?.toString() ?? 'Failed to update order status. Please verify transition rules.';
                          });
                        }
                      },
                child: isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Update Status'),
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
    String category = 'bottle';
    String uom = 'pcs'; // 'pcs' is valid for 'bottle'
    bool isSaving = false;
    final rootCtx = context; // capture root ctx before dialog opens

    String bottleSize = '500ml';
    String jarSize = '20L';

    // Helper to sync default name & code based on category and size
    void applyDefaults(String cat, String bSize, String jSize) {
      if (cat == 'bottle') {
        switch (bSize) {
          case '200ml':
            nameCtrl.text = '200ml Pet Bottle';
            codeCtrl.text = 'RM-BOT-200ML';
            break;
          case '250ml':
            nameCtrl.text = '250ml Pet Bottle';
            codeCtrl.text = 'RM-BOT-250ML';
            break;
          case '500ml':
            nameCtrl.text = '500ml Pet Bottle';
            codeCtrl.text = 'RM-BOT-500ML';
            break;
          case '1L':
            nameCtrl.text = '1 Litre Pet Bottle';
            codeCtrl.text = 'RM-BOT-1000ML';
            break;
          case '20L':
            nameCtrl.text = '20 Litre Water Jar / Can';
            codeCtrl.text = 'RM-JAR-20L';
            break;
        }
      } else if (cat == 'jar') {
        nameCtrl.text = '20 Litre Water Jar';
        codeCtrl.text = 'RM-JAR-20L';
      } else if (cat == 'cap') {
        nameCtrl.text = '28mm Bottle Cap';
        codeCtrl.text = 'RM-CAP-28MM';
      } else if (cat == 'preform') {
        nameCtrl.text = 'Pet Preform';
        codeCtrl.text = 'RM-PRF-20G';
      } else if (cat == 'label') {
        nameCtrl.text = 'Product Brand Label';
        codeCtrl.text = 'RM-LBL-ROLL';
      } else if (cat == 'packaging') {
        nameCtrl.text = 'Corrugated Packaging Box';
        codeCtrl.text = 'RM-BOX-STD';
      } else if (cat == 'chemical') {
        nameCtrl.text = 'Water Treatment Minerals';
        codeCtrl.text = 'RM-CHM-MIN';
      } else if (cat == 'raw_water') {
        nameCtrl.text = 'Raw Water Feed';
        codeCtrl.text = 'RM-WAT-RAW';
      }
    }

    applyDefaults(category, bottleSize, jarSize);

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
                  // Category dropdown
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Material Category *'),
                    items: const [
                      DropdownMenuItem(value: 'bottle', child: Text('Bottles (Pet Bottles)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'jar', child: Text('Jar (Water Jar)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'preform', child: Text('Bottle Preform', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'cap', child: Text('Cap / Closure', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'label', child: Text('Label / Sticker', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'packaging', child: Text('Box / Carton / Packaging', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'chemical', child: Text('Chemical / Minerals', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'raw_water', child: Text('Raw Water', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      final allowed = _uomForCategory(val);
                      setDlgState(() {
                        category = val;
                        if (!allowed.contains(uom)) uom = allowed.first;
                        applyDefaults(category, bottleSize, jarSize);
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Dedicated Bottle Size dropdown when Category is 'bottle'
                  if (category == 'bottle') ...[
                    DropdownButtonFormField<String>(
                      initialValue: bottleSize,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Bottle Size / Variant *',
                        prefixIcon: Icon(Icons.water_drop_outlined, size: 20, color: Color(0xFF0284C7)),
                      ),
                      items: const [
                        DropdownMenuItem(value: '200ml', child: Text('200 ML Bottle')),
                        DropdownMenuItem(value: '250ml', child: Text('250 ML Bottle')),
                        DropdownMenuItem(value: '500ml', child: Text('500 ML Bottle')),
                        DropdownMenuItem(value: '1L', child: Text('1 Litre Bottle')),
                        DropdownMenuItem(value: '20L', child: Text('20 Litre Jar (20000 ML)')),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setDlgState(() {
                          bottleSize = val;
                          applyDefaults(category, bottleSize, jarSize);
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Dedicated Jar Size dropdown when Category is 'jar'
                  if (category == 'jar') ...[
                    DropdownButtonFormField<String>(
                      initialValue: jarSize,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Jar Size / Variant *',
                        prefixIcon: Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFF0284C7)),
                      ),
                      items: const [
                        DropdownMenuItem(value: '20L', child: Text('20 Litre Jar (20000 ML)')),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setDlgState(() {
                          jarSize = val;
                          applyDefaults(category, bottleSize, jarSize);
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                  ],

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
                      labelText: 'Material Code (e.g. RM-BOT-500ML) *',
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Unit of Measure — smart filtered by category
                  Builder(
                    builder: (ctx) {
                      final allowed = _uomForCategory(category);
                      return DropdownButtonFormField<String>(
                        initialValue: allowed.contains(uom) ? uom : allowed.first,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Unit of Measure'),
                        items: allowed.map((k) => DropdownMenuItem(
                          value: k,
                          child: Text(_uomLabel(k), overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) => setDlgState(() => uom = val ?? uom),
                      );
                    },
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
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(rootCtx).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a Material Name.'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        var sku = codeCtrl.text.trim();
                        if (sku.isEmpty) {
                          final prefix = category.toUpperCase().replaceAll('_', '');
                          final pfx = prefix.length > 4 ? prefix.substring(0, 4) : prefix;
                          sku = 'RM-$pfx-${DateTime.now().millisecondsSinceEpoch % 100000}';
                        }

                        setDlgState(() => isSaving = true);
                        final res = await _invService.createRawMaterial({
                          'name': name,
                          'sku': sku,
                          'category': category,
                          'unit_of_measure': uom,
                          'unit_cost':
                              double.tryParse(costCtrl.text.trim().replaceAll(',', '')) ?? 0.0,
                          'current_stock':
                              double.tryParse(stockCtrl.text.trim().replaceAll(',', '')) ?? 0.0,
                          'reorder_level':
                              double.tryParse(reorderCtrl.text.trim().replaceAll(',', '')) ?? 0.0,
                        });
                        setDlgState(() => isSaving = false);
                        if (res['success'] == true) {
                          Navigator.pop(dlgCtx);
                          if (rootCtx.mounted) {
                            final newMat = res['data'];
                            final matName = (newMat is Map ? newMat['name'] : null)
                                ?? nameCtrl.text.trim();
                            ScaffoldMessenger.of(rootCtx).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '✅ "$matName" added to Raw Materials!',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                duration: const Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                            _loadData();
                          }
                        } else {
                          if (rootCtx.mounted) {
                            ScaffoldMessenger.of(rootCtx).showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Failed to add material.'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
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
