import 'package:flutter/material.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/services/franchise_service.dart';
import 'admin_franchise_detail_screen.dart';

class AdminFranchisesScreen extends StatefulWidget {
  const AdminFranchisesScreen({super.key});

  @override
  State<AdminFranchisesScreen> createState() => _AdminFranchisesScreenState();
}

class _AdminFranchisesScreenState extends State<AdminFranchisesScreen> {
  final FranchiseService _franchiseService = FranchiseService();

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
      decoration: const InputDecoration(labelText: 'Status'),
      items: const [
        DropdownMenuItem(value: 'All', child: Text('All Status')),
        DropdownMenuItem(value: 'Active', child: Text('Active')),
        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
        DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
        DropdownMenuItem(value: 'Suspended', child: Text('Suspended')),
        DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
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
                  width: 200,
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
            width: 200,
            child: Row(
              children: [
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
              const SizedBox(height: 8),
              Text('${item['phone']} • ${item['city']}'),
              const SizedBox(height: 5),
              Text('Territory: ${item['territory']}'),
              const SizedBox(height: 5),
              Text('Deposit: ₹${item['securityDeposit']}'),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                children: [
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
                                .createFranchise(
                                  data: {
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
                              AppToast.error(
                                context,
                                result['message']?.toString() ??
                                    'Unable to create franchise.',
                                title: 'Create Failed',
                              );
                              return;
                            }

                            saved = true;

                            Navigator.pop(dialogContext);

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
                                franchiseId: franchiseId,
                                data: {
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
                            AppToast.error(
                              context,
                              result['message']?.toString() ??
                                  'Unable to update franchise.',
                              title: 'Update Failed',
                            );

                            return;
                          }

                          saved = true;

                          Navigator.pop(dialogContext);

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
              child: Text(e.isEmpty ? 'Select' : e),
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
                _detailRow('PAN', item['pan']),
                _detailRow('Aadhaar', item['aadhaar']),
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

  Future<void> _approveFranchise(Map<String, dynamic> item) async {
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
            'Are you sure you want to approve ${item['owner']} as an active franchise partner?',
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

    if (confirmed != true) {
      return;
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

    final result = await _franchiseService.approveFranchise(franchiseId);

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
