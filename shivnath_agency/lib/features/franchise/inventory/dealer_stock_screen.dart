import 'package:flutter/material.dart';

import '../../../core/services/InventoryService.dart';
import '../../../core/services/product_service.dart';
import '../../../models/product_model.dart';

/// Authoritative Wholesale Dealer Stock Screen
/// Displays 5 official variants (SHV-200, SHV-250, SHV-500, SHV-1L, SHV-20L),
/// dual units (cases & bottles), FEFO batch inventory with expiry countdowns,
/// and facilitates stock requests & receipt confirmation with damage tracking.
class DealerStockScreen extends StatefulWidget {
  const DealerStockScreen({super.key});

  @override
  State<DealerStockScreen> createState() => _DealerStockScreenState();
}

class _DealerStockScreenState extends State<DealerStockScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final InventoryService _invService = InventoryService();

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _dealerBatches = [];
  List<Map<String, dynamic>> _stockRequests = [];
  List<ProductModel> _products = [];

  // 5 Official Variant SKUs
  static const List<String> officialSkus = [
    'SHV-200',
    'SHV-250',
    'SHV-500',
    'SHV-1L',
    'SHV-20L',
  ];

  static const Map<String, int> unitsPerCaseMap = {
    'SHV-200': 48,
    'SHV-250': 36,
    'SHV-500': 24,
    'SHV-1L': 12,
    'SHV-20L': 1,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Fetch batches
      final batchRes = await _invService.getDealerBatches();
      if (batchRes['success'] == true && batchRes['data'] is List) {
        _dealerBatches = List<Map<String, dynamic>>.from(batchRes['data']);
      }

      // 2. Fetch stock requests
      final reqRes = await _invService.getDealerStockRequests();
      if (reqRes['success'] == true && reqRes['data'] is List) {
        _stockRequests = List<Map<String, dynamic>>.from(reqRes['data']);
      }

      // 3. Fetch products
      await ProductService().getProducts();
      _products = ProductService.products;
    } catch (e) {
      _error = 'Failed to load stock data: $e';
    }

    if (mounted) setState(() => _loading = false);
  }

  int _getUnitsPerCase(String sku) {
    return unitsPerCaseMap[sku.toUpperCase()] ?? 24;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Franchise Inventory',
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
            onPressed: _loadAll,
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
            Tab(text: 'Current Stock (5 Variants)'),
            Tab(text: 'Stock Requests'),
            Tab(text: 'Dispatches & Receipts'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: const Text(
          'Request Central Stock',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        onPressed: _openNewStockRequestDialog,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
            )
          : _error != null
          ? _buildErrorWidget()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVariantsStockTab(),
                _buildStockRequestsTab(),
                _buildReceiptsTab(),
              ],
            ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'An error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1: 5 OFFICIAL VARIANTS & FEFO BATCHES
  // =========================================================================

  Widget _buildVariantsStockTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Colors.white, size: 36),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Official Shivnath Water Variants',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Stock managed by strict FEFO (First-Expired, First-Out). Cases and units auto-tracked.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5 Official Variants Cards
        ...officialSkus.map((sku) {
          final batchesForSku = _dealerBatches.where((b) {
            final bSku = (b['product_sku'] ?? b['sku'] ?? '')
                .toString()
                .toUpperCase();
            return bSku == sku;
          }).toList();

          int totalUnits = 0;
          for (final b in batchesForSku) {
            totalUnits +=
                int.tryParse(b['remaining_quantity']?.toString() ?? '0') ?? 0;
          }

          final unitsPerCase = _getUnitsPerCase(sku);
          final cases = totalUnits ~/ unitsPerCase;
          final looseUnits = totalUnits % unitsPerCase;

          return _buildVariantCard(
            sku,
            totalUnits,
            cases,
            looseUnits,
            unitsPerCase,
            batchesForSku,
          );
        }),

        const SizedBox(height: 70), // space for FAB
      ],
    );
  }

  Widget _buildVariantCard(
    String sku,
    int totalUnits,
    int cases,
    int looseUnits,
    int unitsPerCase,
    List<Map<String, dynamic>> batches,
  ) {
    String variantName = 'Shivnath Drinking Water $sku';
    if (sku == 'SHV-200') variantName = '200ml Sealed Cup / Bottle';
    if (sku == 'SHV-250') variantName = '250ml Sealed Bottle';
    if (sku == 'SHV-500') variantName = '500ml Bottled Water';
    if (sku == 'SHV-1L') variantName = '1 Litre Premium Water';
    if (sku == 'SHV-20L') variantName = '20 Litre Dispenser Jar';

    final isLowStock = totalUnits < (unitsPerCase * 3);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.water_drop_rounded,
            color: Color(0xFF0284C7),
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Text(
              sku,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(width: 8),
            if (isLowStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Text(
                  'LOW STOCK',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              variantName,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '$cases Cases + $looseUnits Units',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                    fontSize: 13,
                  ),
                ),
                Text(
                  ' (Total: $totalUnits units)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          if (batches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No active batches in stock. Tap "+ Request Central Stock" to reorder from central plant.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active FEFO Batches',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...batches.map((b) => _buildBatchRow(b)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBatchRow(Map<String, dynamic> b) {
    final batchNum = b['batch_number']?.toString() ?? 'BATCH';
    final remaining = b['remaining_quantity']?.toString() ?? '0';
    final expiryDateStr = b['expiry_date']?.toString() ?? '';

    String expiryText = 'Expiry: $expiryDateStr';
    Color expiryColor = const Color(0xFF059669);

    if (expiryDateStr.isNotEmpty) {
      try {
        final exp = DateTime.parse(expiryDateStr);
        final diff = exp.difference(DateTime.now()).inDays;
        if (diff <= 0) {
          expiryText = 'EXPIRED (Quarantined)';
          expiryColor = const Color(0xFFDC2626);
        } else if (diff <= 3) {
          expiryText = 'Exp: $expiryDateStr ($diff days - Critical)';
          expiryColor = const Color(0xFFEF4444);
        } else if (diff <= 7) {
          expiryText = 'Exp: $expiryDateStr ($diff days left)';
          expiryColor = const Color(0xFFEA580C);
        } else if (diff <= 15) {
          expiryText = 'Exp: $expiryDateStr ($diff days left)';
          expiryColor = const Color(0xFFD97706);
        } else {
          expiryText = 'Exp: $expiryDateStr ($diff days left)';
          expiryColor = const Color(0xFF059669);
        }
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                size: 16,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                batchNum,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '$remaining units',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: expiryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  expiryText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: expiryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: STOCK REQUESTS TO CENTRAL PLANT
  // =========================================================================

  Widget _buildStockRequestsTab() {
    if (_stockRequests.isEmpty) {
      return const Center(
        child: Text(
          'No stock requests yet.\nUse "+ Request Central Stock" to create an order to the plant.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _stockRequests.length,
      itemBuilder: (context, idx) {
        final req = _stockRequests[idx];
        final id = req['id'];
        final reqNum = req['request_number'] ?? 'REQ-$id';
        final status = (req['status'] ?? 'PENDING').toString().toUpperCase();
        final items = (req['items'] as List?) ?? [];
        final notes = req['notes']?.toString() ?? '';
        final createdAt = req['created_at']?.toString() ?? '';

        Color statusColor = Colors.orange;
        if (status == 'DISPATCHED' || status == 'PARTIALLY_DISPATCHED')
          statusColor = Colors.blue;
        if (status == 'RECEIVED') statusColor = Colors.green;
        if (status == 'CANCELLED') statusColor = Colors.grey;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
                        fontSize: 15,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Requested: ${_formatDate(createdAt)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Items Requested:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 4),
                ...items.map((it) {
                  final sku = it['product_sku'] ?? it['sku'] ?? 'SKU';
                  final qtyCases = it['quantity_cases'] ?? 0;
                  final qtyUnits = it['quantity_units'] ?? 0;
                  final fulfilledCases = it['fulfilled_cases'] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$sku: $qtyCases Cases ($qtyUnits units)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Dispatched: $fulfilledCases Cases',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Note: $notes',
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 3: DISPATCHES & RECEIPTS (DAMAGE LOGGING)
  // =========================================================================

  Widget _buildReceiptsTab() {
    // Show requests that are DISPATCHED or PARTIALLY_DISPATCHED
    final pendingReceipts = _stockRequests.where((r) {
      final s = (r['status'] ?? '').toString().toUpperCase();
      return s == 'DISPATCHED' || s == 'PARTIALLY_DISPATCHED';
    }).toList();

    if (pendingReceipts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.local_shipping_outlined,
                size: 54,
                color: Color(0xFF94A3B8),
              ),
              SizedBox(height: 12),
              Text(
                'No pending dispatches in transit.\nWhen Central Plant dispatches stock to your location, it will appear here for verification and receipt.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingReceipts.length,
      itemBuilder: (context, idx) {
        final req = pendingReceipts[idx];
        final id = req['id'];
        final reqNum = req['request_number'] ?? 'REQ-$id';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
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
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'IN TRANSIT',
                        style: TextStyle(
                          color: Color(0xFF0284C7),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'A dispatch has been sent from Central Plant. Please inspect goods upon arrival and confirm receipt.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text(
                      'Confirm Receipt & Log Damages',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _openConfirmReceiptDialog(req),
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
  // ACTIONS: NEW STOCK REQUEST & CONFIRM RECEIPT
  // =========================================================================

  void _openNewStockRequestDialog() {
    final quantities = <String, TextEditingController>{};
    for (final sku in officialSkus) {
      quantities[sku] = TextEditingController(text: '0');
    }
    final noteCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text(
                  'Request Central Plant Stock',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: const Text(
                      '✓ Request ANY one or more products (e.g. only SHV-500).\n'
                      '✓ Entering all products is NOT required. Leave unused items as 0 or blank.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...officialSkus.map((sku) {
                    final upc = _getUnitsPerCase(sku);
                    // Find current franchise stock for display only.
                    final batchesForSku = _dealerBatches.where((b) {
                      final bSku = (b['product_sku'] ?? b['sku'] ?? '')
                          .toString()
                          .toUpperCase();
                      return bSku == sku;
                    }).toList();
                    int currentUnits = 0;
                    for (final b in batchesForSku) {
                      currentUnits +=
                          int.tryParse(
                            b['remaining_quantity']?.toString() ?? '0',
                          ) ??
                          0;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$sku  ($upc units/case) — Current stock: $currentUnits units',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: quantities[sku],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Requested Units',
                              hintText: '0 (Leave empty if not needed)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Order Notes / Delivery remarks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
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
                        final items = <Map<String, dynamic>>[];
                        for (final sku in officialSkus) {
                          final requestedUnits =
                              int.tryParse(
                                quantities[sku]?.text.trim() ?? '0',
                              ) ??
                              0;
                          if (requestedUnits <= 0) continue;

                          // Match product by SKU field (exact, case-insensitive) or known aliases
                          final activeProds = _products.where((p) => p.status.toUpperCase() == 'ACTIVE').toList();
                          ProductModel? matched;
                          for (final prod in activeProds) {
                            final pSku = prod.sku.toUpperCase();
                            if (pSku == sku.toUpperCase() ||
                                (sku == 'SHV-200' &&
                                    (pSku == 'SKU-BOT-200' || (pSku.contains('200') && !pSku.contains('2000')))) ||
                                (sku == 'SHV-250' &&
                                    (pSku == 'SKU-BOT-250' || pSku.contains('250'))) ||
                                (sku == 'SHV-500' &&
                                    (pSku == 'SKU-BOT-500' || pSku.contains('500'))) ||
                                (sku == 'SHV-1L' &&
                                    (pSku == 'SKU-BOT-1000' || pSku.contains('1000') || pSku.contains('1L'))) ||
                                (sku == 'SHV-20L' &&
                                    (pSku == 'SKU-JAR-20L' || pSku.contains('20L') || pSku.contains('20000')))) {
                              matched = prod;
                              break;
                            }
                          }
                          // Fallback: match by name containing sku
                          if (matched == null) {
                            for (final prod in activeProds) {
                              if (prod.name.toUpperCase().contains(
                                sku.toUpperCase(),
                              )) {
                                matched = prod;
                                break;
                              }
                            }
                          }

                          items.add({
                            'product_id': matched?.id,
                            'product': matched?.id,
                            'sku': sku,
                            'product_sku': sku,
                            'quantity': requestedUnits,
                            'requested_quantity': requestedUnits,
                            'quantity_units': requestedUnits,
                            'quantity_cases':
                                requestedUnits ~/ _getUnitsPerCase(sku),
                          });
                        }

                        if (items.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a quantity > 0 for at least one product.',
                              ),
                            ),
                          );
                          return;
                        }

                        setDlgState(() => isSubmitting = true);
                        final res = await _invService.createDealerStockRequest({
                          'items': items,
                          'notes': noteCtrl.text.trim(),
                        });
                        setDlgState(() => isSubmitting = false);

                        if (res['success'] == true) {
                          if (mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Stock request submitted successfully to Central Plant!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadAll();
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res['message'] ?? 'Failed to submit request',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Submit Request'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openConfirmReceiptDialog(Map<String, dynamic> req) {
    final damageControllers = <String, TextEditingController>{};
    final items = (req['items'] as List?) ?? [];

    for (int i = 0; i < items.length; i++) {
      damageControllers[i.toString()] = TextEditingController(text: '0');
    }

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.inventory_rounded, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text(
                  'Confirm Goods Receipt',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Inspect delivered goods and enter any damaged units for insurance/credit logging:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final it = entry.value;
                    final sku = it['product_sku'] ?? it['sku'] ?? 'SKU';
                    final cases =
                        it['fulfilled_cases'] ?? it['quantity_cases'] ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              '$sku ($cases cases delivered)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: damageControllers[idx.toString()],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Damaged Units',
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
                onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final receivedItems = <Map<String, dynamic>>[];
                        for (int i = 0; i < items.length; i++) {
                          final it = items[i];
                          final damaged =
                              int.tryParse(
                                damageControllers[i.toString()]?.text ?? '0',
                              ) ??
                              0;
                          receivedItems.add({
                            'item_id': it['id'],
                            'damaged_units': damaged,
                          });
                        }

                        setDlgState(() => isSubmitting = true);
                        final res = await _invService.receiveDealerStockRequest(
                          req['id'],
                          {'items': receivedItems},
                        );
                        setDlgState(() => isSubmitting = false);

                        if (res['success'] == true) {
                          if (mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Stock received and FEFO batch inventory updated!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadAll();
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res['message'] ?? 'Failed to confirm receipt',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Confirm & Accept'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
