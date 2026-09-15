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
  });

  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isRejected => status.toLowerCase() == 'rejected';

  factory UserModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      status: json['status']?.toString() ?? 'approved',
      rejectionReason: json['rejection_reason']?.toString() ?? '',
      businessName: json['business_name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      territory: json['territory']?.toString() ?? '',
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
    );
  }
}