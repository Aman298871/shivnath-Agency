import 'package:flutter/material.dart';

import '../../../core/services/InventoryService.dart';
import 'central_plant_inventory_screen.dart';

/// Live Dealer Stock Request Fulfillment Tracker Screen
/// Provides an authoritative, transparent, continuously-updating breakdown
/// of stock request status, BOM raw material requirements, factory batches,
/// and smart "What to do next" guidance.
class DealerStockRequestFulfillmentScreen extends StatefulWidget {
  final int requestId;
  final Map<String, dynamic>? initialRequest;
  final bool isFranchiseView;

  const DealerStockRequestFulfillmentScreen({
    super.key,
    required this.requestId,
    this.initialRequest,
    this.isFranchiseView = false,
  });

  @override
  State<DealerStockRequestFulfillmentScreen> createState() =>
      _DealerStockRequestFulfillmentScreenState();
}

class _DealerStockRequestFulfillmentScreenState
    extends State<DealerStockRequestFulfillmentScreen> {
  final InventoryService _invService = InventoryService();

  bool _loading = true;
  bool _fulfilling = false;
  String? _error;
  Map<String, dynamic>? _fulfillmentData;

  @override
  void initState() {
    super.initState();
    _loadFulfillmentDetails();
  }

  Future<void> _loadFulfillmentDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _invService.getStockRequestFulfillment(widget.requestId);
      Map<String, dynamic>? dataMap;
      if (res['fulfillment'] is Map) {
        dataMap = Map<String, dynamic>.from(res['fulfillment'] as Map);
      } else if (res['data'] is Map) {
        final inner = res['data'] as Map;
        if (inner['fulfillment'] is Map) {
          dataMap = Map<String, dynamic>.from(inner['fulfillment'] as Map);
        } else {
          dataMap = Map<String, dynamic>.from(inner);
        }
      }

      if (res['success'] == true && dataMap != null && dataMap.isNotEmpty) {
        if (mounted) {
          setState(() {
            _fulfillmentData = dataMap;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = res['message']?.toString() ??
                (res['data'] is Map ? res['data']['message']?.toString() : null) ??
                'Failed to load fulfillment data';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleFulfillAtomic() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Text('Fulfill & Complete', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: const Text(
          'This will automatically verify stock, manufacture a compliant batch if needed, allocate, dispatch with wholesale invoice, and confirm dealer delivery in one atomic operation.\n\nProceed?',
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
            child: const Text('Fulfill Now'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _fulfilling = true);

    try {
      final res = await _invService.fulfillSingleStockRequest(widget.requestId);
      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Request fulfilled and completed successfully!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadFulfillmentDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Fulfillment failed'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _fulfilling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reqNum = _fulfillmentData?['request_summary']?['request_number'] ??
        widget.initialRequest?['request_number'] ??
        'REQ-${widget.requestId}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock Fulfillment Tracker',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              reqNum,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0284C7),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0284C7)),
            onPressed: _loading ? null : _loadFulfillmentDetails,
            tooltip: 'Refresh',
          ),
          if (!widget.isFranchiseView)
            IconButton(
              icon: const Icon(Icons.bolt_rounded, color: Color(0xFF10B981)),
              onPressed: _fulfilling ? null : _handleFulfillAtomic,
              tooltip: 'Fulfill & Complete',
            ),
        ],
      ),
      body: _loading && _fulfillmentData == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
            )
          : _error != null && _fulfillmentData == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadFulfillmentDetails,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final data = _fulfillmentData!;
    final reqSummary = data['request_summary'] as Map<String, dynamic>? ?? {};
    final prodFulfillment =
        data['product_fulfillment'] as Map<String, dynamic>? ?? {};
    final centralStock =
        data['central_stock_analysis'] as Map<String, dynamic>? ?? {};
    final rawMaterials =
        (data['raw_material_requirements'] as List?) ?? [];
    final prodSummary =
        data['production_summary'] as Map<String, dynamic>? ?? {};
    final linkedBatches = (data['linked_batches'] as List?) ?? [];
    final childExplanation =
        data['child_friendly_explanation'] as Map<String, dynamic>? ?? {};
    final nextAction = data['next_action'] as Map<String, dynamic>? ?? {};
    final siblingReqs = (data['sibling_requests'] as List?) ?? [];

    final status = (reqSummary['status'] ?? 'REQUESTED').toString().toUpperCase();
    final isCompleted = status == 'COMPLETED';

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadFulfillmentDetails,
          color: const Color(0xFF0284C7),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // 1. Plain Words / Child-Friendly Explanation Card
              _buildChildFriendlyCard(childExplanation),
              const SizedBox(height: 14),

              // 2. Next Action Recommendation Guide
              _buildNextActionCard(nextAction, centralStock, isCompleted),
              const SizedBox(height: 14),

              // 3. Request Summary Card
              _buildRequestSummaryCard(reqSummary),
              const SizedBox(height: 14),

              // 4. Product Fulfillment Progress & Dual Metrics
              _buildProductFulfillmentCard(prodFulfillment),
              const SizedBox(height: 14),

              // 5. Central Finished Goods Stock Analysis
              _buildCentralStockCard(centralStock),
              const SizedBox(height: 14),

              // 6. BOM Raw Material Requirements & Shortage Table
              _buildRawMaterialsCard(rawMaterials, prodFulfillment),
              const SizedBox(height: 14),

              // 7. Linked Production Batches & History
              _buildLinkedBatchesCard(linkedBatches, prodSummary),
              const SizedBox(height: 14),

              // 8. Sibling Requests (Multi-Product Order)
              if (siblingReqs.isNotEmpty) ...[
                _buildSiblingRequestsCard(siblingReqs),
                const SizedBox(height: 14),
              ],

              // Bottom Spacing for Action Buttons
              const SizedBox(height: 80),
            ],
          ),
        ),

        // Floating Action Bar at the bottom
        if (!widget.isFranchiseView && !isCompleted)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildBottomActionBar(nextAction, centralStock),
          ),
      ],
    );
  }

  // =========================================================================
  // SECTION 1: IN PLAIN WORDS / CHILD-FRIENDLY CARD
  // =========================================================================
  Widget _buildChildFriendlyCard(Map<String, dynamic> c) {
    final headline = c['headline']?.toString() ?? 'Fulfillment Overview';
    final narrative = c['narrative']?.toString() ?? '';
    final requested = c['requested'] ?? 0;
    final fulfilled = c['fulfilled'] ?? 0;
    final remaining = c['remaining'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.amberAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            narrative,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _plainMetric('Requested', '$requested'),
                const Text('→', style: TextStyle(color: Colors.white70)),
                _plainMetric('Fulfilled', '$fulfilled'),
                const Text('→', style: TextStyle(color: Colors.white70)),
                _plainMetric(
                  'Remaining',
                  '$remaining',
                  highlight: remaining > 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plainMetric(String label, String value, {bool highlight = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: highlight ? Colors.amberAccent : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  // =========================================================================
  // SECTION 2: NEXT ACTION GUIDE
  // =========================================================================
  Widget _buildNextActionCard(
    Map<String, dynamic> act,
    Map<String, dynamic> centralStock,
    bool isCompleted,
  ) {
    final state = act['state']?.toString() ?? '';
    final headline = act['headline']?.toString() ?? 'Recommended Next Step';
    final desc = act['description']?.toString() ?? '';

    Color cardBg = const Color(0xFFF0FDF4);
    Color borderColor = const Color(0xFF86EFAC);
    Color textColor = const Color(0xFF166534);
    IconData icon = Icons.check_circle_rounded;

    if (state == 'RAW_MATERIAL_SHORTAGE') {
      cardBg = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFECACA);
      textColor = const Color(0xFF991B1B);
      icon = Icons.warning_amber_rounded;
    } else if (state == 'READY_TO_PRODUCE') {
      cardBg = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFFBFDBFE);
      textColor = const Color(0xFF1E40AF);
      icon = Icons.precision_manufacturing_rounded;
    } else if (state == 'READY_TO_DISPATCH') {
      cardBg = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFFBBF7D0);
      textColor = const Color(0xFF166534);
      icon = Icons.local_shipping_rounded;
    } else if (isCompleted) {
      cardBg = const Color(0xFFF8FAFC);
      borderColor = const Color(0xFFE2E8F0);
      textColor = const Color(0xFF334155);
      icon = Icons.verified_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION 3: REQUEST SUMMARY
  // =========================================================================
  Widget _buildRequestSummaryCard(Map<String, dynamic> r) {
    final reqNum = r['request_number'] ?? '';
    final dealer = r['franchise_name'] ?? 'Franchise';
    final territory = r['territory'] ?? r['city'] ?? '';
    final status = (r['status'] ?? 'REQUESTED').toString().toUpperCase();
    final requestedAt = r['requested_at']?.toString() ?? '';
    final notes = r['dealer_notes']?.toString() ?? '';

    Color statusColor = const Color(0xFFF59E0B);
    if (status == 'COMPLETED' || status == 'RECEIVED') {
      statusColor = const Color(0xFF10B981);
    } else if (status == 'DISPATCHED') {
      statusColor = const Color(0xFF0284C7);
    } else if (status == 'PREPARING' || status == 'APPROVED') {
      statusColor = const Color(0xFF7C3AED);
    }

    return Card(
      elevation: 0,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dealer,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (territory.isNotEmpty)
                      Text(
                        'Territory: $territory',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Req #: $reqNum',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                Text(
                  _formatDate(requestedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Notes: $notes',
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SECTION 4: PRODUCT FULFILLMENT BREAKDOWN & PROGRESS
  // =========================================================================
  Widget _buildProductFulfillmentCard(Map<String, dynamic> p) {
    final name = p['product_name'] ?? 'Product';
    final sku = p['product_sku'] ?? '';
    final unitsPerCase = p['units_per_case'] ?? 24;
    final pct = (p['fulfilled_percentage'] as num?)?.toDouble() ?? 0.0;

    final requestedUnits = p['requested_quantity'] ?? 0;
    final requestedCases = p['requested_cases'] ?? 0;
    final dispatchedUnits = p['dispatched_quantity'] ?? 0;
    final dispatchedCases = p['dispatched_cases'] ?? 0;
    final remainingUnits = p['remaining_quantity'] ?? 0;
    final remainingCases = p['remaining_cases'] ?? 0;

    return Card(
      elevation: 0,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SKU: $sku · $unitsPerCase units/case',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: pct >= 100
                        ? const Color(0xFF10B981)
                        : const Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct >= 100 ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _statBlock(
                    'Total Requested',
                    '$requestedUnits',
                    '$requestedCases cases',
                    const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statBlock(
                    'Dispatched',
                    '$dispatchedUnits',
                    '$dispatchedCases cases',
                    const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statBlock(
                    'Still Needed',
                    '$remainingUnits',
                    '$remainingCases cases',
                    remainingUnits > 0 ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBlock(
      String label, String value1, String value2, Color valColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(value1,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15, color: valColor)),
          Text(value2,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION 5: CENTRAL PLANT FINISHED STOCK ANALYSIS
  // =========================================================================
  Widget _buildCentralStockCard(Map<String, dynamic> c) {
    final onHand = c['total_on_hand'] ?? 0;
    final netAvailable = c['net_available_for_dispatch'] ?? 0;
    final canFulfill = c['can_fulfill_immediately'] == true;
    final coveragePct = (c['coverage_percentage'] as num?)?.toDouble() ?? 0.0;

    return Card(
      elevation: 0,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.warehouse_rounded,
                          size: 18, color: Color(0xFF0284C7)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Central Finished Stock Analysis',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: canFulfill
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    canFulfill ? 'CAN DISPATCH NOW' : 'PRODUCTION NEEDED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: canFulfill
                          ? const Color(0xFF166534)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _plainStockItem('Total Plant Stock', '$onHand units'),
                ),
                Expanded(
                  child: _plainStockItem(
                      'Available for Request', '$netAvailable units'),
                ),
                Expanded(
                  child: _plainStockItem(
                      'Stock Coverage', '${coveragePct.toStringAsFixed(0)}%'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _plainStockItem(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 3),
        Text(val,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF0F172A))),
      ],
    );
  }

  // =========================================================================
  // SECTION 6: BOM RAW MATERIAL REQUIREMENTS & SHORTAGES
  // =========================================================================
  Widget _buildRawMaterialsCard(
    List rawMaterials,
    Map<String, dynamic> prodFulfillment,
  ) {
    final remainingUnits = prodFulfillment['remaining_quantity'] ?? 0;

    return Card(
      elevation: 0,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_rounded,
                          size: 18, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'BOM Raw Materials ${remainingUnits > 0 ? '(For Remaining $remainingUnits)' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.isFranchiseView)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 14),
                    label: const Text('Add RM', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CentralPlantInventoryScreen(
                            initialTab: 1,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (rawMaterials.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No Bill of Materials (BOM) configured for this product variant.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              )
            else
              Column(
                children: rawMaterials.map<Widget>((rm) {
                  final name = rm['name'] ?? 'Material';
                  final category = rm['category'] ?? '';
                  final uom = rm['unit_of_measurement'] ?? '';
                  final req = rm['required_for_remaining'] ?? 0;
                  final stock = rm['current_stock'] ?? 0;
                  final shortage = rm['shortage'] ?? 0;
                  final isShort = rm['is_shortage'] == true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isShort
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isShort
                            ? const Color(0xFFFECACA)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '$category · Needed: $req $uom · In Stock: $stock $uom',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isShort
                                      ? Colors.red.shade700
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isShort
                                ? Colors.red.withValues(alpha: 0.15)
                                : const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isShort ? 'Short: $shortage' : 'SUFFICIENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isShort
                                  ? Colors.red.shade800
                                  : const Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SECTION 7: LINKED PRODUCTION BATCHES & HISTORY
  // =========================================================================
  Widget _buildLinkedBatchesCard(
      List batches, Map<String, dynamic> prodSummary) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history_rounded, size: 18, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text(
                  'Linked Production Batches',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (batches.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No factory production batches recorded for this request yet.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              )
            else
              Column(
                children: batches.map<Widget>((b) {
                  final bn = b['batch_number'] ?? '';
                  final mfg = b['manufacture_date'] ?? '';
                  final exp = b['expiry_date'] ?? '';
                  final qty = b['allocated_quantity'] ?? 0;
                  final disp = b['dispatched_quantity'] ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bn,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Mfg: $mfg · Exp: $exp',
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Text(
                          '$disp / $qty units',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SECTION 8: SIBLING MULTI-PRODUCT REQUESTS
  // =========================================================================
  Widget _buildSiblingRequestsCard(List siblings) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.layers_rounded, size: 18, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text(
                  'Other Items in this Dealer Order',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              children: siblings.map<Widget>((s) {
                final sId = s['id'];
                final sProd = s['product_name'] ?? '';
                final sReq = s['requested_quantity'] ?? 0;
                final sDisp = s['dispatched_quantity'] ?? 0;
                final sStatus = (s['status'] ?? '').toString().toUpperCase();

                return InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DealerStockRequestFulfillmentScreen(
                          requestId: sId,
                          isFranchiseView: widget.isFranchiseView,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            sProd,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$sDisp / $sReq units ($sStatus) →',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SECTION 9: ACTION BUTTONS FOOTER BAR
  // =========================================================================
  Widget _buildBottomActionBar(
    Map<String, dynamic> nextAction,
    Map<String, dynamic> centralStock,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _fulfilling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bolt_rounded, size: 18),
              label: Text(
                _fulfilling ? 'Fulfilling...' : 'Fulfill & Complete',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              onPressed: _fulfilling ? null : _handleFulfillAtomic,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0284C7),
              side: const BorderSide(color: Color(0xFF0284C7)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.precision_manufacturing_rounded, size: 18),
            label: const Text(
              'Produce Batch',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            onPressed: () {
              final reqSum = _fulfillmentData?['request_summary'] as Map<String, dynamic>?;
              final pSku = reqSum?['product_sku']?.toString();
              final pId = reqSum?['product_id'] is int
                  ? reqSum!['product_id'] as int
                  : int.tryParse(reqSum?['product_id']?.toString() ?? '');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CentralPlantInventoryScreen(
                    initialTab: 0,
                    preselectedProductSku: pSku,
                    preselectedProductId: pId,
                    openManufactureDialogOnLoad: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month]} ${dt.year}, $h:$m';
    } catch (_) {
      return raw;
    }
  }
}
