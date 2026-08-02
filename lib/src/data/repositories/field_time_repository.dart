import 'dart:convert';

import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class FieldTimeRepository {
  Future<FieldTimeSnapshot> load();
  Future<void> save(FieldTimeSnapshot snapshot);
}

final class SharedPreferencesFieldTimeRepository
    implements FieldTimeRepository {
  static const storageKey = 'field_time_operational_snapshot_v2';

  @override
  Future<FieldTimeSnapshot> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return FieldTimeSnapshot.seeded();
    try {
      return FieldTimeSnapshot.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return FieldTimeSnapshot.seeded();
    } on TypeError {
      return FieldTimeSnapshot.seeded();
    }
  }

  @override
  Future<void> save(FieldTimeSnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(storageKey, jsonEncode(snapshot.toJson()));
  }
}

final class InMemoryFieldTimeRepository implements FieldTimeRepository {
  InMemoryFieldTimeRepository([FieldTimeSnapshot? initial])
      : _snapshot = initial ?? FieldTimeSnapshot.seeded();

  FieldTimeSnapshot _snapshot;

  @override
  Future<FieldTimeSnapshot> load() async => _snapshot;

  @override
  Future<void> save(FieldTimeSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}
