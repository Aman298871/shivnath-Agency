import 'package:flutter/material.dart';

import '../../../core/repositories/inventory_repository.dart';
import '../../../core/repositories/product_repository.dart';
import '../../../models/product_model.dart';

class FranchiseInventoryScreen extends StatefulWidget {
  final int initialTabIndex;
  const FranchiseInventoryScreen({super.key, this.initialTabIndex = 0});

  @override
  State<FranchiseInventoryScreen> createState() =>
      _FranchiseInventoryScreenState();
}

class _FranchiseInventoryScreenState extends State<FranchiseInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  List<Map<String, dynamic>> _rawMaterials = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _productionLogs = [];
  List<ProductModel> _finishedProducts = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final invRepository = InventoryRepository();

      // Fetch raw materials stock
      final rawRes = await invRepository.getFranchiseRawMaterials();
      if (rawRes['success'] == true && rawRes['data'] is List) {
        _rawMaterials = List<Map<String, dynamic>>.from(rawRes['data']);
      } else if (rawRes['data'] is Map && rawRes['data']['results'] is List) {
        _rawMaterials = List<Map<String, dynamic>>.from(
          rawRes['data']['results'],
        );
      }

      // Fetch transactions
      final txRes = await invRepository.getFranchiseTransactions();
      if (txRes['success'] == true && txRes['data'] is List) {
        _transactions = List<Map<String, dynamic>>.from(txRes['data']);
      } else if (txRes['data'] is Map && txRes['data']['results'] is List) {
        _transactions = List<Map<String, dynamic>>.from(
          txRes['data']['results'],
        );
      }

      // Fetch production logs
      final prodRes = await invRepository.getFranchiseProductionLogs();
      if (prodRes['success'] == true && prodRes['data'] is List) {
        _productionLogs = List<Map<String, dynamic>>.from(prodRes['data']);
      } else if (prodRes['data'] is Map && prodRes['data']['results'] is List) {
        _productionLogs = List<Map<String, dynamic>>.from(
          prodRes['data']['results'],
        );
      }

      // Fetch finished products
      await ProductRepository().getProducts();
      _finishedProducts = ProductRepository.cachedProducts;
    } catch (e) {
      _error = 'Failed to load inventory data. Please check your connection.';
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ────────────────────────
          // HEADER
          // ────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warehouse_rounded,
                        color: Color(0xFF0284C7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Franchise Inventory',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            'Raw materials, finished goods, production & ledger',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF0284C7),
                      ),
                      onPressed: _fetchData,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: const Color(0xFF0284C7),
                  unselectedLabelColor: const Color(0xFF9CA3AF),
                  indicatorColor: const Color(0xFF0284C7),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  tabs: const [
                    Tab(text: 'Raw Materials'),
                    Tab(text: 'Finished Products'),
                    Tab(text: 'Production'),
                    Tab(text: 'Transactions'),
                  ],
                ),
              ],
            ),
          ),

          // ────────────────────────
          // BODY
          // ────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                  )
                : _error != null
                ? _buildError()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRawMaterialsTab(),
                      _buildFinishedProductsTab(),
                      _buildProductionTab(),
                      _buildTransactionsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B),
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // TAB 1: RAW MATERIALS
  // ─────────────────────────────────────────
  Widget _buildRawMaterialsTab() {
    if (_rawMaterials.isEmpty) {
      return _buildEmpty(
        icon: Icons.inventory_2_outlined,
        label: 'No raw material stocks found.',
        subtitle: 'Contact admin to request raw material transfers.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _rawMaterials.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final item = _rawMaterials[i];
        final stock = item['current_stock'] ?? 0;
        final minAlert = item['min_alert_level'] ?? 10;
        final isLow = (stock as num) < (minAlert as num);
        return _InventoryCard(
          icon: Icons.science_outlined,
          iconColor: isLow ? const Color(0xFFEF4444) : const Color(0xFF0284C7),
          title:
              item['item_name']?.toString() ??
              item['item']?.toString() ??
              'Item',
          subtitle: 'Unit: ${item['unit'] ?? 'pcs'}  |  Min Alert: $minAlert',
          value: stock.toString(),
          valueLabel: 'In Stock',
          valueColor: isLow ? const Color(0xFFEF4444) : const Color(0xFF059669),
          badge: isLow ? 'LOW STOCK' : null,
          badgeColor: const Color(0xFFEF4444),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // TAB 2: FINISHED PRODUCTS
  // ─────────────────────────────────────────
  Widget _buildFinishedProductsTab() {
    if (_finishedProducts.isEmpty) {
      return _buildEmpty(
        icon: Icons.local_drink_outlined,
        label: 'No finished products found.',
        subtitle:
            'Log production batches or order stock to populate finished products.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _finishedProducts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final product = _finishedProducts[i];
        final stock = product.stock;
        final isLow = stock <= 10;
        final isOutOfStock = stock <= 0;

        return _InventoryCard(
          icon: product.category == 'Water Jar'
              ? Icons.water_drop_rounded
              : Icons.local_drink_rounded,
          iconColor: isOutOfStock
              ? const Color(0xFFEF4444)
              : (isLow ? const Color(0xFFF59E0B) : const Color(0xFF0284C7)),
          title: product.name,
          subtitle:
              'Category: ${product.category}  |  Size: ${product.size}  |  Price: ₹${product.price.toStringAsFixed(0)} / ${product.unit}',
          value: stock.toString(),
          valueLabel: 'Units Available',
          valueColor: isOutOfStock
              ? const Color(0xFFEF4444)
              : (isLow ? const Color(0xFFF59E0B) : const Color(0xFF059669)),
          badge: isOutOfStock ? 'OUT OF STOCK' : (isLow ? 'LOW STOCK' : null),
          badgeColor: isOutOfStock
              ? const Color(0xFFEF4444)
              : const Color(0xFFF59E0B),
        );
      },
    );
  }

  // TAB 2: PRODUCTION LOGS
  // ─────────────────────────────────────────
  Widget _buildProductionTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showLogProductionDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Log Production Batch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_productionLogs.isEmpty)
          Expanded(
            child: _buildEmpty(
              icon: Icons.precision_manufacturing_outlined,
              label: 'No production logs recorded yet.',
              subtitle:
                  'Tap the button above to log your first production batch.',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _productionLogs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final log = _productionLogs[i];
                return _InventoryCard(
                  icon: Icons.precision_manufacturing_outlined,
                  iconColor: const Color(0xFF7C3AED),
                  title: log['product_name']?.toString() ?? 'Batch',
                  subtitle:
                      'Date: ${log['production_date'] ?? ''}\n${log['notes'] ?? ''}',
                  value: log['quantity_produced']?.toString() ?? '0',
                  valueLabel: 'Produced',
                  valueColor: const Color(0xFF7C3AED),
                );
              },
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // TAB 3: TRANSACTIONS
  // ─────────────────────────────────────────
  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return _buildEmpty(
        icon: Icons.receipt_long_outlined,
        label: 'No inventory transactions found.',
        subtitle: 'Transactions will appear here as stock moves.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final tx = _transactions[i];
        final qty = tx['quantity'] ?? 0;
        final isPositive = (qty as num) >= 0;
        final txType = _formatTxType(tx['transaction_type']?.toString() ?? '');

        return _InventoryCard(
          icon: isPositive
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded,
          iconColor: isPositive
              ? const Color(0xFF059669)
              : const Color(0xFFEF4444),
          title: txType,
          subtitle: tx['notes']?.toString() ?? '',
          value: (isPositive ? '+' : '') + qty.toString(),
          valueLabel: 'Qty',
          valueColor: isPositive
              ? const Color(0xFF059669)
              : const Color(0xFFEF4444),
        );
      },
    );
  }

  String _formatTxType(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1);
        })
        .join(' ');
  }

  Widget _buildEmpty({
    required IconData icon,
    required String label,
    String? subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFFD1D5DB)),
            const SizedBox(height: 14),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showLogProductionDialog() {
    final productCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Log Production Batch',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogField('Product Name', productCtrl),
                const SizedBox(height: 12),
                _dialogField(
                  'Quantity Produced',
                  qtyCtrl,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _dialogField('Notes (optional)', notesCtrl, maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final productName = productCtrl.text.trim();
                      final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                      if (productName.isEmpty || qty <= 0) {
                        ScaffoldMessenger.of(dCtx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter product name and quantity.',
                            ),
                          ),
                        );
                        return;
                      }

                      setDState(() => saving = true);
                      try {
                        await InventoryRepository().createFranchiseProductionLog({
                          'product_name': productName,
                          'quantity_produced': qty,
                          'notes': notesCtrl.text.trim(),
                        });
                        if (mounted) Navigator.pop(dCtx);
                        _fetchData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Production batch logged!'),
                              backgroundColor: Color(0xFF059669),
                            ),
                          );
                        }
                      } catch (e) {
                        setDState(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(dCtx).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// REUSABLE INVENTORY CARD (OVERFLOW-SAFE)
// ─────────────────────────────────────────
class _InventoryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String value;
  final String valueLabel;
  final Color valueColor;
  final String? badge;
  final Color? badgeColor;

  const _InventoryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.valueLabel,
    required this.valueColor,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? Colors.red).withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            color: badgeColor ?? Colors.red,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                valueLabel,
                style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
