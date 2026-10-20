import 'package:flutter/material.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/services/supplier_service.dart';

class AdminSuppliersScreen extends StatefulWidget {
  const AdminSuppliersScreen({super.key});

  @override
  State<AdminSuppliersScreen> createState() => _AdminSuppliersScreenState();
}

class _AdminSuppliersScreenState extends State<AdminSuppliersScreen> {
  final SupplierService _supplierService = SupplierService();

  List<Map<String, dynamic>> _suppliers = [];

  bool loading = true;
  @override
  void initState() {
    super.initState();
    loadSuppliers();
  }

  Future<void> loadSuppliers() async {
    setState(() {
      loading = true;
    });

    final result = await _supplierService.getSuppliers(
      search: _search,
      status: _status,
    );

    if (result["success"] == true) {
      final data = result["data"]["suppliers"] as List;

      _suppliers = List<Map<String, dynamic>>.from(data);
    } else {
      if (mounted) {
        AppToast.error(
          context,

          result["message"] ?? "Unable to load suppliers.",
        );
      }
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  String _search = '';
  String _status = 'All';

  List<Map<String, dynamic>> get _filtered {
    final query = _search.trim().toLowerCase();

    return _suppliers.where((supplier) {
      final matchSearch =
          query.isEmpty ||
          supplier['name'].toString().toLowerCase().contains(query) ||
          supplier['contact'].toString().toLowerCase().contains(query) ||
          supplier['phone'].toString().contains(query);

      final matchStatus =
          _status == 'All' || supplier['status'].toString() == _status;

      return matchSearch && matchStatus;
    }).toList();
  }

  int get _active => _suppliers.where((e) => e['status'] == 'Active').length;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Container(
          color: const Color(0xFFF5F7FB),
          width: double.infinity,
          height: double.infinity,
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
                    desktop ? _desktopTable() : _mobileCards(),
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
                'Suppliers',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 5),
              Text(
                'Manage suppliers and vendor information',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
        if (desktop)
          SizedBox(
            width: 155,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(155, 44),
                maximumSize: const Size(155, 44),
              ),
              onPressed: _supplierForm,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Supplier', maxLines: 1, softWrap: false),
            ),
          ),
      ],
    );
  }

  Widget _stats(bool desktop) {
    final data = [
      [
        'Total Suppliers',
        '${_suppliers.length}',
        Icons.local_shipping_outlined,
      ],
      ['Active Suppliers', '$_active', Icons.verified_outlined],
      ['Purchase Orders', '0', Icons.receipt_long_outlined],
      ['Pending Payment', '', Icons.account_balance_wallet_outlined],
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
          childAspectRatio: 1.1,
        ),
        itemBuilder: (_, i) => _StatCard(
          title: data[i][0] as String,
          value: data[i][1] as String,
          icon: data[i][2] as IconData,
        ),
      );
    }

    return Row(
      children: List.generate(data.length, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == data.length - 1 ? 0 : 14),
            child: _StatCard(
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
    final search = TextField(
      onChanged: (value) async {
        _search = value;

        await loadSuppliers();
      },
      decoration: const InputDecoration(
        hintText: 'Search supplier, contact or phone...',
        prefixIcon: Icon(Icons.search),
      ),
    );

    final filter = DropdownButtonFormField<String>(
      initialValue: _status,
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
          value: 'Inactive',
          child: Text('Inactive', overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
      ],
      onChanged: (value) async {
        if (value == null) return;

        _status = value;

        await loadSuppliers();
      },
    );

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: desktop
          ? Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 14),
                SizedBox(width: 190, child: filter),
              ],
            )
          : Column(
              children: [
                search,
                const SizedBox(height: 10),
                filter,
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _supplierForm,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Supplier'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _desktopTable() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _row(
            header: true,
            values: const [
              'SUPPLIER',
              'CATEGORY',
              'PHONE',
              'CITY',
              'GST',
              'STATUS',
              'ACTION',
            ],
          ),
          if (_filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(50),
              child: Text('No suppliers found'),
            )
          else
            ..._filtered.map(
              (e) => _row(
                supplier: e,
                values: [
                  e['name'],
                  e['category'],
                  e['phone'],
                  e['city'],
                  e['gst'],
                  e['status'],
                  '',
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row({
    required List<dynamic> values,
    bool header = false,
    Map<String, dynamic>? supplier,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: header ? const Color(0xFFF8FAFC) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: List.generate(values.length, (i) {
          if (!header && i == 5) {
            return Expanded(
              child: _statusBadge(supplier!['status'].toString()),
            );
          }

          if (!header && i == 6) {
            return SizedBox(
              width: 100,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _supplierForm(supplier: supplier),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    onPressed: () => _deleteSupplier(supplier!),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            );
          }

          final text = Text(
            values[i].toString(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: header ? 9 : 11,
              fontWeight: header ? FontWeight.w700 : FontWeight.w500,
              color: header ? const Color(0xFF64748B) : const Color(0xFF1E293B),
            ),
          );

          if (i == 0) return Expanded(flex: 2, child: text);
          if (i == 6) return SizedBox(width: 100, child: text);
          return Expanded(child: text);
        }),
      ),
    );
  }

  Widget _mobileCards() {
    if (_filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text('No suppliers found'),
        ),
      );
    }

    return Column(
      children: _filtered.map((supplier) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supplier['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${supplier['contact']} • ${supplier['phone']}',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(supplier['status']),
                ],
              ),
              const Divider(height: 24),
              _info('Category', supplier['category']),
              _info('City', supplier['city']),
              _info('GST', supplier['gst']),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => _supplierForm(supplier: supplier),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () => _deleteSupplier(supplier),
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

  Widget _info(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final active = status == 'Active';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFF15803D) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Future<void> _supplierForm({Map<String, dynamic>? supplier}) async {
    final editing = supplier != null;

    final name = TextEditingController(text: supplier?['name'] ?? '');
    final contact = TextEditingController(text: supplier?['contact'] ?? '');
    final phone = TextEditingController(text: supplier?['phone'] ?? '');
    final email = TextEditingController(text: supplier?['email'] ?? '');
    final category = TextEditingController(text: supplier?['category'] ?? '');
    final gst = TextEditingController(text: supplier?['gst'] ?? '');
    final city = TextEditingController(text: supplier?['city'] ?? '');

    String status = supplier?['status'] ?? 'Active';
    bool saved = false;
    String savedName = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, updateDialog) {
            final desktop = MediaQuery.of(context).size.width >= 800;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: desktop ? 70 : 14,
                vertical: desktop ? 30 : 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 900,
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
                      _dialogHeader(
                        editing ? 'Edit Supplier' : 'Add Supplier',
                        'Manage supplier, contact and business information',
                        () => Navigator.pop(dialogContext),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(desktop ? 22 : 16),
                          child: Column(
                            children: [
                              _section(
                                title: 'Supplier Information',
                                subtitle: 'Basic vendor and contact details',
                                icon: Icons.business_outlined,
                                child: _grid(desktop, [
                                  _field(
                                    name,
                                    'Supplier Name *',
                                    Icons.business_outlined,
                                  ),
                                  _field(
                                    contact,
                                    'Contact Person',
                                    Icons.person_outline,
                                  ),
                                  _field(
                                    phone,
                                    'Phone Number *',
                                    Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                  ),
                                  _field(
                                    email,
                                    'Email Address',
                                    Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 18),
                              _section(
                                title: 'Business Details',
                                subtitle: 'Category, GST and operating city',
                                icon: Icons.apartment_outlined,
                                child: _grid(desktop, [
                                  _field(
                                    category,
                                    'Category',
                                    Icons.category_outlined,
                                  ),
                                  _field(
                                    gst,
                                    'GSTIN',
                                    Icons.receipt_long_outlined,
                                  ),
                                  _field(
                                    city,
                                    'City',
                                    Icons.location_city_outlined,
                                  ),
                                  _dropdown(
                                    label: 'Status',
                                    value: status,
                                    icon: Icons.toggle_on_outlined,
                                    items: const ['Active', 'Inactive'],
                                    onChanged: (value) {
                                      if (value != null) {
                                        updateDialog(() => status = value);
                                      }
                                    },
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 15,
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
                            SizedBox(
                              width: 95,
                              height: 44,
                              child: TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 155,
                              height: 44,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(155, 44),
                                  maximumSize: const Size(155, 44),
                                ),
                                onPressed: () async {
                                  final supplierName = name.text.trim();
                                  final phoneNumber = phone.text.trim();

                                  if (supplierName.isEmpty ||
                                      phoneNumber.isEmpty) {
                                    AppToast.error(
                                      context,
                                      'Supplier name and phone are required.',
                                      title: 'Validation Error',
                                    );
                                    return;
                                  }

                                  if (phoneNumber.length < 10) {
                                    AppToast.error(
                                      context,
                                      'Please enter a valid phone number.',
                                      title: 'Invalid Phone',
                                    );
                                    return;
                                  }
                                  final body = {
                                    "name": supplierName,

                                    "contact": contact.text.trim(),

                                    "phone": phoneNumber,

                                    "email": email.text.trim(),

                                    "category": category.text.trim(),

                                    "gst": gst.text.trim(),

                                    "city": city.text.trim(),

                                    "status": status,
                                  };

                                  Map<String, dynamic> result;

                                  if (editing) {
                                    result = await _supplierService
                                        .updateSupplier(supplier["id"], body);
                                  } else {
                                    result = await _supplierService
                                        .createSupplier(body);
                                  }

                                  if (result["success"]) {
                                    await loadSuppliers();

                                    saved = true;

                                    savedName = supplierName;

                                    Navigator.pop(dialogContext);
                                  } else {
                                    AppToast.error(context, result["message"]);
                                  }
                                },
                                icon: const Icon(Icons.save_outlined, size: 17),
                                label: Text(
                                  editing ? 'Update Supplier' : 'Save Supplier',
                                  maxLines: 1,
                                  softWrap: false,
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
            );
          },
        );
      },
    );

    if (saved && mounted) {
      AppToast.success(
        context,
        editing
            ? '$savedName updated successfully.'
            : '$savedName added successfully.',
        title: editing ? 'Supplier Updated' : 'Supplier Added',
      );
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      name.dispose();
      contact.dispose();
      phone.dispose();
      email.dispose();
      category.dispose();
      gst.dispose();
      city.dispose();
    });
  }

  Widget _dialogHeader(String title, String subtitle, VoidCallback close) {
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Color(0xFF0284C7),
            ),
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
          IconButton(onPressed: close, icon: const Icon(Icons.close_rounded)),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
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

  Widget _grid(bool desktop, List<Widget> fields) {
    if (!desktop) {
      return Column(
        children: List.generate(
          fields.length,
          (i) => Padding(
            padding: EdgeInsets.only(bottom: i == fields.length - 1 ? 0 : 14),
            child: fields[i],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (_, constraints) {
        final width = (constraints.maxWidth - 16) / 2;

        return Wrap(
          spacing: 16,
          runSpacing: 14,
          children: fields
              .map((field) => SizedBox(width: width, child: field))
              .toList(),
        );
      },
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label, icon),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: _inputDecoration(label, icon),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis, maxLines: 1),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
      ),
    );
  }

  Future<void> _deleteSupplier(Map<String, dynamic> supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        title: const Text('Delete Supplier'),
        content: Text('Are you sure you want to delete ${supplier['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supplierName = supplier['name'].toString();

    final response = await _supplierService.deleteSupplier(supplier["id"]);

    if (response["success"]) {
      await loadSuppliers();
    } else {
      AppToast.error(context, response["message"]);

      return;
    }

    if (!mounted) return;

    AppToast.success(
      context,
      '$supplierName deleted successfully.',
      title: 'Supplier Deleted',
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0284C7), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
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

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFFE5E7EB)),
  );
}
