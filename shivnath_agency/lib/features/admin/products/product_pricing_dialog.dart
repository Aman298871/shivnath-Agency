import 'package:flutter/material.dart';
import '../../../core/repositories/product_repository.dart';
import '../../../core/widgets/app_toast.dart';

class ProductPricingDialog extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onUpdated;

  const ProductPricingDialog({
    super.key,
    required this.product,
    required this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> product,
    required VoidCallback onUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductPricingDialog(
        product: product,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<ProductPricingDialog> createState() => _ProductPricingDialogState();
}

class _ProductPricingDialogState extends State<ProductPricingDialog> {
  final ProductRepository _productRepo = ProductRepository();

  late TextEditingController _nameCtrl;
  late TextEditingController _skuCtrl;
  late TextEditingController _sizeCtrl;
  late TextEditingController _customerPriceCtrl;
  late TextEditingController _wholesalePriceCtrl;
  late TextEditingController _mrpCtrl;
  late TextEditingController _cartonPriceCtrl;
  late TextEditingController _unitsPerCartonCtrl;
  late TextEditingController _discountPriceCtrl;
  late TextEditingController _gstCtrl;

  late String _unit;
  late bool _isPriceInclusiveGst;
  late String _packageType;
  bool _saving = false;

  final List<String> _unitOptions = [
    'Bottle',
    'Jar',
    'Carton',
    'Pack',
    'Piece',
    'Box',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameCtrl = TextEditingController(text: p['name']?.toString() ?? '');
    _skuCtrl = TextEditingController(text: p['sku']?.toString() ?? '');
    _sizeCtrl = TextEditingController(text: p['size']?.toString() ?? '');
    _customerPriceCtrl = TextEditingController(
      text: (p['price'] ?? p['customer_price'] ?? '').toString(),
    );
    _wholesalePriceCtrl = TextEditingController(
      text: (p['dealer_transfer_price'] ?? p['dealer_wholesale_price'] ?? p['price'] ?? '').toString(),
    );
    _mrpCtrl = TextEditingController(
      text: (p['mrp'] ?? p['retail_mrp'] ?? p['price'] ?? '').toString(),
    );
    _cartonPriceCtrl = TextEditingController(
      text: (p['carton_price'] ?? '0.0').toString(),
    );
    _unitsPerCartonCtrl = TextEditingController(
      text: (p['units_per_case'] ?? p['units_per_carton'] ?? '24').toString(),
    );
    _discountPriceCtrl = TextEditingController(
      text: (p['discount_price'] ?? '0.0').toString(),
    );
    _gstCtrl = TextEditingController(
      text: (p['gst'] ?? p['gst_rate'] ?? '18').toString(),
    );

    _unit = p['unit']?.toString() ?? 'Bottle';
    if (!_unitOptions.contains(_unit)) {
      _unitOptions.add(_unit);
    }

    _packageType = (p['package_type']?.toString().toUpperCase() == 'JAR') ? 'JAR' : 'BOTTLE';

    if (p['is_price_inclusive_gst'] is bool) {
      _isPriceInclusiveGst = p['is_price_inclusive_gst'] as bool;
    } else {
      _isPriceInclusiveGst = p['is_price_inclusive_gst']?.toString().toLowerCase() != 'false';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _sizeCtrl.dispose();
    _customerPriceCtrl.dispose();
    _wholesalePriceCtrl.dispose();
    _mrpCtrl.dispose();
    _cartonPriceCtrl.dispose();
    _unitsPerCartonCtrl.dispose();
    _discountPriceCtrl.dispose();
    _gstCtrl.dispose();
    super.dispose();
  }

  double get _customerPrice => double.tryParse(_customerPriceCtrl.text.trim()) ?? 0.0;
  double get _wholesalePrice => double.tryParse(_wholesalePriceCtrl.text.trim()) ?? 0.0;
  int get _unitsPerCarton => int.tryParse(_unitsPerCartonCtrl.text.trim()) ?? 1;
  double get _discountPrice => double.tryParse(_discountPriceCtrl.text.trim()) ?? 0.0;
  int get _gst => int.tryParse(_gstCtrl.text.trim()) ?? 18;

  double get _effectivePrice =>
      (_discountPrice > 0 && _discountPrice < _customerPrice) ? _discountPrice : _customerPrice;

  double get _franchiseMargin => _customerPrice - _wholesalePrice;
  double get _franchiseMarginPct =>
      _customerPrice > 0 ? (_franchiseMargin / _customerPrice) * 100 : 0.0;

  void _autoCalculateCartonPrice() {
    final autoPrice = _effectivePrice * _unitsPerCarton;
    setState(() {
      _cartonPriceCtrl.text = autoPrice.toStringAsFixed(2);
    });
  }

  Future<void> _savePricing() async {
    final custPriceText = _customerPriceCtrl.text.trim();
    final wholesalePriceText = _wholesalePriceCtrl.text.trim();
    final mrpText = _mrpCtrl.text.trim();
    final cartonPriceText = _cartonPriceCtrl.text.trim();
    final discountPriceText = _discountPriceCtrl.text.trim();
    final unitsText = _unitsPerCartonCtrl.text.trim();
    final gstText = _gstCtrl.text.trim();

    final cPrice = double.tryParse(custPriceText);
    if (cPrice == null || cPrice < 0) {
      AppToast.error(context, 'Enter a valid Customer Retail Price (>= 0).');
      return;
    }

    final wPrice = double.tryParse(wholesalePriceText);
    if (wPrice == null || wPrice < 0) {
      AppToast.error(context, 'Enter a valid Franchise Wholesale Rate (>= 0).');
      return;
    }

    final mrpVal = mrpText.isEmpty ? cPrice : double.tryParse(mrpText);
    if (mrpVal == null || mrpVal < 0) {
      AppToast.error(context, 'Enter a valid MRP (>= 0).');
      return;
    }

    final cartonVal = cartonPriceText.isEmpty ? 0.0 : double.tryParse(cartonPriceText);
    if (cartonVal == null || cartonVal < 0) {
      AppToast.error(context, 'Carton price cannot be negative.');
      return;
    }

    final discountVal = discountPriceText.isEmpty ? 0.0 : double.tryParse(discountPriceText);
    if (discountVal == null || discountVal < 0) {
      AppToast.error(context, 'Discount price cannot be negative.');
      return;
    }

    final upcVal = int.tryParse(unitsText);
    if (upcVal == null || upcVal < 1) {
      AppToast.error(context, 'Units per carton/case must be at least 1.');
      return;
    }

    final gstVal = int.tryParse(gstText);
    if (gstVal == null || gstVal < 0 || gstVal > 100) {
      AppToast.error(context, 'GST rate must be between 0 and 100%.');
      return;
    }

    setState(() => _saving = true);

    final productId = widget.product['id'];
    final int? id = productId is int ? productId : int.tryParse(productId.toString());
    if (id == null) {
      AppToast.error(context, 'Invalid product identifier.');
      setState(() => _saving = false);
      return;
    }

    final payload = {
      'price': cPrice,
      'customer_price': cPrice,
      'dealer_transfer_price': wPrice,
      'dealer_wholesale_price': wPrice,
      'mrp': mrpVal,
      'retail_mrp': mrpVal,
      'carton_price': cartonVal,
      'discount_price': discountVal,
      'units_per_case': upcVal,
      'units_per_carton': upcVal,
      'bottles_per_box': upcVal,
      'gst': gstVal,
      'gst_rate': gstVal,
      'is_price_inclusive_gst': _isPriceInclusiveGst,
      'unit': _unit,
      'size': _sizeCtrl.text.trim(),
      'package_type': _packageType,
    };

    final res = await _productRepo.updateProductPricing(id, payload);

    if (mounted) {
      setState(() => _saving = false);
      if (res['success'] == true) {
        AppToast.success(
          context,
          'Pricing & packaging saved for "${widget.product['name']}".',
        );
        widget.onUpdated();
        Navigator.of(context).pop();
      } else {
        AppToast.error(
          context,
          res['message'] ?? 'Unable to update product pricing.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.of(context).size.width >= 750;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: desktop ? 48 : 16,
        vertical: desktop ? 24 : 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(desktop ? 22 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductSummaryCard(),
                      const SizedBox(height: 18),
                      _buildPricingSection(desktop),
                      const SizedBox(height: 18),
                      _buildMarginSummaryCard(),
                      const SizedBox(height: 18),
                      _buildPackagingSection(desktop),
                      const SizedBox(height: 18),
                      _buildTaxAndDiscountSection(desktop),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Icon(
              Icons.currency_rupee_rounded,
              color: Color(0xFF059669),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product Pricing & Packaging',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Manage retail price, wholesale rates, box packaging conversion, and GST rules',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSummaryCard() {
    final p = widget.product;
    final catName = p['category_hierarchy'] ?? p['category_name'] ?? p['category'] ?? 'Water';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      p['name']?.toString() ?? 'Product',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p['sku']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Category: $catName | Current Size: ${p['size'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Text(
              _packageType == 'JAR' ? '20L Jar' : 'Bottled Water',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection(bool desktop) {
    return _sectionCard(
      title: 'Price Configuration',
      subtitle: 'Customer retail prices, wholesale dealer transfer rates, and printed MRP',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          if (desktop)
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    controller: _customerPriceCtrl,
                    label: 'Customer Retail Price (₹) *',
                    hint: 'e.g. 20.00',
                    icon: Icons.storefront_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _inputField(
                    controller: _wholesalePriceCtrl,
                    label: 'Franchise Wholesale Rate (₹) *',
                    hint: 'e.g. 14.00',
                    icon: Icons.handshake_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _inputField(
                    controller: _mrpCtrl,
                    label: 'Maximum Retail Price (MRP ₹)',
                    hint: 'Label printed MRP',
                    icon: Icons.price_change_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            )
          else ...[
            _inputField(
              controller: _customerPriceCtrl,
              label: 'Customer Retail Price (₹) *',
              hint: 'e.g. 20.00',
              icon: Icons.storefront_outlined,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _inputField(
              controller: _wholesalePriceCtrl,
              label: 'Franchise Wholesale Rate (₹) *',
              hint: 'e.g. 14.00',
              icon: Icons.handshake_outlined,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _inputField(
              controller: _mrpCtrl,
              label: 'Maximum Retail Price (MRP ₹)',
              hint: 'Label printed MRP',
              icon: Icons.price_change_outlined,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarginSummaryCard() {
    final isNegative = _wholesalePrice > _customerPrice && _customerPrice > 0;
    final isZero = _franchiseMargin == 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNegative
            ? const Color(0xFFFEF2F2)
            : (isZero ? const Color(0xFFF8FAFC) : const Color(0xFFF0FDF4)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNegative
              ? const Color(0xFFFECACA)
              : (isZero ? const Color(0xFFE2E8F0) : const Color(0xFFBBF7D0)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isNegative
                ? Icons.warning_amber_rounded
                : (isZero ? Icons.info_outline : Icons.trending_up_rounded),
            color: isNegative
                ? const Color(0xFFDC2626)
                : (isZero ? const Color(0xFF64748B) : const Color(0xFF16A34A)),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Franchise Profit Margin: ₹${_franchiseMargin.toStringAsFixed(2)} per unit (${_franchiseMarginPct.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isNegative
                        ? const Color(0xFF991B1B)
                        : (isZero ? const Color(0xFF334155) : const Color(0xFF166534)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isNegative
                      ? 'WARNING: Franchise wholesale transfer rate exceeds customer retail selling price!'
                      : 'Franchise earns ₹${_franchiseMargin.toStringAsFixed(2)} per individual unit delivered.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isNegative ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackagingSection(bool desktop) {
    return _sectionCard(
      title: 'Packaging & Pack Conversion',
      subtitle: 'Box/Carton packing units, variant size, and box wholesale/retail price',
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: [
          if (desktop)
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    controller: _unitsPerCartonCtrl,
                    label: 'Units Per Carton / Case *',
                    hint: 'e.g. 24 for 250ml, 1 for 20L',
                    icon: Icons.all_inbox_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _inputField(
                    controller: _cartonPriceCtrl,
                    label: 'Carton / Box Price (₹)',
                    hint: 'Leave 0 to auto-calculate',
                    icon: Icons.inventory_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unit of Measure *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: _inputDecoration(null, Icons.scale_outlined),
                        items: _unitOptions
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _unit = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            _inputField(
              controller: _unitsPerCartonCtrl,
              label: 'Units Per Carton / Case *',
              hint: 'e.g. 24 for 250ml, 1 for 20L',
              icon: Icons.all_inbox_outlined,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _inputField(
              controller: _cartonPriceCtrl,
              label: 'Carton / Box Price (₹)',
              hint: 'Leave 0 to auto-calculate',
              icon: Icons.inventory_outlined,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unit of Measure *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: _inputDecoration(null, Icons.scale_outlined),
                  items: _unitOptions
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _unit = val);
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Auto-calculated carton price: ₹${(_effectivePrice * _unitsPerCarton).toStringAsFixed(2)} '
                  '($_unitsPerCarton ${_unit}s @ ₹${_effectivePrice.toStringAsFixed(2)})',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF0284C7)),
                onPressed: _autoCalculateCartonPrice,
                icon: const Icon(Icons.calculate_outlined, size: 16),
                label: const Text('Apply Calculated Price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxAndDiscountSection(bool desktop) {
    return _sectionCard(
      title: 'GST Treatment & Promotional Pricing',
      subtitle: 'Tax rate percentage, tax inclusion mode, and discount pricing',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          if (desktop)
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    controller: _gstCtrl,
                    label: 'GST Rate (%) *',
                    hint: '18',
                    icon: Icons.percent_rounded,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _inputField(
                    controller: _discountPriceCtrl,
                    label: 'Promotional / Discount Price (₹)',
                    hint: '0 for no discount',
                    icon: Icons.local_offer_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _inputField(
                    controller: _sizeCtrl,
                    label: 'Variant / Volume Size *',
                    hint: 'e.g. 250ml, 1 Litre',
                    icon: Icons.straighten_outlined,
                  ),
                ),
              ],
            )
          else ...[
            _inputField(
              controller: _gstCtrl,
              label: 'GST Rate (%) *',
              hint: '18',
              icon: Icons.percent_rounded,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _inputField(
              controller: _discountPriceCtrl,
              label: 'Promotional / Discount Price (₹)',
              hint: '0 for no discount',
              icon: Icons.local_offer_outlined,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _inputField(
              controller: _sizeCtrl,
              label: 'Variant / Volume Size *',
              hint: 'e.g. 250ml, 1 Litre',
              icon: Icons.straighten_outlined,
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _isPriceInclusiveGst,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: (val) {
                    if (val != null) setState(() => _isPriceInclusiveGst = val);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product price is inclusive of GST (Standard MRP)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        _isPriceInclusiveGst
                            ? 'Customer pays displayed price ₹${_effectivePrice.toStringAsFixed(2)}. GST ($_gst%) is calculated inside the total.'
                            : 'GST ($_gst%) will be added on top of ₹${_effectivePrice.toStringAsFixed(2)} at checkout.',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
              Icon(icon, size: 18, color: const Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          decoration: _inputDecoration(hint, icon),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String? hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _saving ? null : _savePricing,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(_saving ? 'Saving...' : 'Save Pricing & Packaging'),
          ),
        ],
      ),
    );
  }
}
