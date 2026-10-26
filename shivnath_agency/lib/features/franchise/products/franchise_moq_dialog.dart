import 'package:flutter/material.dart';
import '../../../core/services/packaging_service.dart';
import '../../../core/repositories/product_repository.dart';
import '../../../core/utils/app_toast.dart';
import '../../../models/product_model.dart';

class FranchiseMoqDialog extends StatefulWidget {
  const FranchiseMoqDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const FranchiseMoqDialog(),
    );
  }

  @override
  State<FranchiseMoqDialog> createState() => _FranchiseMoqDialogState();
}

class _FranchiseMoqDialogState extends State<FranchiseMoqDialog> {
  final PackagingService _service = PackagingService();
  final ProductRepository _productRepo = ProductRepository();

  bool _loading = true;
  List<ProductModel> _products = [];
  List<dynamic> _rules = [];
  final Map<int, int> _overrides = {};
  final Set<int> _savingProductIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await _productRepo.getProducts(status: 'Active');
    final rulesRes = await _service.getPackagingRules();

    if (mounted) {
      setState(() {
        _loading = false;
        _products = ProductRepository.cachedProducts.where((p) {
          final s = p.status.trim().toLowerCase();
          return s == 'active' && p.sku.toUpperCase() != 'BOTTEL1';
        }).toList();

        if (rulesRes['success'] == true) {
          _rules = rulesRes['rules'] as List? ?? [];
          for (final r in _rules) {
            if (r['franchise'] != null && r['product'] != null) {
              _overrides[r['product'] as int] = (r['min_order_quantity'] as int?) ?? 5;
            }
          }
        }
      });
    }
  }

  Map<String, dynamic>? _getBaselineRule(int productId) {
    return _rules.firstWhere(
      (r) => r['product'] == productId && r['franchise'] == null && r['is_active'] == true,
      orElse: () => null,
    ) as Map<String, dynamic>?;
  }

  Map<String, dynamic>? _getFranchiseRule(int productId) {
    return _rules.firstWhere(
      (r) => r['product'] == productId && r['franchise'] != null,
      orElse: () => null,
    ) as Map<String, dynamic>?;
  }

  Future<void> _saveOverride(int productId, int moq) async {
    setState(() => _savingProductIds.add(productId));
    final existingRule = _getFranchiseRule(productId);

    Map<String, dynamic> res;
    if (existingRule != null) {
      res = await _service.updatePackagingRule(existingRule['id'] as int, {
        'min_order_quantity': moq,
      });
    } else {
      res = await _service.createPackagingRule({
        'product': productId,
        'min_order_quantity': moq,
      });
    }

    if (mounted) {
      setState(() => _savingProductIds.remove(productId));
      if (res['success'] == true) {
        AppToast.success(context, 'MOQ override updated successfully');
        _loadData();
      } else {
        AppToast.error(context, res['message']?.toString() ?? 'Failed to update MOQ');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Minimum Order Quantity (MOQ) Rules',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'View company baseline minimums and adjust authorized franchise order rules.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 28),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_products.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('No active products found.', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final p = _products[idx];
                      final pId = int.tryParse(p.id) ?? 0;
                      final baseline = _getBaselineRule(pId);
                      final fRule = _getFranchiseRule(pId);

                      final isJar = p.name.toUpperCase().contains('JAR') ||
                          p.name.toUpperCase().contains('20L') ||
                          p.sku.toUpperCase().contains('JAR');

                      final baselineMoq = baseline?['min_order_quantity'] as int? ?? 5;
                      final salesUnit = baseline?['sales_unit'] ?? (isJar ? 'JAR' : 'CARTON');
                      final unitDisplay = salesUnit == 'JAR' ? 'Jars' : (salesUnit == 'CARTON' ? 'Boxes' : 'Units');
                      final allowOverride = baseline?['allow_franchise_override'] == true;
                      final maxMoq = baseline?['max_franchise_moq'] as int?;

                      final currentOverride = _overrides[pId] ?? (fRule?['min_order_quantity'] as int?) ?? baselineMoq;
                      final isSaving = _savingProductIds.contains(pId);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: allowOverride ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SKU: ${p.sku} • Package: ${isJar ? '20L Reusable Jar' : 'Carton Case'}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: allowOverride ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    allowOverride ? 'Override Permitted' : 'Baseline Enforced',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: allowOverride ? const Color(0xFF166534) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    'Company Baseline MOQ: $baselineMoq $unitDisplay',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                ),
                                if (allowOverride && maxMoq != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Max Allowed: $maxMoq $unitDisplay',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (!allowOverride) ...[
                              const Row(
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Company policy sets standard MOQ at 5 units. Franchise modifications are locked by Administrator.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const Divider(height: 18),
                              Row(
                                children: [
                                  Text(
                                    'Your Franchise MOQ: $currentOverride $unitDisplay',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF0284C7)),
                                    onPressed: currentOverride <= baselineMoq
                                        ? null
                                        : () {
                                            setState(() {
                                              _overrides[pId] = currentOverride - 1;
                                            });
                                          },
                                  ),
                                  Text(
                                    '$currentOverride',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0284C7)),
                                    onPressed: (maxMoq != null && currentOverride >= maxMoq)
                                        ? null
                                        : () {
                                            setState(() {
                                              _overrides[pId] = currentOverride + 1;
                                            });
                                          },
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: isSaving ? null : () => _saveOverride(pId, currentOverride),
                                    child: isSaving
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Save MOQ'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
