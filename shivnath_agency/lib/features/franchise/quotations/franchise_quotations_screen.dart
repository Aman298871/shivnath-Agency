import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/utils/app_toast.dart';

class FranchiseQuotationsScreen extends StatefulWidget {
  const FranchiseQuotationsScreen({super.key});

  @override
  State<FranchiseQuotationsScreen> createState() =>
      _FranchiseQuotationsScreenState();
}

class _FranchiseQuotationsScreenState extends State<FranchiseQuotationsScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allQuotations = [];
  String _selectedFilter = 'all'; // all, published, accepted, rejected, expired
  late TabController _tabController;

  final List<Map<String, String>> _tabs = [
    {'key': 'all', 'label': 'All'},
    {'key': 'published', 'label': 'Pending'},
    {'key': 'accepted', 'label': 'Accepted'},
    {'key': 'rejected', 'label': 'Rejected'},
    {'key': 'expired', 'label': 'Expired'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedFilter = _tabs[_tabController.index]['key']!;
        });
      }
    });
    _fetchQuotations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuotations() async {
    setState(() => _isLoading = true);
    try {
      final list = await _chatService.getQuotations();
      if (mounted) {
        setState(() {
          _allQuotations = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.error(context, 'Failed to load quotations: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredQuotations {
    if (_selectedFilter == 'all') {
      return _allQuotations;
    } else if (_selectedFilter == 'published') {
      return _allQuotations
          .where((q) => q['status'] == 'published' || q['status'] == 'new')
          .toList();
    } else if (_selectedFilter == 'expired') {
      return _allQuotations
          .where((q) => q['status'] == 'expired' || q['status'] == 'withdrawn')
          .toList();
    } else {
      return _allQuotations
          .where((q) => q['status'] == _selectedFilter)
          .toList();
    }
  }

  void _showQuotationDetails(Map<String, dynamic> q) {
    final status = q['status']?.toString().toLowerCase() ?? 'published';
    final hasPdf = q['has_pdf'] == true;
    final pdfUrl = q['pdf_url']?.toString();
    final qNum = q['quotation_number']?.toString() ?? 'Q-FRN-${q['id']}';
    final isPending = status == 'published' || status == 'new';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
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
                                  qNum,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  q['title']?.toString() ?? 'Special Rate Quotation',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusBadge(status),
                        ],
                      ),
                      const Divider(height: 24),

                      // Product & Quantity
                      _buildDetailRow(
                        'Product',
                        q['product_details']?['name']?.toString() ??
                            q['product_name']?.toString() ??
                            'Custom Product',
                        icon: Icons.inventory_2_outlined,
                      ),
                      _buildDetailRow(
                        'Quantity Tier',
                        q['quantity_tier']?.toString() ?? 'Standard MOQ',
                        icon: Icons.layers_outlined,
                      ),
                      _buildDetailRow(
                        'Unit Rate',
                        '₹${(q['unit_price'] ?? 0)} per unit',
                        icon: Icons.price_check_outlined,
                      ),
                      if (q['discount_percent'] != null &&
                          (double.tryParse(q['discount_percent'].toString()) ?? 0) > 0)
                        _buildDetailRow(
                          'Franchise Discount',
                          '${q['discount_percent']}% OFF',
                          icon: Icons.discount_outlined,
                          color: Colors.green.shade700,
                        ),
                      if (q['additional_charges'] != null &&
                          (double.tryParse(q['additional_charges'].toString()) ?? 0) > 0)
                        _buildDetailRow(
                          'Additional Charges',
                          '₹${q['additional_charges']}',
                          icon: Icons.add_circle_outline,
                        ),
                      _buildDetailRow(
                        'Final Total Rate',
                        '₹${(q['final_amount'] ?? q['total_price'] ?? q['unit_price'] ?? 0)}',
                        icon: Icons.account_balance_wallet_outlined,
                        isBold: true,
                        color: const Color(0xFF0284C7),
                      ),
                      _buildDetailRow(
                        'Validity Period',
                        q['validity']?.toString() ?? '30 Days',
                        icon: Icons.calendar_today_outlined,
                      ),
                      if (q['valid_until'] != null)
                        _buildDetailRow(
                          'Valid Until',
                          q['valid_until'].toString(),
                          icon: Icons.event_available_outlined,
                        ),

                      const SizedBox(height: 16),
                      // Terms & Conditions
                      const Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          q['applicable_terms']?.toString() ??
                              'Standard company delivery and quality standards apply.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),

                      if (q['notes'] != null && q['notes'].toString().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Additional Remarks',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Text(
                            q['notes'].toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],

                      if (q['rejection_reason'] != null &&
                          q['rejection_reason'].toString().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Rejection Reason',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Text(
                            q['rejection_reason'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],

                      if (hasPdf && pdfUrl != null) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(pdfUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              if (context.mounted) {
                                AppToast.error(context, 'Could not open PDF document');
                              }
                            }
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                          label: const Text('View Official Attached PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE11D48),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],

                      if (isPending) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showRejectDialog(q);
                                },
                                icon: const Icon(Icons.close_rounded, color: Colors.red),
                                label: const Text('Reject', style: TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _confirmAccept(q);
                                },
                                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                                label: const Text('Accept Quotation'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    IconData? icon,
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'accepted':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        label = 'ACCEPTED';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        label = 'REJECTED';
        break;
      case 'expired':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'EXPIRED';
        break;
      case 'withdrawn':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        label = 'WITHDRAWN';
        break;
      case 'draft':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = 'DRAFT';
        break;
      default:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        label = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  void _confirmAccept(Map<String, dynamic> q) {
    final qNum = q['quotation_number']?.toString() ?? 'Q-FRN-${q['id']}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Accept Quotation?'),
        content: SingleChildScrollView(
          child: Text(
            'Are you sure you want to accept quotation $qNum at the quoted rate of ₹${q['final_amount'] ?? q['total_price'] ?? q['unit_price']}?\n\nThis will record your acceptance and notify the administration.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _chatService.respondToQuotation(
                id: q['id'],
                action: 'accept',
              );
              if (mounted) {
                if (res['success'] == true) {
                  AppToast.success(context, 'Quotation accepted successfully!');
                  _fetchQuotations();
                } else {
                  AppToast.error(context, res['message']?.toString() ?? 'Failed to accept quotation');
                }
              }
            },
            child: const Text('Confirm Accept'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> q) {
    final reasonCtrl = TextEditingController();
    final qNum = q['quotation_number']?.toString() ?? 'Q-FRN-${q['id']}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Quotation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please provide a mandatory reason for rejecting quotation $qNum:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g. Price exceeds current market budget, requested revision...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty || reason.length < 3) {
                AppToast.error(context, 'Please enter a valid rejection reason.');
                return;
              }
              Navigator.pop(ctx);
              final res = await _chatService.respondToQuotation(
                id: q['id'],
                action: 'reject',
                reason: reason,
              );
              if (mounted) {
                if (res['success'] == true) {
                  AppToast.success(context, 'Quotation rejected.');
                  _fetchQuotations();
                } else {
                  AppToast.error(context, res['message']?.toString() ?? 'Failed to reject quotation');
                }
              }
            },
            child: const Text('Submit Rejection'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Franchise Quotations',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF0284C7),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0284C7),
          tabs: _tabs.map((t) => Tab(text: t['label'])).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchQuotations,
              child: _filteredQuotations.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.request_quote_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No quotations found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'New quotations issued by Admin will appear here.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredQuotations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) {
                        final q = _filteredQuotations[idx];
                        final qNum =
                            q['quotation_number']?.toString() ?? 'Q-FRN-${q['id']}';
                        final status =
                            q['status']?.toString().toLowerCase() ?? 'published';
                        final isUnread = q['is_read_by_franchise'] == false;
                        final hasPdf = q['has_pdf'] == true;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isUnread
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFFE2E8F0),
                              width: isUnread ? 1.5 : 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showQuotationDetails(q),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            qNum,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (isUnread) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0284C7),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'NEW',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      _buildStatusBadge(status),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    q['title']?.toString() ??
                                        'Special Franchise Quotation',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Details Wrap Layout (Prevents pixel overflow)
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Quantity',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            q['quantity_tier']?.toString() ??
                                                '1 Unit',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Quoted Rate',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '₹${q['final_amount'] ?? q['total_price'] ?? q['unit_price']}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: Color(0xFF0284C7),
                                            ),
                                          ),
                                        ],
                                      ),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 140,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Validity',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Text(
                                              q['validity']?.toString() ??
                                                  '30 Days',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (hasPdf) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.attach_file_rounded,
                                          size: 14,
                                          color: Color(0xFFE11D48),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Official PDF Attached',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
