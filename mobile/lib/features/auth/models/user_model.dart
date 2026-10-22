class UserModel {
  final int id;
  final String role;
  final String? firstName;
  final String? lastName;
  final String name;
  final String? email;
  final String? phone;
  final String? gender;
  final String? status;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.role,
    this.firstName,
    this.lastName,
    required this.name,
    this.email,
    this.phone,
    this.gender,
    this.status,
    this.avatarUrl,
  });

  bool get isCustomer => role.toUpperCase() == 'CUSTOMER';
  bool get isProvider => role.toUpperCase() == 'PROVIDER';
  bool get isAdmin => role.toUpperCase() == 'ADMIN';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      role: json['role']?.toString().toUpperCase() ?? 'CUSTOMER',
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      name: json['name']?.toString() ??
          '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      gender: json['gender']?.toString(),
      status: json['status']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  UserModel copyWith({String? avatarUrl}) {
    return UserModel(
      id: id,
      role: role,
      firstName: firstName,
      lastName: lastName,
      name: name,
      email: email,
      phone: phone,
      gender: gender,
      status: status,
      avatarUrl: avatarUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'name': name,
      'email': email,
      'phone': phone,
      'gender': gender,
      'status': status,
      'avatar_url': avatarUrl,
    };
  }
}
