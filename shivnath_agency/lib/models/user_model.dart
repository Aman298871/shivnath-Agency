class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String phone;
  final String status;
  final String rejectionReason;
  final String businessName;
  final String city;
  final String territory;
  final String district;
  final String address;
  final String locality;
  final String serviceArea;
  final int? zoneId;
  final String zoneName;
  final bool isTerritoryAssigned;
  final double? creditLimit;
  final int? paymentTermsDays;
  final double? commissionPercentage;
  final String? dealerStatus;
  final bool mustChangePassword;
  final List<String> adminPermissions;
  final String dataScopeType;
  final List<String> assignedScopeIds;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.status = 'approved',
    this.rejectionReason = '',
    this.businessName = '',
    this.city = '',
    this.territory = '',
    this.district = '',
    this.address = '',
    this.locality = '',
    this.serviceArea = '',
    this.zoneId,
    this.zoneName = '',
    this.isTerritoryAssigned = false,
    this.creditLimit,
    this.paymentTermsDays,
    this.commissionPercentage,
    this.dealerStatus,
    this.mustChangePassword = false,
    this.adminPermissions = const [],
    this.dataScopeType = 'all_data',
    this.assignedScopeIds = const [],
  });

  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isRejected => status.toLowerCase() == 'rejected';

  // Role Helpers
  bool get isSuperAdmin => role.toLowerCase() == 'super_admin';
  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isStockManager => role.toLowerCase() == 'stock_manager';
  bool get isSalesExecutive => role.toLowerCase() == 'sales_executive';
  bool get isStaffOrAdmin => isSuperAdmin || isAdmin || isSalesExecutive || isStockManager;
  bool get isDealer => role.toLowerCase() == 'franchise';
  bool get isFranchise => role.toLowerCase() == 'franchise' || isDealer;
  bool get isCustomer => role.toLowerCase() == 'customer';

  String get roleDisplay {
    if (isSuperAdmin) return 'Super Admin';
    if (isAdmin) return 'Plant Admin';
    if (isStockManager) return 'Stock Manager';
    if (isSalesExecutive) return 'Sales Executive';
    if (isDealer) return 'Franchise';
    if (isCustomer) return 'Customer';
    return role;
  }

  /// Authoritative granular permission check for administrative staff
  bool hasPermission(String module, [String action = 'view']) {
    if (isSuperAdmin) return true;
    if (!isAdmin && !isStaffOrAdmin) return false;

    final mod = module.toLowerCase().trim();
    final act = action.toLowerCase().trim();

    // Default role baselines
    if (isSalesExecutive && (mod == 'leads' || mod == 'customers' || mod == 'followups') && (act == 'view' || act == 'create' || act == 'edit')) {
      return true;
    }
    if (isStockManager && (mod == 'inventory' || mod == 'products' || mod == 'production') && (act == 'view' || act == 'edit' || act == 'adjust')) {
      return true;
    }

    final perms = Set<String>.from(adminPermissions.map((p) => p.toLowerCase().trim()));
    if (perms.contains('*') || perms.contains('all')) return true;

    // Check module wildcard or exact action
    if (perms.contains(mod) || perms.contains('$mod:*') || perms.contains('$mod:$act')) return true;

    // Module aliases
    if (mod == 'dealers' || mod == 'franchises') {
      if (perms.contains('dealers') || perms.contains('dealers:*') || perms.contains('dealers:$act')) return true;
      if (perms.contains('franchises') || perms.contains('franchises:*') || perms.contains('franchises:$act')) return true;
    }
    if (mod == 'moq' || mod == 'pricing' || mod == 'delivery') {
      if (perms.contains('moq') || perms.contains('moq:*') || perms.contains('moq:$act')) return true;
      if (perms.contains('pricing') || perms.contains('pricing:*') || perms.contains('pricing:$act')) return true;
      if (perms.contains('delivery') || perms.contains('delivery:*') || perms.contains('delivery:$act')) return true;
    }
    if (mod == 'employees' || mod == 'admin_management') {
      if (perms.contains('employees') || perms.contains('employees:*') || perms.contains('employees:$act')) return true;
      if (perms.contains('admin_management') || perms.contains('admin_management:*') || perms.contains('admin_management:$act')) return true;
    }
    if (mod == 'stock_requests' && (perms.contains('inventory') || perms.contains('inventory:*'))) return true;

    return false;
  }

  factory UserModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final tInfo = json['territory_info'] is Map<String, dynamic>
        ? json['territory_info'] as Map<String, dynamic>
        : (json['territory_info'] is Map
            ? Map<String, dynamic>.from(json['territory_info'] as Map)
            : null);

    final dist = tInfo?['district']?.toString() ??
        json['district']?.toString() ??
        json['city']?.toString() ??
        '';
    final terr = tInfo?['territory']?.toString() ??
        json['territory']?.toString() ??
        '';
    final sArea = tInfo?['service_area']?.toString() ??
        json['locality']?.toString() ??
        '';
    final addr = tInfo?['address']?.toString() ??
        json['address']?.toString() ??
        '';
    final bool assigned = tInfo?['is_assigned'] == true ||
        (dist.isNotEmpty && terr.isNotEmpty && terr.toLowerCase() != 'other');

    int? zId;
    if (tInfo?['zone_id'] != null) {
      zId = int.tryParse(tInfo!['zone_id'].toString());
    } else if (json['zone_id'] != null) {
      zId = int.tryParse(json['zone_id'].toString());
    }

    final cLimit = json['credit_limit'] != null ? double.tryParse(json['credit_limit'].toString()) : null;
    final pTerms = json['payment_terms_days'] != null ? int.tryParse(json['payment_terms_days'].toString()) : null;
    final commPct = json['commission_percentage'] != null ? double.tryParse(json['commission_percentage'].toString()) : null;
    final dStatus = json['dealer_status']?.toString();

    List<String> perms = [];
    if (json['admin_permissions'] is List) {
      perms = (json['admin_permissions'] as List).map((e) => e.toString()).toList();
    }
    final dScope = json['data_scope_type']?.toString() ?? 'all_data';
    List<String> scopes = [];
    if (json['assigned_scope_ids'] is List) {
      scopes = (json['assigned_scope_ids'] as List).map((e) => e.toString()).toList();
    }

    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      status: json['status']?.toString() ?? 'approved',
      rejectionReason: json['rejection_reason']?.toString() ?? '',
      businessName: json['business_name']?.toString() ?? '',
      city: dist.isNotEmpty ? dist : (json['city']?.toString() ?? ''),
      territory: terr,
      district: dist,
      address: addr,
      locality: sArea,
      serviceArea: sArea,
      zoneId: zId,
      zoneName: tInfo?['zone_name']?.toString() ??
          json['zone_name']?.toString() ??
          terr,
      isTerritoryAssigned: assigned,
      creditLimit: cLimit,
      paymentTermsDays: pTerms,
      commissionPercentage: commPct,
      dealerStatus: dStatus,
      mustChangePassword: json['must_change_password'] == true,
      adminPermissions: perms,
      dataScopeType: dScope,
      assignedScopeIds: scopes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'status': status,
      'must_change_password': mustChangePassword,
      'rejection_reason': rejectionReason,
      'business_name': businessName,
      'city': city,
      'territory': territory,
      'district': district,
      'address': address,
      'locality': locality,
      'service_area': serviceArea,
      'zone_id': zoneId,
      'zone_name': zoneName,
      'is_assigned': isTerritoryAssigned,
      'credit_limit': creditLimit,
      'payment_terms_days': paymentTermsDays,
      'commission_percentage': commissionPercentage,
      'dealer_status': dealerStatus,
      'admin_permissions': adminPermissions,
      'data_scope_type': dataScopeType,
      'assigned_scope_ids': assignedScopeIds,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? status,
    String? rejectionReason,
    String? businessName,
    String? city,
    String? territory,
    String? district,
    String? address,
    String? locality,
    String? serviceArea,
    int? zoneId,
    String? zoneName,
    bool? isTerritoryAssigned,
    double? creditLimit,
    int? paymentTermsDays,
    double? commissionPercentage,
    String? dealerStatus,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      businessName: businessName ?? this.businessName,
      city: city ?? this.city,
      territory: territory ?? this.territory,
      district: district ?? this.district,
      address: address ?? this.address,
      locality: locality ?? this.locality,
      serviceArea: serviceArea ?? this.serviceArea,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      isTerritoryAssigned: isTerritoryAssigned ?? this.isTerritoryAssigned,
      creditLimit: creditLimit ?? this.creditLimit,
      paymentTermsDays: paymentTermsDays ?? this.paymentTermsDays,
      commissionPercentage: commissionPercentage ?? this.commissionPercentage,
      dealerStatus: dealerStatus ?? this.dealerStatus,
    );
  }
}