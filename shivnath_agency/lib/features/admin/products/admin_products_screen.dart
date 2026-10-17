import 'package:flutter/material.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../../../core/services/product_service.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final ProductService _productService = ProductService();

  List<Map<String, dynamic>> products = [];
  bool loading = true;

  // Category Tree State
  List<Map<String, dynamic>> categoryTree = [];
  List<Map<String, dynamic>> flatCategories = [];
  bool loadingCategories = false;
  bool categoriesExpanded = true;
  Set<int> expandedCategoryIds = {};
  int? selectedCategoryId;

  @override
  void initState() {
    super.initState();
    loadCategories();
    loadProducts();
  }

  Future<void> loadCategories() async {
    setState(() => loadingCategories = true);
    final result = await _productService.getCategories(treeOnly: true);
    if (result["success"] == true && result["data"] is Map) {
      final rawList = result["data"]["categories"] as List? ?? [];
      categoryTree = List<Map<String, dynamic>>.from(rawList);
      flatCategories = [];
      _flattenCategories(categoryTree, '');
      _collectCategoryIds(categoryTree, expandedCategoryIds);
    }
    if (mounted) setState(() => loadingCategories = false);
  }

  void _flattenCategories(List<dynamic> list, String prefix) {
    for (var item in list) {
      if (item is Map<String, dynamic>) {
        final path = prefix.isEmpty
            ? item['name'].toString()
            : '$prefix > ${item['name']}';
        flatCategories.add({
          'id': item['id'],
          'name': item['name'],
          'full_path': item['full_path'] ?? path,
          'is_active': item['is_active'] ?? true,
        });
        final children = item['children'] ?? item['subcategories'];
        if (children is List && children.isNotEmpty) {
          _flattenCategories(children, path);
        }
      }
    }
  }

  void _collectCategoryIds(List<dynamic> list, Set<int> target) {
    for (var item in list) {
      if (item is Map<String, dynamic> && item['id'] is int) {
        target.add(item['id']);
        final children = item['children'] ?? item['subcategories'];
        if (children is List && children.isNotEmpty) {
          _collectCategoryIds(children, target);
        }
      }
    }
  }

  Future<void> loadProducts() async {
    setState(() {
      loading = true;
    });

    final result = await _productService.getProducts(
      search: search,
      categoryId: selectedCategoryId,
      category: selectedCategoryId == null && categoryFilter != 'All'
          ? categoryFilter
          : null,
    );

    if (result["success"] == true) {
      final dynamic raw =
          (result["data"] is Map && result["data"]["products"] is List)
          ? result["data"]["products"]
          : (result["products"] is List
                ? result["products"]
                : (result["data"] is List ? result["data"] : []));
      products = (raw as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      if (mounted) {
        AppToast.error(
          context,
          result["message"] ?? "Unable to load products.",
        );
      }
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  String search = '';
  String categoryFilter = 'All';

  List<Map<String, dynamic>> get filteredProducts {
    final keyword = search.trim().toLowerCase();

    return products.where((product) {
      final matchesSearch =
          keyword.isEmpty ||
          product['name'].toString().toLowerCase().contains(keyword) ||
          product['sku'].toString().toLowerCase().contains(keyword);

      return matchesSearch;
    }).toList();
  }

  int get activeProducts =>
      products.where((item) => item['status'] == 'Active').length;

  int get bottleCount => products
      .where(
        (item) =>
            item['category']?.toString().toLowerCase().contains('bottle') ==
            true,
      )
      .length;

  int get jarCount => products
      .where(
        (item) =>
            item['category']?.toString().toLowerCase().contains('jar') == true,
      )
      .length;

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
                    _buildHeader(desktop),
                    const SizedBox(height: 22),
                    _buildStats(desktop),
                    const SizedBox(height: 20),
                    _buildCategoriesSection(desktop),
                    const SizedBox(height: 20),
                    _buildToolbar(desktop),
                    const SizedBox(height: 14),
                    desktop ? _buildDesktopTable() : _buildMobileList(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool desktop) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Products',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Manage finished products and pricing',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        if (desktop)
          SizedBox(
            width: 150,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(150, 44),
                maximumSize: const Size(150, 44),
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
              onPressed: _openProductForm,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Product', maxLines: 1, softWrap: false),
            ),
          ),
      ],
    );
  }

  Widget _buildStats(bool desktop) {
    final stats = [
      ['Total Products', '${products.length}', Icons.inventory_2_outlined],
      ['Active Products', '$activeProducts', Icons.check_circle_outline],
      ['Bottles', '$bottleCount', Icons.local_drink_outlined],
      ['Jars', '$jarCount', Icons.water_drop_outlined],
    ];

    if (desktop) {
      return Row(
        children: List.generate(stats.length, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == stats.length - 1 ? 0 : 14,
              ),
              child: _ProductStatCard(
                title: stats[index][0] as String,
                value: stats[index][1] as String,
                icon: stats[index][2] as IconData,
              ),
            ),
          );
        }),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (_, index) {
        return _ProductStatCard(
          title: stats[index][0] as String,
          value: stats[index][1] as String,
          icon: stats[index][2] as IconData,
        );
      },
    );
  }

  Widget _buildCategoriesSection(bool desktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(desktop ? 20 : 14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desktop)
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_tree_outlined,
                    color: Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage hierarchical category tree, unlimited subcategories, and assignments (${flatCategories.length} categories total)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _openCategoryDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    '+ Add Category',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_tree_outlined,
                        color: Color(0xFF0284C7),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Product Categories',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            '${flatCategories.length} categories total',
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _openCategoryDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      '+ Add Category',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          if (loadingCategories)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (categoryTree.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.folder_open_outlined,
                      size: 40,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No categories found. Click "+ Add Category" to create the first root category.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildCategoryTreeWidget(categoryTree, 0, desktop: desktop),
        ],
      ),
    );
  }

  Widget _buildCategoryTreeWidget(
    List<dynamic> nodes,
    int depth, {
    bool desktop = false,
  }) {
    return Column(
      children: nodes.map((node) {
        if (node is! Map<String, dynamic>) return const SizedBox.shrink();
        return _buildCategoryNode(node, depth, desktop: desktop);
      }).toList(),
    );
  }

  Widget _buildCategoryNode(
    Map<String, dynamic> cat,
    int depth, {
    bool desktop = false,
  }) {
    final catId = cat['id'] as int? ?? 0;
    final name = cat['name']?.toString() ?? 'Unnamed';
    final fullPath = cat['full_path']?.toString() ?? name;
    final isActive = cat['is_active'] != false;
    final productCount = cat['product_count'] ?? 0;
    final rawChildren = cat['children'] ?? cat['subcategories'];
    final children = (rawChildren is List) ? rawChildren : const [];
    final hasChildren = children.isNotEmpty;
    final isExpanded = expandedCategoryIds.contains(catId);

    final leftIndent = desktop ? (12.0 + depth * 22.0) : (8.0 + depth * 12.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: depth == 0 ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: depth == 0 ? const Color(0xFFE2E8F0) : const Color(0xFFEEF2F6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: leftIndent,
              right: desktop ? 12.0 : 8.0,
              top: 8.0,
              bottom: 8.0,
            ),
            child: desktop
                ? Row(
                    children: [
                      if (hasChildren)
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                expandedCategoryIds.remove(catId);
                              } else {
                                expandedCategoryIds.add(catId);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              isExpanded
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                              size: 20,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Icon(
                        depth == 0
                            ? Icons.folder_rounded
                            : Icons.subdirectory_arrow_right_rounded,
                        size: 18,
                        color: depth == 0
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Tooltip(
                          message: 'Full Path: $fullPath',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: depth == 0
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isActive
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFF94A3B8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$productCount products',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isActive ? 'Active' : 'Archived',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        onPressed: () => _openCategoryDialog(parent: cat),
                        icon: const Icon(Icons.add_circle_outline, size: 15),
                        label: const Text(
                          'Add Child',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit Category',
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 17,
                          color: Color(0xFF64748B),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () => _openCategoryDialog(category: cat),
                      ),
                      IconButton(
                        tooltip: 'Archive Category',
                        icon: const Icon(
                          Icons.archive_outlined,
                          size: 17,
                          color: Color(0xFFDC2626),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () => _archiveCategory(cat),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (hasChildren)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    expandedCategoryIds.remove(catId);
                                  } else {
                                    expandedCategoryIds.add(catId);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  isExpanded
                                      ? Icons.expand_more
                                      : Icons.chevron_right,
                                  size: 20,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.circle,
                                size: 6,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          const SizedBox(width: 4),
                          Icon(
                            depth == 0
                                ? Icons.folder_rounded
                                : Icons.subdirectory_arrow_right_rounded,
                            size: 16,
                            color: depth == 0
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: depth == 0
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isActive
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF94A3B8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$productCount',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Archived',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFF0284C7),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                            ),
                            onPressed: () => _openCategoryDialog(parent: cat),
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 14,
                            ),
                            label: const Text(
                              'Add Child',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit Category',
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: () => _openCategoryDialog(category: cat),
                          ),
                          IconButton(
                            tooltip: 'Archive Category',
                            icon: const Icon(
                              Icons.archive_outlined,
                              size: 16,
                              color: Color(0xFFDC2626),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: () => _archiveCategory(cat),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          if (hasChildren && isExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildCategoryTreeWidget(
                children,
                depth + 1,
                desktop: desktop,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openCategoryDialog({
    Map<String, dynamic>? category,
    Map<String, dynamic>? parent,
  }) async {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?['name'] ?? '');
    final descController = TextEditingController(
      text: category?['description'] ?? '',
    );
    final orderController = TextEditingController(
      text: category?['order']?.toString() ?? '0',
    );
    bool isActive = category?['is_active'] ?? true;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              actionsOverflowDirection: VerticalDirection.down,
              actionsOverflowButtonSpacing: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
                    color: const Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Edit Category'
                          : (parent != null
                                ? 'Add Subcategory'
                                : 'Add Top-Level Category'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 450,
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (parent != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Color(0xFF1D4ED8),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Parent: ${parent['full_path'] ?? parent['name']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E40AF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Category Name *',
                            hintText: 'e.g. 1 Litre, Sparkling, 20 Litre Jar',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.label_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: descController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Description (Optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.description_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: orderController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Display Order',
                            hintText: '0',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.sort_rounded),
                          ),
                        ),
                        if (isEditing) ...[
                          const SizedBox(height: 14),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Is Active',
                              style: TextStyle(fontSize: 14),
                            ),
                            value: isActive,
                            onChanged: (val) =>
                                setDialogState(() => isActive = val),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            AppToast.error(
                              context,
                              'Category name cannot be empty.',
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          final payload = <String, dynamic>{
                            'name': name,
                            'description': descController.text.trim(),
                            'order':
                                int.tryParse(orderController.text.trim()) ?? 0,
                            'is_active': isActive,
                          };
                          if (parent != null && parent['id'] != null) {
                            payload['parent_id'] = parent['id'];
                          }

                          final res = isEditing
                              ? await _productService.updateCategory(
                                  category['id'] as int,
                                  payload,
                                )
                              : await _productService.createCategory(payload);

                          if (res['success'] == true) {
                            if (mounted) {
                              AppToast.success(
                                context,
                                isEditing
                                    ? 'Category "$name" updated successfully.'
                                    : 'Category "$name" created successfully.',
                              );
                              Navigator.pop(dialogCtx);
                              await loadCategories();
                              await loadProducts();
                            }
                          } else {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              AppToast.error(
                                context,
                                res['message'] ?? 'Unable to save category.',
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEditing ? 'Save Changes' : 'Create Category'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _archiveCategory(Map<String, dynamic> cat) async {
    final catId = cat['id'] as int? ?? 0;
    final name = cat['name']?.toString() ?? 'Category';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        title: const Text('Archive Category?'),
        content: SingleChildScrollView(
          child: Text(
            'Are you sure you want to archive "$name"?\n\n'
            'Categories with active subcategories or active products cannot be archived.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _productService.deleteCategory(catId);
    if (res['success'] == true) {
      if (mounted) {
        AppToast.success(context, 'Category "$name" archived successfully.');
        await loadCategories();
        await loadProducts();
      }
    } else {
      if (mounted) {
        AppToast.error(
          context,
          res['message'] ?? 'Unable to archive category.',
        );
      }
    }
  }

  Widget _buildToolbar(bool desktop) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: desktop
          ? Row(
              children: [
                Expanded(child: _searchField()),
                const SizedBox(width: 14),
                SizedBox(width: 220, child: _categoryDropdown()),
              ],
            )
          : Column(
              children: [
                _searchField(),
                const SizedBox(height: 10),
                _categoryDropdown(),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _openProductForm,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Product'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        onChanged: (value) async {
          search = value;
          await loadProducts();
        },
        decoration: InputDecoration(
          hintText: 'Search product or SKU...',
          prefixIcon: const Icon(Icons.search_rounded, size: 19),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF0284C7)),
          ),
        ),
      ),
    );
  }

  Widget _categoryDropdown() {
    final List<DropdownMenuItem<dynamic>> dropdownItems = [
      const DropdownMenuItem(
        value: 'All',
        child: Text('All Categories', overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
      ...flatCategories.map((cat) {
        final id = cat['id'];
        final fullPath = cat['full_path'] ?? cat['name'];
        return DropdownMenuItem(
          value: id,
          child: Text(
            fullPath.toString(),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }),
    ];

    dynamic safeValue = selectedCategoryId;
    if (safeValue == null ||
        !dropdownItems.any((item) => item.value == safeValue)) {
      safeValue = 'All';
    }

    return DropdownButtonFormField<dynamic>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      items: dropdownItems,
      onChanged: (value) async {
        if (value == null || value == 'All') {
          selectedCategoryId = null;
          categoryFilter = 'All';
        } else if (value is int) {
          selectedCategoryId = value;
          categoryFilter = value.toString();
        } else {
          selectedCategoryId = null;
          categoryFilter = value.toString();
        }
        await loadProducts();
      },
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _tableHeader(),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 55),
              child: Text(
                'No products found.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ...filteredProducts.map(_tableRow),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('PRODUCT', style: _headerStyle)),
          Expanded(child: Text('SIZE', style: _headerStyle)),
          Expanded(child: Text('CATEGORY', style: _headerStyle)),
          Expanded(child: Text('PRICE', style: _headerStyle)),
          Expanded(child: Text('GST', style: _headerStyle)),
          Expanded(child: Text('STOCK', style: _headerStyle)),
          Expanded(child: Text('STATUS', style: _headerStyle)),
          SizedBox(width: 100, child: Text('ACTIONS', style: _headerStyle)),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> product) {
    final lowStock = (product['stock'] as num) <= 100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ProductThumbnail.fromMap(
                  data: product,
                  width: 38,
                  height: 38,
                  borderRadius: BorderRadius.circular(9),
                  fit: BoxFit.contain,
                  padding: const EdgeInsets.all(2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'].toString(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        product['sku'].toString(),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _cell(product['size']?.toString() ?? '')),
          Expanded(child: _cell(product['category']?.toString() ?? '')),
          Expanded(child: _cell(_formatPrice(product['price']), bold: true)),
          Expanded(child: _cell('${product['gst']}%')),
          Expanded(
            child: Text(
              '${product['stock']}',
              style: TextStyle(
                fontSize: 10,
                color: lowStock ? Colors.red : const Color(0xFF111827),
                fontWeight: lowStock ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _statusBadge(product['status'].toString()),
            ),
          ),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Edit',
                  constraints: const BoxConstraints(
                    minWidth: 35,
                    minHeight: 35,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => _openProductForm(product: product),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 17,
                    color: Color(0xFF64748B),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  constraints: const BoxConstraints(
                    minWidth: 35,
                    minHeight: 35,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => _deleteProduct(product),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 17,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(dynamic value, {bool bold = false}) {
    return Text(
      value.toString(),
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _buildMobileList() {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (filteredProducts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text("No products found"),
        ),
      );
    }

    return Column(
      children: filteredProducts.map((product) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProductThumbnail.fromMap(
                    data: product,
                    width: 42,
                    height: 42,
                    borderRadius: BorderRadius.circular(10),
                    fit: BoxFit.contain,
                    padding: const EdgeInsets.all(3),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          product['sku'].toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(product['status'].toString()),
                ],
              ),
              const SizedBox(height: 14),
              _mobileInfo('Size', product['size']?.toString() ?? ''),
              _mobileInfo('Category', product['category']?.toString() ?? ''),
              _mobileInfo('Price', _formatPrice(product['price'])),
              _mobileInfo('GST', '${product['gst']}%'),
              _mobileInfo('Stock', product['stock']),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => _openProductForm(product: product),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () => _deleteProduct(product),
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

  Widget _mobileInfo(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProductForm({Map<String, dynamic>? product}) async {
    final editing = product != null;

    final nameController = TextEditingController(text: product?['name'] ?? '');
    final skuController = TextEditingController(text: product?['sku'] ?? '');
    final sizeController = TextEditingController(text: product?['size'] ?? '');
    final priceController = TextEditingController(
      text: (product?['dealer_wholesale_price'] ?? product?['dealer_transfer_price'] ?? product?['price'])?.toString() ?? '',
    );
    final mrpController = TextEditingController(
      text: (product?['retail_mrp'] ?? product?['mrp'])?.toString() ?? '',
    );
    final gstController = TextEditingController(
      text: product?['gst']?.toString() ?? '18',
    );
    final stockController = TextEditingController(
      text: product?['stock']?.toString() ?? '0',
    );
    int? categoryRefId;
    if (product != null) {
      if (product['category_ref_id'] is int) {
        categoryRefId = product['category_ref_id'] as int;
      } else if (product['category_ref'] is Map &&
          product['category_ref']['id'] is int) {
        categoryRefId = product['category_ref']['id'] as int;
      } else if (product['category_id'] is int) {
        categoryRefId = product['category_id'] as int;
      }
    }

    if (categoryRefId == null && product?['category'] != null) {
      final productCatStr =
          product!['category']?.toString().toLowerCase() ?? '';
      final match = flatCategories.firstWhere(
        (c) => c['name'].toString().toLowerCase() == productCatStr,
        orElse: () => {},
      );
      if (match.isNotEmpty && match['id'] is int) {
        categoryRefId = match['id'] as int;
      }
    }

    String category =
        product?['category']?.toString() ??
        (flatCategories.isNotEmpty
            ? flatCategories.first['name'].toString()
            : 'Bottle');
    String status = product?['status'] ?? 'Active';
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
                  maxWidth: 880,
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
                        editing ? 'Edit Product' : 'Add Product',
                        'Manage product information, pricing and inventory',
                        Icons.inventory_2_outlined,
                        () => Navigator.pop(dialogContext),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(desktop ? 22 : 16),
                          child: Column(
                            children: [
                              _formSection(
                                title: 'Product Information',
                                subtitle:
                                    'Basic product identification details',
                                icon: Icons.category_outlined,
                                child: _formGrid(desktop, [
                                  _professionalInput(
                                    controller: nameController,
                                    label: 'Product Name *',
                                    icon: Icons.inventory_2_outlined,
                                  ),
                                  _professionalInput(
                                    controller: skuController,
                                    label: 'SKU *',
                                    icon: Icons.qr_code_2_outlined,
                                  ),
                                  _professionalInput(
                                    controller: sizeController,
                                    label: 'Size *',
                                    hint: 'Example: 1 Litre',
                                    icon: Icons.straighten_outlined,
                                  ),
                                  _professionalCategoryPicker(
                                    label: 'Category *',
                                    value:
                                        categoryRefId != null &&
                                            flatCategories.any(
                                              (c) => c['id'] == categoryRefId,
                                            )
                                        ? categoryRefId
                                        : null,
                                    items: flatCategories,
                                    onChanged: (val) {
                                      updateDialog(() {
                                        categoryRefId = val;
                                        if (val != null) {
                                          final match = flatCategories
                                              .firstWhere(
                                                (c) => c['id'] == val,
                                                orElse: () => {},
                                              );
                                          if (match.isNotEmpty) {
                                            category =
                                                match['name']?.toString() ??
                                                category;
                                          }
                                        }
                                      });
                                    },
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 18),
                              _formSection(
                                title: 'Pricing & Tax',
                                subtitle: 'Configure dealer price, retail MRP and GST',
                                icon: Icons.payments_outlined,
                                child: _formGrid(desktop, [
                                  _professionalInput(
                                    controller: priceController,
                                    label: 'Dealer / Transfer Price *',
                                    hint: 'Wholesale franchise rate',
                                    icon: Icons.currency_rupee,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                  _professionalInput(
                                    controller: mrpController,
                                    label: 'Retail MRP',
                                    hint: 'Customer retail maximum price',
                                    icon: Icons.price_change_outlined,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                  _professionalInput(
                                    controller: gstController,
                                    label: 'GST %',
                                    icon: Icons.percent_rounded,
                                    keyboardType: TextInputType.number,
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 18),
                              _formSection(
                                title: 'Inventory & Availability',
                                subtitle:
                                    'Manage stock and product availability',
                                icon: Icons.warehouse_outlined,
                                child: _formGrid(desktop, [
                                  _professionalInput(
                                    controller: stockController,
                                    label: 'Current Stock',
                                    icon: Icons.inventory_outlined,
                                    keyboardType: TextInputType.number,
                                  ),
                                  _professionalDropdown(
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
                      _dialogFooter(
                        dialogContext: dialogContext,
                        saveLabel: editing ? 'Update Product' : 'Save Product',
                        onSave: () async {
                          final name = nameController.text.trim();
                          final sku = skuController.text.trim();
                          final size = sizeController.text.trim();
                          final price = double.tryParse(
                            priceController.text.trim(),
                          );
                          final mrp = double.tryParse(
                            mrpController.text.trim(),
                          );
                          final gst =
                              int.tryParse(gstController.text.trim()) ?? 0;
                          final stock =
                              int.tryParse(stockController.text.trim()) ?? 0;

                          if (name.isEmpty) {
                            AppToast.error(
                              context,
                              "Product name is required.",
                            );
                            return;
                          }

                          if (sku.isEmpty) {
                            AppToast.error(context, "SKU is required.");
                            return;
                          }

                          if (size.isEmpty) {
                            AppToast.error(context, "Size is required.");
                            return;
                          }

                          if (price == null || price < 0) {
                            AppToast.error(context, "Enter valid price.");
                            return;
                          }

                          if (gst < 0 || gst > 100 || stock < 0) {
                            AppToast.error(context, "Invalid GST or Stock.");
                            return;
                          }

                          final body = {
                            "name": name,
                            "sku": sku,
                            "size": size,
                            "category": category,
                            "category_ref_id": ?categoryRefId,
                            "price": price,
                            "dealer_wholesale_price": price,
                            "dealer_transfer_price": price,
                            "retail_mrp": ?mrp,
                            "mrp": ?mrp,
                            "gst": gst,
                            "stock": stock,
                            "status": status,
                          };

                          Map<String, dynamic> result;

                          if (editing) {
                            result = await _productService.updateProduct(
                              product["id"],
                              body,
                            );
                          } else {
                            result = await _productService.createProduct(body);
                          }

                          if (result["success"] == true) {
                            await loadProducts();

                            saved = true;
                            savedName = name;

                            if (mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } else {
                            AppToast.error(
                              context,
                              result["message"] ?? "Unable to save product.",
                            );
                          }
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
            ? '$savedName updated successfully.'
            : '$savedName added successfully.',
        title: editing ? 'Product Updated' : 'Product Added',
      );
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      nameController.dispose();
      skuController.dispose();
      sizeController.dispose();
      priceController.dispose();
      mrpController.dispose();
      gstController.dispose();
      stockController.dispose();
    });
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          title: const Text('Delete Product'),
          content: Text('Are you sure you want to delete ${product['name']}?'),
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
        );
      },
    );

    if (result != true) return;

    final name = product['name'].toString();

    final response = await _productService.deleteProduct(product["id"]);

    if (response["success"]) {
      await loadProducts();
    } else {
      AppToast.error(context, response["message"]);

      return;
    }

    if (!mounted) return;

    AppToast.success(
      context,
      '$name deleted successfully.',
      title: 'Product Deleted',
    );
  }

  Widget _dialogHeader(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback close,
  ) {
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
                const SizedBox(height: 2),
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

  Widget _formSection({
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

  Widget _formGrid(bool desktop, List<Widget> fields) {
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
          children: fields.map((field) {
            return SizedBox(width: width, child: field);
          }).toList(),
        );
      },
    );
  }

  Widget _professionalInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _formDecoration(label, icon, hint: hint),
    );
  }

  Widget _professionalDropdown({
    required String label,
    required String value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final effectiveItems = items.toSet().toList();
    if (value.isNotEmpty && !effectiveItems.contains(value)) {
      effectiveItems.insert(0, value);
    }
    final safeValue = effectiveItems.contains(value)
        ? value
        : (effectiveItems.isNotEmpty ? effectiveItems.first : null);

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: _formDecoration(label, icon),
      items: effectiveItems
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis, maxLines: 1),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _professionalCategoryPicker({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<int?> onChanged,
  }) {
    final validIds = items.map((cat) => cat['id'] as int?).toSet();
    final safeValue = (value != null && validIds.contains(value))
        ? value
        : null;

    return DropdownButtonFormField<int?>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: _formDecoration(label, Icons.category_outlined),
      hint: const Text('Select Category'),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text(
            'None / Select Category',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        ...items.map((cat) {
          return DropdownMenuItem<int?>(
            value: cat['id'] as int?,
            child: Text(
              cat['full_path']?.toString() ?? cat['name']?.toString() ?? '',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }

  InputDecoration _formDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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

  Widget _dialogFooter({
    required BuildContext dialogContext,
    required String saveLabel,
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
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined, size: 17),
              label: Text(saveLabel, maxLines: 1, softWrap: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final active = status == 'Active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 9,
          color: active ? const Color(0xFF15803D) : const Color(0xFF64748B),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatPrice(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0;

    if (number == number.roundToDouble()) {
      return '₹${number.toInt()}';
    }

    return '₹${number.toStringAsFixed(2)}';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    );
  }
}

class _ProductStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ProductStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
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
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
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

const TextStyle _headerStyle = TextStyle(
  fontSize: 8.5,
  fontWeight: FontWeight.w700,
  color: Color(0xFF64748B),
  letterSpacing: 0.3,
);
