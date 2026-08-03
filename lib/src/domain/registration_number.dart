import 'package:uuid/uuid.dart';

enum RegistrationRecordType {
  payrollEmployee('PAY', 4),
  subcontractorCompany('SUB', 4),
  subcontractorWorker('TER', 4),
  job('JOB', 4),
  receipt('REC', 6),
  reimbursement('RMB', 6),
  timesheet('TS', 6),
  invoice('INV', 6),
  newJobRequest('REQ', 6);

  const RegistrationRecordType(this.prefix, this.width);

  final String prefix;
  final int width;
}

abstract final class RegistrationNumberPolicy {
  static const uuidPattern =
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

  static const pilotSubcontractorCompanyId =
      '1f6f8d7d-8c98-4f4d-9d38-9846ecb10a01';
  static const pilotResponsibleWorkerId =
      '9d48bb6e-52cb-48a8-84f2-7e9a3ef8f001';
  static const pilotSubcontractorRegistrationNumber = 'SUB-0001';
  static const pilotWorkerRegistrationNumber = 'TER-0001';

  static String newUuid() => const Uuid().v4();

  static bool isUuid(String value) => RegExp(uuidPattern).hasMatch(value);

  static String deterministicUuid(String seed) {
    final hex = _hex128(seed);
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '4${hex.substring(13, 16)}-'
        '${(8 + int.parse(hex.substring(16, 17), radix: 16) % 4).toRadixString(16)}${hex.substring(17, 20)}-'
        '${hex.substring(20, 32)}';
  }

  static String next(
    RegistrationRecordType type,
    Iterable<String?> existingNumbers,
  ) {
    final maxSequence = maxSequenceFor(type, existingNumbers);
    return format(type, maxSequence + 1);
  }

  static int maxSequenceFor(
    RegistrationRecordType type,
    Iterable<String?> existingNumbers,
  ) =>
      existingNumbers
          .whereType<String>()
          .map((value) => _sequence(type, value))
          .fold<int>(0, (max, value) => value > max ? value : max);

  static String temporary(RegistrationRecordType type) {
    final suffix = newUuid().split('-').first.toUpperCase();
    return '${type.prefix}-TMP-$suffix';
  }

  static String format(RegistrationRecordType type, int sequence) =>
      '${type.prefix}-${sequence.toString().padLeft(type.width, '0')}';

  static bool hasDuplicate({
    required String id,
    required String registrationNumber,
    required Iterable<({String id, String registrationNumber})> records,
  }) {
    return records.any((record) =>
        record.id == id || record.registrationNumber == registrationNumber);
  }

  static int _sequence(RegistrationRecordType type, String value) {
    final match = RegExp('^${type.prefix}-(\\d{${type.width}})\$')
        .firstMatch(value.trim().toUpperCase());
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  static String _hex128(String seed) {
    const basis = 0x811c9dc5;
    const prime = 0x01000193;
    final parts = <String>[];
    for (var round = 0; round < 4; round++) {
      var hash = basis ^ round;
      for (final unit in '$seed#$round'.codeUnits) {
        hash ^= unit;
        hash = (hash * prime) & 0xffffffff;
      }
      parts.add(hash.toRadixString(16).padLeft(8, '0'));
    }
    return parts.join();
  }
}
