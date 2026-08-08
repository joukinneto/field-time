import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_theme.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_controller.dart';
import 'package:jkdd_field_time_records_production/src/auth/auth_session.dart';
import 'package:jkdd_field_time_records_production/src/config/supabase_config.dart';
import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';
import 'package:jkdd_field_time_records_production/src/presentation/screens/login_screen.dart';
import 'package:jkdd_field_time_records_production/src/presentation/screens/time_records_screen.dart';
import 'package:jkdd_field_time_records_production/src/supervisor_center/field_time_supervisor_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const ProviderScope(child: FieldTimeApp()));
}

final class FieldTimeApp extends ConsumerWidget {
  const FieldTimeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageControllerProvider);
    final session = ref.watch(authSessionProvider);
    ref.watch(fieldTimeSupervisorSyncProvider);
    ref.listen<AuthSessionState>(authSessionProvider, (previous, next) {
      final becameAuthenticated =
          previous?.authenticated != true && next.authenticated;
      if (becameAuthenticated) {
        _retryPersistedClockSnapshot(ref);
      }
    });
    final strings = AppStrings(language);
    return MaterialApp(
      title: strings.t('app.title'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: Locale(language.code),
      home: session.loading
          ? const _AppLoadingScreen()
          : session.authenticated
              ? const TimeRecordsScreen()
              : const LoginScreen(),
    );
  }

  Future<void> _retryPersistedClockSnapshot(WidgetRef ref) async {
    try {
      final snapshot = await ref.read(fieldTimeRepositoryProvider).load();
      await ref
          .read(fieldTimeClockSyncCoordinatorProvider)
          .retryPersistedSnapshot(snapshot);
    } on Object {
      // Offline-first invariant: recovery sync is best-effort. A failed retry
      // must never block an authenticated user or modify the local snapshot.
    }
  }
}

final class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}
