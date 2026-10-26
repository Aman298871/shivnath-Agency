import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_constants.dart';
import '../services/session_service.dart';
import 'app_toast.dart';

/// Interactive high-speed In-App Thermal POS Slip & Invoice Modal.
/// Provides 0ms instantaneous receipt preview, 80mm/58mm format toggle,
/// debounced execution, strict 10s HTTP fallbacks, and sequential system print/share.
class ThermalBillPreviewModal extends StatefulWidget {
  final Map<String, dynamic>? orderData;
  final Map<String, dynamic>? invoiceData;
  final int? invoiceId;

  const ThermalBillPreviewModal({
    super.key,
    this.orderData,
    this.invoiceData,
    this.invoiceId,
  });

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? orderData,
    Map<String, dynamic>? invoiceData,
    int? invoiceId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ThermalBillPreviewModal(
        orderData: orderData,
        invoiceData: invoiceData,
        invoiceId: invoiceId,
      ),
    );
  }

  @override
  State<ThermalBillPreviewModal> createState() =>
      _ThermalBillPreviewModalState();
}

class _ThermalBillPreviewModalState extends State<ThermalBillPreviewModal> {
  int _paperWidthMm = 80; // 80mm (Desktop POS) or 58mm (Handheld Bluetooth)
  bool _isDownloadingPdf = false;
  bool _isPrinting = false;
  bool _isSharing = false;

  int? get _resolvedInvoiceId {
    if (widget.invoiceId != null && widget.invoiceId! > 0) {
      return widget.invoiceId;
    }
    final invIdFromInv = int.tryParse(widget.invoiceData?['id']?.toString() ?? '');
    if (invIdFromInv != null && invIdFromInv > 0) return invIdFromInv;

    final invIdFromOrd = int.tryParse(widget.orderData?['invoice_id']?.toString() ?? '');
    if (invIdFromOrd != null && invIdFromOrd > 0) return invIdFromOrd;

    return null;
  }

  String get _invoiceNumber {
    return widget.invoiceData?['invoice']?.toString() ??
        widget.invoiceData?['invoice_number']?.toString() ??
        widget.orderData?['invoice_number']?.toString() ??
        widget.orderData?['order_code']?.toString() ??
        'INV-${_resolvedInvoiceId ?? "DRAFT"}';
  }

  String get _customerName {
    return widget.orderData?['customer_name']?.toString() ??
        widget.invoiceData?['customer']?.toString() ??
        widget.invoiceData?['billed_to_name']?.toString() ??
        'Valued Customer';
  }

  String get _orderCode {
    return widget.orderData?['order_code']?.toString() ??
        widget.invoiceData?['order']?.toString() ??
        '#ORD-${widget.orderData?['id'] ?? widget.invoiceData?['order_id'] ?? ""}';
  }

