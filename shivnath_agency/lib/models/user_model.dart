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
  });

  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isRejected => status.toLowerCase() == 'rejected';

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
    );
  }
}