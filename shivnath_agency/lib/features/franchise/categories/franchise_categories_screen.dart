import 'package:flutter/material.dart';

import '../../../core/services/product_service.dart';
import '../../../core/utils/app_toast.dart';

class FranchiseCategoriesScreen extends StatefulWidget {
  const FranchiseCategoriesScreen({super.key});

  @override
  State<FranchiseCategoriesScreen> createState() =>
      _FranchiseCategoriesScreenState();
}

class _FranchiseCategoriesScreenState extends State<FranchiseCategoriesScreen> {
  final ProductService _productService = ProductService();

  List<Map<String, dynamic>> _categoryTree = [];
  List<Map<String, dynamic>> _flatCategories = [];
  final Set<int> _expandedCategoryIds = {};
  bool _loading = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final res = await _productService.getCategories(treeOnly: true);
      if (res['success'] == true && res['data'] is Map) {
        final list = res['data']['categories'] as List? ?? [];
        _categoryTree = List<Map<String, dynamic>>.from(list);
        _flatCategories = [];
        _flattenCategories(_categoryTree, '');
        _collectCategoryIds(_categoryTree, _expandedCategoryIds);
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  void _flattenCategories(List<dynamic> list, String prefix) {
    for (var item in list) {
      if (item is Map<String, dynamic>) {
        final path = prefix.isEmpty
            ? item['name'].toString()
            : '$prefix > ${item['name']}';
        _flatCategories.add({
          'id': item['id'],
          'name': item['name'],
          'full_path': item['full_path'] ?? path,
          'is_active': item['is_active'] ?? true,
          'product_count': item['product_count'] ?? 0,
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

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: desktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              title: const Text(
                'Product Categories',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF0284C7),
                  ),
                  onPressed: _loadCategories,
                  tooltip: 'Refresh',
                ),
              ],
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desktop) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Product Categories',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Official company product catalog hierarchy and variant groupings',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: _loadCategories,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Refresh'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0284C7),
                              side: const BorderSide(color: Color(0xFF0284C7)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Search & Actions toolbar
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (val) => setState(
                                () => _search = val.trim().toLowerCase(),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search categories by name...',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF94A3B8),
                                ),
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                if (_expandedCategoryIds.isEmpty) {
                                  _collectCategoryIds(
                                    _categoryTree,
                                    _expandedCategoryIds,
                                  );
                                } else {
                                  _expandedCategoryIds.clear();
                                }
                              });
                            },
                            icon: Icon(
                              _expandedCategoryIds.isEmpty
                                  ? Icons.unfold_more_rounded
                                  : Icons.unfold_less_rounded,
                              size: 18,
                              color: const Color(0xFF0284C7),
                            ),
                            label: Text(
                              _expandedCategoryIds.isEmpty
                                  ? 'Expand All'
                                  : 'Collapse All',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0284C7),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Categories Tree Container
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            )
                          : _categoryTree.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.category_outlined,
                                      size: 48,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No product categories found.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Company product categories will appear here once configured by Admin.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(12),
                              child: _buildTreeWidget(
                                _filterTree(_categoryTree),
                                0,
                                desktop: desktop,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _filterTree(List<Map<String, dynamic>> nodes) {
    if (_search.isEmpty) return nodes;

    List<Map<String, dynamic>> result = [];
    for (var node in nodes) {
      final name = (node['name'] ?? '').toString().toLowerCase();
      final children = node['children'] ?? node['subcategories'];
      List<Map<String, dynamic>> matchedChildren = [];
      if (children is List && children.isNotEmpty) {
        matchedChildren = _filterTree(
          List<Map<String, dynamic>>.from(children),
        );
      }

      if (name.contains(_search) || matchedChildren.isNotEmpty) {
        final copy = Map<String, dynamic>.from(node);
        if (matchedChildren.isNotEmpty) {
          copy['children'] = matchedChildren;
        }
        result.add(copy);
      }
    }
    return result;
  }

  Widget _buildTreeWidget(
    List<Map<String, dynamic>> nodes,
    int depth, {
    required bool desktop,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: nodes.map((cat) {
        final catId = cat['id'] as int? ?? 0;
        final name = cat['name']?.toString() ?? '';
        final isActive = cat['is_active'] == true;
        final productCount = cat['product_count'] ?? 0;
        final rawChildren = cat['children'] ?? cat['subcategories'];
        final children = rawChildren is List
            ? List<Map<String, dynamic>>.from(rawChildren)
            : <Map<String, dynamic>>[];
        final hasChildren = children.isNotEmpty;
        final isExpanded = _expandedCategoryIds.contains(catId);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: depth == 0 ? const Color(0xFFF8FAFC) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: depth == 0
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFFF1F5F9),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 12.0 + (depth * 20.0) : 8.0 + (depth * 14.0),
                  8,
                  8,
                  8,
                ),
                child: Row(
                  children: [
                    if (hasChildren)
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedCategoryIds.remove(catId);
                            } else {
                              _expandedCategoryIds.add(catId);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isExpanded
                                ? Icons.expand_more_rounded
                                : Icons.chevron_right_rounded,
                            size: 20,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.circle,
                          size: 5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    const SizedBox(width: 4),
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
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: depth == 0 ? 14 : 13,
                          fontWeight: depth == 0
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isActive
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
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
                          fontSize: 10,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
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
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasChildren && isExpanded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildTreeWidget(
                    children,
                    depth + 1,
                    desktop: desktop,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
