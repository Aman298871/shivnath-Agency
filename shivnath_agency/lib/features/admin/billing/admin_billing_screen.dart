import 'package:flutter/material.dart';
import '../../../core/services/InventoryService.dart';
import '../../../core/widgets/app_toast.dart';

int _asInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is num) return val.toInt();
  return num.tryParse(val.toString())?.toInt() ?? 0;
}

class AdminBillingScreen extends StatefulWidget {
  const AdminBillingScreen({super.key});

  @override
  State<AdminBillingScreen> createState() => _AdminBillingScreenState();
}

class _AdminBillingScreenState extends State<AdminBillingScreen> {
  String search = '';
  String statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadBackendInvoices();
  }

  Future<void> _loadBackendInvoices() async {
    try {
      final res = await InventoryService().getInvoices();
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) {
          final mapped = list.map((item) {
            final total = _asInt(item['grand_total'] ?? item['total_amount'] ?? item['total']);
            final paid = _asInt(item['amount_paid'] ?? item['paid']);
            final subtotal = _asInt(item['subtotal'] ?? (total * 0.82).round());
            final gst = _asInt(item['cgst_amount'] != null ? (_asInt(item['cgst_amount']) + _asInt(item['sgst_amount'])) : (item['tax_amount'] ?? (total - subtotal)));
            final rawStatus = item['status']?.toString() ?? '';
            String status = 'Unpaid';
            if (rawStatus == 'PAID' || rawStatus == 'Paid') {
              status = 'Paid';
            } else if (rawStatus == 'PARTIALLY_PAID' || rawStatus == 'Partial') {
              status = 'Partial';
            } else if (rawStatus == 'PAYMENT_PENDING_VERIFICATION') {
              status = 'Payment Verification Required';
            } else if (paid >= total && total > 0) {
              status = 'Paid';
            } else if (paid > 0) {
              status = 'Partial';
            }

            return {
              'id': item['id'],
              'invoice': item['invoice_number'] ?? 'INV-${item['id']}',
              'order': item['order_number'] ?? (item['order'] != null ? 'ORD-${item['order']}' : 'WHL-STOCK-TRANSFER'),
              'franchise': item['dealer_name'] ?? item['franchise_name'] ?? item['billed_to_name'] ?? item['customer_name'] ?? 'Authorized Dealer',
              'date': item['issue_date'] ?? item['invoice_date'] ?? item['issued_at']?.toString().split('T').first ?? 'Today',
              'subtotal': subtotal,
              'gst': gst,
              'total': total,
              'paid': paid,
              'creditDays': _asInt(item['credit_days'] ?? item['creditDays'] ?? 15),
              'dueDate': item['due_date'] ?? 'N/A',
              'status': status,
              'raw_status': rawStatus,
              'latest_pending_payment': item['latest_pending_payment'],
              'lastReminder': item['last_reminder'] ?? '-',
            };
          }).toList();

          if (mounted) {
            setState(() {
              invoices.clear();
              invoices.addAll(mapped);
            });
          }
        }
      }
    } catch (_) {}
  }

  final List<Map<String, dynamic>> invoices = [
    {
      'invoice': 'INV-2026-101',
      'order': 'ORD-1001',
      'franchise': 'Rahul Sharma',
      'date': '07 Sep 2026',
      'subtotal': 48500,
      'gst': 8730,
      'total': 57230,
      'paid': 0,
      'creditDays': 15,
      'dueDate': '22 Sep 2026',
      'status': 'Unpaid',
      'lastReminder': '-',
    },
    {
      'invoice': 'INV-2026-102',
      'order': 'ORD-1002',
      'franchise': 'Aqua Point',
      'date': '06 Sep 2026',
      'subtotal': 32200,
      'gst': 5796,
      'total': 37996,
      'paid': 20000,
      'creditDays': 7,
      'dueDate': '13 Sep 2026',
      'status': 'Partial',
      'lastReminder': '09 Sep 2026',
    },
    {
      'invoice': 'INV-2026-103',
      'order': 'ORD-1003',
      'franchise': 'Shiv Water',
      'date': '05 Sep 2026',
      'subtotal': 68400,
      'gst': 12312,
      'total': 80712,
      'paid': 80712,
      'creditDays': 0,
      'dueDate': '05 Sep 2026',
      'status': 'Paid',
      'lastReminder': '-',
    },
  ];

  List<Map<String, dynamic>> get filtered {
    final q = search.trim().toLowerCase();

    return invoices.where((invoice) {
      final matchesSearch =
          q.isEmpty ||
          invoice['invoice'].toString().toLowerCase().contains(q) ||
          invoice['order'].toString().toLowerCase().contains(q) ||
          invoice['franchise'].toString().toLowerCase().contains(q);

      final matchesStatus =
          statusFilter == 'All' || invoice['status'] == statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  int get totalBilling {
    return invoices.fold<int>(
      0,
      (sum, item) => sum + ((item['total'] as num?)?.toInt() ?? 0),
    );
  }

  int get totalCollected {
    return invoices.fold<int>(
      0,
      (sum, item) => sum + ((item['paid'] as num?)?.toInt() ?? 0),
    );
  }

  int get totalOutstanding {
    return totalBilling - totalCollected;
  }

  int get unpaidCount {
    return invoices.where((e) => e['status'] != 'Paid').length;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF5F7FB),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1350),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(desktop),

                    const SizedBox(height: 22),

                    _stats(desktop),

                    const SizedBox(height: 20),

                    _toolbar(desktop),

                    const SizedBox(height: 14),

                    desktop ? _desktopTable() : _mobileList(),

                    const SizedBox(height: 22),

                    _reportsSection(desktop),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(bool desktop) {
    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Billing & Accounts',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'GST billing, payment collection, outstanding and credit management.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: _createInvoice,
              icon: const Icon(Icons.add),
              label: const Text('New Invoice'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Billing & Accounts',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 5),
              Text(
                'GST billing, payment collection, outstanding and credit management.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),

        SizedBox(
          width: 155,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 44),
              maximumSize: const Size(155, 44),
            ),
            onPressed: _createInvoice,
            icon: const Icon(Icons.add),
            label: const Text('New Invoice'),
          ),
        ),
      ],
    );
  }

  Widget _stats(bool desktop) {
    final data = [
      ['Total Invoices', '${invoices.length}', Icons.receipt_long_outlined],
      ['Total Billing', _currency(totalBilling), Icons.currency_rupee],
      ['Collected', _currency(totalCollected), Icons.check_circle_outline],
      ['Outstanding', _currency(totalOutstanding), Icons.schedule_outlined],
      ['Payment Due', '$unpaidCount', Icons.notifications_active_outlined],
    ];

    if (!desktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.25,
        ),
        itemBuilder: (_, i) {
          return _BillingStat(
            title: data[i][0] as String,
            value: data[i][1] as String,
            icon: data[i][2] as IconData,
          );
        },
      );
    }

    return Row(
      children: List.generate(data.length, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == data.length - 1 ? 0 : 12),
            child: _BillingStat(
              title: data[i][0] as String,
              value: data[i][1] as String,
              icon: data[i][2] as IconData,
            ),
          ),
        );
      }),
    );
  }

  Widget _toolbar(bool desktop) {
    if (!desktop) {
      return Column(
        children: [_searchBox(), const SizedBox(height: 10), _statusDropdown()],
      );
    }

    return Row(
      children: [
        Expanded(child: _searchBox()),
        const SizedBox(width: 12),
        SizedBox(width: 180, child: _statusDropdown()),
      ],
    );
  }

  Widget _searchBox() {
    return TextField(
      onChanged: (value) {
        setState(() {
          search = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search invoice, order or franchise...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _statusDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: statusFilter,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: const ['All', 'Paid', 'Partial', 'Unpaid'].map((value) {
        return DropdownMenuItem(
          value: value,
          child: Text(value, overflow: TextOverflow.ellipsis, maxLines: 1),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          statusFilter = value;
        });
      },
    );
  }

  Widget _desktopTable() {
    return Container(
      width: double.infinity,
      decoration: _billingCard(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1250,
          child: Column(
            children: [
              _tableHeader(),
              ...filtered.map((invoice) => _tableRow(invoice)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      color: const Color(0xFFF8FAFC),
      child: const Row(
        children: [
          Expanded(child: Text('INVOICE', style: _billingHeader)),
          Expanded(child: Text('ORDER', style: _billingHeader)),
          Expanded(flex: 2, child: Text('FRANCHISE', style: _billingHeader)),
          Expanded(child: Text('TOTAL', style: _billingHeader)),
          Expanded(child: Text('PAID', style: _billingHeader)),
          Expanded(child: Text('BALANCE', style: _billingHeader)),
          Expanded(child: Text('DUE DATE', style: _billingHeader)),
          Expanded(child: Text('STATUS', style: _billingHeader)),
          SizedBox(width: 200, child: Text('ACTIONS', style: _billingHeader, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> invoice) {
    final total = _asInt(invoice['total']);

    final paid = _asInt(invoice['paid']);

    final balance = total - paid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(invoice['invoice'].toString(), style: _billingCellBold),
          ),
          Expanded(
            child: Text(invoice['order'].toString(), style: _billingCell),
          ),
          Expanded(
            flex: 2,
            child: Text(invoice['franchise'].toString(), style: _billingCell),
          ),
          Expanded(child: Text(_currency(total), style: _billingCell)),
          Expanded(child: Text(_currency(paid), style: _billingCell)),
          Expanded(
            child: Text(
              _currency(balance),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: balance > 0
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF15803D),
              ),
            ),
          ),
          Expanded(
            child: Text(invoice['dueDate'].toString(), style: _billingCell),
          ),
          Expanded(child: _badge(invoice['status'].toString())),
          SizedBox(
            width: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'View Invoice',
                  onPressed: () {
                    _viewInvoice(invoice);
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                ),

                if (invoice['status'] == 'Payment Verification Required')
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Verify & Approve Payment',
                    onPressed: () {
                      _verifyPayment(invoice);
                    },
                    icon: const Icon(
                      Icons.verified_user_rounded,
                      size: 20,
                      color: Color(0xFFD97706),
                    ),
                  ),

                if (invoice['status'] != 'Paid' && invoice['status'] != 'Payment Verification Required')
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Record Payment',
                    onPressed: () {
                      _recordPayment(invoice);
                    },
                    icon: const Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: Color(0xFF16A34A),
                    ),
                  ),

                if (invoice['status'] != 'Paid')
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Send Payment Reminder',
                    onPressed: () {
                      _sendReminder(invoice);
                    },
                    icon: const Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                      color: Color(0xFFEA580C),
                    ),
                  ),

                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Credit Management',
                  onPressed: () {
                    _manageCredit(invoice);
                  },
                  icon: const Icon(
                    Icons.credit_score_outlined,
                    size: 18,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileList() {
    return Column(
      children: filtered.map((invoice) {
        final total = _asInt(invoice['total']);

        final paid = _asInt(invoice['paid']);

        final balance = total - paid;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: _billingCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice['invoice'].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _badge(invoice['status'].toString()),
                ],
              ),

              const Divider(height: 24),

              _info('Order', invoice['order']),
              _info('Franchise', invoice['franchise']),
              _info('Invoice Date', invoice['date']),
              _info('Due Date', invoice['dueDate']),
              _info('Total', _currency(total)),
              _info('Paid', _currency(paid)),
              _info('Outstanding', _currency(balance)),

              const SizedBox(height: 10),

              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      _viewInvoice(invoice);
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('View'),
                  ),

                  if (invoice['status'] == 'Payment Verification Required')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () {
                        _verifyPayment(invoice);
                      },
                      icon: const Icon(Icons.verified_user_rounded, size: 16),
                      label: const Text('Verify Payment'),
                    ),

                  if (invoice['status'] != 'Paid' && invoice['status'] != 'Payment Verification Required')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () {
                        _recordPayment(invoice);
                      },
                      icon: const Icon(Icons.payments_outlined, size: 16),
                      label: const Text('Payment'),
                    ),

                  if (invoice['status'] != 'Paid')
                    OutlinedButton.icon(
                      onPressed: () {
                        _sendReminder(invoice);
                      },
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                      ),
                      label: const Text('Reminder'),
                    ),

                  OutlinedButton.icon(
                    onPressed: () {
                      _manageCredit(invoice);
                    },
                    icon: const Icon(Icons.credit_score_outlined, size: 16),
                    label: const Text('Credit'),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _reportsSection(bool desktop) {
    final reports = [
      {
        'title': 'Collection Report',
        'subtitle': 'View payment collection summary',
        'icon': Icons.analytics_outlined,
        'action': _collectionReport,
      },
      {
        'title': 'Sales Register',
        'subtitle': 'View invoice-wise sales register',
        'icon': Icons.menu_book_outlined,
        'action': _salesRegister,
      },
      {
        'title': 'Tax Report',
        'subtitle': 'View GST and tax summary',
        'icon': Icons.account_balance_outlined,
        'action': _taxReport,
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _billingCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Billing Reports',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Collection, sales and tax reporting.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          if (desktop)
            Row(
              children: List.generate(reports.length, (index) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == reports.length - 1 ? 0 : 12,
                    ),
                    child: _reportCard(reports[index]),
                  ),
                );
              }),
            )
          else
            Column(
              children: reports
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _reportCard(item),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> item) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: item['action'] as VoidCallback,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item['icon'] as IconData,
                color: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'].toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    item['subtitle'].toString(),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Future<void> _createInvoice() async {
    final orderController = TextEditingController();
    final franchiseController = TextEditingController();
    final subtotalController = TextEditingController();
    final gstController = TextEditingController(text: '18');
    final creditController = TextEditingController(text: '0');
    final notesController = TextEditingController();

    bool created = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final subtotal = int.tryParse(subtotalController.text.trim()) ?? 0;

            final gstPercent = double.tryParse(gstController.text.trim()) ?? 18;

            final creditDays = int.tryParse(creditController.text.trim()) ?? 0;

            final gstAmount = (subtotal * gstPercent / 100).round();

            final grandTotal = subtotal + gstAmount;

            final invoiceDate = DateTime.now();

            final dueDate = invoiceDate.add(Duration(days: creditDays));

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 900,
                  maxHeight: 720,
                ),
                child: Column(
                  children: [
                    // ============================================
                    // HEADER
                    // ============================================
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              color: Color(0xFF0284C7),
                            ),
                          ),

                          const SizedBox(width: 14),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create GST Invoice',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Create invoice, GST and payment details',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),

                    // ============================================
                    // FORM BODY
                    // ============================================
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF8FAFC),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              // ==================================
                              // INVOICE INFORMATION
                              // ==================================
                              _invoiceFormSection(
                                icon: Icons.description_outlined,
                                title: 'Invoice Information',
                                subtitle:
                                    'Order, franchise and invoice details',
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final twoColumn =
                                        constraints.maxWidth >= 650;

                                    final fields = [
                                      _invoiceInput(
                                        controller: orderController,
                                        label: 'Order ID *',
                                        icon: Icons.shopping_bag_outlined,
                                      ),
                                      _invoiceInput(
                                        controller: franchiseController,
                                        label: 'Franchise *',
                                        icon: Icons.store_outlined,
                                      ),
                                      _invoiceReadOnlyField(
                                        label: 'Invoice Date',
                                        value: _formatDate(invoiceDate),
                                        icon: Icons.calendar_today_outlined,
                                      ),
                                      _invoiceInput(
                                        controller: creditController,
                                        label: 'Credit Days',
                                        icon: Icons.credit_score_outlined,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) {
                                          setDialogState(() {});
                                        },
                                      ),
                                    ];

                                    return _invoiceFieldGrid(fields, twoColumn);
                                  },
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ==================================
                              // BILLING DETAILS
                              // ==================================
                              _invoiceFormSection(
                                icon: Icons.calculate_outlined,
                                title: 'Billing Details',
                                subtitle: 'Taxable amount and GST calculation',
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final twoColumn =
                                        constraints.maxWidth >= 650;

                                    final fields = [
                                      _invoiceInput(
                                        controller: subtotalController,
                                        label: 'Subtotal Amount *',
                                        icon: Icons.currency_rupee,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) {
                                          setDialogState(() {});
                                        },
                                      ),
                                      _invoiceInput(
                                        controller: gstController,
                                        label: 'GST %',
                                        icon: Icons.percent,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) {
                                          setDialogState(() {});
                                        },
                                      ),
                                      _invoiceReadOnlyField(
                                        label: 'GST Amount',
                                        value: _currency(gstAmount),
                                        icon: Icons.account_balance_outlined,
                                      ),
                                      _invoiceReadOnlyField(
                                        label: 'Grand Total',
                                        value: _currency(grandTotal),
                                        icon: Icons.payments_outlined,
                                        highlight: true,
                                      ),
                                    ];

                                    return _invoiceFieldGrid(fields, twoColumn);
                                  },
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ==================================
                              // PAYMENT DETAILS
                              // ==================================
                              _invoiceFormSection(
                                icon: Icons.payments_outlined,
                                title: 'Payment Details',
                                subtitle: 'Payment terms and due date',
                                child: Column(
                                  children: [
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final twoColumn =
                                            constraints.maxWidth >= 650;

                                        return _invoiceFieldGrid([
                                          _invoiceReadOnlyField(
                                            label: 'Payment Terms',
                                            value: creditDays == 0
                                                ? 'Immediate Payment'
                                                : '$creditDays Days Credit',
                                            icon: Icons.schedule_outlined,
                                          ),
                                          _invoiceReadOnlyField(
                                            label: 'Due Date',
                                            value: _formatDate(dueDate),
                                            icon: Icons.event_outlined,
                                          ),
                                        ], twoColumn);
                                      },
                                    ),

                                    const SizedBox(height: 14),

                                    TextField(
                                      controller: notesController,
                                      maxLines: 3,
                                      decoration: InputDecoration(
                                        labelText: 'Notes / Remarks',
                                        hintText: 'Optional invoice notes...',
                                        prefixIcon: const Padding(
                                          padding: EdgeInsets.only(bottom: 45),
                                          child: Icon(Icons.notes_outlined),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ============================================
                    // FOOTER
                    // ============================================
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(18),
                        ),
                        border: Border(
                          top: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            child: const Text('Cancel'),
                          ),

                          const SizedBox(width: 12),

                          SizedBox(
                            width: 165,
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                maximumSize: const Size(165, 44),
                              ),
                              onPressed: () {
                                final subtotal = int.tryParse(
                                  subtotalController.text.trim(),
                                );

                                final gstPercent =
                                    double.tryParse(
                                      gstController.text.trim(),
                                    ) ??
                                    18;

                                final creditDays =
                                    int.tryParse(
                                      creditController.text.trim(),
                                    ) ??
                                    0;

                                if (orderController.text.trim().isEmpty ||
                                    franchiseController.text.trim().isEmpty ||
                                    subtotal == null ||
                                    subtotal <= 0) {
                                  AppToast.error(
                                    context,
                                    'Order, franchise and valid subtotal are required.',
                                    title: 'Validation Error',
                                  );
                                  return;
                                }

                                if (gstPercent < 0 || gstPercent > 100) {
                                  AppToast.error(
                                    context,
                                    'Enter valid GST percentage.',
                                    title: 'Invalid GST',
                                  );
                                  return;
                                }

                                if (creditDays < 0) {
                                  AppToast.error(
                                    context,
                                    'Credit days cannot be negative.',
                                    title: 'Invalid Credit',
                                  );
                                  return;
                                }

                                final gstAmount = (subtotal * gstPercent / 100)
                                    .round();

                                final total = subtotal + gstAmount;

                                final invoiceDate = DateTime.now();

                                final dueDate = invoiceDate.add(
                                  Duration(days: creditDays),
                                );

                                setState(() {
                                  invoices.insert(0, {
                                    'invoice':
                                        'INV-${invoiceDate.year}-${100 + invoices.length + 1}',
                                    'order': orderController.text.trim(),
                                    'franchise': franchiseController.text
                                        .trim(),
                                    'date': _formatDate(invoiceDate),
                                    'subtotal': subtotal,
                                    'gst': gstAmount,
                                    'gstPercent': gstPercent,
                                    'total': total,
                                    'paid': 0,
                                    'creditDays': creditDays,
                                    'dueDate': _formatDate(dueDate),
                                    'status': 'Unpaid',
                                    'lastReminder': '-',
                                    'notes': notesController.text.trim(),
                                  });
                                });

                                created = true;

                                Navigator.pop(dialogContext);
                              },
                              icon: const Icon(Icons.save_outlined, size: 17),
                              label: const Text('Create Invoice'),
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
      },
    );

    Future.delayed(const Duration(milliseconds: 600), () {
      orderController.dispose();
      franchiseController.dispose();
      subtotalController.dispose();
      gstController.dispose();
      creditController.dispose();
      notesController.dispose();
    });

    if (created && mounted) {
      AppToast.success(
        context,
        'GST invoice created successfully.',
        title: 'Invoice Created',
      );
    }
  }

  Widget _invoiceFormSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: const Color(0xFF0284C7)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _invoiceInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _invoiceReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    bool highlight = false,
  }) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: value,
      readOnly: true,
      style: TextStyle(
        fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
        color: highlight ? const Color(0xFF0284C7) : const Color(0xFF334155),
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          size: 19,
          color: highlight ? const Color(0xFF0284C7) : null,
        ),
        filled: true,
        fillColor: highlight
            ? const Color(0xFFE0F2FE)
            : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: highlight
                ? const Color(0xFFBAE6FD)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }

  Widget _invoiceFieldGrid(List<Widget> fields, bool twoColumn) {
    if (!twoColumn) {
      return Column(
        children: List.generate(
          fields.length,
          (index) => Padding(
            padding: EdgeInsets.only(
              bottom: index == fields.length - 1 ? 0 : 12,
            ),
            child: fields[index],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < fields.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < fields.length ? 12 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: fields[i]),
                const SizedBox(width: 14),
                Expanded(
                  child: i + 1 < fields.length
                      ? fields[i + 1]
                      : const SizedBox(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _recordPayment(Map<String, dynamic> invoice) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _AdminRecordPaymentDialog(
          invoice: invoice,
          onPaymentRecorded: (amount) {
            final total = _asInt(invoice['total']);
            final paid = _asInt(invoice['paid']);
            final newPaid = paid + amount;

            setState(() {
              invoice['paid'] = newPaid;
              if (newPaid >= total) {
                invoice['status'] = 'Paid';
              } else {
                invoice['status'] = 'Partial';
              }
            });
          },
        );
      },
    );

    if (result == true && mounted) {
      AppToast.success(
        context,
        'Payment recorded successfully.',
        title: 'Payment Recorded',
      );
      _loadBackendInvoices();
    }
  }

  Future<void> _verifyPayment(Map<String, dynamic> invoice) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _AdminVerifyPaymentDialog(
          invoice: invoice,
          onVerified: () {
            _loadBackendInvoices();
          },
        );
      },
    );

    if (result == true && mounted) {
      _loadBackendInvoices();
    }
  }

  Future<void> _sendReminder(Map<String, dynamic> invoice) async {
    final total = _asInt(invoice['total']);

    final paid = _asInt(invoice['paid']);

    final balance = total - paid;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Payment Reminder'),
          content: Text(
            'Send payment reminder to ${invoice['franchise']} for outstanding ${_currency(balance)}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 120,
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  maximumSize: const Size(120, 42),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                icon: const Icon(Icons.send_outlined, size: 16),
                label: const Text('Send'),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      invoice['lastReminder'] = _formatDate(DateTime.now());
    });

    if (!mounted) return;

    AppToast.success(
      context,
      'Payment reminder sent to ${invoice['franchise']}.',
      title: 'Reminder Sent',
    );
  }

  Future<void> _manageCredit(Map<String, dynamic> invoice) async {
    final controller = TextEditingController(
      text: invoice['creditDays'].toString(),
    );

    bool updated = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Credit Management'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _invoiceLine('Franchise', invoice['franchise']),
                _invoiceLine('Invoice', invoice['invoice']),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Credit Period (Days)',
                    helperText: '0 for immediate payment',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 120,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  maximumSize: const Size(120, 42),
                ),
                onPressed: () {
                  final days = int.tryParse(controller.text.trim());

                  if (days == null || days < 0) {
                    AppToast.error(
                      context,
                      'Enter valid credit days.',
                      title: 'Invalid Credit',
                    );
                    return;
                  }

                  final invoiceDate = _parseDate(invoice['date'].toString());

                  setState(() {
                    invoice['creditDays'] = days;

                    invoice['dueDate'] = _formatDate(
                      invoiceDate.add(Duration(days: days)),
                    );
                  });

                  updated = true;

                  Navigator.pop(dialogContext);
                },
                child: const Text('Update'),
              ),
            ),
          ],
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 600), () {
      controller.dispose();
    });

    if (updated && mounted) {
      AppToast.success(
        context,
        'Credit period updated successfully.',
        title: 'Credit Updated',
      );
    }
  }

  void _viewInvoice(Map<String, dynamic> invoice) {
    final total = _asInt(invoice['total']);

    final paid = _asInt(invoice['paid']);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(invoice['invoice'].toString()),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _invoiceLine('Order', invoice['order']),
                  _invoiceLine('Franchise', invoice['franchise']),
                  _invoiceLine('Invoice Date', invoice['date']),
                  _invoiceLine('Due Date', invoice['dueDate']),
                  _invoiceLine(
                    'Credit Period',
                    '${invoice['creditDays']} Days',
                  ),

                  const Divider(height: 28),

                  _invoiceLine(
                    'Subtotal',
                    _currency((invoice['subtotal'] as num).toInt()),
                  ),
                  _invoiceLine(
                    'GST',
                    _currency((invoice['gst'] as num).toInt()),
                  ),
                  _invoiceLine('Grand Total', _currency(total)),
                  _invoiceLine('Paid Amount', _currency(paid)),
                  _invoiceLine('Outstanding', _currency(total - paid)),

                  const Divider(height: 28),

                  _invoiceLine('Payment Status', invoice['status']),
                  _invoiceLine('Last Reminder', invoice['lastReminder']),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _collectionReport() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Collection Report'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _invoiceLine('Total Billing', _currency(totalBilling)),
                _invoiceLine('Total Collected', _currency(totalCollected)),
                _invoiceLine('Outstanding', _currency(totalOutstanding)),
                _invoiceLine(
                  'Collection %',
                  totalBilling == 0
                      ? '0%'
                      : '${((totalCollected / totalBilling) * 100).toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _salesRegister() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sales Register'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: invoices.map((invoice) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(invoice['invoice'].toString())),
                        Expanded(child: Text(invoice['franchise'].toString())),
                        Expanded(
                          child: Text(
                            _currency((invoice['total'] as num).toInt()),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _taxReport() {
    final subtotal = invoices.fold<int>(
      0,
      (sum, item) => sum + ((item['subtotal'] as num?)?.toInt() ?? 0),
    );

    final gst = invoices.fold<int>(
      0,
      (sum, item) => sum + ((item['gst'] as num?)?.toInt() ?? 0),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('GST / Tax Report'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _invoiceLine('Taxable Sales', _currency(subtotal)),
                _invoiceLine('GST Collected', _currency(gst)),
                _invoiceLine('Invoice Value', _currency(subtotal + gst)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _badge(String status) {
    Color background;
    Color foreground;

    if (status.contains('Verification') || status.contains('PENDING') || status == 'Payment Verification Required') {
      background = const Color(0xFFFEF3C7);
      foreground = const Color(0xFFB45309);
    } else {
      switch (status) {
        case 'Paid':
          background = const Color(0xFFECFDF5);
          foreground = const Color(0xFF15803D);
          break;

        case 'Partial':
          background = const Color(0xFFFFF7ED);
          foreground = const Color(0xFFEA580C);
          break;

        default:
          background = const Color(0xFFFEF2F2);
          foreground = const Color(0xFFDC2626);
      }
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }

  Widget _info(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceLine(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          Text(
            value?.toString() ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _currency(int amount) {
    final value = amount.toString();

    if (value.length <= 3) {
      return '₹$value';
    }

    String lastThree = value.substring(value.length - 3);

    String remaining = value.substring(0, value.length - 3);

    if (remaining.length > 2) {
      remaining =
          '${remaining.substring(0, remaining.length - 2)},${remaining.substring(remaining.length - 2)}';
    }

    return '₹$remaining,$lastThree';
  }

  String _formatDate(DateTime date) {
    const months = [
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
      'Dec',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  DateTime _parseDate(String date) {
    final parts = date.split(' ');

    if (parts.length != 3) {
      return DateTime.now();
    }

    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };

    return DateTime(
      int.tryParse(parts[2]) ?? DateTime.now().year,
      months[parts[1]] ?? DateTime.now().month,
      int.tryParse(parts[0]) ?? DateTime.now().day,
    );
  }
}

class _BillingStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _BillingStat({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _billingCard(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0284C7)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _billingCard() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFFE5E7EB)),
  );
}

const TextStyle _billingHeader = TextStyle(
  fontSize: 8.5,
  fontWeight: FontWeight.w700,
  color: Color(0xFF64748B),
  letterSpacing: 0.3,
);

const TextStyle _billingCell = TextStyle(
  fontSize: 10,
  color: Color(0xFF334155),
);

const TextStyle _billingCellBold = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w700,
  color: Color(0xFF111827),
);

class _AdminRecordPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final ValueChanged<int> onPaymentRecorded;

  const _AdminRecordPaymentDialog({
    required this.invoice,
    required this.onPaymentRecorded,
  });

  @override
  State<_AdminRecordPaymentDialog> createState() =>
      _AdminRecordPaymentDialogState();
}

class _AdminRecordPaymentDialogState extends State<_AdminRecordPaymentDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _refController;
  late final TextEditingController _notesController;
  String _paymentMethod = 'UPI';
  bool _isSubmitting = false;

  late final int _total;
  late final int _paid;
  late final int _balance;

  @override
  void initState() {
    super.initState();
    _total = _asInt(widget.invoice['total']);
    _paid = _asInt(widget.invoice['paid']);
    _balance = (_total - _paid).clamp(0, _total);

    _amountController =
        TextEditingController(text: _balance > 0 ? _balance.toString() : '');
    _refController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    final text = _amountController.text.trim();
    final amount = int.tryParse(text);

    if (amount == null || amount <= 0 || amount > _balance) {
      AppToast.error(
        context,
        'Enter a valid payment amount up to ₹$_balance.',
        title: 'Invalid Payment',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final invId = widget.invoice['id'] ?? widget.invoice['invoice_id'];
      if (invId != null) {
        final parsedId = int.tryParse(invId.toString());
        if (parsedId != null && parsedId > 0) {
          await InventoryService().recordPayment(parsedId, {
            'amount': amount,
            'payment_method': _paymentMethod,
            'reference_number': _refController.text.trim(),
            'notes': _notesController.text.trim(),
          });
        }
      }
    } catch (_) {}

    if (!mounted) return;
    widget.onPaymentRecorded(amount);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.payments_outlined, color: Color(0xFF16A34A), size: 24),
          SizedBox(width: 8),
          Text('Record Payment'),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogLine('Invoice', widget.invoice['invoice']?.toString() ?? '-'),
              _dialogLine('Franchise', widget.invoice['franchise']?.toString() ?? '-'),
              _dialogLine('Total Amount', '₹$_total'),
              _dialogLine('Paid Amount', '₹$_paid'),
              _dialogLine(
                'Outstanding',
                '₹$_balance',
                isBold: true,
                color: const Color(0xFFDC2626),
              ),
              const Divider(height: 20),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Payment Amount *',
                  prefixText: '₹ ',
                  helperText: 'Max payable: ₹$_balance',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'UPI',
                    child: Text('UPI', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'Bank Transfer',
                    child: Text(
                      'Bank Transfer (NEFT/RTGS)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Cash',
                    child: Text('Cash', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'Cheque',
                    child: Text('Cheque', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMethod = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _refController,
                decoration: const InputDecoration(
                  labelText: 'Reference Number / UTR',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _isSubmitting ? null : _submitPayment,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Record Payment'),
        ),
      ],
    );
  }

  Widget _dialogLine(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminVerifyPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onVerified;

  const _AdminVerifyPaymentDialog({
    required this.invoice,
    required this.onVerified,
  });

  @override
  State<_AdminVerifyPaymentDialog> createState() =>
      _AdminVerifyPaymentDialogState();
}

class _AdminVerifyPaymentDialogState extends State<_AdminVerifyPaymentDialog> {
  final TextEditingController _notesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Widget _dialogLine(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: color ?? const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.invoice['latest_pending_payment'] as Map<String, dynamic>?;
    final invId = widget.invoice['id'] ?? widget.invoice['invoice_id'];
    final pendingAmount = pending != null
        ? _asInt(pending['amount_paid'])
        : _asInt(widget.invoice['total'] - widget.invoice['paid']);
    final method = pending?['payment_method']?.toString() ?? 'UPI';
    final ref = pending?['reference_number']?.toString() ?? 'Not provided';
    final notes = pending?['notes']?.toString() ?? '';
    final date = pending?['payment_date']?.toString().split('T').first ?? 'Recent';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFFD97706),
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Verify Payment Receipt',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The franchise submitted this payment. Verify that funds have reached your agency bank account or cash collection before approving.',
                style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _dialogLine('Invoice #', widget.invoice['invoice']?.toString() ?? '-'),
                    _dialogLine('Franchise', widget.invoice['franchise']?.toString() ?? '-'),
                    _dialogLine(
                      'Claimed Amount',
                      '₹$pendingAmount',
                      isBold: true,
                      color: const Color(0xFF16A34A),
                    ),
                    _dialogLine('Payment Mode', method),
                    _dialogLine(
                      'UTR / Reference #',
                      ref,
                      isBold: true,
                      color: const Color(0xFF0284C7),
                    ),
                    _dialogLine('Submitted Date', date),
                    if (notes.isNotEmpty) _dialogLine('Dealer Notes', notes),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Verification Notes (Optional)',
                  hintText: 'e.g. Verified with bank statement',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: _isProcessing ? null : () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626)),
              ),
              onPressed: _isProcessing
                  ? null
                  : () async {
                      final reasonCtrl = TextEditingController();
                      final rejectConfirmed = await showDialog<bool>(
                        context: context,
                        builder: (rejectCtx) => AlertDialog(
                          title: const Text('Reject Payment Proof'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Please state why this payment proof could not be verified (e.g. UTR not found in bank statement, incorrect amount):',
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: reasonCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Rejection Reason *',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(rejectCtx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                if (reasonCtrl.text.trim().isEmpty) return;
                                Navigator.pop(rejectCtx, true);
                              },
                              child: const Text('Confirm Reject'),
                            ),
                          ],
                        ),
                      );

                      if (rejectConfirmed == true) {
                        setState(() => _isProcessing = true);
                        final parsedId = int.tryParse(invId.toString()) ?? 0;
                        if (parsedId > 0) {
                          final res = await InventoryService().rejectInvoicePayment(
                            invoiceId: parsedId,
                            reason: reasonCtrl.text.trim(),
                          );
                          if (mounted) {
                            Navigator.pop(context, true);
                            if (res['success'] == true) {
                              AppToast.success(
                                context,
                                'Payment proof rejected. Franchise notified.',
                                title: 'Payment Rejected',
                              );
                              widget.onVerified();
                            } else {
                              AppToast.error(
                                context,
                                res['message']?.toString() ?? 'Failed to reject payment',
                                title: 'Error',
                              );
                            }
                          }
                        }
                      }
                    },
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Reject Proof'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              onPressed: _isProcessing
                  ? null
                  : () async {
                      setState(() => _isProcessing = true);
                      final parsedId = int.tryParse(invId.toString()) ?? 0;
                      if (parsedId > 0) {
                        final res = await InventoryService().verifyInvoicePayment(
                          invoiceId: parsedId,
                          notes: _notesController.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(context, true);
                          if (res['success'] == true) {
                            AppToast.success(
                              context,
                              'Payment verified & approved! Ledger updated.',
                              title: 'Approved',
                            );
                            widget.onVerified();
                          } else {
                            AppToast.error(
                              context,
                              res['message']?.toString() ?? 'Failed to verify payment',
                              title: 'Error',
                            );
                          }
                        }
                      }
                    },
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check, size: 16),
              label: const Text('Approve & Confirm'),
            ),
          ],
        ),
      ],
    );
  }
}
