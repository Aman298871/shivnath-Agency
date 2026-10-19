import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/repositories/franchise_repository.dart';
import '../../../core/widgets/document_preview_dialog.dart';
import 'admin_franchise_detail_screen.dart';

class AdminFranchisesScreen extends StatefulWidget {
  const AdminFranchisesScreen({super.key});

  @override
  State<AdminFranchisesScreen> createState() => _AdminFranchisesScreenState();
}

class _AdminFranchisesScreenState extends State<AdminFranchisesScreen> {
  final FranchiseRepository _franchiseService = FranchiseRepository();

  final List<Map<String, dynamic>> franchises = [];

  bool isLoading = true;
  String? loadError;

  String search = '';
  String statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadFranchises();
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return double.tryParse(value?.toString() ?? '')?.toInt() ?? 0;
  }

  Future<void> _loadFranchises() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    final result = await _franchiseService.getFranchises();

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        isLoading = false;
        loadError =
            result['message']?.toString() ?? 'Unable to load franchises.';
      });
      return;
    }

    final dynamic rawData = result['data'];

    if (rawData is! List) {
      setState(() {
        isLoading = false;
        loadError = 'Invalid franchise data received.';
      });
      return;
    }

    final loaded = rawData.map<Map<String, dynamic>>((raw) {
      final item = Map<String, dynamic>.from(raw as Map);

      final backendStatus =
          item['status']?.toString().toLowerCase() ?? 'pending';

      String uiStatus = 'Pending';

      if (backendStatus == 'approved') {
        uiStatus = 'Active';
      } else if (backendStatus == 'rejected') {
        uiStatus = 'Rejected';
      } else if (backendStatus == 'inactive') {
        uiStatus = 'Inactive';
      } else if (backendStatus == 'suspended') {
        uiStatus = 'Suspended';
      }

      return {
        'id': item['id'],
        'owner': item['owner_name']?.toString() ?? '',
        'phone': item['phone']?.toString() ?? '',
        'email': item['email']?.toString() ?? '',
        'city': item['city']?.toString() ?? '',
        'territory': item['territory']?.toString() ?? '',
        'gst': item['gst_number']?.toString() ?? '',
        'pan': item['pan']?.toString() ?? '',
        'aadhaar': item['aadhaar']?.toString() ?? '',
        'businessName': item['business_name']?.toString() ?? '',
        'fssaiNumber': item['fssai_number']?.toString() ?? '',
        'fssaiBusinessName': item['fssai_business_name']?.toString() ?? '',
        'fssaiStatus': (item['fssai_verification_status']?.toString() ?? 'PENDING_VERIFICATION').toUpperCase(),
        'fssaiExpiryDate': item['fssai_expiry_date']?.toString() ?? '',
        'fssaiCertificateUrl': item['fssai_certificate_url']?.toString() ?? '',
        'fssaiRejectionReason': item['fssai_rejection_reason']?.toString() ?? '',

        'address': item['address']?.toString() ?? '',
        'securityDeposit': _toInt(item['security_deposit']),
        'commission': item['commission']?.toString() ?? '',
        'status': uiStatus,
        'renewalDate': item['renewal_date']?.toString() ?? '',
        'agreement': item['agreement']?.toString() ?? 'Pending',
        'approvalStatus': uiStatus == 'Active' ? 'Approved' : uiStatus,
        'approvalDate': item['approved_at']?.toString(),
        'rejectionReason': item['rejection_reason']?.toString() ?? '',
      };
    }).toList();

    setState(() {
      franchises
        ..clear()
        ..addAll(loaded);

      isLoading = false;
    });
  }

  List<Map<String, dynamic>> get filtered {
    final keyword = search.trim().toLowerCase();

    return franchises.where((item) {
      final matchesSearch =
          keyword.isEmpty ||
          item['owner'].toString().toLowerCase().contains(keyword) ||
          item['phone'].toString().contains(keyword) ||
          item['city'].toString().toLowerCase().contains(keyword) ||
          item['territory'].toString().toLowerCase().contains(keyword);

      final matchesStatus =
          statusFilter == 'All' || item['status'] == statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  int get totalDeposit {
    return franchises.fold<int>(
      0,
      (sum, item) => sum + ((item['securityDeposit'] as num?)?.toInt() ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
                    desktop ? _table() : _mobileList(),
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
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Franchises',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Manage approved franchise partners and territories',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        if (desktop)
          SizedBox(
            width: 180,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(180, 44),
                maximumSize: const Size(180, 44),
              ),
              onPressed: () {
                _openForm();
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Franchise', maxLines: 1, softWrap: false),
            ),
          ),
      ],
    );
  }

  Widget _stats(bool desktop) {
    final data = [
      ['Total Franchises', '${franchises.length}'],
      ['Active', '${franchises.where((e) => e['status'] == 'Active').length}'],
      [
        'Pending Approval',
        '${franchises.where((e) => e['status'] == 'Pending').length}',
      ],
      ['Security Deposit', '₹${(totalDeposit / 100000).toStringAsFixed(1)}L'],
    ];

    if (desktop) {
      return Row(
        children: List.generate(
          data.length,
          (index) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == data.length - 1 ? 0 : 14,
              ),
              child: _MiniStat(title: data[index][0], value: data[index][1]),
            ),
          ),
        ),
      );
    }

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
      itemBuilder: (_, index) {
        return _MiniStat(title: data[index][0], value: data[index][1]);
      },
    );
  }

  Widget _toolbar(bool desktop) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: desktop
          ? Row(
              children: [
                Expanded(child: _searchBox()),
                const SizedBox(width: 14),
                SizedBox(width: 190, child: _statusFilter()),
              ],
            )
          : Column(
              children: [
                _searchBox(),
                const SizedBox(height: 10),
                _statusFilter(),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _openForm();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Franchise'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _searchBox() {
    return TextField(
      onChanged: (value) {
        setState(() {
          search = value;
        });
      },
      decoration: const InputDecoration(
        hintText: 'Search owner, phone, city or territory...',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }

  Widget _statusFilter() {
    return DropdownButtonFormField<String>(
      initialValue: statusFilter,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Status'),
      items: const [
        DropdownMenuItem(
          value: 'All',
          child: Text('All Status', overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        DropdownMenuItem(
          value: 'Active',
          child: Text('Active', overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        DropdownMenuItem(
          value: 'Pending',
          child: Text('Pending', overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        DropdownMenuItem(
          value: 'Inactive',
          child: Text('Inactive', overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        DropdownMenuItem(
          value: 'Suspended',
          child: Text('Suspended', overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        DropdownMenuItem(
          value: 'Rejected',
          child: Text('Rejected', overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
      ],
      onChanged: (value) {
        setState(() {
          statusFilter = value ?? 'All';
        });
      },
    );
  }

  Widget _table() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('FRANCHISE OWNER', style: _headerStyle),
                ),
                Expanded(child: Text('TERRITORY', style: _headerStyle)),
                Expanded(flex: 2, child: Text('GST', style: _headerStyle)),
                Expanded(child: Text('DEPOSIT', style: _headerStyle)),
                Expanded(child: Text('COMMISSION', style: _headerStyle)),
                Expanded(child: Text('AGREEMENT', style: _headerStyle)),
                Expanded(child: Text('STATUS', style: _headerStyle)),
                Expanded(child: Text('RENEWAL', style: _headerStyle)),
                SizedBox(
                  width: 270,
                  child: Text('ACTIONS', style: _headerStyle),
                ),
              ],
            ),
          ),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Text('No franchise found.'),
            )
          else
            ...filtered.map(_desktopRow),
        ],
      ),
    );
  }

  Widget _desktopRow(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['owner'].toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  item['phone'].toString(),
                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                ),
                if ((item['fssaiNumber'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Text(
                          'FSSAI: ${item['fssaiNumber']}',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 4),
                        _fssaiStatusBadge(item['fssaiStatus']?.toString() ?? 'PENDING_VERIFICATION'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              item['territory'].toString(),
              style: const TextStyle(fontSize: 10),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item['gst'].toString(),
              style: const TextStyle(fontSize: 9),
            ),
          ),
          Expanded(
            child: Text(
              '₹${item['securityDeposit']}',
              style: const TextStyle(fontSize: 10),
            ),
          ),
          Expanded(child: Text(item['commission'].toString())),
          Expanded(child: _badge(item['agreement'].toString())),
          Expanded(child: _badge(item['status'].toString())),
          Expanded(
            child: Text(
              item['renewalDate'].toString(),
              style: const TextStyle(fontSize: 9),
            ),
          ),
          SizedBox(
            width: 270,
            child: Row(
              children: [
                if (item['fssaiCertificateUrl'] != null && item['fssaiCertificateUrl'].toString().isNotEmpty)
                  IconButton(
                    tooltip: 'View FSSAI Certificate',
                    onPressed: () {
                      DocumentPreviewDialog.show(
                        context: context,
                        title: 'FSSAI Certificate - ${item['businessName'] ?? item['owner']}',
                        documentUrl: item['fssaiCertificateUrl'].toString(),
                        documentNumber: item['fssaiNumber']?.toString(),
                        documentType: 'FSSAI_CERTIFICATE',
                        verificationStatus: item['fssaiStatus']?.toString(),
                      );
                    },
                    icon: const Icon(Icons.description_outlined, color: Color(0xFF0284C7), size: 17),
                  ),
                IconButton(
                  tooltip: 'Verify FSSAI Status',
                  onPressed: () {
                    _showVerifyFssaiDialog(item);
                  },
                  icon: const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF16A34A),
                    size: 17,
                  ),
                ),
                IconButton(
                  tooltip: 'View Franchise',
                  onPressed: () {
                    _view(item);
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                ),

                // APPROVE / REJECT ONLY FOR PENDING FRANCHISE
                if (item['status'] == 'Pending') ...[
                  IconButton(
                    tooltip: 'Approve Franchise',
                    onPressed: () {
                      _approveFranchise(item);
                    },
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF16A34A),
                      size: 18,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reject Franchise',
                    onPressed: () {
                      _rejectFranchise(item);
                    },
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: Color(0xFFDC2626),
                      size: 18,
                    ),
                  ),
                ],

                IconButton(
                  tooltip: 'View Details',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminFranchiseDetailScreen(
                          franchiseId: _toInt(item['id']),
                          franchiseName:
                              item['name']?.toString() ??
                              item['owner']?.toString() ??
                              'Franchise',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.visibility_outlined,
                    color: Color(0xFF0284C7),
                    size: 17,
                  ),
                ),

                IconButton(
                  tooltip: 'Edit Franchise',
                  onPressed: () {
                    _openForm(item: item);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 17),
                ),

                IconButton(
                  tooltip: 'Delete Franchise',
                  onPressed: () {
                    _delete(item);
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 17,
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
      children: filtered.map((item) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item['owner'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _badge(item['status'].toString()),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF0284C7)),
                  const SizedBox(width: 4),
                  Text(
                    'FSSAI: ${item['fssaiNumber'] != null && item['fssaiNumber'].toString().isNotEmpty ? item['fssaiNumber'] : 'Not Provided'}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  const SizedBox(width: 8),
                  _fssaiStatusBadge(item['fssaiStatus']?.toString() ?? 'PENDING_VERIFICATION'),
                ],
              ),
              const SizedBox(height: 6),
              Text('${item['phone']} • ${item['city']}'),
              const SizedBox(height: 5),
              Text('Territory: ${item['territory']}'),
              const SizedBox(height: 5),
              Text('Deposit: ₹${item['securityDeposit']}'),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                children: [
                  if (item['fssaiCertificateUrl'] != null && item['fssaiCertificateUrl'].toString().isNotEmpty)
                    IconButton(
                      tooltip: 'View FSSAI Certificate',
                      onPressed: () {
                        DocumentPreviewDialog.show(
                          context: context,
                          title: 'FSSAI Certificate - ${item['businessName'] ?? item['owner']}',
                          documentUrl: item['fssaiCertificateUrl'].toString(),
                          documentNumber: item['fssaiNumber']?.toString(),
                          documentType: 'FSSAI_CERTIFICATE',
                          verificationStatus: item['fssaiStatus']?.toString(),
                        );
                      },
                      icon: const Icon(Icons.description_outlined, color: Color(0xFF0284C7)),
                    ),

                  IconButton(
                    tooltip: 'Verify FSSAI Status',
                    onPressed: () {
                      _showVerifyFssaiDialog(item);
                    },
                    icon: const Icon(Icons.verified_user_outlined, color: Color(0xFF16A34A)),
                  ),

                  IconButton(
                    tooltip: 'View',
                    onPressed: () {
                      _view(item);
                    },
                    icon: const Icon(Icons.visibility_outlined),
                  ),

                  if (item['status'] == 'Pending') ...[
                    IconButton(
                      tooltip: 'Approve',
                      onPressed: () {
                        _approveFranchise(item);
                      },
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reject',
                      onPressed: () {
                        _rejectFranchise(item);
                      },
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],

                  IconButton(
                    tooltip: 'View Details',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminFranchiseDetailScreen(
                            franchiseId: _toInt(item['id']),
                            franchiseName:
                                item['name']?.toString() ??
                                item['owner']?.toString() ??
                                'Franchise',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.visibility_outlined,
                      color: Color(0xFF0284C7),
                      size: 17,
                    ),
                  ),

                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () {
                      _openForm(item: item);
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),

                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () {
                      _delete(item);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _badge(String value) {
    Color bg = const Color(0xFFE0F2FE);
    Color fg = const Color(0xFF0284C7);

    if (value == 'Active' || value == 'Uploaded') {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF16A34A);
    } else if (value == 'Pending') {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
    } else if (value == 'Inactive' ||
        value == 'Suspended' ||
        value == 'Rejected') {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          value,
          style: TextStyle(fontSize: 9, color: fg, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    final editing = item != null;

    final owner = TextEditingController(text: item?['owner'] ?? '');
    final phone = TextEditingController(text: item?['phone'] ?? '');
    final email = TextEditingController(text: item?['email'] ?? '');
    final city = TextEditingController(text: item?['city'] ?? '');
    final territory = TextEditingController(text: item?['territory'] ?? '');
    final gst = TextEditingController(text: item?['gst'] ?? '');
    final pan = TextEditingController(text: item?['pan'] ?? '');
    final aadhaar = TextEditingController(text: item?['aadhaar'] ?? '');
    final deposit = TextEditingController(
      text: item?['securityDeposit']?.toString() ?? '',
    );
    final commission = TextEditingController(text: item?['commission'] ?? '');
    final renewal = TextEditingController(text: item?['renewalDate'] ?? '');
    final businessName = TextEditingController(
      text: item?['businessName']?.toString() ?? '',
    );

    final address = TextEditingController(
      text: item?['address']?.toString() ?? '',
    );

    final password = TextEditingController();

    final confirmPassword = TextEditingController();

    String status = item?['status'] ?? 'Pending';
    String agreement = item?['agreement'] ?? 'Pending';

    bool saved = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final desktop = MediaQuery.of(context).size.width >= 900;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: desktop ? 70 : 14,
                vertical: desktop ? 28 : 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: desktop ? 920 : 600,
                  maxHeight: MediaQuery.of(context).size.height * .9,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _formHeader(
                        title: editing ? 'Edit Franchise' : 'Add New Franchise',
                        subtitle:
                            'Manage partner, territory and agreement information',
                        icon: Icons.storefront_outlined,
                        onClose: () {
                          Navigator.pop(dialogContext);
                        },
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(desktop ? 22 : 16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final twoColumns = constraints.maxWidth >= 700;

                              return Column(
                                children: [
                                  _formSection(
                                    title: 'Owner Information',
                                    subtitle:
                                        'Primary franchise contact details',
                                    icon: Icons.person_outline,
                                    child: _formGrid(twoColumns, [
                                      _formField(
                                        owner,
                                        'Owner Name',
                                        Icons.person_outline,
                                        requiredField: true,
                                      ),
                                      _formField(
                                        phone,
                                        'Phone',
                                        Icons.phone_outlined,
                                        requiredField: true,
                                        keyboardType: TextInputType.phone,
                                      ),
                                      _formField(
                                        email,
                                        'Email',
                                        Icons.email_outlined,
                                      ),
                                      _formField(
                                        businessName,
                                        'Business / Franchise Name',
                                        Icons.storefront_outlined,
                                        requiredField: true,
                                      ),
                                      _formField(
                                        city,
                                        'City',
                                        Icons.location_city_outlined,
                                        requiredField: true,
                                      ),
                                      _formField(
                                        address,
                                        'Address',
                                        Icons.location_on_outlined,
                                      ),
                                      if (!editing)
                                        _formField(
                                          password,
                                          'Password',
                                          Icons.lock_outline,
                                          requiredField: true,
                                          obscureText: true,
                                        ),

                                      if (!editing)
                                        _formField(
                                          confirmPassword,
                                          'Confirm Password',
                                          Icons.lock_outline,
                                          requiredField: true,
                                          obscureText: true,
                                        ),
                                    ]),
                                  ),

                                  const SizedBox(height: 18),

                                  _formSection(
                                    title: 'Business Details',
                                    subtitle: 'Territory and legal information',
                                    icon: Icons.business_center_outlined,
                                    child: _formGrid(twoColumns, [
                                      _formField(
                                        territory,
                                        'Territory',
                                        Icons.map_outlined,
                                      ),
                                      _formField(
                                        gst,
                                        'GST Number',
                                        Icons.receipt_long_outlined,
                                      ),
                                      _formField(
                                        pan,
                                        'PAN',
                                        Icons.badge_outlined,
                                      ),
                                      _formField(
                                        aadhaar,
                                        'Aadhaar',
                                        Icons.credit_card_outlined,
                                      ),
                                    ]),
                                  ),

                                  const SizedBox(height: 18),

                                  _formSection(
                                    title: 'Commercial & Agreement',
                                    subtitle:
                                        'Deposit, commission and agreement status',
                                    icon: Icons.handshake_outlined,
                                    child: _formGrid(twoColumns, [
                                      _formField(
                                        deposit,
                                        'Security Deposit',
                                        Icons.currency_rupee,
                                        keyboardType: TextInputType.number,
                                      ),
                                      _formField(
                                        commission,
                                        'Commission',
                                        Icons.percent_outlined,
                                      ),
                                      _formField(
                                        renewal,
                                        'Renewal Date',
                                        Icons.calendar_today_outlined,
                                      ),
                                      _formDropdown(
                                        label: 'Status',
                                        value: status,
                                        items: const [
                                          'Active',
                                          'Pending',
                                          'Inactive',
                                          'Suspended',
                                          'Rejected',
                                        ],
                                        onChanged: (value) {
                                          setDialogState(() {
                                            status = value ?? status;
                                          });
                                        },
                                      ),
                                      _formDropdown(
                                        label: 'Agreement',
                                        value: agreement,
                                        items: const ['Uploaded', 'Pending'],
                                        onChanged: (value) {
                                          setDialogState(() {
                                            agreement = value ?? agreement;
                                          });
                                        },
                                      ),
                                    ]),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      _formFooter(
                        primaryLabel: editing
                            ? 'Update Franchise'
                            : 'Save Franchise',
                        onCancel: () {
                          Navigator.pop(dialogContext);
                        },
                        onSave: () async {
                          if (owner.text.trim().isEmpty ||
                              phone.text.trim().isEmpty ||
                              city.text.trim().isEmpty) {
                            AppToast.error(
                              context,
                              'Owner name, phone and city are required.',
                              title: 'Validation Error',
                            );

                            return;
                          }

                          final parsedDeposit = double.tryParse(
                            deposit.text.trim(),
                          );

                          if (deposit.text.trim().isNotEmpty &&
                              parsedDeposit == null) {
                            AppToast.error(
                              context,
                              'Enter a valid security deposit.',
                              title: 'Invalid Deposit',
                            );

                            return;
                          }

                          final parsedCommission = double.tryParse(
                            commission.text.trim().replaceAll('%', ''),
                          );

                          if (commission.text.trim().isNotEmpty &&
                              parsedCommission == null) {
                            AppToast.error(
                              context,
                              'Enter a valid commission.',
                              title: 'Invalid Commission',
                            );

                            return;
                          }

                          if (parsedCommission != null &&
                              (parsedCommission < 0 ||
                                  parsedCommission > 100)) {
                            AppToast.error(
                              context,
                              'Commission must be between 0 and 100.',
                              title: 'Invalid Commission',
                            );

                            return;
                          }

                          // -----------------------------------
                          // ADD MODE
                          // -----------------------------------

                          if (!editing) {
                            if (businessName.text.trim().isEmpty) {
                              AppToast.error(
                                context,
                                'Business name is required.',
                                title: 'Validation Error',
                              );
                              return;
                            }

                            if (email.text.trim().isEmpty) {
                              AppToast.error(
                                context,
                                'Email is required.',
                                title: 'Validation Error',
                              );
                              return;
                            }

                            if (password.text.length < 6) {
                              AppToast.error(
                                context,
                                'Password must be at least 6 characters.',
                                title: 'Invalid Password',
                              );
                              return;
                            }

                            if (password.text != confirmPassword.text) {
                              AppToast.error(
                                context,
                                'Password and confirm password do not match.',
                                title: 'Password Mismatch',
                              );
                              return;
                            }

                            String backendStatus = 'pending';

                            switch (status) {
                              case 'Active':
                                backendStatus = 'approved';
                                break;

                              case 'Inactive':
                                backendStatus = 'inactive';
                                break;

                              case 'Suspended':
                                backendStatus = 'suspended';
                                break;

                              case 'Rejected':
                                backendStatus = 'rejected';
                                break;

                              case 'Pending':
                              default:
                                backendStatus = 'pending';
                                break;
                            }

                            final result = await _franchiseService
                                .createFranchise({
                                  'owner_name': owner.text.trim(),
                                    'business_name': businessName.text.trim(),
                                    'phone': phone.text.trim(),
                                    'email': email.text.trim(),
                                    'password': password.text,
                                    'city': city.text.trim(),
                                    'address': address.text.trim(),
                                    'territory': territory.text.trim(),
                                    'gst_number': gst.text.trim(),
                                    'pan_number': pan.text.trim(),
                                    'aadhaar_number': aadhaar.text.trim(),
                                    'security_deposit': parsedDeposit ?? 0,
                                    'commission': parsedCommission ?? 0,
                                    'renewal_date': renewal.text.trim(),
                                    'agreement_status': agreement == 'Uploaded'
                                        ? 'uploaded'
                                        : 'pending',
                                    'status': backendStatus,
                                  },
                                );

                            if (!mounted) return;

                            if (result['success'] != true) {
                              if (dialogContext.mounted) {
                                AppToast.error(
                                  dialogContext,
                                  result['message']?.toString() ??
                                      'Unable to create franchise.',
                                );
                              }
                              return;
                            }

                            saved = true;

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            await _loadFranchises();

                            return;
                          }

                          // -----------------------------------
                          // EDIT MODE
                          // -----------------------------------

                          final franchiseId = int.tryParse(
                            item['id']?.toString() ?? '',
                          );

                          if (franchiseId == null) {
                            AppToast.error(
                              context,
                              'Invalid franchise ID.',
                              title: 'Update Failed',
                            );

                            return;
                          }

                          String backendStatus = 'pending';

                          switch (status) {
                            case 'Active':
                              backendStatus = 'approved';
                              break;

                            case 'Inactive':
                              backendStatus = 'inactive';
                              break;

                            case 'Suspended':
                              backendStatus = 'suspended';
                              break;

                            case 'Rejected':
                              backendStatus = 'rejected';
                              break;

                            case 'Pending':
                            default:
                              backendStatus = 'pending';
                              break;
                          }

                          final result = await _franchiseService
                              .updateFranchise(
                                franchiseId,
                                {
                                  'owner_name': owner.text.trim(),

                                  'phone': phone.text.trim(),

                                  'email': email.text.trim(),

                                  'city': city.text.trim(),

                                  'territory': territory.text.trim(),

                                  'gst_number': gst.text.trim(),

                                  'pan_number': pan.text.trim(),

                                  'aadhaar_number': aadhaar.text.trim(),

                                  'security_deposit': parsedDeposit ?? 0,

                                  'commission': parsedCommission ?? 0,

                                  'renewal_date': renewal.text.trim(),

                                  'agreement_status': agreement == 'Uploaded'
                                      ? 'uploaded'
                                      : 'pending',

                                  'status': backendStatus,
                                },
                              );

                          if (!mounted) return;

                          if (result['success'] != true) {
                            if (dialogContext.mounted) {
                              AppToast.error(
                                dialogContext,
                                result['message']?.toString() ??
                                    'Unable to update franchise.',
                              );
                            }

                            return;
                          }

                          saved = true;

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }

                          await _loadFranchises();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved && mounted) {
      AppToast.success(
        context,
        editing
            ? '${owner.text.trim()} updated successfully.'
            : '${owner.text.trim()} added successfully.',
        title: editing ? 'Franchise Updated' : 'Franchise Added',
      );
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      owner.dispose();
      phone.dispose();
      email.dispose();
      city.dispose();
      territory.dispose();
      gst.dispose();
      pan.dispose();
      aadhaar.dispose();
      deposit.dispose();
      commission.dispose();
      renewal.dispose();
      businessName.dispose();
      address.dispose();
      password.dispose();
      confirmPassword.dispose();
    });
  }

  Widget _formHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onClose,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0284C7)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
        ],
      ),
    );
  }

  Widget _formSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF0284C7)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
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

  Widget _formGrid(bool twoColumns, List<Widget> fields) {
    if (!twoColumns) {
      return Column(
        children: List.generate(
          fields.length,
          (index) => Padding(
            padding: EdgeInsets.only(
              bottom: index == fields.length - 1 ? 0 : 14,
            ),
            child: fields[index],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 14,
      children: fields
          .map(
            (field) => ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width > 440
                    ? 405
                    : double.infinity,
              ),
              child: field,
            ),
          )
          .toList(),
    );
  }

  Widget _formField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool requiredField = false,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0284C7)),
        ),
      ),
    );
  }

  Widget _formDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final effectiveItems = items.toSet().toList();
    if (value.isNotEmpty && !effectiveItems.contains(value)) {
      effectiveItems.insert(0, value);
    } else if (value.isEmpty && !effectiveItems.contains('')) {
      effectiveItems.insert(0, '');
    }

    final safeValue = effectiveItems.contains(value)
        ? value
        : (effectiveItems.isNotEmpty ? effectiveItems.first : null);

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0284C7)),
        ),
      ),
      items: effectiveItems
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(
                e.isEmpty ? 'Select' : e,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _formFooter({
    required String primaryLabel,
    required VoidCallback onCancel,
    required VoidCallback onSave,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 95,
            height: 44,
            child: TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 175,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
                maximumSize: const Size(175, 44),
              ),
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(primaryLabel, maxLines: 1, softWrap: false),
            ),
          ),
        ],
      ),
    );
  }

  void _view(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(item['owner']),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Phone', item['phone']),
                _detailRow('Email', item['email']),
                _detailRow('City', item['city']),
                _detailRow('Territory', item['territory']),
                _detailRow('GST', item['gst']),
                _detailRow(
                  'FSSAI Number',
                  item['fssaiNumber'] != null && item['fssaiNumber'].toString().isNotEmpty
                      ? item['fssaiNumber']
                      : 'Not Provided',
                ),
                _detailRow('FSSAI Status', item['fssaiStatus']),
                if ((item['fssaiRejectionReason'] ?? '').toString().isNotEmpty)
                  _detailRow('FSSAI Reason', item['fssaiRejectionReason']),
                if (item['fssaiCertificateUrl'] != null && item['fssaiCertificateUrl'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                      ),
                      onPressed: () {
                        DocumentPreviewDialog.show(
                          context: context,
                          title: 'FSSAI Certificate - ${item['businessName'] ?? item['owner']}',
                          documentUrl: item['fssaiCertificateUrl'].toString(),
                          documentNumber: item['fssaiNumber']?.toString(),
                          documentType: 'FSSAI_CERTIFICATE',
                          verificationStatus: item['fssaiStatus']?.toString(),
                        );
                      },
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: const Text('View FSSAI Certificate'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _detailRow('Security Deposit', '₹${item['securityDeposit']}'),
                _detailRow('Commission', item['commission']),
                _detailRow('Agreement', item['agreement']),
                _detailRow('Status', item['status']),
                if (item['approvalStatus'] != null)
                  _detailRow('Approval Status', item['approvalStatus']),

                if (item['approvalDate'] != null)
                  _detailRow('Approval Date', item['approvalDate']),

                if ((item['rejectionReason'] ?? '').toString().isNotEmpty)
                  _detailRow('Rejection Reason', item['rejectionReason']),
                _detailRow('Renewal', item['renewalDate']),
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

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 145,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value?.toString() ?? '-')),
        ],
      ),
    );
  }

  Future<void> _showVerifyFssaiDialog(Map<String, dynamic> item) async {
    final franchiseId = _toInt(item['id']);
    if (franchiseId <= 0) {
      AppToast.error(context, 'Invalid franchise ID.');
      return;
    }

    String selectedAction = 'VERIFIED';
    final currentStatus = (item['fssaiStatus']?.toString() ?? 'PENDING_VERIFICATION').toUpperCase();
    if (currentStatus == 'FAILED') {
      selectedAction = 'FAILED';
    } else if (currentStatus == 'MANUAL_REVIEW_REQUIRED') {
      selectedAction = 'MANUAL_REVIEW_REQUIRED';
    }

    final officialNameCtrl = TextEditingController(text: item['fssaiBusinessName']?.toString() ?? item['businessName']?.toString() ?? '');
    final officialExpiryCtrl = TextEditingController(text: item['fssaiExpiryDate']?.toString() ?? '');
    final notesCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: item['fssaiRejectionReason']?.toString() ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isMobile = MediaQuery.of(ctx).size.width < 600;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verify FSSAI: ${item['businessName'] ?? item['owner']}',
                    style: TextStyle(fontSize: isMobile ? 15 : 17, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isMobile ? 360 : 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'FSSAI Number: ${item['fssaiNumber'] != null && item['fssaiNumber'].toString().isNotEmpty ? item['fssaiNumber'] : 'Not Provided'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                                ),
                              ),
                              _fssaiStatusBadge(currentStatus),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Franchise Owner: ${item['owner'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final uri = Uri.parse('https://foscos.fssai.gov.in/');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: const Row(
                              children: [
                                Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF0284C7)),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Lookup on Official FoSCoS Portal (https://foscos.fssai.gov.in)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF0284C7),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item['fssaiCertificateUrl'] != null && item['fssaiCertificateUrl'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                DocumentPreviewDialog.show(
                                  context: ctx,
                                  title: 'FSSAI Certificate - ${item['businessName'] ?? item['owner']}',
                                  documentUrl: item['fssaiCertificateUrl'].toString(),
                                  documentNumber: item['fssaiNumber']?.toString(),
                                  documentType: 'FSSAI_CERTIFICATE',
                                  verificationStatus: item['fssaiStatus']?.toString(),
                                );
                              },
                              child: const Row(
                                children: [
                                  Icon(Icons.description_outlined, size: 14, color: Color(0xFF0284C7)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Preview Uploaded Certificate',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF0284C7),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Verification Decision *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'VERIFIED', label: Text('Verified', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 'MANUAL_REVIEW_REQUIRED', label: Text('Review', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 'FAILED', label: Text('Failed', style: TextStyle(fontSize: 12))),
                      ],
                      selected: {selectedAction},
                      onSelectionChanged: (set) {
                        setDialogState(() {
                          selectedAction = set.first;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: officialNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Official Business Name (on FoSCoS portal)',
                        hintText: 'Exact FBO name returned by FoSCoS',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: officialExpiryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Official Validity Expiry (YYYY-MM-DD)',
                        hintText: 'e.g. 2027-12-31',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    if (selectedAction == 'FAILED' || selectedAction == 'MANUAL_REVIEW_REQUIRED') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: selectedAction == 'FAILED' ? 'Rejection Reason *' : 'Review Reason',
                          hintText: selectedAction == 'FAILED'
                              ? 'Explain why certificate failed verification...'
                              : 'Reason for manual review / mismatch notes...',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Internal Audit Notes',
                        hintText: 'Optional remarks for audit history...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedAction == 'FAILED'
                      ? const Color(0xFFDC2626)
                      : (selectedAction == 'VERIFIED' ? const Color(0xFF16A34A) : const Color(0xFFD97706)),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (selectedAction == 'FAILED' && reasonCtrl.text.trim().isEmpty) {
                    AppToast.error(ctx, 'Rejection reason is required when marking FSSAI as FAILED.');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: Text('Submit $selectedAction'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      final res = await _franchiseService.verifyFranchiseFSSAI(
        franchiseId: franchiseId,
        action: selectedAction,
        notes: notesCtrl.text.trim(),
        reason: reasonCtrl.text.trim(),
        officialBusinessName: officialNameCtrl.text.trim(),
        officialExpiryDate: officialExpiryCtrl.text.trim().isNotEmpty ? officialExpiryCtrl.text.trim() : null,
      );

      if (!mounted) return;
      if (res['success'] == true) {
        AppToast.success(context, res['message']?.toString() ?? 'FSSAI status updated successfully');
        await _loadFranchises();
      } else {
        AppToast.error(context, res['message']?.toString() ?? 'Failed to update FSSAI status');
      }
    }
  }

  Future<void> _approveFranchise(Map<String, dynamic> item) async {
    final fssaiStatus = (item['fssaiStatus']?.toString() ?? 'PENDING_VERIFICATION').toUpperCase();

    if (fssaiStatus == 'FAILED' || fssaiStatus == 'EXPIRED') {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.block_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 10),
              Text('Approval Blocked'),
            ],
          ),
          content: Text(
            'Cannot approve franchise: Mandatory FSSAI verification is marked as $fssaiStatus.\n\n'
            'Reason: ${item['fssaiRejectionReason'] ?? 'Non-compliant or invalid certificate.'}\n\n'
            'The franchise partner must rectify regulatory compliance before approval.',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    String? overrideReason;
    if (fssaiStatus != 'VERIFIED') {
      final overrideCtrl = TextEditingController();
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
              SizedBox(width: 10),
              Text('FSSAI Not Yet Verified'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FSSAI Status: $fssaiStatus.\n'
                'Approving an unverified franchise requires a Super Admin regulatory override reason.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: overrideCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Override Justification *',
                  hintText: 'Enter reason for approving without verified FSSAI...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
              onPressed: () {
                if (overrideCtrl.text.trim().isEmpty) {
                  AppToast.error(ctx, 'Override justification is required.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Proceed with Override'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      overrideReason = overrideCtrl.text.trim();
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
                SizedBox(width: 10),
                Text('Approve Franchise'),
              ],
            ),
            content: Text(
              'Are you sure you want to approve ${item['owner']} as an active franchise partner?\n'
              'FSSAI certificate is VERIFIED.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              SizedBox(
                width: 110,
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    maximumSize: const Size(110, 42),
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  icon: const Icon(Icons.check, size: 17),
                  label: const Text('Approve'),
                ),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }

    final franchiseId = int.tryParse(item['id']?.toString() ?? '');

    if (franchiseId == null) {
      if (!mounted) return;

      AppToast.error(
        context,
        'Invalid franchise ID.',
        title: 'Approval Failed',
      );
      return;
    }

    final result = await _franchiseService.approveFranchise(
      franchiseId,
      overrideReason: overrideReason,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      AppToast.error(
        context,
        result['message']?.toString() ?? 'Unable to approve franchise.',
        title: 'Approval Failed',
      );
      return;
    }

    await _loadFranchises();

    if (!mounted) return;

    AppToast.success(
      context,
      '${item['owner']} has been approved successfully.',
      title: 'Franchise Approved',
    );
  }

  Widget _fssaiStatusBadge(String status) {
    Color bg;
    Color fg;
    final upper = status.toUpperCase();

    switch (upper) {
      case 'VERIFIED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'PENDING':
      case 'PENDING_VERIFICATION':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF0284C7);
        break;
      case 'MANUAL_REVIEW_REQUIRED':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case 'FAILED':
      case 'REJECTED':
      case 'EXPIRED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        upper.replaceAll('_', ' '),
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _todayDate() {
    final now = DateTime.now();

    final day = now.day.toString().padLeft(2, '0');

    final month = now.month.toString().padLeft(2, '0');

    return '$day/$month/${now.year}';
  }

  Future<void> _rejectFranchise(Map<String, dynamic> item) async {
    final reasonController = TextEditingController();

    String? rejectionReason;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
              SizedBox(width: 10),
              Text('Reject Franchise'),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reject ${item['owner']} franchise application?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: reasonController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason *',
                    hintText: 'Enter reason for rejection...',
                    alignLabelWithHint: true,
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
              width: 110,
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  maximumSize: const Size(110, 42),
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final reason = reasonController.text.trim();

                  if (reason.isEmpty) {
                    AppToast.error(
                      context,
                      'Please enter rejection reason.',
                      title: 'Rejection Reason Required',
                    );
                    return;
                  }

                  setState(() {
                    item['status'] = 'Rejected';
                    item['approvalStatus'] = 'Rejected';
                    item['rejectionReason'] = reason;
                    item['approvalDate'] = _todayDate();
                  });

                  rejectionReason = reason;

                  Navigator.pop(dialogContext);
                },
                icon: const Icon(Icons.close, size: 17),
                label: const Text('Reject'),
              ),
            ),
          ],
        );
      },
    );

    final name = item['owner']?.toString() ?? 'Franchise';

    Future.delayed(const Duration(milliseconds: 600), () {
      reasonController.dispose();
    });

    if (rejectionReason == null || rejectionReason!.trim().isEmpty) {
      return;
    }

    final franchiseId = int.tryParse(item['id']?.toString() ?? '');

    if (franchiseId == null) {
      if (!mounted) return;

      AppToast.error(
        context,
        'Invalid franchise ID.',
        title: 'Rejection Failed',
      );
      return;
    }

    final result = await _franchiseService.rejectFranchise(
      franchiseId: franchiseId,
      reason: rejectionReason!,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      AppToast.error(
        context,
        result['message']?.toString() ?? 'Unable to reject franchise.',
        title: 'Rejection Failed',
      );
      return;
    }

    await _loadFranchises();

    if (!mounted) return;
    AppToast.success(
      context,
      '$name franchise application has been rejected.',
      title: 'Franchise Rejected',
    );
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Franchise'),
          content: Text(
            'Are you sure you want to permanently delete ${item['owner']}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (yes != true) {
      return;
    }

    final franchiseId = int.tryParse(item['id']?.toString() ?? '');

    if (franchiseId == null) {
      if (!mounted) return;

      AppToast.error(context, 'Invalid franchise ID.', title: 'Delete Failed');

      return;
    }

    final name = item['owner']?.toString() ?? 'Franchise';

    final result = await _franchiseService.deleteFranchise(franchiseId);

    if (!mounted) return;

    if (result['success'] != true) {
      AppToast.error(
        context,
        result['message']?.toString() ?? 'Unable to delete franchise.',
        title: 'Delete Failed',
      );

      return;
    }

    await _loadFranchises();

    if (!mounted) return;

    AppToast.success(
      context,
      '$name deleted successfully.',
      title: 'Franchise Deleted',
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final String value;

  const _MiniStat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

const _headerStyle = TextStyle(
  fontSize: 8.5,
  fontWeight: FontWeight.w700,
  color: Color(0xFF64748B),
);
