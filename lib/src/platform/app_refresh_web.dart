// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<void> refreshApplication({
  bool clearCache = false,
  bool returnToSettings = false,
}) async {
  if (clearCache) {
    try {
      final cacheStorage = html.window.caches;
      if (cacheStorage != null) {
        final keys = await cacheStorage.keys();
        for (final key in keys) {
          await cacheStorage.delete(key);
        }
      }
    } catch (_) {
      // Reload still proceeds when Cache API is unavailable.
    }

    try {
      final serviceWorker = html.window.navigator.serviceWorker;
      if (serviceWorker != null) {
        final registrations = await serviceWorker.getRegistrations();
        for (final registration in registrations) {
          await registration.unregister();
        }
      }
    } catch (_) {
      // Service workers are optional and may be unavailable.
    }
  }

  final current = Uri.parse(html.window.location.href);
  final query = Map<String, String>.from(current.queryParameters);
  query['refresh'] = DateTime.now().millisecondsSinceEpoch.toString();
  if (returnToSettings) {
    query['section'] = 'settings';
  }
  html.window.location.replace(
    current.replace(queryParameters: query).toString(),
  );
}
