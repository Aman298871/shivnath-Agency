import 'package:flutter/material.dart';

import '../../../core/services/franchise_service.dart';
import '../../../core/services/InventoryService.dart';
import '../../../core/utils/app_toast.dart';

class AdminFranchiseDetailScreen extends StatefulWidget {
  final int franchiseId;
  final String franchiseName;

  const AdminFranchiseDetailScreen({
    super.key,
    required this.franchiseId,
    required this.franchiseName,
  });

  @override
  State<AdminFranchiseDetailScreen> createState() =>
      _AdminFranchiseDetailScreenState();
}

class _AdminFranchiseDetailScreenState extends State<AdminFranchiseDetailScreen>
    with SingleTickerProviderStateMixin {
  final FranchiseService _franchiseService = FranchiseService();
  final InventoryService _inventoryService = InventoryService();
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? detailData;
  late TabController _tabController;

  // KYC Documents
  List<Map<String, dynamic>> _kycDocs = [];
  bool _loadingDocs = false;

  // Credit Profile & Aging
  Map<String, dynamic>? _creditProfile;
  Map<String, dynamic>? _agingReport;
  bool _loadingCredit = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDetail();
    _loadKycDocs();
    _loadCreditProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final res = await _franchiseService.getFranchiseDetail(widget.franchiseId);
    if (!mounted) return;

    if (res['success'] == true && res['data'] is Map) {
      setState(() {
        isLoading = false;
        detailData = Map<String, dynamic>.from(res['data']);
      });
    } else {
      setState(() {
        isLoading = false;
        errorMessage =
            res['message']?.toString() ?? 'Unable to load franchise details.';
      });
    }
  }

  Future<void> _loadKycDocs() async {
    setState(() => _loadingDocs = true);
    final res = await _franchiseService.getFranchiseDocuments(widget.franchiseId);
    if (!mounted) return;
    if (res['success'] == true) {
      final data = res['data'];
      final docsList = data is Map ? (data['documents'] ?? []) : (data is List ? data : []);
      setState(() {
        _kycDocs = List<Map<String, dynamic>>.from(
          (docsList as List).map((d) => Map<String, dynamic>.from(d as Map)),
        );
        _loadingDocs = false;
      });
    } else {
      setState(() => _loadingDocs = false);
    }
  }

  Future<void> _verifyDoc(int docId, String action) async {
    String? rejectionReason;
    if (action == 'REJECTED') {
      rejectionReason = await _showRejectionDialog();
      if (rejectionReason == null) return; // cancelled
    }

    final res = await _franchiseService.verifyFranchiseDocument(
      docId: docId,
      action: action,
      rejectionReason: rejectionReason ?? '',
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? (res['success'] == true ? 'Done!' : 'Error')),
        backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (res['success'] == true) {
      _loadKycDocs();
    }
  }

  Future<String?> _showRejectionDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejection Reason'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter reason for rejection...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Reject Document'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCreditProfile() async {
    setState(() => _loadingCredit = true);
    try {
      final cpRes = await _inventoryService.getDealerCreditProfile(widget.franchiseId);
      final agRes = await _inventoryService.getDealerAgingReport(widget.franchiseId);
      if (!mounted) return;
      setState(() {
        if (cpRes['success'] == true) {
          _creditProfile = Map<String, dynamic>.from(cpRes['data'] ?? cpRes);
        }
        if (agRes['success'] == true) {
          _agingReport = Map<String, dynamic>.from(agRes['data'] ?? agRes);
        }
        _loadingCredit = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCredit = false);
    }
  }

  Future<void> _showEditCreditDialog() async {
    final limitCtrl = TextEditingController(
      text: _creditProfile != null
          ? (_creditProfile!['credit_limit']?.toString() ?? '0')
          : '0',
    );
    final termsCtrl = TextEditingController(
      text: _creditProfile != null
          ? (_creditProfile!['payment_terms_days']?.toString() ?? '15')
          : '15',
    );
    String creditStatus = _creditProfile?['credit_status']?.toString() ?? 'ACTIVE';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text('Edit Credit & Billing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Credit Limit (₹)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: limitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Payment Terms (Days)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: termsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    suffixText: 'Days',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Credit Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: ['ACTIVE', 'SUSPENDED', 'BLOCKED', 'UNDER_REVIEW'].contains(creditStatus)
                      ? creditStatus
                      : 'ACTIVE',
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE (Normal)')),
                    DropdownMenuItem(value: 'UNDER_REVIEW', child: Text('UNDER_REVIEW')),
                    DropdownMenuItem(value: 'SUSPENDED', child: Text('SUSPENDED (Grace)')),
                    DropdownMenuItem(value: 'BLOCKED', child: Text('BLOCKED (No Orders)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => creditStatus = val);
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final double? parsedLimit = double.tryParse(limitCtrl.text.trim());
      final int? parsedDays = int.tryParse(termsCtrl.text.trim());
      if (parsedLimit == null) {
        if (mounted) AppToast.error(context, 'Please enter a valid credit limit amount');
        return;
      }
      final res = await _inventoryService.updateDealerCreditProfile(
        dealerId: widget.franchiseId,
        creditLimit: parsedLimit,
        paymentTermsDays: parsedDays ?? 15,
        creditStatus: creditStatus,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        AppToast.success(context, 'Credit profile updated successfully');
        _loadCreditProfile();
      } else {
        AppToast.error(context, res['message']?.toString() ?? 'Failed to update credit profile');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.franchiseName),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadDetail();
              _loadKycDocs();
              _loadCreditProfile();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(errorMessage!, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadDetail,
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
    final franchise = detailData?['franchise'] as Map? ?? {};
    final summary = detailData?['summary'] as Map? ?? {};
    final servedCustomers = (detailData?['served_customers'] as List? ?? []);
    final registeredCustomers = (detailData?['registered_customers'] as List? ?? []);
    final orders = (detailData?['orders'] as List? ?? []);
    final stockCycles = (detailData?['stock_cycles'] as List? ?? []);

    // Count pending docs for badge
    final pendingDocs = _kycDocs.where((d) => d['verification_status'] == 'PENDING').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Franchise Overview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFF0284C7), size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  franchise['business_name']?.toString() ?? widget.franchiseName,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: franchise['status'] == 'approved'
                                      ? const Color(0xFFDCFCE7)
                                      : franchise['status'] == 'rejected'
                                          ? const Color(0xFFFEE2E2)
                                          : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (franchise['status']?.toString() ?? 'Pending').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: franchise['status'] == 'approved'
                                        ? const Color(0xFF16A34A)
                                        : franchise['status'] == 'rejected'
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                              if (pendingDocs > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFCD34D)),
                                  ),
                                  child: Text(
                                    '$pendingDocs KYC Pending',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Owner: ${franchise['owner_name'] ?? 'N/A'} • Territory: ${franchise['territory'] ?? 'Unassigned'} • City: ${franchise['city'] ?? ''}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Phone: ${franchise['phone'] ?? 'N/A'} • Email: ${franchise['email'] ?? 'N/A'}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 4 Summary Metrics
              Row(
                children: [
                  Expanded(child: _metricCard(
                    title: 'Customers Served',
                    value: '${summary['customers_served_count'] ?? servedCustomers.length}',
                    subtitle: 'Currently fulfilling',
                    icon: Icons.local_shipping_outlined,
                    color: const Color(0xFF0284C7),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _metricCard(
                    title: 'Registered Cust.',
                    value: '${summary['registered_customers_count'] ?? registeredCustomers.length}',
                    subtitle: 'Direct registration',
                    icon: Icons.how_to_reg_outlined,
                    color: const Color(0xFF16A34A),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _metricCard(
                    title: 'Total Orders',
                    value: '${summary['total_orders_count'] ?? orders.length}',
                    subtitle: 'Historical orders',
                    icon: Icons.shopping_bag_outlined,
                    color: const Color(0xFFD97706),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _metricCard(
                    title: 'KYC Documents',
                    value: '${_kycDocs.length}',
                    subtitle: '$pendingDocs pending review',
                    icon: Icons.verified_user_outlined,
                    color: pendingDocs > 0 ? const Color(0xFFD97706) : const Color(0xFF9333EA),
                  )),
                ],
              ),

              const SizedBox(height: 24),

              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF0284C7),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF0284C7),
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.people_outline_rounded, size: 18),
                      text: 'Customers',
                    ),
                    const Tab(
                      icon: Icon(Icons.receipt_long_rounded, size: 18),
                      text: 'Orders & Stock',
                    ),
                    Tab(
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.badge_outlined, size: 18),
                          if (pendingDocs > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$pendingDocs',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                      text: 'KYC Documents',
                    ),
                    const Tab(
                      icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                      text: 'Credit & Billing',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tab Views
              SizedBox(
                height: 600,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCustomersTab(servedCustomers, registeredCustomers),
                    _buildOrdersTab(orders, stockCycles),
                    _buildKycDocsTab(),
                    _buildCreditBillingTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildKycDocsTab() {
    if (_loadingDocs) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_kycDocs.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open_rounded, size: 52, color: Color(0xFF94A3B8)),
              SizedBox(height: 12),
              Text(
                'No KYC documents uploaded yet.',
                style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
              ),
              SizedBox(height: 6),
              Text(
                'Documents will appear here once the franchise submits them.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _kycDocs.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (ctx, i) {
          final doc = _kycDocs[i];
          final docStatus = doc['verification_status']?.toString() ?? 'PENDING';
          final docType = doc['document_type_display']?.toString() ?? doc['document_type']?.toString() ?? 'Document';
          final docNumber = doc['document_number']?.toString() ?? '';
          final uploadedAt = (doc['uploaded_at']?.toString() ?? '').split('T').first;
          final docUrl = doc['document_url']?.toString() ?? '';

          Color statusColor;
          IconData statusIcon;
          Color statusBg;

          switch (docStatus) {
            case 'VERIFIED':
              statusColor = const Color(0xFF16A34A);
              statusBg = const Color(0xFFDCFCE7);
              statusIcon = Icons.verified_rounded;
              break;
            case 'REJECTED':
              statusColor = const Color(0xFFDC2626);
              statusBg = const Color(0xFFFEE2E2);
              statusIcon = Icons.cancel_rounded;
              break;
            default:
              statusColor = const Color(0xFFD97706);
              statusBg = const Color(0xFFFEF3C7);
              statusIcon = Icons.pending_rounded;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            docType,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          if (docNumber.isNotEmpty)
                            Text(
                              'Document No: $docNumber',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          Text(
                            'Uploaded: $uploadedAt',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        docStatus,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                      ),
                    ),
                  ],
                ),
                if (doc['rejection_reason']?.toString().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Rejection Reason: ${doc['rejection_reason']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
                if (docStatus == 'PENDING') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            foregroundColor: const Color(0xFFDC2626),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => _verifyDoc(doc['id'] as int, 'REJECTED'),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => _verifyDoc(doc['id'] as int, 'VERIFIED'),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Verify & Approve', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
                if (docStatus == 'VERIFIED') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        doc['verified_at'] != null
                            ? 'Verified on ${doc['verified_at'].toString().split('T').first}'
                            : 'Document Verified',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                      ),
                      if (doc['verified_by'] != null) ...[
                        const Text(' by ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text(
                          doc['verified_by'].toString(),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                ],
                if (docUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Document file available',
                            style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF1D4ED8)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomersTab(List<dynamic> servedList, List<dynamic> registeredList) {
    if (servedList.isEmpty && registeredList.isEmpty) {
      return const Center(child: Text('No customers associated with this franchise yet.'));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: servedList.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (ctx, index) {
          final c = servedList[index] as Map? ?? {};
          final isRegisteredToThis = registeredList.any((r) => r['id'] == c['id']);

          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE0F2FE),
              child: Icon(Icons.person_outline, color: Color(0xFF0284C7)),
            ),
            title: Row(
              children: [
                Text(
                  c['name']?.toString() ?? 'Customer',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRegisteredToThis ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isRegisteredToThis ? 'Registered & Serving' : 'Served (Other Franchise)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isRegisteredToThis ? const Color(0xFF16A34A) : const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Phone: ${c['phone'] ?? ''} • Territory: ${c['territory'] ?? 'Default'} • Orders: ${c['orders_count'] ?? 0}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            trailing: Text(
              '${c['active_stock'] ?? 0} active jars',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrdersTab(List<dynamic> orders, List<dynamic> stockCycles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: orders.isEmpty
          ? const Center(child: Text('No order records fulfilled by this franchise yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, index) {
                final o = orders[index] as Map? ?? {};
                return ListTile(
                  leading: const Icon(Icons.receipt_outlined, color: Color(0xFF64748B)),
                  title: Text(
                    'Order #${o['id']} • Customer: ${o['customer_name'] ?? 'Direct Customer'}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Items: ${o['items']} • Status: ${o['status']} • Date: ${o['created_at'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  trailing: Text(
                    '₹${o['amount'] ?? 0}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCreditBillingTab() {
    if (_loadingCredit) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final double creditLimit = double.tryParse(_creditProfile?['credit_limit']?.toString() ?? '0') ?? 0.0;
    final double outstanding = double.tryParse(_creditProfile?['current_outstanding']?.toString() ?? '0') ?? 0.0;
    final double availableCredit = double.tryParse(_creditProfile?['available_credit']?.toString() ?? '0') ?? (creditLimit - outstanding);
    final int termsDays = int.tryParse(_creditProfile?['payment_terms_days']?.toString() ?? '15') ?? 15;
    final String status = _creditProfile?['credit_status']?.toString() ?? 'ACTIVE';

    final aging = _agingReport?['aging'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Franchise Credit & Billing Profile',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Live backend ledger and enforceable credit limit',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showEditCreditDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Credit & Terms', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Credit summary tiles
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final tiles = [
                  _creditStatTile('Credit Limit', '₹${creditLimit.toStringAsFixed(0)}', const Color(0xFF0284C7), Icons.credit_score_rounded),
                  _creditStatTile('Current Outstanding', '₹${outstanding.toStringAsFixed(0)}', const Color(0xFFDC2626), Icons.money_off_rounded),
                  _creditStatTile('Available Credit', '₹${availableCredit.toStringAsFixed(0)}', availableCredit > 0 ? const Color(0xFF16A34A) : Colors.red, Icons.account_balance_wallet_rounded),
                  _creditStatTile('Payment Terms', '$termsDays Days', const Color(0xFF6366F1), Icons.calendar_today_rounded),
                ];

                if (isNarrow) {
                  return Column(
                    children: tiles.map((t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: t)).toList(),
                  );
                }

                return Row(
                  children: tiles.map((t) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: t))).toList(),
                );
              },
            ),

            const SizedBox(height: 24),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            // Credit Status & Risk Level
            Row(
              children: [
                const Text('Credit Status: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'ACTIVE'
                        ? const Color(0xFFDCFCE7)
                        : (status == 'SUSPENDED' ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: status == 'ACTIVE'
                          ? const Color(0xFF16A34A)
                          : (status == 'SUSPENDED' ? const Color(0xFFD97706) : Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  availableCredit <= 0 ? '⚠ Limit Exceeded — Stock Orders Blocked' : '✓ Credit in Good Standing',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: availableCredit <= 0 ? Colors.red : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text(
              'Aging Ledger Breakdown (Unpaid Balance by Duration)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _agingColumn('Current', '₹${aging['current'] ?? '0.00'}', const Color(0xFF16A34A)),
                  _agingColumn('1-15 Days', '₹${aging['1_15_days'] ?? '0.00'}', const Color(0xFF0284C7)),
                  _agingColumn('16-30 Days', '₹${aging['16_30_days'] ?? '0.00'}', const Color(0xFFD97706)),
                  _agingColumn('31-45 Days', '₹${aging['31_45_days'] ?? '0.00'}', Colors.orange),
                  _agingColumn('45+ Days', '₹${aging['45_plus_days'] ?? '0.00'}', Colors.red),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _creditStatTile(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            radius: 18,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _agingColumn(String bucket, String amount, Color color) {
    return Column(
      children: [
        Text(bucket, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(amount, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
