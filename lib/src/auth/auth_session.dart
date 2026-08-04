import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/supervisor_center_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

final class HomologationAccount {
  const HomologationAccount({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    required this.role,
    required this.roleLabelKey,
  });

  final String id;
  final String name;
  final String username;
  final String password;
  final PilotRole role;
  final String roleLabelKey;

  Map<String, dynamic> toSessionJson() => {
        'id': id,
        'username': username,
        'role': role.name,
      };
}

final class AuthSessionController extends StateNotifier<AuthSessionState> {
  AuthSessionController() : super(const AuthSessionState());

  static const storageKey = 'field_time_homologation_session_v1';

  static const accounts = [
    HomologationAccount(
      id: 'TER-0001',
      name: 'Santana',
      username: 'collaborator@test.jkdd',
      password: 'Test123!',
      role: PilotRole.employee,
      roleLabelKey: 'auth.roleCollaborator',
    ),
    HomologationAccount(
      id: 'test-supervisor',
      name: 'Supervisor Test',
      username: 'supervisor@test.jkdd',
      password: 'Test123!',
      role: PilotRole.supervisor,
      roleLabelKey: 'auth.roleSupervisor',
    ),
    HomologationAccount(
      id: 'test-director',
      name: 'Director Test',
      username: 'director@test.jkdd',
      password: 'Test123!',
      role: PilotRole.owner,
      roleLabelKey: 'auth.roleDirector',
    ),
  ];

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      state = const AuthSessionState(loading: false);
      return;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final id = json['id'] as String?;
      final username = json['username'] as String?;
      final roleName = json['role'] as String?;
      final account = accounts.firstWhere(
        (account) =>
            account.id == id &&
            account.username == username &&
            account.role.name == roleName,
      );
      state = AuthSessionState(loading: false, user: account);
    } on Object {
      await preferences.remove(storageKey);
      state = const AuthSessionState(loading: false);
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(authenticating: true, clearError: true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    HomologationAccount? matched;
    for (final account in accounts) {
      if (account.username.toLowerCase() == username.trim().toLowerCase() &&
          account.password == password) {
        matched = account;
        break;
      }
    }
    if (matched == null) {
      state = const AuthSessionState(
        loading: false,
        errorKey: 'auth.invalidCredentials',
      );
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        storageKey, jsonEncode(matched.toSessionJson()));
    state = AuthSessionState(loading: false, user: matched);
  }

  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(storageKey);
    state = const AuthSessionState(loading: false);
  }
}
