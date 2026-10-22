import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  unsupportedAdmin,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isCustomer => user?.isCustomer ?? false;
  bool get isProvider => user?.isProvider ?? false;
  bool get isUnsupportedAdmin => status == AuthStatus.unsupportedAdmin;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// 1. Dependency Providers
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(
    storage: storage,
    onUnauthorized: () {
      ref.read(authNotifierProvider.notifier).handleUnauthorized();
    },
  );
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return PushNotificationService(
    apiClient: apiClient,
    storage: storage,
  );
});

// 2. Auth Notifier Provider
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  final SecureStorageService? _customStorage;
  final ApiClient? _customApiClient;
  final PushNotificationService? _customPushService;
  AuthState? _initialState;

  AuthNotifier({
    SecureStorageService? storage,
    ApiClient? apiClient,
    PushNotificationService? pushService,
    AuthState? initialState,
  })  : _customStorage = storage,
        _customApiClient = apiClient,
        _customPushService = pushService {
    _initialState = initialState;
  }

  @override
  AuthState build() {
    return _initialState ?? const AuthState();
  }

  SecureStorageService get _storage => _customStorage ?? ref.read(secureStorageProvider);
  ApiClient get _apiClient => _customApiClient ?? ref.read(apiClientProvider);
  PushNotificationService get _pushService => _customPushService ?? ref.read(pushNotificationServiceProvider);

  void setTestState(AuthState s) {
    state = s;
  }

  /// Updates the cached user's avatar app-wide without a network round trip
  /// (the upload/delete endpoints already return the canonical new value).
  void updateAvatarUrl(String? avatarUrl) {
    final current = state.user;
    if (current == null) return;
    state = state.copyWith(user: current.copyWith(avatarUrl: avatarUrl));
  }

  /// Restore existing session on app startup.
  Future<void> restoreSession() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      final response = await _apiClient.get('/auth/me');
      final data = response.data;

      if (data is Map<String, dynamic> && data['data'] != null) {
        final userData = data['data']['user'] as Map<String, dynamic>;
        final user = UserModel.fromJson(userData);

        if (user.isAdmin) {
          state = AuthState(
            status: AuthStatus.unsupportedAdmin,
            user: user,
          );
          return;
        }

        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );

        // Register push device in background
        _pushService.registerDevice();
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } on AppException catch (e) {
      if (e.statusCode == 401) {
        // Token is genuinely invalid or expired on backend
        await _storage.clearToken();
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        // Network timeout / offline: DO NOT clear token!
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: e.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Oturum açılamadı.',
      );
    }
  }

  /// Login with email/phone and password.
  Future<bool> login({
    required String login,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final response = await _apiClient.post('/auth/login', data: {
        'login': login.trim(),
        'password': password,
      });

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const AppException(
          message: 'Sunucudan geçersiz yanıt alındı. Lütfen daha sonra tekrar deneyin.',
        );
      }

      final authResponse = AuthResponse.fromJson(data);
      await _storage.saveToken(authResponse.token);

      if (authResponse.user.isAdmin) {
        state = AuthState(
          status: AuthStatus.unsupportedAdmin,
          user: authResponse.user,
        );
        return false;
      }

      state = AuthState(
        status: AuthStatus.authenticated,
        user: authResponse.user,
      );

      // Register device and request notification permission
      _pushService.registerDevice();
      _pushService.requestPermissions();

      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Giriş yapılamadı, lütfen tekrar deneyin.',
      );
      return false;
    }
  }

  /// Register customer or provider (ADMIN is rejected).
  Future<bool> register({
    required String firstName,
    required String lastName,
    required String role,
    String? email,
    String? phone,
    required String password,
    required String passwordConfirmation,
    String? businessName,
  }) async {
    // Client-side guard: ADMIN cannot be registered
    final cleanRole = role.toUpperCase().trim();
    if (cleanRole != 'CUSTOMER' && cleanRole != 'PROVIDER') {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Yalnızca Müşteri veya Berber olarak kayıt olabilirsiniz.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final payload = <String, dynamic>{
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'role': cleanRole,
        'password': password,
        'password_confirmation': passwordConfirmation,
      };

      if (email != null && email.trim().isNotEmpty) {
        payload['email'] = email.trim();
      }
      if (phone != null && phone.trim().isNotEmpty) {
        payload['phone'] = phone.trim();
      }
      if (cleanRole == 'PROVIDER' && businessName != null && businessName.trim().isNotEmpty) {
        payload['business_name'] = businessName.trim();
      }

      final response = await _apiClient.post('/auth/register', data: payload);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const AppException(
          message: 'Sunucudan geçersiz yanıt alındı. Lütfen daha sonra tekrar deneyin.',
        );
      }

      final authResponse = AuthResponse.fromJson(data);
      await _storage.saveToken(authResponse.token);

      state = AuthState(
        status: AuthStatus.authenticated,
        user: authResponse.user,
      );

      _pushService.registerDevice();
      _pushService.requestPermissions();

      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Kayıt işlemi başarısız oldu.',
      );
      return false;
    }
  }

  /// Logout from backend and clean local secure session.
  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _apiClient.post('/auth/logout');
    } catch (_) {
      // Best-effort backend notification
    }

    await _pushService.unregisterDevice();
    await _storage.clearToken();

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Called when API interceptor detects 401 Unauthenticated.
  void handleUnauthorized() {
    _storage.clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
