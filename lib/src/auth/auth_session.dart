import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authSessionProvider =
    StateNotifierProvider<AuthSessionController, AuthSessionState>(
  (ref) => AuthSessionController.live()..load(),
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
  AuthSessionController.live()
      : _client = Supabase.instance.client,
        super(const AuthSessionState()) {
    _subscription = _client!.auth.onAuthStateChange.listen((event) async {
      if (event.session == null) {
        state = const AuthSessionState(loading: false);
        return;
      }
      await _hydrateAuthenticatedUser(event.session!.user);
    });
  }

  AuthSessionController.test({HomologationAccount? user})
      : _client = null,
        super(AuthSessionState(loading: false, user: user));

  static const testWorker = HomologationAccount(
    id: 'TER-0001',
    authUserId: '00000000-0000-0000-0000-000000000001',
    companyId: '00000000-0000-0000-0000-000000000101',
    name: 'Santana',
    username: 'collaborator@test.jkdd',
    role: PilotRole.employee,
    roleLabelKey: 'auth.roleCollaborator',
  );

  final SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase client is unavailable in test session mode.');
    }
    return client;
  }

  Future<void> load() async {
    final client = _requiredClient;
    final session = client.auth.currentSession;
    if (session == null) {
      state = const AuthSessionState(loading: false);
      return;
    }
    await _hydrateAuthenticatedUser(session.user);
  }

  Future<void> login(String username, String password) async {
    final client = _requiredClient;
    state = state.copyWith(authenticating: true, clearError: true);
    try {
      final response = await client.auth.signInWithPassword(
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
      await client.auth.signOut();
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
    await _requiredClient.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> logout() async {
    final client = _client;
    if (client != null) {
      await client.auth.signOut();
    }
    state = const AuthSessionState(loading: false);
  }

  Future<void> _hydrateAuthenticatedUser(User authUser) async {
    final client = _requiredClient;
    try {
      final membership = await client
          .from('company_members')
          .select('company_id, role')
          .eq('user_id', authUser.id)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();

      if (membership == null) {
        await client.auth.signOut();
        state = const AuthSessionState(
          loading: false,
          errorKey: 'auth.invalidCredentials',
        );
        return;
      }

      final companyId = membership['company_id'] as String;
      final databaseRole = membership['role'] as String;
      final profile = await client
          .from('profiles')
          .select('first_name, last_name')
          .eq('id', authUser.id)
          .maybeSingle();

      final firstName = (profile?['first_name'] as String?)?.trim() ?? '';
      final lastName = (profile?['last_name'] as String?)?.trim() ?? '';
      final displayName = '$firstName $lastName'.trim();

      String? workerId;
      if (databaseRole == 'worker' || databaseRole == 'supervisor') {
        final worker = await client
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
      await client.auth.signOut();
      state = const AuthSessionState(
        loading: false,
        errorKey: 'auth.invalidCredentials',
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
