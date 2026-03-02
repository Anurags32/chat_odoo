import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_api_service.dart';
import '../../domain/models/login_response.dart';
import '../../domain/models/api_user_model.dart';

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService();
});

// Auth state
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final LoginResponse? loginData;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.loginData,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    LoginResponse? loginData,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      loginData: loginData ?? this.loginData,
      error: error,
    );
  }
}

// Auth provider
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApiService _authApiService;

  AuthNotifier(this._authApiService) : super(AuthState());

  Future<void> login(String login, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final response = await _authApiService.login(
      login: login,
      password: password,
    );

    if (response.success && response.data != null) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        loginData: response.data,
        error: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        error: response.message ?? 'Login failed',
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);

    final response = await _authApiService.logout();

    if (response.success) {
      state = AuthState(); // Reset to initial state
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.message ?? 'Logout failed',
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authApiService = ref.watch(authApiServiceProvider);
  return AuthNotifier(authApiService);
});

// Users state
class UsersState {
  final bool isLoading;
  final List<ApiUserModel> users;
  final String? error;

  UsersState({this.isLoading = false, this.users = const [], this.error});

  UsersState copyWith({
    bool? isLoading,
    List<ApiUserModel>? users,
    String? error,
  }) {
    return UsersState(
      isLoading: isLoading ?? this.isLoading,
      users: users ?? this.users,
      error: error,
    );
  }
}

// Users provider
class UsersNotifier extends StateNotifier<UsersState> {
  final AuthApiService _authApiService;

  UsersNotifier(this._authApiService) : super(UsersState());

  Future<void> fetchUsers() async {
    state = state.copyWith(isLoading: true, error: null);

    final response = await _authApiService.getUsers();

    if (response.success && response.data != null) {
      state = state.copyWith(
        isLoading: false,
        users: response.data!.users,
        error: null,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.message ?? 'Failed to fetch users',
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final usersApiProvider = StateNotifierProvider<UsersNotifier, UsersState>((
  ref,
) {
  final authApiService = ref.watch(authApiServiceProvider);
  return UsersNotifier(authApiService);
});
