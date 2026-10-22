import 'user_model.dart';

class AuthResponse {
  final UserModel user;
  final String token;
  final String tokenType;

  const AuthResponse({
    required this.user,
    required this.token,
    this.tokenType = 'Bearer',
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Backend returns { success: true, message: '...', data: { user: {...}, token: '...', token_type: 'Bearer' } }
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    final userMap = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : (data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : <String, dynamic>{});

    return AuthResponse(
      user: UserModel.fromJson(userMap),
      token: data['token']?.toString() ?? '',
      tokenType: data['token_type']?.toString() ?? 'Bearer',
    );
  }
}
