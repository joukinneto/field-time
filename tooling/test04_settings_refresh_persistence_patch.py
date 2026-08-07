from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str):
    text = path.read_text()
    if old not in text:
        raise RuntimeError(f'Pattern not found: {label}')
    path.write_text(text.replace(old, new, 1))

path = Path('lib/src/presentation/screens/time_records_screen.dart')
replace_once(
    path,
    """  _Destination _destination = _Destination.home;\n""",
    """  _Destination _destination =\n      Uri.base.queryParameters['section'] == 'settings'\n      ? _Destination.settings\n      : _Destination.home;\n""",
    'initial destination from URL',
)
replace_once(
    path,
    """      onRefreshApp: () => refreshApplication(),\n      onClearCacheAndRefresh: () => refreshApplication(clearCache: true),\n""",
    """      onRefreshApp: () => refreshApplication(returnToSettings: true),\n      onClearCacheAndRefresh: () =>\n          refreshApplication(clearCache: true, returnToSettings: true),\n""",
    'settings refresh callbacks',
)

path = Path('lib/src/platform/app_refresh_stub.dart')
text = path.read_text()
text = text.replace(
    'Future<void> refreshApplication({bool clearCache = false}) async {}',
    'Future<void> refreshApplication({\n  bool clearCache = false,\n  bool returnToSettings = false,\n}) async {}',
)
path.write_text(text)

path = Path('lib/src/platform/app_refresh_web.dart')
replace_once(
    path,
    """Future<void> refreshApplication({bool clearCache = false}) async {\n""",
    """Future<void> refreshApplication({\n  bool clearCache = false,\n  bool returnToSettings = false,\n}) async {\n""",
    'web refresh signature',
)
replace_once(
    path,
    """  query['refresh'] = DateTime.now().millisecondsSinceEpoch.toString();\n""",
    """  query['refresh'] = DateTime.now().millisecondsSinceEpoch.toString();\n  if (returnToSettings) {\n    query['section'] = 'settings';\n  }\n""",
    'settings query marker',
)
