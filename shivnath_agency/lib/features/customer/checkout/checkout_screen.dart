import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/repositories/app_repositories.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/session_service.dart';
import '../cart/cart_provider.dart';
import '../wallet/customer_wallet_screen.dart';
import 'order_success_screen.dart';
import '../../../core/widgets/customer_outstanding_breakdown_modal.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final OrderRepository _orderRepository = OrderRepository();
  Map<String, dynamic>? _outstandingData;
  final AuthRepository _authRepository = AuthRepository();

  String selectedPaymentMethod =
      'WALLET'; // 'WALLET', 'RAZORPAY', or 'FRANCHISE_COLLECTION'
  double _walletBalance = 0.0;
  bool _isLoadingWallet = true;
  bool _isSubmitting = false;

  late Razorpay _razorpay;
  Map<String, dynamic>? _gatewayStatus;
  int? _pendingOrderDbId;
  Map<String, dynamic>? _pendingOrderObj;
  String? _pendingRzpOrderId;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final customDaysController = TextEditingController(text: '45');

  // Structured Address fields for multi-city accuracy
  final houseNoController = TextEditingController();
  final streetController = TextEditingController();
  final localityController = TextEditingController();
  final cityController = TextEditingController(text: 'Raipur');
  final pincodeController = TextEditingController();
  final searchAddressController = TextEditingController();

  bool _isLocatingGps = false;
  bool _useManualStructured = false;
  List<Map<String, dynamic>> _addressSuggestions = [];
  Map<String, dynamic>? _selectedAreaInfo;
  bool _isLoadingSuggestions = false;
  String? _originName;
  String? _originCity;

  Timer? _searchDebounce;

  // Delivery calculation state
  double _deliveryFee = 0.0;
  double? _deliveryDistanceKm;
  String? _deliveryBandName;
  bool _isCalculatingDelivery = false;
  bool _isDeliverySupported = true;
  bool _isDeliveryBlocked = false;
  String? _deliveryErrorMsg;
  double? _destLat;
  double? _destLng;
  Timer? _addressDebounce;

  bool _isGstRequested = false;
  final gstLegalNameController = TextEditingController();
  final gstinController = TextEditingController();
  final gstBillingAddressController = TextEditingController();
  final gstStateController = TextEditingController();
  final gstPincodeController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  String selectedDurationChoice = '1 Month';
  int selectedDurationDays = 30;
  bool isCustomDuration = false;

  List<Map<String, dynamic>> eligibleFranchises = [];
  int? selectedFranchiseId;
  String? userZoneName;
  bool isLoadingFranchises = true;
  bool isFallbackFranchise = false;
  String? fallbackMessage;
  String matchLevel = 'exact';
  Map<String, dynamic>? supportContact;
  String orderSource = 'FRANCHISE'; // 'FRANCHISE' or 'DIRECT_COMPANY'
  bool hasCustomerTerritory = false;
  double _previousOutstanding = 0.0;
  List<Map<String, dynamic>> _unpaidOrders = [];

  // Authoritative Tax Configuration from CompanyBillingProfile
  double _gstRate = 18.0;
  bool _isPriceInclusiveGst = false;
  bool _isDeliveryTaxable = true;
  double _taxableAmount = 0.0;
  double _calculatedTaxAmount = 0.0;
  double _calculatedGrandTotal = 0.0;
  double _cgstAmount = 0.0;
  double _sgstAmount = 0.0;
  double _igstAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    addressController.addListener(_onAddressChanged);
    _loadCustomerAndFranchises();
    _loadWalletDetails();
    _checkGatewayStatus();
    _loadTaxConfiguration();
  }

  Future<void> _loadTaxConfiguration() async {
    try {
      final token = await SessionService().getAccessToken();
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/company-profile/');
      final res = await http.get(
        uri,
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            if (data['default_gst_rate'] != null) {
              _gstRate = double.tryParse(data['default_gst_rate'].toString()) ?? 18.0;
            }
            if (data['is_price_inclusive_gst'] != null) {
              _isPriceInclusiveGst = data['is_price_inclusive_gst'] == true;
            }
            if (data['is_delivery_taxable'] != null) {
              _isDeliveryTaxable = data['is_delivery_taxable'] != false;
            }
          });
        }
      }
    } catch (_) {
      // Keep authoritative fallback
    }
  }

  void _recalculateTaxes(double subtotal) {
    final delivery = _deliveryFee;
    final isIntraState = gstStateController.text.trim().isEmpty ||
        gstStateController.text.trim().toLowerCase() == 'chhattisgarh';

    if (_isPriceInclusiveGst) {
      final gross = subtotal + (_isDeliveryTaxable ? delivery : 0.0);
      final divisor = 1.0 + (_gstRate / 100.0);
      _taxableAmount = gross / divisor;
      _calculatedTaxAmount = gross - _taxableAmount;
      _calculatedGrandTotal = subtotal + delivery;
    } else {
      _taxableAmount = subtotal + (_isDeliveryTaxable ? delivery : 0.0);
      _calculatedTaxAmount = (_taxableAmount * _gstRate) / 100.0;
      _calculatedGrandTotal = subtotal + delivery + _calculatedTaxAmount;
    }

    if (isIntraState) {
      _cgstAmount = _calculatedTaxAmount / 2.0;
      _sgstAmount = _calculatedTaxAmount / 2.0;
      _igstAmount = 0.0;
    } else {
      _cgstAmount = 0.0;
      _sgstAmount = 0.0;
      _igstAmount = _calculatedTaxAmount;
    }
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    _searchDebounce?.cancel();
    addressController.removeListener(_onAddressChanged);
    _razorpay.clear();
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    searchAddressController.dispose();
    houseNoController.dispose();
    streetController.dispose();
    localityController.dispose();
    cityController.dispose();
    pincodeController.dispose();
    customDaysController.dispose();
    gstLegalNameController.dispose();
    gstinController.dispose();
    gstBillingAddressController.dispose();
    gstStateController.dispose();
    gstPincodeController.dispose();
    super.dispose();
  }

  void _onAddressChanged() {
    _addressDebounce?.cancel();
    _addressDebounce = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        _calculateDeliveryCharges();
      }
    });
  }

  void _onSearchAddressChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 2) {
      if (mounted) {
        setState(() {
          _addressSuggestions = [];
          _isLoadingSuggestions = false;
        });
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isLoadingSuggestions = true);
      final suggestions = await _orderRepository.getAddressSuggestions(
        query.trim(),
        city: cityController.text.trim().isNotEmpty ? cityController.text.trim() : null,
      );
      if (mounted) {
        setState(() {
          _addressSuggestions = suggestions;
          _isLoadingSuggestions = false;
        });
      }
    });
  }

  void _applySuggestion(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? item['locality']?.toString() ?? '';
    final locName = item['locality']?.toString() ?? name.split(',')[0].trim();
    final city = item['city']?.toString() ?? item['district']?.toString() ?? 'Raipur';
    final pin = item['pincode']?.toString() ?? '';
    final lat = double.tryParse((item['latitude'] ?? '').toString());
    final lng = double.tryParse((item['longitude'] ?? '').toString());
    final zoneName = item['zone_name']?.toString() ?? '$city Central Zone';
    final covered = (item['covered_localities'] is List)
        ? List<String>.from(item['covered_localities'])
        : <String>[locName];
    final hub = item['fulfilment_hub']?.toString() ?? 'Shivnath Agency Central Dispatch';

    setState(() {
      _selectedAreaInfo = {
        'locality': locName,
        'city': city,
        'zone_name': zoneName,
        'covered_localities': covered,
        'fulfilment_hub': hub,
        'pincode': pin,
      };
      _destLat = lat ?? _destLat;
      _destLng = lng ?? _destLng;
      if (city.isNotEmpty) cityController.text = city;
      if (pin.isNotEmpty) pincodeController.text = pin;
      localityController.text = locName;

      final parts = [
        if (houseNoController.text.trim().isNotEmpty) houseNoController.text.trim(),
        if (streetController.text.trim().isNotEmpty) streetController.text.trim(),
        locName,
        if (city.isNotEmpty) city,
        if (pin.isNotEmpty) pin,
        'Chhattisgarh',
      ];
      addressController.text = parts.join(', ');
      _addressSuggestions = [];
      searchAddressController.clear();
    });

    _calculateDeliveryCharges();
  }

  void _showZoneCoveredAreasDialog(String zoneName, List<String> localities) {
    showDialog(
      context: context,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = localities.where((l) => l.toLowerCase().contains(filter.toLowerCase())).toList();
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.map_outlined, color: Color(0xFF0284C7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Areas in $zoneName',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search locality in this zone...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => setDialogState(() => filter = val),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: filtered.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No matching locality found.')))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (c, idx) {
                                final loc = filtered[idx];
                                return ListTile(
                                  dense: true,
                                  title: Text(loc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    localityController.text = loc;
                                    searchAddressController.text = loc;
                                    _onSearchAddressChanged(loc);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showBrowseZonesModal() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String searchQuery = '';
        List<dynamic> allZones = [];
        bool loading = true;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (loading) {
              Future.microtask(() async {
                try {
                  final token = await SessionService().getAccessToken();
                  final res = await ApiClient.get(
                    Uri.parse('${AppConstants.apiBaseUrl}/api/accounts/zones/?is_active=true'),
                    headers: {
                      'Accept': 'application/json',
                      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
                    },
                  );
                  if (res.statusCode >= 200 && res.statusCode < 300) {
                    final data = jsonDecode(res.body);
                    allZones = data['zones'] ?? [];
                  }
                } catch (_) {}
                if (ctx.mounted) {
                  setModalState(() => loading = false);
                }
              });
            }

            final filteredZones = allZones.where((z) {
              final zName = (z['name'] ?? '').toString().toLowerCase();
              final dName = (z['district_name'] ?? '').toString().toLowerCase();
              final locs = ((z['localities'] as List?) ?? []).join(' ').toLowerCase();
              final q = searchQuery.toLowerCase();
              return zName.contains(q) || dName.contains(q) || locs.contains(q);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.explore_outlined, color: Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          const Text('Discover Zones & Covered Areas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search zone, district or covered locality...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (val) => setModalState(() => searchQuery = val),
                      ),
                      const SizedBox(height: 12),
                      if (loading)
                        const Expanded(child: Center(child: CircularProgressIndicator()))
                      else if (filteredZones.isEmpty)
                        const Expanded(child: Center(child: Text('No service zones matching your search.')))
                      else
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            itemCount: filteredZones.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (c, idx) {
                              final z = filteredZones[idx];
                              final zName = z['name'] ?? 'Zone';
                              final dName = z['district_name'] ?? 'Chhattisgarh';
                              final localities = List<String>.from(z['localities'] ?? []);
                              final hub = z['fulfilment_hub_name'] ?? 'Central Dispatch';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(6)),
                                          child: Text(dName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(zName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Fulfilment Origin: $hub', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    if (localities.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      const Text('Covered Localities (tap to select):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: localities.map((loc) {
                                          return ActionChip(
                                            label: Text(loc, style: const TextStyle(fontSize: 11)),
                                            backgroundColor: Colors.white,
                                            side: BorderSide(color: Colors.grey.shade300),
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              _applySuggestion({
                                                'locality': loc,
                                                'name': '$loc, $dName',
                                                'city': dName,
                                                'district': dName,
                                                'zone_id': z['id'],
                                                'zone_name': zName,
                                                'fulfilment_hub': hub,
                                                'covered_localities': localities,
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _syncManualStructuredAddress() {
    final parts = [
      if (houseNoController.text.trim().isNotEmpty) houseNoController.text.trim(),
      if (streetController.text.trim().isNotEmpty) streetController.text.trim(),
      if (localityController.text.trim().isNotEmpty) localityController.text.trim(),
      if (cityController.text.trim().isNotEmpty) cityController.text.trim(),
      if (pincodeController.text.trim().isNotEmpty) pincodeController.text.trim(),
      'Chhattisgarh',
    ];
    final combined = parts.join(', ');
    if (combined != addressController.text) {
      addressController.text = combined;
    }
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isLocatingGps = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled on device. You can enter your address manually.'),
              backgroundColor: Color(0xFFD97706),
            ),
          );
          setState(() => _isLocatingGps = false);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied. You can enter your address manually.'),
                backgroundColor: Color(0xFF64748B),
              ),
            );
            setState(() => _isLocatingGps = false);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission permanently denied. You can enter your address manually.'),
              backgroundColor: Color(0xFF64748B),
            ),
          );
          setState(() => _isLocatingGps = false);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (!mounted) return;

      setState(() {
        _destLat = position.latitude;
        _destLng = position.longitude;
        if (addressController.text.trim().isEmpty) {
          addressController.text = 'GPS Pin (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
        }
        _isLocatingGps = false;
      });

      _calculateDeliveryCharges();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS detection unavailable: $e. You can enter your address manually.'),
            backgroundColor: const Color(0xFF64748B),
          ),
        );
        setState(() => _isLocatingGps = false);
      }
    }
  }

  Future<void> _calculateDeliveryCharges() async {
    final addr = addressController.text.trim();
    if (addr.isEmpty && _destLat == null && _destLng == null) {
      if (mounted) {
        setState(() {
          _deliveryFee = 0.0;
          _deliveryDistanceKm = null;
          _deliveryBandName = null;
          _originName = null;
          _originCity = null;
          _isCalculatingDelivery = false;
          _isDeliverySupported = true;
          _isDeliveryBlocked = false;
          _deliveryErrorMsg = null;
        });
        Provider.of<CartProvider>(context, listen: false).resetDeliveryCharge();
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isCalculatingDelivery = true;
        _deliveryErrorMsg = null;
      });
    }

    try {
      final cityHint = cityController.text.trim().isNotEmpty ? cityController.text.trim() : null;
      final res = await _orderRepository.calculateDelivery(
        address: addr,
        latitude: _destLat,
        longitude: _destLng,
        city: cityHint,
        channel: 'CUSTOMER',
      );

      if (!mounted) return;

      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final fee = double.tryParse((data['delivery_charge'] ?? '0').toString()) ?? 0.0;
        final dist = double.tryParse((data['distance_km'] ?? '').toString());
        final band = data['band_name']?.toString();
        final supported = data['is_supported'] != false;
        final blocked = data['is_blocked'] == true;
        final msg = data['message']?.toString();
        final origName = data['origin_name']?.toString() ?? (data['origin'] is Map ? data['origin']['name']?.toString() : null) ?? 'Central Dispatch';
        final origCity = data['origin_city']?.toString() ?? (data['origin'] is Map ? data['origin']['city']?.toString() : null) ?? 'Raipur';

        if (data['destination'] is Map) {
          final dest = Map<String, dynamic>.from(data['destination'] as Map);
          _destLat = double.tryParse((dest['latitude'] ?? '').toString()) ?? _destLat;
          _destLng = double.tryParse((dest['longitude'] ?? '').toString()) ?? _destLng;
        }

        setState(() {
          _deliveryFee = fee;
          _deliveryDistanceKm = dist;
          _deliveryBandName = band;
          _originName = origName;
          _originCity = origCity;
          _isDeliverySupported = supported;
          _isDeliveryBlocked = blocked;
          _deliveryErrorMsg = (!supported || blocked) ? (msg ?? 'Delivery not serviceable') : null;
          _isCalculatingDelivery = false;
        });

        if (supported && !blocked) {
          Provider.of<CartProvider>(context, listen: false).setDeliveryCharge(fee);
        } else {
          Provider.of<CartProvider>(context, listen: false).resetDeliveryCharge();
        }
      } else {
        final data = res['data'] is Map<String, dynamic> ? Map<String, dynamic>.from(res['data'] as Map) : null;
        final msg = res['message']?.toString() ?? data?['message']?.toString() ?? 'Unable to calculate delivery fee for this address.';
        final blocked = data?['is_blocked'] == true;
        setState(() {
          _deliveryFee = 0.0;
          _isCalculatingDelivery = false;
          _isDeliverySupported = false;
          _isDeliveryBlocked = blocked;
          _deliveryErrorMsg = msg;
        });
        Provider.of<CartProvider>(context, listen: false).resetDeliveryCharge();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCalculatingDelivery = false;
          _deliveryErrorMsg = 'Network error calculating delivery charges: $e';
        });
      }
    }
  }

  Future<void> _loadWalletDetails() async {
    try {
      final walletRes = await _orderRepository.getWalletDetails();
      if (walletRes['success'] == true && mounted) {
        final bal =
            double.tryParse(walletRes['balance']?.toString() ?? '0') ?? 0.0;
        setState(() {
          _walletBalance = bal;
          _isLoadingWallet = false;
          // If customer has zero or negative balance, default selection to alternate method
          if (_walletBalance <= 0) {
            selectedPaymentMethod =
                (orderSource == 'FRANCHISE' && selectedFranchiseId != null)
                ? 'FRANCHISE_COLLECTION'
                : 'RAZORPAY';
          }
        });
      } else if (mounted) {
        setState(() => _isLoadingWallet = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  Future<void> _checkGatewayStatus() async {
    final status = await _orderRepository.getRazorpayStatus();
    if (!mounted) return;

    final Map<String, dynamic> normalized = Map<String, dynamic>.from(status);
    if (status['data'] is Map<String, dynamic>) {
      normalized.addAll(Map<String, dynamic>.from(status['data'] as Map));
    }

    setState(() {
      _gatewayStatus = normalized;
    });
  }

  Future<void> _loadCustomerAndFranchises() async {
    String? district;
    int? zoneId;
    bool hasTerritory = false;

    // Instant local autofill from AuthRepository and SharedPreferences
    final localUser = await _authRepository.getCachedUser();
    if (localUser != null) {
      if (localUser.name.isNotEmpty && nameController.text.isEmpty) {
        nameController.text = localUser.name;
      }
      if (localUser.phone.isNotEmpty && phoneController.text.isEmpty) {
        phoneController.text = localUser.phone;
      }
      if (localUser.city.isNotEmpty) {
        district = localUser.city;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddr = prefs.getString('customer_delivery_address');
      if (savedAddr != null &&
          savedAddr.isNotEmpty &&
          addressController.text.isEmpty) {
        addressController.text = savedAddr;
      }
    } catch (_) {}

    final userRes = await _authRepository.getCurrentUser();
    if (userRes['success'] == true && userRes['data'] is Map<String, dynamic>) {
      final data = userRes['data'] as Map<String, dynamic>;
      if (data['name'] != null && data['name'].toString().isNotEmpty) {
        nameController.text = data['name'].toString();
      }
      if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
        phoneController.text = data['phone'].toString();
      }
      if (data['address'] != null && data['address'].toString().isNotEmpty) {
        addressController.text = data['address'].toString();
      }
      if (data['is_gst_requested'] == true) {
        _isGstRequested = true;
      }
      if (data['gstin'] != null && data['gstin'].toString().isNotEmpty && gstinController.text.isEmpty) {
        gstinController.text = data['gstin'].toString();
      }
      if (data['gst_legal_name'] != null && data['gst_legal_name'].toString().isNotEmpty && gstLegalNameController.text.isEmpty) {
        gstLegalNameController.text = data['gst_legal_name'].toString();
      }
      if (data['gst_billing_address'] != null && data['gst_billing_address'].toString().isNotEmpty && gstBillingAddressController.text.isEmpty) {
        gstBillingAddressController.text = data['gst_billing_address'].toString();
      }
      if (data['gst_state_name'] != null && data['gst_state_name'].toString().isNotEmpty && gstStateController.text.isEmpty) {
        gstStateController.text = data['gst_state_name'].toString();
      }
      if (data['gst_pincode'] != null && data['gst_pincode'].toString().isNotEmpty && gstPincodeController.text.isEmpty) {
        gstPincodeController.text = data['gst_pincode'].toString();
      }

      final terrInfo = data['territory_info'] is Map ? Map<String, dynamic>.from(data['territory_info'] as Map) : null;
      final terr = data['territory'] is Map ? Map<String, dynamic>.from(data['territory'] as Map) : null;

      // Fetch authoritative customer previous outstanding and breakdown
      try {
        final outRes = await _orderRepository.getCustomerOutstanding();
        if (outRes['success'] == true) {
          _outstandingData = outRes;
          final summary = outRes['summary'] as Map<String, dynamic>?;
          _previousOutstanding = (summary?['total_outstanding'] as num?)?.toDouble() ?? 0.0;
          _unpaidOrders = List<Map<String, dynamic>>.from(outRes['items'] ?? []);
        } else {
          final ordRes = await _orderRepository.getOrders();
          if (ordRes['success'] == true &&
              ordRes['data'] != null &&
              ordRes['data']['orders'] is List) {
            final ordList = List<Map<String, dynamic>>.from(
              ordRes['data']['orders'],
            );
            _unpaidOrders = ordList.where((o) {
              final st = (o['status'] ?? '').toString().toLowerCase();
              final paySt = (o['payment_status'] ?? '').toString().toLowerCase();
              final bal = double.tryParse((o['outstanding_balance'] ?? o['outstanding_amount'] ?? '0').toString()) ?? 0.0;
              final isDeliveredOrInvoiced = st == 'delivered' || (o['invoice_number'] != null && o['invoice_number'].toString().isNotEmpty && st != 'order_placement' && st != 'created');
              return isDeliveredOrInvoiced && st != 'cancelled' && paySt != 'paid' && bal > 0.05;
            }).toList();

            _previousOutstanding = _unpaidOrders.fold(0.0, (sum, o) {
              final bal = double.tryParse((o['outstanding_balance'] ?? o['outstanding_amount'] ?? '0').toString()) ?? 0.0;
              return sum + bal;
            });
          }
        }
      } catch (_) {}

      if (terrInfo != null && terrInfo['is_assigned'] == true) {
        hasTerritory = true;
        district = terrInfo['district']?.toString();
        userZoneName = terrInfo['territory']?.toString();
        zoneId = terrInfo['zone_id'] as int?;
      } else if (terr != null &&
          (terr['zone_id'] != null || terr['district'] != null)) {
        hasTerritory = true;
        userZoneName =
            terr['zone_name']?.toString() ?? data['zone_name']?.toString();
        zoneId = (terr['zone_id'] as int?) ?? (data['zone_id'] as int?);
        district = terr['district']?.toString() ?? data['district']?.toString();
      } else if (data['zone_id'] != null ||
          (data['district'] != null &&
              data['district'].toString().isNotEmpty)) {
        hasTerritory = true;
        zoneId = data['zone_id'] as int?;
        district = data['district']?.toString();
        userZoneName = data['zone_name']?.toString();
      }
    }

    Map<String, dynamic> fRes = {
      'success': true,
      'data': {'franchises': []},
    };
    if (district != null && district.isNotEmpty) {
      fRes = await _authRepository.getEligibleFranchises(
        district: district,
        zoneId: zoneId,
      );
    }

    if (mounted) {
      List<Map<String, dynamic>> franchises = [];
      bool isFallback = false;
      String? fallbackMsg;
      String mLevel = 'exact';
      Map<String, dynamic>? supContact;

      if (fRes['success'] == true && fRes['data'] != null) {
        final data = fRes['data'];
        if (data is Map<String, dynamic>) {
          if (data['franchises'] is List) {
            franchises = List<Map<String, dynamic>>.from(data['franchises']);
          }
          isFallback = data['is_fallback'] == true;
          fallbackMsg = data['fallback_message']?.toString();
          mLevel =
              data['match_level']?.toString() ??
              (franchises.isNotEmpty ? 'exact' : 'none');
          if (data['support_contact'] is Map) {
            supContact = Map<String, dynamic>.from(data['support_contact']);
          }
        }
      }
      setState(() {
        hasCustomerTerritory = hasTerritory;
        eligibleFranchises = franchises;
        isFallbackFranchise = isFallback;
        fallbackMessage = fallbackMsg;
        matchLevel = mLevel;
        supportContact = supContact;
        isLoadingFranchises = false;
        if (franchises.isNotEmpty) {
          selectedFranchiseId = franchises.first['id'] as int?;
          orderSource = 'FRANCHISE';
        } else {
          selectedFranchiseId = null;
          orderSource = 'DIRECT_COMPANY';
        }
      });
      if (addressController.text.trim().isNotEmpty) {
        _calculateDeliveryCharges();
      }
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final orderDbId = _pendingOrderDbId;
    if (orderDbId == null) return;
    setState(() => _isSubmitting = true);

    try {
      final verifyRes = await _orderRepository.verifyRazorpayPayment(
        orderId: orderDbId,
        razorpayOrderId: response.orderId ?? _pendingRzpOrderId ?? '',
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      if (!mounted) return;

      if (verifyRes['success'] == true) {
        final cart = Provider.of<CartProvider>(context, listen: false);
        cart.clearCart();

        final rawVerifyData = (verifyRes['data'] is Map)
            ? Map<String, dynamic>.from(verifyRes['data'] as Map)
            : verifyRes;
        final isTestMode = rawVerifyData['is_test_mode'] == true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isTestMode
                    ? '[TEST MODE] Razorpay sandbox payment verified successfully.'
                    : 'Payment verified successfully. Order confirmed!',
              ),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 4),
            ),
          );
        }

        final Map<String, dynamic> verifiedOrder =
            (verifyRes['data'] is Map && verifyRes['data']['order'] is Map)
            ? Map<String, dynamic>.from(verifyRes['data']['order'] as Map)
            : (_pendingOrderObj ?? {'id': orderDbId});

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(
              amount: (verifiedOrder['amount'] is num)
                  ? (verifiedOrder['amount'] as num).toDouble()
                  : 0.0,
              orderData: verifiedOrder,
            ),
          ),
        );
      } else {
        setState(() => _isSubmitting = false);
        final errorMsg =
            verifyRes['message']?.toString() ?? 'Payment verification failed.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment verification error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handlePaymentError(PaymentFailureResponse response) async {
    setState(() => _isSubmitting = false);
    final orderDbId = _pendingOrderDbId;
    final rzpOrderId = _pendingRzpOrderId;

    if (orderDbId != null) {
      await _orderRepository.cancelRazorpayPayment(
        orderId: orderDbId,
        razorpayOrderId: rzpOrderId ?? '',
        reason: '${response.code}: ${response.message}',
      );
    }

    if (!mounted) return;
    final isUserCancel = response.code == Razorpay.PAYMENT_CANCELLED;
    final message = isUserCancel
        ? 'Payment cancelled. Your cart and order have been preserved.'
        : 'Payment failed (${response.message ?? 'Unknown reason'}). Your cart has been preserved.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isUserCancel
            ? const Color(0xFF475569)
            : Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Redirecting to wallet: ${response.walletName}...'),
        backgroundColor: const Color(0xFF0284C7),
      ),
    );
  }

  DateTime get _calculatedEndDate {
    final days = isCustomDuration
        ? (int.tryParse(customDaysController.text.trim()) ?? 30)
        : selectedDurationDays;
    return DateTime.now().add(Duration(days: days));
  }

  String _formatDate(DateTime d) {
    const months = [
      '',
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
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  Future<void> placeOrder() async {
    if (_isSubmitting) return;

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your cart is empty.')));
      return;
    }

    final moqError = cart.validateCartMoq();
    if (moqError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(moqError),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_isCalculatingDelivery) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait while delivery charges are being calculated.'),
          backgroundColor: Color(0xFF0284C7),
        ),
      );
      return;
    }

    if (_isDeliveryBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_deliveryErrorMsg ?? 'Delivery configuration is blocked by Admin. Please contact support.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (!_isDeliverySupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_deliveryErrorMsg ?? 'Delivery is not supported for this address.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    final subtotal = cart.subtotal;
    final deliveryFee = _deliveryFee;
    _recalculateTaxes(subtotal);
    final authoritativeGrandTotal = _calculatedGrandTotal;
    final totalItems = cart.itemCount;

    final durationDays = isCustomDuration
        ? (int.tryParse(customDaysController.text.trim()) ?? 30)
        : selectedDurationDays;
    final durationChoice = isCustomDuration
        ? '$durationDays Days (Custom)'
        : selectedDurationChoice;

    final isDirect =
        orderSource == 'DIRECT_COMPANY' ||
        eligibleFranchises.isEmpty ||
        selectedFranchiseId == null;
    final finalServingFranchiseId = isDirect ? null : selectedFranchiseId;

    String selectedFranchiseName = 'Shivnath Agency (Direct)';
    if (!isDirect && selectedFranchiseId != null) {
      final match = eligibleFranchises.firstWhere(
        (f) => f['id'] == selectedFranchiseId,
        orElse: () => {},
      );
      selectedFranchiseName =
          match['business_name']?.toString() ??
          match['name']?.toString() ??
          'Authorized Franchise Partner';
    }

    // Water Wallet Payment branch
    if (selectedPaymentMethod == 'WALLET') {
      if (_walletBalance < authoritativeGrandTotal) {
        final shortfall = authoritativeGrandTotal - _walletBalance;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Insufficient Wallet Balance',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your current Water Wallet balance is insufficient to complete this order.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Order Total:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '₹${authoritativeGrandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Available Balance:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '₹${_walletBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Shortfall Required:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                          Text(
                            '₹${shortfall.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please recharge your wallet or choose another payment method to place this order.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Change Method'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add_card_rounded, size: 16),
                label: const Text('Recharge Wallet'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerWalletScreen(),
                    ),
                  );
                  _loadWalletDetails();
                },
              ),
            ],
          ),
        );
        return;
      }

      final shouldPlaceWallet = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF0284C7),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Confirm Wallet Payment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deduct payment directly from your Water Wallet balance?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Available Balance:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF166534),
                              ),
                            ),
                            Text(
                              '₹${_walletBalance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF14532D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Order Total:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF166534),
                              ),
                            ),
                            Text(
                              '₹${authoritativeGrandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF14532D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Wallet Amount to Use:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            Text(
                              '₹${authoritativeGrandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Balance After Order:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF166534),
                              ),
                            ),
                            Text(
                              '₹${(_walletBalance - authoritativeGrandTotal).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: Color(0xFF0284C7),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Direct Central Admin Fulfillment (No Franchise Assignment)',
                          style: TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text('Pay ₹${authoritativeGrandTotal.toStringAsFixed(0)} & Place Order'),
              ),
            ],
          );
        },
      );

      if (shouldPlaceWallet != true) return;

      final orderItems = cart.items.map((it) {
        final pid = int.tryParse(it.id) ?? 1;
        return {'product_id': pid, 'quantity': it.quantity, 'price': it.price};
      }).toList();

      setState(() => _isSubmitting = true);

      try {
        final res = await _orderRepository.createOrder({
          'franchise': 'Shivnath Central Admin (Water Wallet)',
          'city': cityController.text.trim().isNotEmpty ? cityController.text.trim() : addressController.text.trim(),
          'customer_name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'delivery_address': addressController.text.trim(),
          'items': totalItems,
          'amount': subtotal,
          'delivery_charges': deliveryFee,
          'grand_total': authoritativeGrandTotal,
          'delivery_latitude': _destLat,
          'delivery_longitude': _destLng,
          'status': 'order_placement',
          'payment': 'paid',
          'payment_mode': 'WALLET',
          'duration_choice': durationChoice,
          'duration_days': durationDays,
          'order_source': 'WATER_WALLET',
          'serving_franchise_id': null,
          'order_items': orderItems,
          'is_gst_requested': _isGstRequested,
          'gstin': _isGstRequested ? gstinController.text.trim().toUpperCase() : '',
          'gst_legal_name': _isGstRequested ? gstLegalNameController.text.trim() : '',
          'gst_billing_address': _isGstRequested ? gstBillingAddressController.text.trim() : '',
          'gst_state_name': _isGstRequested ? gstStateController.text.trim() : '',
          'gst_pincode': _isGstRequested ? gstPincodeController.text.trim() : '',
          'idempotency_key':
              'wallet_order_${DateTime.now().millisecondsSinceEpoch}_$totalItems',
        });

        if (!mounted) return;

        if (res['success'] == true) {
          final dynamic rawData = res['data'];
          final Map<String, dynamic> orderObj =
              (rawData is Map && rawData['order'] is Map)
              ? Map<String, dynamic>.from(rawData['order'] as Map)
              : (rawData is Map
                    ? Map<String, dynamic>.from(rawData)
                    : <String, dynamic>{});

          final newBal =
              double.tryParse(rawData['wallet_balance']?.toString() ?? '') ??
              (_walletBalance - authoritativeGrandTotal).clamp(0.0, double.infinity);

          setState(() {
            _walletBalance = newBal;
            _isSubmitting = false;
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('customer_water_wallet_balance', newBal);

          if (!mounted) return;

          cart.clearCart();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  OrderSuccessScreen(amount: authoritativeGrandTotal, orderData: orderObj),
            ),
          );
          return;
        } else {
          setState(() => _isSubmitting = false);
          final errorMsg =
              res['message']?.toString() ??
              'Failed to place order using Water Wallet.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing wallet payment: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
    }

    // Only central direct company orders with Razorpay require online gateway check
    if (isDirect && selectedPaymentMethod == 'RAZORPAY') {
      final isGatewayAvail =
          _gatewayStatus != null &&
          (_gatewayStatus!['available'] == true ||
              (_gatewayStatus!['data'] is Map &&
                  _gatewayStatus!['data']['available'] == true));
      if (!isGatewayAvail) {
        final diag = (_gatewayStatus?['diagnostics'] is Map)
            ? _gatewayStatus!['diagnostics'] as Map<String, dynamic>
            : (_gatewayStatus?['data'] is Map &&
                  _gatewayStatus!['data']['diagnostics'] is Map)
            ? _gatewayStatus!['data']['diagnostics'] as Map<String, dynamic>
            : null;
        final msg =
            diag?['message']?.toString() ??
            _gatewayStatus?['message']?.toString() ??
            'Payment Gateway Unavailable: Razorpay API credentials are not configured on the production server. Mock payment mode is strictly prohibited in production.';
        final isProd =
            _gatewayStatus?['is_production'] == true ||
            (_gatewayStatus?['data'] is Map &&
                _gatewayStatus!['data']['is_production'] == true);

        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payment Gateway Unavailable',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg, style: const TextStyle(fontSize: 13, height: 1.4)),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Environment: ${_gatewayStatus!['environment'] ?? (isProd ? 'PRODUCTION' : 'TEST')}\n'
                      'Error Code: ${diag?['error_code'] ?? 'GATEWAY_CREDENTIALS_MISSING'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF475569),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _checkGatewayStatus();
                },
                child: const Text('Re-check Status'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
        return;
      }
    }

    // Explicit confirmation dialog to prevent accidental order placement on back/exit
    final shouldPlace = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.payment_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 10),
              Expanded(child: Text('Confirm Order & Pay')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDirect
                      ? 'Ready to complete your central order via Razorpay?'
                      : 'Place order with $selectedFranchiseName?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text('Total Items: $totalItems'),
                const SizedBox(height: 4),
                Text(
                  'Payable Amount: ₹${authoritativeGrandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0284C7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      isDirect
                          ? Icons.lock_outline_rounded
                          : Icons.handshake_outlined,
                      size: 14,
                      color: const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isDirect
                            ? (_gatewayStatus?['is_test_mode'] == true
                                  ? 'Razorpay Sandbox (Test Mode) Checkout'
                                  : '100% Secure Razorpay Online Payment')
                            : 'Pay on Delivery to Franchise (Cash / UPI)',
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isDirect ? 'Pay Now & Place Order' : 'Place Order'),
            ),
          ],
        );
      },
    );

    if (shouldPlace != true) return;

    final orderItems = cart.items.map((it) {
      final pid = int.tryParse(it.id) ?? 1;
      return {'product_id': pid, 'quantity': it.quantity, 'price': it.price};
    }).toList();

    setState(() => _isSubmitting = true);

    if (!isDirect) {
      // Step 1: Create Order for Franchise - Settled directly with the serving franchise
      try {
        final res = await _orderRepository.createOrder({
          'franchise': selectedFranchiseName,
          'city': cityController.text.trim().isNotEmpty ? cityController.text.trim() : addressController.text.trim(),
          'customer_name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'delivery_address': addressController.text.trim(),
          'items': totalItems,
          'amount': subtotal,
          'delivery_charges': deliveryFee,
          'grand_total': authoritativeGrandTotal,
          'delivery_latitude': _destLat,
          'delivery_longitude': _destLng,
          'status': 'order_placement',
          'payment': 'pending',
          'payment_mode': 'FRANCHISE_COLLECTION',
          'duration_choice': durationChoice,
          'duration_days': durationDays,
          'order_source': 'FRANCHISE',
          'serving_franchise_id': finalServingFranchiseId,
          'order_items': orderItems,
          'is_gst_requested': _isGstRequested,
          'gstin': _isGstRequested ? gstinController.text.trim().toUpperCase() : '',
          'gst_legal_name': _isGstRequested ? gstLegalNameController.text.trim() : '',
          'gst_billing_address': _isGstRequested ? gstBillingAddressController.text.trim() : '',
          'gst_state_name': _isGstRequested ? gstStateController.text.trim() : '',
          'gst_pincode': _isGstRequested ? gstPincodeController.text.trim() : '',
        });

        if (!mounted) return;

        if (res['success'] == true) {
          final dynamic rawData = res['data'];
          final Map<String, dynamic> orderObj =
              (rawData is Map && rawData['order'] is Map)
              ? Map<String, dynamic>.from(rawData['order'] as Map)
              : (rawData is Map
                    ? Map<String, dynamic>.from(rawData)
                    : <String, dynamic>{});
          cart.clearCart();
          setState(() => _isSubmitting = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  OrderSuccessScreen(amount: authoritativeGrandTotal, orderData: orderObj),
            ),
          );
          return;
        } else {
          setState(() => _isSubmitting = false);
          final errorMsg =
              res['message']?.toString() ?? 'Failed to place franchise order.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error during franchise order creation: $e'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
        return;
      }
    }

    try {
      // Step 1: Create Order with pending payment (Direct Company Order)
      final res = await _orderRepository.createOrder({
        'franchise': 'Shivnath Agency (Direct)',
        'city': cityController.text.trim().isNotEmpty ? cityController.text.trim() : addressController.text.trim(),
        'customer_name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'delivery_address': addressController.text.trim(),
        'items': totalItems,
        'amount': subtotal,
        'delivery_charges': deliveryFee,
        'grand_total': authoritativeGrandTotal,
        'delivery_latitude': _destLat,
        'delivery_longitude': _destLng,
        'status': 'order_placement',
        'payment': 'pending',
        'payment_mode': 'RAZORPAY',
        'duration_choice': durationChoice,
        'duration_days': durationDays,
        'order_source': 'DIRECT_COMPANY',
        'serving_franchise_id': null,
        'order_items': orderItems,
        'is_gst_requested': _isGstRequested,
        'gstin': _isGstRequested ? gstinController.text.trim().toUpperCase() : '',
        'gst_legal_name': _isGstRequested ? gstLegalNameController.text.trim() : '',
        'gst_billing_address': _isGstRequested ? gstBillingAddressController.text.trim() : '',
        'gst_state_name': _isGstRequested ? gstStateController.text.trim() : '',
        'gst_pincode': _isGstRequested ? gstPincodeController.text.trim() : '',
      });

      if (!mounted) return;

      if (res['success'] == true) {
        final dynamic rawData = res['data'];
        final Map<String, dynamic> orderObj =
            (rawData is Map && rawData['order'] is Map)
            ? Map<String, dynamic>.from(rawData['order'] as Map)
            : (rawData is Map
                  ? Map<String, dynamic>.from(rawData)
                  : <String, dynamic>{});
        final int orderDbId =
            int.tryParse(
              orderObj['id']?.toString() ?? res['id']?.toString() ?? '0',
            ) ??
            0;

        // Step 2: Initialize Razorpay online order with server-validated amount
        final rzpOrderRes = await _orderRepository.createRazorpayOrder(
          orderId: orderDbId > 0 ? orderDbId : null,
          amount: authoritativeGrandTotal,
        );

        if (rzpOrderRes['success'] != true) {
          if (!mounted) return;
          setState(() => _isSubmitting = false);
          final errorMsg =
              rzpOrderRes['message']?.toString() ??
              'Unable to initialize payment.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }

        final dynamic rawRzpData = (rzpOrderRes['data'] is Map)
            ? rzpOrderRes['data']
            : rzpOrderRes;
        final Map<String, dynamic> rzpData = rawRzpData is Map<String, dynamic>
            ? rawRzpData
            : (rawRzpData is Map
                  ? Map<String, dynamic>.from(rawRzpData)
                  : <String, dynamic>{});
        final rzpOrderId = rzpData['razorpay_order_id']?.toString() ?? '';
        final keyId = rzpData['key_id']?.toString() ?? '';
        final amountInPaise =
            rzpData['amount_in_paise'] as int? ?? (authoritativeGrandTotal * 100).round();

        _pendingOrderDbId = orderDbId;
        _pendingOrderObj = orderObj;
        _pendingRzpOrderId = rzpOrderId;

        // Step 3: Open Genuine Razorpay Checkout
        final localUser = await _authRepository.getCachedUser();
        final options = {
          'key': keyId.isNotEmpty ? keyId : AppConstants.razorpayKeyId,
          'amount': amountInPaise,
          'name': 'Shivnath Agency - WATER WALA',
          'order_id': rzpOrderId,
          'description': 'Order #${orderObj['order_code'] ?? orderDbId}',
          'timeout': 300,
          'prefill': {
            'contact': phoneController.text.trim().isNotEmpty
                ? phoneController.text.trim()
                : (localUser?.phone != null &&
                          localUser!.phone.trim().isNotEmpty
                      ? localUser.phone.trim()
                      : '9876543210'),
            'email':
                (localUser?.email != null && localUser!.email.trim().isNotEmpty)
                ? localUser.email.trim()
                : 'customer@shivnath.com',
          },
          'notes': {
            'order_id': orderDbId.toString(),
            'app_environment': AppConstants.environmentName,
          },
          'theme': {'color': '#0284C7'},
          'retry': {'enabled': true, 'max_count': 3},
          'send_sms_hash': true,
        };

        try {
          _razorpay.open(options);
        } catch (e) {
          if (!mounted) return;
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error launching Razorpay checkout: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } else {
        setState(() => _isSubmitting = false);
        final msg =
            res['message'] ?? 'Unable to place order. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error during order initialization: $e'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
  }

  void _showOutstandingBreakdown() {
    CustomerOutstandingBreakdownModal.show(
      context,
      initialData: _outstandingData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Checkout',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const Text(
                    'Delivery Address',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 10) {
                        return 'Enter valid mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Address Entry Header with GPS and Discover Zones buttons
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Delivery Address',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              foregroundColor: const Color(0xFF0369A1),
                            ),
                            onPressed: _showBrowseZonesModal,
                            icon: const Icon(Icons.explore_outlined, size: 15),
                            label: const Text('Discover Zones', style: TextStyle(fontSize: 12)),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              foregroundColor: const Color(0xFF0284C7),
                            ),
                            onPressed: _isLocatingGps ? null : _detectCurrentLocation,
                            icon: _isLocatingGps
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.my_location, size: 15),
                            label: Text(_isLocatingGps ? 'Locating...' : 'Use GPS', style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Locality / Pincode Autocomplete Search
                  TextField(
                    controller: searchAddressController,
                    onChanged: _onSearchAddressChanged,
                    decoration: InputDecoration(
                      hintText: 'Search locality, area or PIN code...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                      suffixIcon: _isLoadingSuggestions
                          ? const SizedBox(width: 16, height: 16, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                          : (searchAddressController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchAddressController.clear();
                                    setState(() => _addressSuggestions = []);
                                  },
                                )
                              : null),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),

                  // Suggestions Dropdown List
                  if (_addressSuggestions.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _addressSuggestions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = _addressSuggestions[i];
                          final label = item['name'] ?? item['locality'] ?? item['address'] ?? '';
                          final city = item['city'] ?? '';
                          final pin = item['pincode'] ?? '';
                          final zone = item['zone_name'] ?? '';
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on, size: 18, color: Color(0xFF0284C7)),
                            title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text('$city${pin.isNotEmpty ? ' - $pin' : ''}${zone.isNotEmpty ? ' • Zone: $zone' : ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            onTap: () => _applySuggestion(item),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Selected Area & Configured Zone Information Card
                  if (_selectedAreaInfo != null) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your selected area: ${_selectedAreaInfo!['locality']}, ${_selectedAreaInfo!['city']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Delivery zone: ${_selectedAreaInfo!['zone_name']}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF15803D)),
                          ),
                          if ((_selectedAreaInfo!['covered_localities'] as List).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Areas covered in this zone: ${(_selectedAreaInfo!['covered_localities'] as List).take(5).join(', ')}${(_selectedAreaInfo!['covered_localities'] as List).length > 5 ? ' and more...' : ''}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _showZoneCoveredAreasDialog(
                                _selectedAreaInfo!['zone_name'],
                                List<String>.from(_selectedAreaInfo!['covered_localities']),
                              ),
                              child: const Text(
                                '🔍 View all areas covered in this zone',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0369A1),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          const Text(
                            'Note: Final serviceability is checked using complete delivery address GPS coordinates.',
                            style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // City Selection Filter Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('City/District:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ),
                      ...['Raipur', 'Bhilai', 'Durg', 'Bilaspur', 'Rajnandgaon', 'Korba'].map((c) {
                        final isSel = cityController.text.trim().toLowerCase() == c.toLowerCase();
                        return ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          label: Text(c, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : const Color(0xFF334155))),
                          selected: isSel,
                          selectedColor: const Color(0xFF0284C7),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                cityController.text = c;
                                if (localityController.text.trim().isNotEmpty) {
                                  _syncManualStructuredAddress();
                                }
                              });
                              _calculateDeliveryCharges();
                            }
                          },
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Toggle Structured Address Entry
                  InkWell(
                    onTap: () => setState(() => _useManualStructured = !_useManualStructured),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            _useManualStructured ? Icons.indeterminate_check_box_outlined : Icons.add_box_outlined,
                            size: 16,
                            color: const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _useManualStructured ? 'Hide Detailed Flat/House Fields' : 'Enter Detailed Flat/House, Street & Landmark',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Structured Address Fields
                  if (_useManualStructured) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: houseNoController,
                            decoration: const InputDecoration(
                              labelText: 'House / Flat / Plot No.',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (_) => _syncManualStructuredAddress(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: streetController,
                            decoration: const InputDecoration(
                              labelText: 'Street / Landmark',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (_) => _syncManualStructuredAddress(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: localityController,
                            decoration: const InputDecoration(
                              labelText: 'Locality / Area',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (_) => _syncManualStructuredAddress(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: pincodeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'PIN Code',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (_) => _syncManualStructuredAddress(),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Complete Delivery Address Field (Editable)
                  TextFormField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Full Delivery Address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      hintText: 'e.g., House 12, Main Road, Mowa, Raipur, Chhattisgarh',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter delivery address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Live delivery serviceability & calculation feedback
                  if (_isCalculatingDelivery) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Calculating authoritative straight-line delivery charges${_originName != null ? ' from $_originName' : ''}...',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF0369A1), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else if (_isDeliveryBlocked) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _deliveryErrorMsg ?? 'Delivery configuration is blocked by Admin. Please contact support.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else if (!_isDeliverySupported) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_off_rounded, size: 16, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _deliveryErrorMsg ?? 'Address is outside the serviceable delivery area.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else if (addressController.text.trim().isNotEmpty && _deliveryDistanceKm != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF16A34A)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_deliveryBandName ?? 'Serviceable'} • ${_deliveryFee == 0 ? 'FREE DELIVERY' : 'Delivery: ₹${_deliveryFee.toStringAsFixed(0)}'}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Distance: ${_deliveryDistanceKm!.toStringAsFixed(1)} km (HAVERSINE_STRAIGHT_LINE) from ${_originName ?? 'Central Dispatch'}${_originCity != null ? ' ($_originCity)' : ''}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isGstRequested ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isGstRequested ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.business_rounded,
                              color: _isGstRequested ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add GST Details for Tax Invoice',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Optional • For businesses claiming Input Tax Credit',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _isGstRequested,
                              activeColor: const Color(0xFF16A34A),
                              onChanged: (val) {
                                setState(() {
                                  _isGstRequested = val;
                                });
                              },
                            ),
                          ],
                        ),
                        if (_isGstRequested) ...[
                          const Divider(height: 20),
                          TextFormField(
                            controller: gstinController,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 15,
                            decoration: const InputDecoration(
                              labelText: 'GSTIN (15 Digits) *',
                              hintText: 'e.g. 22AAAAA0000A1Z5',
                              prefixIcon: Icon(Icons.badge_outlined),
                              counterText: '',
                            ),
                            validator: (val) {
                              if (!_isGstRequested) return null;
                              final trimmed = val?.trim() ?? '';
                              if (trimmed.isEmpty) return 'Please enter GSTIN';
                              final gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
                              if (!gstRegex.hasMatch(trimmed.toUpperCase())) {
                                return 'Enter a valid 15-character GSTIN format';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: gstLegalNameController,
                            decoration: const InputDecoration(
                              labelText: 'Company / Trade Name *',
                              hintText: 'Registered business name',
                              prefixIcon: Icon(Icons.corporate_fare_outlined),
                            ),
                            validator: (val) {
                              if (!_isGstRequested) return null;
                              if (val == null || val.trim().isEmpty) return 'Enter registered business name';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: gstBillingAddressController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'GST Billing Address *',
                              hintText: 'Address as per GST registration',
                              prefixIcon: Icon(Icons.apartment_outlined),
                            ),
                            validator: (val) {
                              if (!_isGstRequested) return null;
                              if (val == null || val.trim().isEmpty) return 'Enter GST billing address';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: gstStateController,
                                  decoration: const InputDecoration(
                                    labelText: 'State *',
                                    hintText: 'e.g. Chhattisgarh',
                                  ),
                                  validator: (val) {
                                    if (!_isGstRequested) return null;
                                    if (val == null || val.trim().isEmpty) return 'Enter state';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: gstPincodeController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  decoration: const InputDecoration(
                                    labelText: 'PIN *',
                                    counterText: '',
                                  ),
                                  validator: (val) {
                                    if (!_isGstRequested) return null;
                                    if (val == null || val.trim().length != 6) return '6 digits';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Stock Supply Duration',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select the planned duration for this water stock. Expected cycle end date will be calculated automatically.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('1 Month (~30 Days)'),
                        selected:
                            !isCustomDuration && selectedDurationDays == 30,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              isCustomDuration = false;
                              selectedDurationDays = 30;
                              selectedDurationChoice = '1 Month';
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('2 Months (~60 Days)'),
                        selected:
                            !isCustomDuration && selectedDurationDays == 60,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              isCustomDuration = false;
                              selectedDurationDays = 60;
                              selectedDurationChoice = '2 Months';
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('3 Months (~90 Days)'),
                        selected:
                            !isCustomDuration && selectedDurationDays == 90,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              isCustomDuration = false;
                              selectedDurationDays = 90;
                              selectedDurationChoice = '3 Months';
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Custom Duration'),
                        selected: isCustomDuration,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              isCustomDuration = true;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (isCustomDuration) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: customDaysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Custom Duration (Days)',
                        prefixIcon: Icon(Icons.date_range_outlined),
                        suffixText: 'Days',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF0284C7),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '📅 Stock cycle ends on ${_formatDate(_calculatedEndDate)}. You will receive a low-stock reminder 7 days prior.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0369A1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Order Fulfillment',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (userZoneName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            userZoneName!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (isLoadingFranchises)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Checking fulfillment availability...',
                              style: TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (eligibleFranchises.isNotEmpty) ...[
                    const Text(
                      'Choose how you would like your order to be fulfilled:',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    _PaymentTile(
                      title: 'Order from Franchise',
                      subtitle:
                          'Delivered by authorized local franchise in your zone',
                      icon: Icons.storefront_outlined,
                      value: 'FRANCHISE',
                      groupValue: orderSource,
                      onChanged: (val) {
                        setState(() => orderSource = val);
                      },
                    ),
                    if (orderSource == 'FRANCHISE') ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        initialValue: selectedFranchiseId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.location_city_outlined),
                          labelText: 'Select Serving Franchise',
                        ),
                        items: eligibleFranchises.map((f) {
                          final name =
                              f['business_name']?.toString() ?? 'Franchise';
                          final isPrimary = f['is_primary'] == true;
                          final coverage = f['service_coverage']?.toString();
                          final label =
                              (coverage != null && coverage.isNotEmpty)
                              ? '$name ($coverage)'
                              : (isPrimary
                                    ? '$name (Primary Franchise)'
                                    : name);

                          return DropdownMenuItem<int>(
                            value: f['id'] as int?,
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontWeight: isPrimary
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => selectedFranchiseId = val);
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    _PaymentTile(
                      title: 'Order Directly from Water Wala',
                      subtitle: 'Central company fulfillment & dispatch',
                      icon: Icons.business_outlined,
                      value: 'DIRECT_COMPANY',
                      groupValue: orderSource,
                      onChanged: (val) {
                        setState(() => orderSource = val);
                      },
                    ),
                  ] else if (hasCustomerTerritory) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.business_outlined,
                                color: Color(0xFF0284C7),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Direct Company Fulfillment',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF0369A1),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Water Wala',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No franchise is currently assigned to your territory. Your order will be fulfilled directly by Water Wala central dispatch.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF075985),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.business_outlined,
                                color: Color(0xFF334155),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Direct Company Fulfillment',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF475569),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Water Wala',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No delivery territory selected. Your order will be handled directly by Water Wala (you can complete your territory in Profile anytime).',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'Payment Method',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: Color(0xFF16A34A),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '100% Secure',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Option 1: Pay using Water Wallet (Selectable)
                  InkWell(
                    onTap: () {
                      setState(() {
                        selectedPaymentMethod = 'WALLET';
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: selectedPaymentMethod == 'WALLET'
                            ? const Color(0xFFF0F9FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selectedPaymentMethod == 'WALLET'
                              ? const Color(0xFF0284C7)
                              : const Color(0xFFE2E8F0),
                          width: selectedPaymentMethod == 'WALLET' ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                color: selectedPaymentMethod == 'WALLET'
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF64748B),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Row(
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'Pay using Water Wallet',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: const Color(0xFFBAE6FD),
                                        ),
                                      ),
                                      child: const Text(
                                        'CENTRAL ADMIN',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0369A1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                selectedPaymentMethod == 'WALLET'
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: selectedPaymentMethod == 'WALLET'
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF94A3B8),
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Wallet Balance details
                          _isLoadingWallet
                              ? const Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Checking wallet balance...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Available Wallet Balance:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF475569),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '₹${_walletBalance.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                _walletBalance >=
                                                    cart.totalAmount
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (_walletBalance >= cart.totalAmount) ...[
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFBBF7D0),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Wallet Amount to Use: ₹${cart.totalAmount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF166534),
                                              ),
                                            ),
                                            Text(
                                              'Balance After: ₹${(_walletBalance - cart.totalAmount).toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF166534),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFECACA),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.info_outline,
                                              size: 14,
                                              color: Color(0xFFDC2626),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Shortfall of ₹${(cart.totalAmount - _walletBalance).toStringAsFixed(2)}. Please recharge.',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF991B1B),
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () async {
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const CustomerWalletScreen(),
                                                  ),
                                                );
                                                _loadWalletDetails();
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFDC2626,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Recharge',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Option 2: Alternate Payment (Franchise Cash / UPI OR Central Online Razorpay)
                  if (orderSource == 'FRANCHISE' &&
                      selectedFranchiseId != null) ...[
                    InkWell(
                      onTap: () {
                        setState(() {
                          selectedPaymentMethod = 'FRANCHISE_COLLECTION';
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selectedPaymentMethod == 'FRANCHISE_COLLECTION'
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                selectedPaymentMethod == 'FRANCHISE_COLLECTION'
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFE2E8F0),
                            width:
                                selectedPaymentMethod == 'FRANCHISE_COLLECTION'
                                ? 2
                                : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.handshake_rounded,
                                  color:
                                      selectedPaymentMethod ==
                                          'FRANCHISE_COLLECTION'
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF64748B),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Flexible(
                                        child: Text(
                                          'Pay on Delivery to Franchise',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: Color(0xFF14532D),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF86EFAC),
                                          ),
                                        ),
                                        child: const Text(
                                          'FRANCHISE ORDER',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF166534),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  selectedPaymentMethod ==
                                          'FRANCHISE_COLLECTION'
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color:
                                      selectedPaymentMethod ==
                                          'FRANCHISE_COLLECTION'
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Payment will be collected directly upon delivery by ${eligibleFranchises.firstWhere((f) => f['id'] == selectedFranchiseId, orElse: () => {})['business_name'] ?? 'the serving franchise'}.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF166534),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _payBadge('Cash on Delivery'),
                                _payBadge('Franchise UPI / QR'),
                                _payBadge('Direct Settlement'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Razorpay Online Payment for Direct Orders
                    InkWell(
                      onTap: () {
                        setState(() {
                          selectedPaymentMethod = 'RAZORPAY';
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selectedPaymentMethod == 'RAZORPAY'
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedPaymentMethod == 'RAZORPAY'
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFE2E8F0),
                            width: selectedPaymentMethod == 'RAZORPAY' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.credit_card_rounded,
                                  color: selectedPaymentMethod == 'RAZORPAY'
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF64748B),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Flexible(
                                        child: Text(
                                          'Online Payment — Razorpay',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: Color(0xFF14532D),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      if (_gatewayStatus?['is_test_mode'] ==
                                              true ||
                                          (_gatewayStatus?['data'] is Map &&
                                              _gatewayStatus!['data']['is_test_mode'] ==
                                                  true)) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF08A),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFEAB308),
                                            ),
                                          ),
                                          child: const Text(
                                            'SANDBOX TEST',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF854D0E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  selectedPaymentMethod == 'RAZORPAY'
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: selectedPaymentMethod == 'RAZORPAY'
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'UPI (GPay, PhonePe, Paytm), Debit/Credit Cards, Net Banking & Wallets',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF166534),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: () {
                                final dynamic methods = _gatewayStatus?['supported_methods'] ??
                                    ((_gatewayStatus?['data'] is Map)
                                        ? (_gatewayStatus!['data'] as Map)['supported_methods']
                                        : null);
                                if (methods is List && methods.isNotEmpty) {
                                  return methods.map((m) => _payBadge(m.toString())).toList();
                                }
                                return [
                                  _payBadge('UPI'),
                                  _payBadge('Cards'),
                                  _payBadge('Net Banking'),
                                  _payBadge('Wallets'),
                                ];
                              }(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ordered Items',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item.image.isNotEmpty
                                    ? Image.network(
                                        item.image,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Image.asset(
                                          item.assetFallbackImage,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Image.asset(
                                        item.assetFallbackImage,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${item.unitPrice.toStringAsFixed(0)} × ${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${item.total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Order Summary',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Builder(
                      builder: (ctx) {
                        _recalculateTaxes(cart.subtotal);
                        final isIntraState = gstStateController.text.trim().isEmpty ||
                            gstStateController.text.trim().toLowerCase() == 'chhattisgarh';

                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _SummaryRow(
                                title: 'Items Subtotal (${cart.itemCount} items)',
                                value: '₹${cart.subtotal.toStringAsFixed(2)}',
                              ),
                              const SizedBox(height: 10),
                              _SummaryRow(
                                title: 'Delivery Charges',
                                value: _isCalculatingDelivery
                                    ? 'Calculating...'
                                    : (_isDeliveryBlocked
                                        ? 'Config Blocked'
                                        : (!_isDeliverySupported
                                            ? 'Outside Service Area'
                                            : (_deliveryFee == 0
                                                ? 'FREE'
                                                : '₹${_deliveryFee.toStringAsFixed(2)}'))),
                                color: _isCalculatingDelivery
                                    ? const Color(0xFF0284C7)
                                    : (_isDeliveryBlocked || !_isDeliverySupported
                                        ? const Color(0xFFDC2626)
                                        : (_deliveryFee == 0 ? const Color(0xFF16A34A) : null)),
                              ),
                              const SizedBox(height: 10),
                              _SummaryRow(
                                title: 'Taxable Amount',
                                value: _isCalculatingDelivery ? 'Calculating...' : '₹${_taxableAmount.toStringAsFixed(2)}',
                                color: const Color(0xFF64748B),
                              ),
                              const SizedBox(height: 10),
                              if (!isIntraState) ...[
                                _SummaryRow(
                                  title: 'IGST (${_gstRate.toStringAsFixed(_gstRate.truncateToDouble() == _gstRate ? 0 : 1)}%${_isPriceInclusiveGst ? " Incl." : ""})',
                                  value: '₹${_igstAmount.toStringAsFixed(2)}',
                                  color: const Color(0xFF64748B),
                                ),
                              ] else ...[
                                _SummaryRow(
                                  title: 'CGST (${(_gstRate / 2).toStringAsFixed(1)}%${_isPriceInclusiveGst ? " Incl." : ""})',
                                  value: '₹${_cgstAmount.toStringAsFixed(2)}',
                                  color: const Color(0xFF64748B),
                                ),
                                const SizedBox(height: 6),
                                _SummaryRow(
                                  title: 'SGST (${(_gstRate / 2).toStringAsFixed(1)}%${_isPriceInclusiveGst ? " Incl." : ""})',
                                  value: '₹${_sgstAmount.toStringAsFixed(2)}',
                                  color: const Color(0xFF64748B),
                                ),
                              ],
                              const Divider(height: 24),
                              _SummaryRow(
                                title: 'Current Order Total',
                                value: _isCalculatingDelivery
                                    ? 'Calculating...'
                                    : (_isDeliveryBlocked || !_isDeliverySupported
                                        ? 'Unavailable'
                                        : '₹${_calculatedGrandTotal.toStringAsFixed(2)}'),
                                bold: true,
                              ),
                              if (_previousOutstanding > 0) ...[
                                const SizedBox(height: 10),
                                InkWell(
                                  onTap: _showOutstandingBreakdown,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'Previous Outstanding',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFDC2626),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEE2E2),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: const Color(0xFFFECACA),
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.info_outline,
                                                    size: 11,
                                                    color: Color(0xFFDC2626),
                                                  ),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    'View Details',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFFDC2626),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '₹${_previousOutstanding.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFDC2626),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(height: 20),
                                _SummaryRow(
                                  title: 'Total Amount Due',
                                  value: _isCalculatingDelivery
                                      ? 'Calculating...'
                                      : (_isDeliveryBlocked || !_isDeliverySupported
                                          ? 'Unavailable'
                                          : '₹${(_calculatedGrandTotal + _previousOutstanding).toStringAsFixed(2)}'),
                                  bold: true,
                                ),
                              ] else ...[
                                const Divider(height: 20),
                                _SummaryRow(
                                  title: 'Payable Amount',
                                  value: _isCalculatingDelivery
                                      ? 'Calculating...'
                                      : (_isDeliveryBlocked || !_isDeliverySupported
                                          ? 'Unavailable'
                                          : '₹${_calculatedGrandTotal.toStringAsFixed(2)}'),
                                  bold: true,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  Builder(
                    builder: (ctx) {
                      final currentPayable = _calculatedGrandTotal > 0 ? _calculatedGrandTotal : (cart.subtotal + _deliveryFee);
                      final isBlockedOrUnsupported = _isDeliveryBlocked || !_isDeliverySupported;

                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCalculatingDelivery
                              ? const Color(0xFF64748B)
                              : (isBlockedOrUnsupported
                                  ? const Color(0xFF94A3B8)
                                  : (selectedPaymentMethod == 'WALLET' && _walletBalance < currentPayable
                                      ? const Color(0xFFDC2626)
                                      : (selectedPaymentMethod == 'FRANCHISE_COLLECTION'
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF0284C7)))),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: (_isSubmitting || _isCalculatingDelivery || isBlockedOrUnsupported)
                            ? null
                            : (selectedPaymentMethod == 'WALLET' && _walletBalance < currentPayable
                                ? () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const CustomerWalletScreen(),
                                      ),
                                    );
                                    _loadWalletDetails();
                                  }
                                : placeOrder),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isCalculatingDelivery
                                    ? 'CALCULATING DELIVERY CHARGES...'
                                    : (_isDeliveryBlocked
                                        ? 'DELIVERY CONFIGURATION BLOCKED'
                                        : (!_isDeliverySupported
                                            ? 'OUTSIDE SERVICE AREA - CANNOT ORDER'
                                            : (selectedPaymentMethod == 'WALLET'
                                                ? (_walletBalance < currentPayable
                                                    ? 'RECHARGE WALLET (SHORTFALL: ₹${(currentPayable - _walletBalance).toStringAsFixed(0)})'
                                                    : 'PAY WITH WATER WALLET (₹${currentPayable.toStringAsFixed(2)})')
                                                : (selectedPaymentMethod == 'FRANCHISE_COLLECTION'
                                                    ? 'CONFIRM FRANCHISE ORDER (₹${currentPayable.toStringAsFixed(2)})'
                                                    : 'PAY VIA RAZORPAY (₹${currentPayable.toStringAsFixed(2)})')))),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _payBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF166534),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final bool bold;
  final Color? color;

  const _SummaryRow({
    required this.title,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color:
                  color ??
                  (bold ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color:
                  color ??
                  (bold ? const Color(0xFF0284C7) : const Color(0xFF0F172A)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _PaymentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF64748B),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: selected
                          ? const Color(0xFF166534)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
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
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              activeColor: const Color(0xFF16A34A),
            ),
          ],
        ),
      ),
    );
  }
}