  double get _subtotal {
    final v = widget.orderData?['invoice_subtotal'] ??
        widget.orderData?['subtotal'] ??
        widget.invoiceData?['subtotal'] ??
        widget.orderData?['amount'] ??
        widget.invoiceData?['total'] ??
        0;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  double get _tax {
    final v = widget.orderData?['invoice_tax'] ??
        widget.orderData?['tax_amount'] ??
        widget.invoiceData?['gst'] ??
        widget.invoiceData?['tax'] ??
        0;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  double get _taxRate {
    final snap = widget.invoiceData?['financial_snapshot'] as Map<String, dynamic>?;
    final v = snap?['gst_rate'] ?? widget.invoiceData?['tax_rate'] ?? widget.orderData?['tax_rate'];
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  double get _cgstRate {
    final snap = widget.invoiceData?['financial_snapshot'] as Map<String, dynamic>?;
    final v = snap?['cgst_rate'] ?? widget.invoiceData?['cgst_rate'] ?? widget.orderData?['cgst_rate'];
    return double.tryParse(v?.toString() ?? '') ?? (_taxRate > 0 ? _taxRate / 2 : 0.0);
  }

  double get _sgstRate {
    final snap = widget.invoiceData?['financial_snapshot'] as Map<String, dynamic>?;
    final v = snap?['sgst_rate'] ?? widget.invoiceData?['sgst_rate'] ?? widget.orderData?['sgst_rate'];
    return double.tryParse(v?.toString() ?? '') ?? (_taxRate > 0 ? _taxRate / 2 : 0.0);
  }

  double get _igstRate {
    final snap = widget.invoiceData?['financial_snapshot'] as Map<String, dynamic>?;
    final v = snap?['igst_rate'] ?? widget.invoiceData?['igst_rate'] ?? widget.orderData?['igst_rate'];
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  double get _taxableAmount {
    final snap = widget.invoiceData?['financial_snapshot'] as Map<String, dynamic>?;
    final v = snap?['taxable_amount'] ?? widget.invoiceData?['taxable_amount'] ?? widget.orderData?['taxable_amount'];
    return double.tryParse(v?.toString() ?? '') ?? _subtotal;
  }

  double get _customerOutstandingBalance {
    final v = widget.orderData?['customer_outstanding_balance'] ??
        widget.invoiceData?['customer_outstanding_balance'] ??
        widget.orderData?['customer_dues'] ??
        widget.invoiceData?['customer_dues'] ??
        0;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  double get _deliveryFee {
    final v = widget.orderData?['delivery_charges'] ??
        widget.invoiceData?['delivery_charges'] ??
        0;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  double get _grandTotal {
    final v = widget.orderData?['invoice_grand_total'] ??
        widget.orderData?['grand_total'] ??
        widget.invoiceData?['total'] ??
        widget.orderData?['amount'] ??
        0;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  double get _amountPaid {
    final v = widget.orderData?['amount_paid'] ??
        widget.invoiceData?['paid'] ??
        0;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String get _paymentStatus {
    final status = (widget.orderData?['payment_status'] ??
            widget.invoiceData?['status'] ??
            '')
        .toString()
        .toUpperCase();
    if (_grandTotal > 0 && (_grandTotal - _amountPaid) <= 0.05) {
      return 'PAID';
    }
    if (_amountPaid > 0 && (_grandTotal - _amountPaid) > 0.05) {
      return 'PARTIALLY PAID';
    }
    if (status.contains('PAID')) return 'PAID';
    return status.isNotEmpty ? status : 'PENDING';
  }

  List<Map<String, dynamic>> get _items {
    final rawItems = widget.orderData?['items'] ??
        widget.invoiceData?['items'] ??
        widget.invoiceData?['order_items_snapshot'];
    if (rawItems is List && rawItems.isNotEmpty) {
      return rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [
      {
        'product_name': 'Shivnath Mineral Packaged Water',
        'quantity': 1,
        'unit_price': _subtotal > 0 ? _subtotal : _grandTotal,
        'total_price': _subtotal > 0 ? _subtotal : _grandTotal,
      }
    ];
  }

  String _formatPlainReceiptText() {
    final buffer = StringBuffer();
    final width = _paperWidthMm == 58 ? 32 : 44;
    final div = '=' * width;
    final subDiv = '-' * width;

    buffer.writeln(div);
    buffer.writeln('     SHIVNATH AGENCIES (WATER WALA)');
    buffer.writeln('    Pure Packaged Drinking Water');
    buffer.writeln(' Raipur, Chhattisgarh | Helpline: 1800-SHIVNATH');
    buffer.writeln(div);
    buffer.writeln('Receipt / Inv: $_invoiceNumber');
    buffer.writeln('Order Ref   : $_orderCode');
    buffer.writeln('Customer    : $_customerName');
    buffer.writeln('Date/Time   : ${DateTime.now().toLocal().toString().split('.')[0]}');
    buffer.writeln(subDiv);
    buffer.writeln(_paperWidthMm == 58 ? 'Item           Qty  Rate  Total' : 'Item Description          Qty   Rate    Total');
    buffer.writeln(subDiv);

    for (final item in _items) {
      final name = item['product_name']?.toString() ?? 'Packaged Water';
      final qty = item['quantity']?.toString() ?? '1';
      final packaging = item['packaging_display']?.toString();
      final rate = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0.0;
      final total = double.tryParse(item['total_price']?.toString() ?? '0') ?? 0.0;

      final shortName = name.length > (_paperWidthMm == 58 ? 14 : 24)
          ? '${name.substring(0, _paperWidthMm == 58 ? 12 : 22)}..'
          : name;
      buffer.writeln('${shortName.padRight(_paperWidthMm == 58 ? 14 : 24)} ${qty.padLeft(3)} ${rate.toStringAsFixed(0).padLeft(5)} ${total.toStringAsFixed(2).padLeft(7)}');
      if (packaging != null && packaging.isNotEmpty) {
        buffer.writeln('  Pkg: $packaging');
      }
    }

    buffer.writeln(subDiv);
    buffer.writeln('Subtotal      : Rs. ${_subtotal.toStringAsFixed(2)}');
    if (_taxableAmount > 0 && (_taxableAmount - _subtotal).abs() > 0.01) {
      buffer.writeln('Taxable Base  : Rs. ${_taxableAmount.toStringAsFixed(2)}');
    }
    if (_tax > 0) {
      if (_igstRate > 0) {
        final rateStr = _igstRate.toStringAsFixed(_igstRate.truncateToDouble() == _igstRate ? 0 : 1);
        buffer.writeln('IGST ($rateStr%)   : Rs. ${_tax.toStringAsFixed(2)}');
      } else {
        final cRate = _cgstRate > 0 ? _cgstRate : (_taxRate > 0 ? _taxRate / 2 : 9.0);
        final sRate = _sgstRate > 0 ? _sgstRate : (_taxRate > 0 ? _taxRate / 2 : 9.0);
        final cStr = cRate.toStringAsFixed(cRate.truncateToDouble() == cRate ? 0 : 1);
        final sStr = sRate.toStringAsFixed(sRate.truncateToDouble() == sRate ? 0 : 1);
        buffer.writeln('CGST ($cStr%)   : Rs. ${(_tax / 2).toStringAsFixed(2)}');
        buffer.writeln('SGST ($sStr%)   : Rs. ${(_tax / 2).toStringAsFixed(2)}');
      }
    }
    if (_deliveryFee > 0) {
      buffer.writeln('Delivery Fee  : Rs. ${_deliveryFee.toStringAsFixed(2)}');
    } else {
      buffer.writeln('Delivery Fee  : FREE');
    }
    buffer.writeln(div);
    buffer.writeln('GRAND TOTAL   : Rs. ${_grandTotal.toStringAsFixed(2)}');
    buffer.writeln('PAYMENT STATUS: $_paymentStatus');
    if (_customerOutstandingBalance > 0.01) {
      buffer.writeln(subDiv);
      buffer.writeln('PAST DUES (SEPARATE): Rs. ${_customerOutstandingBalance.toStringAsFixed(2)}');
    }
    buffer.writeln(div);
    buffer.writeln(' Thank you for ordering with Shivnath Agency!');
    buffer.writeln(' Scan QR or Visit: shivnathagency.in');
    buffer.writeln(div);

    return buffer.toString();
  }

  Future<void> _handleShareReceiptText() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final text = _formatPlainReceiptText();
      await SharePlus.instance.share(ShareParams(text: text, subject: 'WATER WALA Thermal Slip: $_invoiceNumber'));
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not share thermal slip: $e');
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<File?> _fetchInvoicePdfWithTimeout() async {
    final invId = _resolvedInvoiceId;
    if (invId == null) {
      throw Exception('Invoice record has not been generated for this order yet.');
    }

    final token = await SessionService().getAccessToken();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/invoices/$invId/download/');

    final res = await http.get(
      uri,
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Server request timed out after 10 seconds. Check network connectivity.'),
    );

    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      throw Exception('Server returned HTTP ${res.statusCode} when generating invoice PDF.');
    }

    Directory targetDir;
    if (Platform.isAndroid) {
      final publicDownloadDir = Directory('/storage/emulated/0/Download');
      if (publicDownloadDir.existsSync()) {
        targetDir = publicDownloadDir;
      } else {
        final ext = await getExternalStorageDirectory();
        targetDir = ext ?? await getApplicationDocumentsDirectory();
      }
    } else {
      targetDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }

    final safeName = _invoiceNumber.replaceAll(RegExp(r'[\\/*?:"<>|]'), '_');
    final file = File('${targetDir.path}/Invoice_$safeName.pdf');
    await file.writeAsBytes(res.bodyBytes, flush: true);
    return file;
  }

  Future<void> _handleSystemPrint() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      AppToast.info(context, 'Preparing print document...', title: 'Print Service');
      final file = await _fetchInvoicePdfWithTimeout();
      if (file == null || !file.existsSync()) {
        throw Exception('Failed to generate local printable document.');
      }

      if (mounted) {
        AppToast.success(context, 'Document ready. Opening printer intent...', title: 'Printing');
      }

      // Open print/viewer intent sequentially
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        // Fallback to sharing the file if no dedicated PDF viewer exists
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'WATER WALA Print Invoice: $_invoiceNumber'));
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e.toString().replaceAll('Exception: ', ''), title: 'Print Error');
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _handleDownloadPdf() async {
    if (_isDownloadingPdf) return;
    setState(() => _isDownloadingPdf = true);

    try {
      AppToast.info(context, 'Downloading official PDF...', title: 'Downloading');
      final file = await _fetchInvoicePdfWithTimeout();
      if (file != null && file.existsSync()) {
        if (mounted) {
          AppToast.success(
            context,
            'Saved to Downloads: ${file.path.split('/').last}',
            title: 'PDF Saved',
          );
        }
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e.toString().replaceAll('Exception: ', ''), title: 'Download Error');
      }
    } finally {
      if (mounted) setState(() => _isDownloadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final is58mm = _paperWidthMm == 58;
    final isPaid = _paymentStatus == 'PAID';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with Paper Width Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Color(0xFF0284C7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thermal POS Bill',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _invoiceNumber,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Width Toggle (80mm vs 58mm)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildWidthPill(80, '80mm'),
                      _buildWidthPill(58, '58mm'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Receipt Preview Scrollable Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: is58mm ? 290 : 360,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Serrated Top Edge representation
                      Container(
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0284C7),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Company Brand
                            const Text(
                              'SHIVNATH AGENCIES',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Text(
                              'WATER WALA PACKAGED DRINKING WATER',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const Text(
                              'Raipur, C.G. | Customer Care: 1800-SHIVNATH',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: Color(0xFF64748B),
                              ),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: _DashedLine(),
                            ),

                            // Metadata Grid
                            _buildThermalMetaRow('RECEIPT #', _invoiceNumber),
                            _buildThermalMetaRow('ORDER CODE', _orderCode),
                            _buildThermalMetaRow('CUSTOMER', _customerName),
                            _buildThermalMetaRow(
                              'DATE/TIME',
                              DateTime.now().toLocal().toString().substring(0, 16),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: _DashedLine(),
                            ),

                            // Items Table Header
                            Row(
                              children: [
                                const Expanded(
                                  flex: 3,
                                  child: Text(
                                    'ITEM',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  flex: 1,
                                  child: Text(
                                    'QTY',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  flex: 2,
                                  child: Text(
                                    'RATE',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  flex: 2,
                                  child: Text(
                                    'AMOUNT',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const _DashedLine(),
                            const SizedBox(height: 4),

                            // Item Rows
                            ..._items.map((item) {
                              final name = item['product_name']?.toString() ?? 'Packaged Water';
                              final qty = item['quantity']?.toString() ?? '1';
                              final packaging = item['packaging_display']?.toString();
                              final rate = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0.0;
                              final total = double.tryParse(item['total_price']?.toString() ?? '0') ?? 0.0;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.5),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (packaging != null && packaging.isNotEmpty)
                                            Text(
                                              packaging,
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0284C7),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        qty,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        rate.toStringAsFixed(0),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        total.toStringAsFixed(2),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: _DashedLine(),
                            ),

                            // Financial Summary
                            _buildThermalSummaryRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),
                            if (_taxableAmount > 0 && (_taxableAmount - _subtotal).abs() > 0.01)
                              _buildThermalSummaryRow('Taxable Base', '₹${_taxableAmount.toStringAsFixed(2)}'),
                            if (_tax > 0) ...[
                              if (_igstRate > 0)
                                _buildThermalSummaryRow(
                                  'IGST (${_igstRate.toStringAsFixed(_igstRate.truncateToDouble() == _igstRate ? 0 : 1)}%)',
                                  '₹${_tax.toStringAsFixed(2)}',
                                )
                              else ...[
                                _buildThermalSummaryRow(
                                  'CGST (${(_cgstRate > 0 ? _cgstRate : (_taxRate > 0 ? _taxRate / 2 : 9.0)).toStringAsFixed((_cgstRate > 0 ? _cgstRate : (_taxRate > 0 ? _taxRate / 2 : 9.0)).truncateToDouble() == (_cgstRate > 0 ? _cgstRate : (_taxRate > 0 ? _taxRate / 2 : 9.0)) ? 0 : 1)}%)',
                                  '₹${(_tax / 2).toStringAsFixed(2)}',
                                ),
                                _buildThermalSummaryRow(
                                  'SGST (${(_sgstRate > 0 ? _sgstRate : (_taxRate > 0 ? _taxRate / 2 : 9.0)).toStringAsFixed((_sgstRate > 0 ? _sgstRate : (_taxRate > 0 ? _taxRate / 2 : 9.0)).truncateToDouble() == (_sgstRate > 0 ? _sgstRate : (_taxRate > 0 ? _taxRate / 2 : 9.0)) ? 0 : 1)}%)',
                                  '₹${(_tax / 2).toStringAsFixed(2)}',
                                ),
                              ],
                            ],
                            _buildThermalSummaryRow(
                              'Delivery Fee',
                              _deliveryFee > 0 ? '₹${_deliveryFee.toStringAsFixed(2)}' : 'FREE',
                            ),

                            const SizedBox(height: 6),
                            const _DashedLine(),
                            const SizedBox(height: 6),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'GRAND TOTAL',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '₹${_grandTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),

                            if (_customerOutstandingBalance > 0.01) ...[
                              const SizedBox(height: 6),
                              const _DashedLine(),
                              const SizedBox(height: 4),
                              _buildThermalSummaryRow(
                                'Past Outstanding (Separate)',
                                '₹${_customerOutstandingBalance.toStringAsFixed(2)}',
                                isDues: true,
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Payment Stamp Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '*** $_paymentStatus ***',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                  color: isPaid ? const Color(0xFF166534) : const Color(0xFFB45309),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            const Text(
                              'Thank you for ordering with Water Wala!',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const Text(
                              '100% Hygienic • Reverse Osmosis Purified',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 8,
                                color: Color(0xFF94A3B8),
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
          ),

          // Bottom Action Buttons Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Share Plain Slip / Text
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: (_isSharing || _isPrinting || _isDownloadingPdf)
                          ? null
                          : _handleShareReceiptText,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share_rounded, size: 16, color: Color(0xFF475569)),
                      label: const Text(
                        'Share',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Download PDF
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                      ),
                      onPressed: (_isSharing || _isPrinting || _isDownloadingPdf)
                          ? null
                          : _handleDownloadPdf,
                      icon: _isDownloadingPdf
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFF0284C7)),
                      label: const Text(
                        'PDF',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Print System / Bluetooth
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: (_isSharing || _isPrinting || _isDownloadingPdf)
                          ? null
                          : _handleSystemPrint,
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.print_rounded, size: 18),
                      label: Text(
                        _isPrinting ? 'Preparing...' : 'Print Bill',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidthPill(int width, String label) {
    final isSelected = _paperWidthMm == width;
    return GestureDetector(
      onTap: () => setState(() => _paperWidthMm = width),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildThermalMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThermalSummaryRow(String label, String value, {bool isDues = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: isDues ? const Color(0xFFB45309) : const Color(0xFF475569),
              fontWeight: isDues ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDues ? const Color(0xFFB45309) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFCBD5E1)),
              ),
            );
          }),
        );
      },
    );
  }
}
