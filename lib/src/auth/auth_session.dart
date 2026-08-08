import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authSessionProvider =
    StateNotifierProvider<AuthSessionController, AuthSessionState>(
  (ref) => AuthSessionController()..load(),
);

final class AuthSessionState {
  const AuthSessionState({
    this.loading = true,
    this.authenticating = false,
    this.user,
    this.errorKey,
  });

  final bool loading;
  final bool authenticating;
  final HomologationAccount? user;
  final String? errorKey;

  bool get authenticated => user != null;

  AuthSessionState copyWith({
    bool? loading,
    bool? authenticating,
    HomologationAccount? user,
    String? errorKey,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthSessionState(
        loading: loading ?? this.loading,
        authenticating: authenticating ?? this.authenticating,
        user: clearUser ? null : user ?? this.user,
        errorKey: clearError ? null : errorKey ?? this.errorKey,
      );
}

/// Application-facing authenticated account.
///
/// Authentication credentials are owned by Supabase Auth and are never stored
/// in this model or in SharedPreferences.
final class HomologationAccount {
  const HomologationAccount({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.roleLabelKey,
    required this.companyId,
    required this.authUserId,
  });

  /// Worker id for worker/supervisor accounts when available. Company admins
  /// fall back to the Supabase Auth user UUID.
  final String id;
  final String name;
  final String username;
  final PilotRole role;
  final String roleLabelKey;
  final String companyId;
  final String authUserId;
}

final class AuthSessionController extends StateNotifier<AuthSessionState> {
  AuthSessionController()
      : _client = Supabase.instance.client,
        super(const AuthSessionState()) {
    _subscription = _client.auth.onAuthStateChange.listen((event) async {
      if (event.session == null) {
        state = const AuthSessionState(loading: false);
        return;
      }
      await _hydrateAuthenticatedUser(event.session!.user);
    });
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _subscription;

  Future<void> load() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      state = const AuthSessionState(loading: false);
      return;
    }
    await _hydrateAuthenticatedUser(session.user);
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(authenticating: true, clearError: true);
    try {
      final response = await _client.auth.signInWithPassword(
        email: username.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        state = const AuthSessionState(
          loading: false,
          errorKey: 'auth.invalidCredentials',
        );
        return;
      }
      await _hydrateAuthenticatedUser(user);
    } on AuthException {
      state = const AuthSessionState(
        loading: false,
        errorKey: 'auth.invalidCredentials',
      );
    } on PostgrestException {
      await _client.auth.signOut();
      state = const AuthSessionState(
        loading: false,
        errorKey: 'auth.invalidCredentials',
      );
    } on Object {
      state = const AuthSessionState(
        loading: false,
        errorKey: 'auth.invalidCredentials',
      );
    }
  }

  Future<void> requestPasswordRecovery(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    state = const AuthSessionState(loading: false);
  }

  Future<void> _hydrateAuthenticatedUser(User authUser) async {
    try {
      final membership = await _client
          .from('company_members')
          .select('company_id, role')
          .eq('user_id', authUser.id)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();

      if (membership == null) {
        await _client.auth.signOut();
        state = const AuthSessionState(
          loading: false,
          errorKey: 'auth.invalidCredentials',
        );
        return;
      }

      final companyId = membership['company_id'] as String;
      final databaseRole = membership['role'] as String;
      final profile = await _client
          .from('profiles')
          .select('first_name, last_name')
          .eq('id', authUser.id)
          .maybeSingle();

      final firstName = (profile?['first_name'] as String?)?.trim() ?? '';
      final lastName = (profile?['last_name'] as String?)?.trim() ?? '';
      final displayName = '$firstName $lastName'.trim();

      String? workerId;
      if (databaseRole == 'worker' || databaseRole == 'supervisor') {
        final worker = await _client
            .from('workers')
            .select('id')
            .eq('company_id', companyId)
            .eq('user_id', authUser.id)
            .eq('status', 'active')
            .limit(1)
            .maybeSingle();
        workerId = worker?['id'] as String?;
      }

      final mappedRole = switch (databaseRole) {
        'company_admin' => PilotRole.owner,
        'supervisor' => PilotRole.supervisor,
        _ => PilotRole.employee,
      };

      final roleLabelKey = switch (databaseRole) {
        'company_admin' => 'auth.roleDirector',
        'supervisor' => 'auth.roleSupervisor',
        _ => 'auth.roleCollaborator',
      };

      state = AuthSessionState(
        loading: false,
        user: HomologationAccount(
          id: workerId ?? authUser.id,
          authUserId: authUser.id,
          companyId: companyId,
          name: displayName.isEmpty
              ? (authUser.email ?? 'JKDD Field User')
              : displayName,
          username: authUser.email ?? '',
          role: mappedRole,
          roleLabelKey: roleLabelKey,
        ),
      );
    } on Object {
      await _client.auth.signOut();
      state = const AuthSessionState(
        loading: false,
        errorKey: 'auth.invalidCredentials',
      );
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
