final class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bpiibiyisykaqwkewjwq.supabase.co',
  );

  // Publishable key only. Never place service_role or database credentials
  // in the Flutter client.
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_dXiKfF3odwgPXkRhL6yiUw_cYjJDpII',
  );
}
