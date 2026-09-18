import 'package:flutter/material.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/services/InventoryService.dart';
import 'admin_stock_management_screen.dart';

class AdminInventoryScreen extends StatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  State<AdminInventoryScreen> createState() =>
      _AdminInventoryScreenState();
}

class _AdminInventoryScreenState
    extends State<AdminInventoryScreen> {
  final InventoryService _inventoryService =
      InventoryService();

  List<Map<String, dynamic>> inventory = [];
  List<Map<String, dynamic>> stockRequests = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    final itemsResult = await _inventoryService.getItems();
    final requestsResult =
        await _inventoryService.getStockRequests();

    if (!mounted) return;

    if (itemsResult['success'] == true) {
      final List<dynamic> items =
          itemsResult['data']['items'] ?? [];

      inventory = items
          .map(
            (item) => _inventoryService.mapItem(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } else {
      AppToast.error(
        context,
        itemsResult['message'] ??
            'Failed to load inventory.',
        title: 'Unable to Load',
      );
    }

    if (requestsResult['success'] == true) {
      final List<dynamic> requests =
          requestsResult['data']['requests'] ?? [];

      stockRequests = requests
          .map(
            (item) => _inventoryService.mapStockRequest(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    setState(() {
      isLoading = false;
    });
  }

  int get pendingApprovals {
    return stockRequests
        .where((e) => e['status'] == 'Pending')
        .length;
  }

  String search = '';
  String typeFilter = 'All';

  List<Map<String, dynamic>> get filtered {
    final key = search.trim().toLowerCase();

    return inventory.where((item) {
      final matchesSearch =
          key.isEmpty ||
          item['name']
              .toString()
              .toLowerCase()
              .contains(key) ||
          item['sku']
              .toString()
              .toLowerCase()
              .contains(key) ||
          item['supplier']
              .toString()
              .toLowerCase()
              .contains(key);

      final matchesType =
          typeFilter == 'All' ||
          item['type'] == typeFilter;

      return matchesSearch && matchesType;
    }).toList();
  }

  int get lowStock {
    return inventory
        .where(
          (item) =>
              (item['stock'] as num) <=
              (item['minStock'] as num),
        )
        .length;
  }

  double get totalValue {
    return inventory.fold<double>(
      0,
      (sum, item) =>
          sum +
          ((item['stock'] as num).toDouble() *
              (item['purchaseRate'] as num)
                  .toDouble()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final desktop =
            constraints.maxWidth >= 900;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF5F7FB),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              desktop ? 28 : 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 1350,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _header(desktop),
                    const SizedBox(height: 14),
                    _customerStockBanner(),
                    const SizedBox(height: 16),
                    _stats(desktop),
                    const SizedBox(height: 20),
                    _toolbar(desktop),
                    const SizedBox(height: 14),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 60,
                        ),
                        child: Center(
                          child:
                              CircularProgressIndicator(),
                        ),
                      )
                    else ...[
                      desktop
                          ? _table()
                          : _mobileList(),
                      const SizedBox(height: 22),
                      _stockApprovalSection(desktop),
                    ],
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
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Manage raw materials and finished products',
                style: TextStyle(
                  color:
                      Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        if (desktop)
          Row(
            children: [
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminStockManagementScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.water_drop_outlined,
                    size: 18,
                  ),
                  label: const Text(
                    'Customer Stocks',
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 145,
                height: 44,
                child:
                    OutlinedButton.icon(
                  style:
                      OutlinedButton
                          .styleFrom(
                    minimumSize:
                        const Size(
                      145,
                      44,
                    ),
                    maximumSize:
                        const Size(
                      145,
                      44,
                    ),
                  ),
                  onPressed:
                      _stockEntry,
                  icon: const Icon(
                    Icons
                        .move_to_inbox_outlined,
                    size: 18,
                  ),
                  label: const Text(
                    'Stock Entry',
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 135,
                height: 44,
                child:
                    ElevatedButton.icon(
                  style:
                      ElevatedButton
                          .styleFrom(
                    minimumSize:
                        const Size(
                      135,
                      44,
                    ),
                    maximumSize:
                        const Size(
                      135,
                      44,
                    ),
                  ),
                  onPressed: () {
                    _openItemForm();
                  },
                  icon: const Icon(
                    Icons.add,
                    size: 18,
                  ),
                  label:
                      const Text(
                    'Add Item',
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _customerStockBanner() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminStockManagementScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0284C7).withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.water_drop_rounded, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Stock Cycles & Alerts',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Monitor customer countdowns, 7-day low-stock alerts & hold audit log',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _stats(bool desktop) {
    final data = [
      [
        'Total Items',
        '${inventory.length}',
        Icons.inventory_2_outlined,
      ],
      [
        'Low Stock',
        '$lowStock',
        Icons.warning_amber,
      ],
      [
        'Pending Approval',
        '$pendingApprovals',
        Icons.approval_outlined,
      ],
      [
        'Stock Value',
        '₹${totalValue.toStringAsFixed(0)}',
        Icons.currency_rupee,
      ],
    ];

    if (desktop) {
      return Row(
        children: List.generate(
          data.length,
          (index) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right:
                    index ==
                            data.length - 1
                        ? 0
                        : 14,
              ),
              child: _InventoryStat(
                title:
                    data[index][0]
                        .toString(),
                value:
                    data[index][1]
                        .toString(),
                icon:
                    data[index][2]
                        as IconData,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: data
          .map(
            (item) => Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              child: _InventoryStat(
                title:
                    item[0].toString(),
                value:
                    item[1].toString(),
                icon:
                    item[2] as IconData,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _toolbar(bool desktop) {
    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
      ),
      child: desktop
          ? Row(
              children: [
                Expanded(
                  child: _searchBox(),
                ),
                const SizedBox(
                  width: 14,
                ),
                SizedBox(
                  width: 190,
                  child: _typeDropdown(),
                ),
              ],
            )
          : Column(
              children: [
                _searchBox(),
                const SizedBox(
                  height: 10,
                ),
                _typeDropdown(),
                const SizedBox(
                  height: 10,
                ),
                Row(
                  children: [
                    Expanded(
                      child:
                          OutlinedButton(
                        onPressed:
                            _stockEntry,
                        child:
                            const Text(
                          'Stock Entry',
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child:
                          ElevatedButton(
                        onPressed: () {
                          _openItemForm();
                        },
                        child:
                            const Text(
                          'Add Item',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminStockManagementScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.water_drop_rounded, size: 18),
                    label: const Text(
                      'Customer Stocks',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
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
      decoration:
          const InputDecoration(
        hintText:
            'Search item, SKU or supplier...',
        prefixIcon:
            Icon(Icons.search),
      ),
    );
  }

  Widget _typeDropdown() {
    return DropdownButtonFormField<
        String>(
      value: typeFilter,
      items: const [
        DropdownMenuItem(
          value: 'All',
          child:
              Text('All Types'),
        ),
        DropdownMenuItem(
          value:
              'Raw Material',
          child:
              Text('Raw Material'),
        ),
        DropdownMenuItem(
          value:
              'Finished Product',
          child: Text(
            'Finished Product',
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          typeFilter =
              value ?? 'All';
        });
      },
    );
  }

  Widget _table() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.all(
              14,
            ),
            color:
                const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'ITEM',
                    style:
                        _inventoryHeader,
                  ),
                ),
                Expanded(
                  child: Text(
                    'TYPE',
                    style:
                        _inventoryHeader,
                  ),
                ),
                Expanded(
                  child: Text(
                    'STOCK',
                    style:
                        _inventoryHeader,
                  ),
                ),
                Expanded(
                  child: Text(
                    'MIN STOCK',
                    style:
                        _inventoryHeader,
                  ),
                ),
                Expanded(
                  child: Text(
                    'RATE',
                    style:
                        _inventoryHeader,
                  ),
                ),
                Expanded(
                  child: Text(
                    'BATCH',
                    style:
                        _inventoryHeader,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'SUPPLIER',
                    style:
                        _inventoryHeader,
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    'ACTIONS',
                    style:
                        _inventoryHeader,
                  ),
                ),
              ],
            ),
          ),
          if (filtered.isEmpty)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical: 50,
              ),
              child: Text(
                'No inventory item found.',
              ),
            )
          else
            ...filtered.map(
              _tableRow,
            ),
        ],
      ),
    );
  }

  Widget _tableRow(
    Map<String, dynamic> item,
  ) {
    final low =
        (item['stock'] as num) <=
        (item['minStock'] as num);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration:
          const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']
                      .toString(),
                  style:
                      const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                Text(
                  item['sku']
                      .toString(),
                  style:
                      const TextStyle(
                    fontSize: 9,
                    color:
                        Color(
                      0xFF94A3B8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              item['type']
                  .toString(),
              style:
                  const TextStyle(
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${item['stock']} ${item['unit']}',
              style: TextStyle(
                fontSize: 10,
                color: low
                    ? Colors.red
                    : Colors.black87,
                fontWeight: low
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${item['minStock']}',
            ),
          ),
          Expanded(
            child: Text(
              '₹${item['purchaseRate']}',
            ),
          ),
          Expanded(
            child: Text(
              item['batch']
                  .toString(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item['supplier']
                  .toString(),
            ),
          ),
          SizedBox(
            width: 90,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () {
                    _openItemForm(
                      item: item,
                    );
                  },
                  icon:
                      const Icon(
                    Icons.edit_outlined,
                    size: 17,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () {
                    _deleteItem(
                      item,
                    );
                  },
                  icon:
                      const Icon(
                    Icons.delete_outline,
                    color:
                        Colors.red,
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
    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(35),
        alignment: Alignment.center,
        child: const Text(
          'No inventory item found.',
        ),
      );
    }

    return Column(
      children:
          filtered.map((item) {
        final low =
            (item['stock'] as num) <=
            (item['minStock'] as num);

        return Container(
          width: double.infinity,
          margin:
              const EdgeInsets.only(
            bottom: 12,
          ),
          padding:
              const EdgeInsets.all(
            15,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color:
                  const Color(
                0xFFE5E7EB,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                item['name']
                    .toString(),
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                '${item['sku']} • ${item['type']}',
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                'Stock: ${item['stock']} ${item['unit']}',
                style: TextStyle(
                  color: low
                      ? Colors.red
                      : Colors.black87,
                  fontWeight: low
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              Text(
                'Supplier: ${item['supplier']}',
              ),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () {
                      _openItemForm(
                        item: item,
                      );
                    },
                    icon:
                        const Icon(
                      Icons.edit_outlined,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _deleteItem(
                        item,
                      );
                    },
                    icon:
                        const Icon(
                      Icons.delete_outline,
                      color:
                          Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // =========================================================
  // STOCK ENTRY PROFESSIONAL DIALOG
  // =========================================================

  Future<void> _stockEntry() async {
    if (inventory.isEmpty) {
      await showDialog(
        context: context,
        builder: (dialogCtx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF0284C7),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No Inventory Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What is "Stock Entry"?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• "Stock In": Record incoming goods, new stock, or raw materials received from suppliers into warehouse stock.\n'
                  '• "Stock Out": Record goods issued, dispatched, or marked as damaged/expired.\n\n'
                  'To log a Stock Entry, you must first add items to your inventory so stock can be added or deducted against them.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _openItemForm();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add First Item'),
              ),
            ],
          );
        },
      );
      return;
    }

    int selectedId =
        inventory.first['id'] as int;

    String action =
        'Stock In';

    final qtyController =
        TextEditingController();
    final reasonController =
        TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (
        dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return Dialog(
              backgroundColor:
                  Colors.transparent,
              child:
                  ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 520,
                ),
                child: Container(
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFF8FAFC,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      18,
                    ),
                    boxShadow:
                        const [
                      BoxShadow(
                        color:
                            Color(
                          0x22000000,
                        ),
                        blurRadius:
                            25,
                        offset:
                            Offset(
                          0,
                          10,
                        ),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets
                                .all(
                          20,
                        ),
                        decoration:
                            const BoxDecoration(
                          color:
                              Colors.white,
                          borderRadius:
                              BorderRadius
                                  .vertical(
                            top:
                                Radius
                                    .circular(
                              18,
                            ),
                          ),
                          border:
                              Border(
                            bottom:
                                BorderSide(
                              color:
                                  Color(
                                0xFFE5E7EB,
                              ),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration:
                                  BoxDecoration(
                                color:
                                    const Color(
                                  0xFFE0F2FE,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  12,
                                ),
                              ),
                              child:
                                  const Icon(
                                Icons
                                    .sync_alt_rounded,
                                color:
                                    Color(
                                  0xFF0284C7,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    'Stock Entry',
                                    style:
                                        TextStyle(
                                      fontSize: 19,
                                      fontWeight:
                                          FontWeight
                                              .w800,
                                    ),
                                  ),
                                  Text(
                                    'Add or remove inventory quantity',
                                    style:
                                        TextStyle(
                                      color:
                                          Color(
                                        0xFF64748B,
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.pop(
                                  dialogContext,
                                );
                              },
                              icon:
                                  const Icon(
                                Icons
                                    .close_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding:
                            const EdgeInsets
                                .all(
                          22,
                        ),
                        child: Column(
                          children: [
                            DropdownButtonFormField<
                                int>(
                              value:
                                  selectedId,
                              isExpanded:
                                  true,
                              decoration:
                                  _dialogInputDecoration(
                                'Inventory Item',
                                Icons
                                    .inventory_2_outlined,
                              ),
                              items:
                                  inventory
                                      .map(
                                (item) {
                                  return DropdownMenuItem<
                                      int>(
                                    value:
                                        item['id']
                                            as int,
                                    child:
                                        Text(
                                      item['name']
                                          .toString(),
                                    ),
                                  );
                                },
                              ).toList(),
                              onChanged:
                                  (
                                value,
                              ) {
                                if (value ==
                                    null) {
                                  return;
                                }

                                setDialogState(
                                  () {
                                    selectedId =
                                        value;
                                  },
                                );
                              },
                            ),

                            Builder(
                              builder: (_) {
                                final selItem = inventory.firstWhere(
                                  (item) => item['id'] == selectedId,
                                  orElse: () => inventory.first,
                                );
                                final stockVal =
                                    (selItem['stock'] as num?)?.toInt() ?? 0;
                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.inventory_2_outlined,
                                        size: 16,
                                        color: Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Current Stock: $stockVal units in warehouse',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            DropdownButtonFormField<
                                String>(
                              value:
                                  action,
                              decoration:
                                  _dialogInputDecoration(
                                'Transaction Type',
                                Icons
                                    .swap_vert_rounded,
                              ),
                              items:
                                  const [
                                DropdownMenuItem(
                                  value:
                                      'Stock In',
                                  child:
                                      Text(
                                    'Stock In',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value:
                                      'Stock Out',
                                  child:
                                      Text(
                                    'Stock Out',
                                  ),
                                ),
                              ],
                              onChanged:
                                  (
                                value,
                              ) {
                                if (value ==
                                    null) {
                                  return;
                                }

                                setDialogState(
                                  () {
                                    action =
                                        value;
                                  },
                                );
                              },
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            TextField(
                              controller:
                                  qtyController,
                              keyboardType:
                                  TextInputType
                                      .number,
                              decoration:
                                  _dialogInputDecoration(
                                'Quantity',
                                Icons
                                    .numbers_rounded,
                              ),
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            TextField(
                              controller:
                                  reasonController,
                              decoration:
                                  _dialogInputDecoration(
                                'Reason / Notes (Optional)',
                                Icons
                                    .edit_note_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .all(
                          18,
                        ),
                        decoration:
                            const BoxDecoration(
                          color:
                              Colors.white,
                          borderRadius:
                              BorderRadius
                                  .vertical(
                            bottom:
                                Radius
                                    .circular(
                              18,
                            ),
                          ),
                          border:
                              Border(
                            top:
                                BorderSide(
                              color:
                                  Color(
                                0xFFE5E7EB,
                              ),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .end,
                          children: [
                            SizedBox(
                              width: 90,
                              height: 44,
                              child:
                                  TextButton(
                                onPressed: () {
                                  Navigator.pop(
                                    dialogContext,
                                  );
                                },
                                child:
                                    const Text(
                                  'Cancel',
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            SizedBox(
                              width: 145,
                              height: 44,
                              child:
                                  ElevatedButton
                                      .icon(
                                style:
                                    ElevatedButton
                                        .styleFrom(
                                  minimumSize:
                                      const Size(
                                    145,
                                    44,
                                  ),
                                  maximumSize:
                                      const Size(
                                    145,
                                    44,
                                  ),
                                ),
                                onPressed:
                                    () async {
                                  final qty =
                                      int.tryParse(
                                            qtyController
                                                .text
                                                .trim(),
                                          ) ??
                                          0;

                                  if (qty <= 0) {
                                    AppToast.error(
                                      context,
                                      'Please enter a valid quantity.',
                                      title:
                                          'Invalid Quantity',
                                    );
                                    return;
                                  }

                                  final index =
                                      inventory.indexWhere(
                                    (item) =>
                                        item['id'] ==
                                        selectedId,
                                  );

                                  if (index ==
                                      -1) {
                                    return;
                                  }

                                  final current =
                                      (inventory[index]
                                                  ['stock']
                                              as num)
                                          .toInt();

                                  if (action ==
                                          'Stock Out' &&
                                      qty >
                                          current) {
                                    AppToast.error(
                                      context,
                                      'Stock out quantity is greater than available stock.',
                                      title:
                                          'Insufficient Stock',
                                    );
                                    return;
                                  }

                                  final itemName =
                                      inventory[index]
                                              ['name']
                                          .toString();

                                  final customReason =
                                      reasonController
                                          .text
                                          .trim();

                                  final reasonText =
                                      customReason
                                              .isNotEmpty
                                          ? customReason
                                          : (action ==
                                                  'Stock In'
                                              ? 'Stock received / purchase entry'
                                              : 'Stock issue / adjustment');

                                  final result =
                                      await _inventoryService
                                          .createStockRequest(
                                    itemId:
                                        selectedId,
                                    type: action,
                                    quantity: qty,
                                    reason:
                                        reasonText,
                                  );

                                  if (result[
                                          'success'] ==
                                      true) {
                                    if (context
                                        .mounted) {
                                      Navigator.pop(
                                        dialogContext,
                                      );
                                    }

                                    await _loadData();

                                    if (!mounted) {
                                      return;
                                    }

                                    AppToast.success(
                                      context,
                                      '$itemName - $action request submitted for approval.',
                                      title:
                                          'Approval Requested',
                                    );
                                  } else {
                                    AppToast.error(
                                      context,
                                      result[
                                              'message'] ??
                                          'Unable to submit request.',
                                      title:
                                          'Request Failed',
                                    );
                                  }
                                },
                                icon:
                                    const Icon(
                                  Icons
                                      .save_outlined,
                                  size: 18,
                                ),
                                label:
                                    const Text(
                                  'Save Entry',
                                  maxLines: 1,
                                  softWrap:
                                      false,
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

    qtyController.dispose();
  }

  Widget _stockApprovalSection(bool desktop) {
    final pending = stockRequests
        .where((e) => e['status'] == 'Pending')
        .toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFFFF7ED),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.approval_outlined,
                    color:
                        Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inventory Approval',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      Text(
                        '$pendingApprovals pending stock transactions',
                        style: const TextStyle(
                          fontSize: 11,
                          color:
                              Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          if (pending.isEmpty)
            const Padding(
              padding: EdgeInsets.all(35),
              child: Center(
                child: Text(
                  'No pending inventory approvals.',
                  style: TextStyle(
                    color:
                        Color(0xFF64748B),
                  ),
                ),
              ),
            )
          else if (desktop)
            _approvalDesktopTable(pending)
          else
            _approvalMobileList(pending),
        ],
      ),
    );
  }

  Widget _approvalDesktopTable(
    List<Map<String, dynamic>> data,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          color: const Color(0xFFF8FAFC),
          child: const Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'ITEM',
                  style: _inventoryHeader,
                ),
              ),
              Expanded(
                child: Text(
                  'TYPE',
                  style: _inventoryHeader,
                ),
              ),
              Expanded(
                child: Text(
                  'QTY',
                  style: _inventoryHeader,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'REQUESTED BY',
                  style: _inventoryHeader,
                ),
              ),
              Expanded(
                child: Text(
                  'DATE',
                  style: _inventoryHeader,
                ),
              ),
              SizedBox(
                width: 150,
                child: Text(
                  'ACTION',
                  style: _inventoryHeader,
                ),
              ),
            ],
          ),
        ),

        ...data.map(
          (request) =>
              _approvalDesktopRow(request),
        ),
      ],
    );
  }

  Widget _approvalDesktopRow(
    Map<String, dynamic> request,
  ) {
    final type =
        request['type'].toString();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              request['itemName'].toString(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          Expanded(
            child: Text(
              type,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: type == 'Stock In'
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFEA580C),
              ),
            ),
          ),

          Expanded(
            child: Text(
              request['quantity'].toString(),
              style: const TextStyle(
                fontSize: 10,
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              request['requestedBy']
                  .toString(),
              style: const TextStyle(
                fontSize: 10,
              ),
            ),
          ),

          Expanded(
            child: Text(
              request['date'].toString(),
              style: const TextStyle(
                fontSize: 9,
              ),
            ),
          ),

          SizedBox(
            width: 150,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Approve',
                  onPressed: () {
                    _approveStockRequest(
                      request,
                    );
                  },
                  icon: const Icon(
                    Icons
                        .check_circle_outline,
                    color:
                        Color(0xFF16A34A),
                    size: 19,
                  ),
                ),
                IconButton(
                  tooltip: 'Reject',
                  onPressed: () {
                    _rejectStockRequest(
                      request,
                    );
                  },
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color:
                        Color(0xFFDC2626),
                    size: 19,
                  ),
                ),
                IconButton(
                  tooltip: 'View',
                  onPressed: () {
                    _viewStockRequest(
                      request,
                    );
                  },
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvalMobileList(
    List<Map<String, dynamic>> data,
  ) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: data.map(
          (request) {
            return Container(
              width: double.infinity,
              margin:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              padding:
                  const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    const Color(0xFFF8FAFC),
                borderRadius:
                    BorderRadius.circular(10),
                border: Border.all(
                  color:
                      const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request['itemName']
                              .toString(),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                      _approvalBadge(
                        request['status']
                            .toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _approvalInfo(
                    'Type',
                    request['type'],
                  ),
                  _approvalInfo(
                    'Quantity',
                    request['quantity'],
                  ),
                  _approvalInfo(
                    'Requested By',
                    request['requestedBy'],
                  ),
                  _approvalInfo(
                    'Date',
                    request['date'],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          _viewStockRequest(
                            request,
                          );
                        },
                        icon: const Icon(
                          Icons
                              .visibility_outlined,
                          size: 16,
                        ),
                        label:
                            const Text('View'),
                      ),
                      ElevatedButton.icon(
                        style:
                            ElevatedButton.styleFrom(
                          minimumSize:
                              const Size(0, 40),
                          backgroundColor:
                              const Color(
                            0xFF16A34A,
                          ),
                          foregroundColor:
                              Colors.white,
                        ),
                        onPressed: () {
                          _approveStockRequest(
                            request,
                          );
                        },
                        icon: const Icon(
                          Icons.check,
                          size: 16,
                        ),
                        label: const Text(
                          'Approve',
                        ),
                      ),
                      OutlinedButton.icon(
                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              const Color(
                            0xFFDC2626,
                          ),
                        ),
                        onPressed: () {
                          _rejectStockRequest(
                            request,
                          );
                        },
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                        ),
                        label:
                            const Text('Reject'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  Future<void> _approveStockRequest(
    Map<String, dynamic> request,
  ) async {
    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text('Approve Stock Entry'),
          content: Text(
            'Approve ${request['type']} of ${request['quantity']} for ${request['itemName']}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 110,
              height: 42,
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                  minimumSize:
                      const Size(0, 42),
                  maximumSize:
                      const Size(110, 42),
                  backgroundColor:
                      const Color(
                    0xFF16A34A,
                  ),
                  foregroundColor:
                      Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                child:
                    const Text('Approve'),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final result =
        await _inventoryService.approveStockRequest(
      request['id'] as int,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      await _loadData();

      if (!mounted) return;

      AppToast.success(
        context,
        '${request['itemName']} stock request approved successfully.',
        title: 'Inventory Approved',
      );
    } else {
      AppToast.error(
        context,
        result['message'] ??
            'Unable to approve request.',
        title: 'Approval Failed',
      );
    }
  }

  Future<void> _rejectStockRequest(
    Map<String, dynamic> request,
  ) async {
    final reasonController =
        TextEditingController();

    bool rejected = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Reject Stock Entry',
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            ),
            child: TextField(
              controller:
                  reasonController,
              minLines: 3,
              maxLines: 5,
              decoration:
                  const InputDecoration(
                labelText:
                    'Rejection Reason *',
                hintText:
                    'Enter reason...',
                alignLabelWithHint:
                    true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 105,
              height: 42,
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                  minimumSize:
                      const Size(0, 42),
                  maximumSize:
                      const Size(105, 42),
                  backgroundColor:
                      const Color(
                    0xFFDC2626,
                  ),
                  foregroundColor:
                      Colors.white,
                ),
                onPressed: () async {
                  final reason =
                      reasonController.text
                          .trim();

                  if (reason.isEmpty) {
                    AppToast.error(
                      context,
                      'Please enter rejection reason.',
                      title:
                          'Reason Required',
                    );
                    return;
                  }

                  final result =
                      await _inventoryService
                          .rejectStockRequest(
                    request['id'] as int,
                    reason: reason,
                  );

                  if (result['success'] ==
                      true) {
                    rejected = true;

                    if (dialogContext
                        .mounted) {
                      Navigator.pop(
                        dialogContext,
                      );
                    }
                  } else {
                    AppToast.error(
                      context,
                      result['message'] ??
                          'Unable to reject request.',
                      title:
                          'Rejection Failed',
                    );
                  }
                },
                child:
                    const Text('Reject'),
              ),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (!rejected || !mounted) {
      return;
    }

    await _loadData();

    if (!mounted) return;

    AppToast.success(
      context,
      '${request['itemName']} stock request rejected.',
      title: 'Request Rejected',
    );
  }

  void _viewStockRequest(
    Map<String, dynamic> request,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Stock Request Details',
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                _approvalInfo(
                  'Item',
                  request['itemName'],
                ),
                _approvalInfo(
                  'Transaction',
                  request['type'],
                ),
                _approvalInfo(
                  'Quantity',
                  request['quantity'],
                ),
                _approvalInfo(
                  'Requested By',
                  request['requestedBy'],
                ),
                _approvalInfo(
                  'Date',
                  request['date'],
                ),
                _approvalInfo(
                  'Reason',
                  request['reason'] ?? '-',
                ),
                _approvalInfo(
                  'Status',
                  request['status'],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _approvalInfo(
    String label,
    dynamic value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color:
                    Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvalBadge(
    String status,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            const Color(0xFFFFF7ED),
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Color(0xFFEA580C),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // =========================================================
  // ADD / EDIT PROFESSIONAL DIALOG
  // =========================================================

  Future<void> _openItemForm({
    Map<String, dynamic>? item,
  }) async {
    final editing =
        item != null;

    final name =
        TextEditingController(
      text: item?['name'] ?? '',
    );

    final sku =
        TextEditingController(
      text: item?['sku'] ?? '',
    );

    final stock =
        TextEditingController(
      text:
          item?['stock']
                  ?.toString() ??
              '',
    );

    final minStock =
        TextEditingController(
      text:
          item?['minStock']
                  ?.toString() ??
              '',
    );

    final rate =
        TextEditingController(
      text:
          item?['purchaseRate']
                  ?.toString() ??
              '',
    );

    final batch =
        TextEditingController(
      text:
          item?['batch'] ?? '',
    );

    final supplier =
        TextEditingController(
      text:
          item?['supplier'] ?? '',
    );

    String type =
        item?['type'] ??
            'Raw Material';

    String unit =
        item?['unit'] ??
            'Pcs';

    bool saved = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (
        dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            final desktop =
                MediaQuery.of(
                      context,
                    ).size.width >=
                    900;

            return Dialog(
              backgroundColor:
                  Colors.transparent,
              insetPadding:
                  EdgeInsets.symmetric(
                horizontal:
                    desktop ? 80 : 14,
                vertical:
                    desktop ? 30 : 16,
              ),
              child:
                  ConstrainedBox(
                constraints:
                    BoxConstraints(
                  maxWidth:
                      desktop
                          ? 860
                          : 600,
                  maxHeight:
                      MediaQuery.of(
                            context,
                          ).size.height *
                          .9,
                ),
                child: Container(
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFF8FAFC,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      18,
                    ),
                    boxShadow:
                        const [
                      BoxShadow(
                        color:
                            Color(
                          0x22000000,
                        ),
                        blurRadius:
                            28,
                        offset:
                            Offset(
                          0,
                          12,
                        ),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _inventoryDialogHeader(
                        editing
                            ? 'Edit Inventory Item'
                            : 'Add Inventory Item',
                        'Manage item, stock, price and supplier information',
                        () {
                          Navigator.pop(
                            dialogContext,
                          );
                        },
                      ),

                      Expanded(
                        child:
                            SingleChildScrollView(
                          padding:
                              EdgeInsets.all(
                            desktop
                                ? 22
                                : 16,
                          ),
                          child:
                              LayoutBuilder(
                            builder: (
                              context,
                              constraints,
                            ) {
                              final twoColumns =
                                  constraints
                                          .maxWidth >=
                                      650;

                              return Column(
                                children: [
                                  _inventorySection(
                                    title:
                                        'Item Information',
                                    subtitle:
                                        'Identification and classification',
                                    icon:
                                        Icons
                                            .category_outlined,
                                    child:
                                        _inventoryGrid(
                                      twoColumns,
                                      [
                                        _inventoryField(
                                          name,
                                          'Item Name',
                                          Icons
                                              .inventory_2_outlined,
                                          requiredField:
                                              true,
                                        ),
                                        _inventoryField(
                                          sku,
                                          'SKU',
                                          Icons
                                              .qr_code_2_outlined,
                                        ),
                                        _inventoryDropdown(
                                          label:
                                              'Type',
                                          value:
                                              type,
                                          items:
                                              const [
                                            'Raw Material',
                                            'Finished Product',
                                          ],
                                          onChanged:
                                              (
                                            value,
                                          ) {
                                            setDialogState(
                                              () {
                                                type =
                                                    value ??
                                                        type;
                                              },
                                            );
                                          },
                                        ),
                                        _inventoryDropdown(
                                          label:
                                              'Unit',
                                          value:
                                              unit,
                                          items:
                                              const [
                                            'Pcs',
                                            'Bottles',
                                            'Jars',
                                            'Kg',
                                          ],
                                          onChanged:
                                              (
                                            value,
                                          ) {
                                            setDialogState(
                                              () {
                                                unit =
                                                    value ??
                                                        unit;
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 18,
                                  ),

                                  _inventorySection(
                                    title:
                                        'Stock & Pricing',
                                    subtitle:
                                        'Quantity and purchase information',
                                    icon:
                                        Icons
                                            .stacked_bar_chart_outlined,
                                    child:
                                        _inventoryGrid(
                                      twoColumns,
                                      [
                                        _inventoryField(
                                          stock,
                                          'Current Stock',
                                          Icons
                                              .inventory_outlined,
                                          keyboardType:
                                              TextInputType
                                                  .number,
                                        ),
                                        _inventoryField(
                                          minStock,
                                          'Minimum Stock',
                                          Icons
                                              .warning_amber_outlined,
                                          keyboardType:
                                              TextInputType
                                                  .number,
                                        ),
                                        _inventoryField(
                                          rate,
                                          'Purchase Rate',
                                          Icons
                                              .currency_rupee,
                                          keyboardType:
                                              const TextInputType
                                                  .numberWithOptions(
                                            decimal:
                                                true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 18,
                                  ),

                                  _inventorySection(
                                    title:
                                        'Batch & Supplier',
                                    subtitle:
                                        'Traceability and vendor details',
                                    icon:
                                        Icons
                                            .local_shipping_outlined,
                                    child:
                                        _inventoryGrid(
                                      twoColumns,
                                      [
                                        _inventoryField(
                                          batch,
                                          'Batch Number',
                                          Icons
                                              .tag_outlined,
                                        ),
                                        _inventoryField(
                                          supplier,
                                          'Supplier',
                                          Icons
                                              .business_outlined,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 24,
                          vertical: 15,
                        ),
                        decoration:
                            const BoxDecoration(
                          color:
                              Colors.white,
                          borderRadius:
                              BorderRadius
                                  .vertical(
                            bottom:
                                Radius
                                    .circular(
                              18,
                            ),
                          ),
                          border:
                              Border(
                            top:
                                BorderSide(
                              color:
                                  Color(
                                0xFFE5E7EB,
                              ),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .end,
                          children: [
                            SizedBox(
                              width: 95,
                              height: 44,
                              child:
                                  TextButton(
                                onPressed: () {
                                  Navigator.pop(
                                    dialogContext,
                                  );
                                },
                                child:
                                    const Text(
                                  'Cancel',
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            SizedBox(
                              width: 145,
                              height: 44,
                              child:
                                  ElevatedButton
                                      .icon(
                                style:
                                    ElevatedButton
                                        .styleFrom(
                                  minimumSize:
                                      const Size(
                                    145,
                                    44,
                                  ),
                                  maximumSize:
                                      const Size(
                                    145,
                                    44,
                                  ),
                                ),
                                onPressed:
                                    () async {
                                  if (name.text
                                      .trim()
                                      .isEmpty) {
                                    AppToast.error(
                                      context,
                                      'Item name is required.',
                                      title:
                                          'Validation Error',
                                    );
                                    return;
                                  }

                                  final stockValue =
                                      int.tryParse(
                                            stock.text
                                                .trim(),
                                          ) ??
                                          0;

                                  final minimumValue =
                                      int.tryParse(
                                            minStock.text
                                                .trim(),
                                          ) ??
                                          0;

                                  final rateValue =
                                      double.tryParse(
                                            rate.text
                                                .trim(),
                                          ) ??
                                          0;

                                  if (stockValue <
                                          0 ||
                                      minimumValue <
                                          0 ||
                                      rateValue <
                                          0) {
                                    AppToast.error(
                                      context,
                                      'Stock, minimum stock and rate cannot be negative.',
                                      title:
                                          'Invalid Value',
                                    );
                                    return;
                                  }

                                  final data =
                                      {
                                    'name':
                                        name.text
                                            .trim(),
                                    'type':
                                        type,
                                    'sku':
                                        sku.text
                                            .trim(),
                                    'unit':
                                        unit,
                                    'stock':
                                        stockValue,
                                    'minStock':
                                        minimumValue,
                                    'purchaseRate':
                                        rateValue,
                                    'batch':
                                        batch.text
                                            .trim(),
                                    'supplier':
                                        supplier.text
                                            .trim(),
                                  };

                                  Map<String,
                                          dynamic>
                                      result;

                                  if (editing) {
                                    result =
                                        await _inventoryService
                                            .updateItem(
                                      item['id']
                                          as int,
                                      data,
                                    );
                                  } else {
                                    result =
                                        await _inventoryService
                                            .createItem(
                                      data,
                                    );
                                  }

                                  if (result[
                                          'success'] ==
                                      true) {
                                    saved = true;

                                    if (context
                                        .mounted) {
                                      Navigator.pop(
                                        dialogContext,
                                      );
                                    }

                                    await _loadData();
                                  } else {
                                    AppToast.error(
                                      context,
                                      result[
                                              'message'] ??
                                          'Unable to save item.',
                                      title: editing
                                          ? 'Update Failed'
                                          : 'Create Failed',
                                    );
                                  }
                                },
                                icon:
                                    const Icon(
                                  Icons
                                      .save_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  editing
                                      ? 'Update Item'
                                      : 'Save Item',
                                  maxLines: 1,
                                  softWrap:
                                      false,
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
            ? '${name.text.trim()} updated successfully.'
            : '${name.text.trim()} added successfully.',
        title: editing
            ? 'Inventory Updated'
            : 'Inventory Item Added',
      );
    }

    name.dispose();
    sku.dispose();
    stock.dispose();
    minStock.dispose();
    rate.dispose();
    batch.dispose();
    supplier.dispose();
  }

  // =========================================================
  // PROFESSIONAL FORM HELPERS
  // =========================================================

  Widget _inventoryDialogHeader(
    String title,
    String subtitle,
    VoidCallback onClose,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 18,
      ),
      decoration:
          const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(
          top:
              Radius.circular(18),
        ),
        border: Border(
          bottom: BorderSide(
            color:
                Color(
              0xFFE5E7EB,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFE0F2FE,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: const Icon(
              Icons
                  .inventory_2_outlined,
              color:
                  Color(
                0xFF0284C7,
              ),
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color:
                        Color(
                      0xFF64748B,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon:
                const Icon(
              Icons.close_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inventorySection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFE5E7EB,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFE0F2FE,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color:
                      const Color(
                    0xFF0284C7,
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        fontSize: 11,
                        color:
                            Color(
                          0xFF64748B,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 18,
          ),
          child,
        ],
      ),
    );
  }

  Widget _inventoryGrid(
    bool twoColumns,
    List<Widget> fields,
  ) {
    if (!twoColumns) {
      return Column(
        children:
            List.generate(
          fields.length,
          (index) => Padding(
            padding:
                EdgeInsets.only(
              bottom:
                  index ==
                          fields.length -
                              1
                      ? 0
                      : 14,
            ),
            child:
                fields[index],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 14,
      children: fields
          .map(
            (field) =>
                ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width > 420 ? 370 : double.infinity,
              ),
              child: field,
            ),
          )
          .toList(),
    );
  }

  Widget _inventoryField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool requiredField = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType:
          keyboardType,
      decoration:
          InputDecoration(
        labelText:
            requiredField
                ? '$label *'
                : label,
        prefixIcon: Icon(
          icon,
          size: 18,
        ),
        filled: true,
        fillColor:
            const Color(
          0xFFF8FAFC,
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          borderSide:
              const BorderSide(
            color:
                Color(
              0xFFE2E8F0,
            ),
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          borderSide:
              const BorderSide(
            color:
                Color(
              0xFF0284C7,
            ),
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _inventoryDropdown({
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
      value: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF0284C7),
          ),
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

  InputDecoration _dialogInputDecoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        size: 18,
      ),
      filled: true,
      fillColor: Colors.white,
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        borderSide:
            const BorderSide(
          color:
              Color(
            0xFFE2E8F0,
          ),
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        borderSide:
            const BorderSide(
          color:
              Color(
            0xFF0284C7,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteItem(
    Map<String, dynamic> item,
  ) async {
    final yes =
        await showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title:
              const Text(
            'Delete Item',
          ),
          content: Text(
            'Delete ${item['name']}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text(
                'Cancel',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text(
                'Delete',
                style: TextStyle(
                  color:
                      Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (yes != true) return;

    final itemName =
        item['name'].toString();

    final result =
        await _inventoryService.deleteItem(
      item['id'] as int,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      await _loadData();

      if (!mounted) return;

      AppToast.success(
        context,
        '$itemName deleted successfully.',
        title:
            'Inventory Item Deleted',
      );
    } else {
      AppToast.error(
        context,
        result['message'] ??
            'Unable to delete item.',
        title: 'Delete Failed',
      );
    }
  }
}

class _InventoryStat
    extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InventoryStat({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: 95,
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFE5E7EB,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFE0F2FE,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              icon,
              color:
                  const Color(
                0xFF0284C7,
              ),
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF64748B,
                    ),
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style:
                      const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
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

const _inventoryHeader =
    TextStyle(
  fontSize: 8.5,
  fontWeight: FontWeight.w700,
  color: Color(0xFF64748B),
);