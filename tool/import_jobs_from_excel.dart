import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';

const _primaryWorkbook = 'JKDD FIELD - BANCO DE DADOS DE OBRAS.xlsx';
const _secondaryWorkbook =
    'JKDD FIELD - PILOTO COM CONTROLE DE CUSTOS ADMIN.xlsx';

const _inputDir = 'data_import/input';
const _processedDir = 'data_import/processed';
const _archiveDir = 'data_import/archive';
const _reportsDir = 'data_import/reports';
const _jobsJsonPath = 'assets/data/jobs.json';
const _reportPath = 'data_import/reports/JOBS_IMPORT_REPORT.md';

const _client = 'EWW';
const _subcontractor = 'JKDD Finish & Remodeling Corp';

const _fields = [
  'Job_ID',
  'Job_Number',
  'Job_Name',
  'Full_Address',
  'Address',
  'City',
  'County',
  'State',
  'ZIP_Code',
  'Country',
  'Latitude',
  'Longitude',
  'Allowed_Radius_ft',
  'Travel_Bonus_Hours',
  'Status',
  'Client',
  'Supervisor',
  'Start_Date',
  'End_Date',
  'Notes',
  'Access_Instructions',
];

const _requiredFields = [
  'Job_Number',
  'Address',
  'City',
  'State',
  'ZIP_Code',
];
const _sheetDetectionFields = [
  'Job_ID',
  'Job_Number',
  'Address',
  'City',
  'State',
  'ZIP_Code',
  'Client',
  'Status',
];
const _minimumSheetDetectionHits = 5;

void main() {
  final importer = _JobsImporter(now: DateTime.now());
  final result = importer.run();
  stdout.writeln(result.summary);
  if (!result.success) exitCode = 1;
}

final class _JobsImporter {
  const _JobsImporter({required this.now});

  final DateTime now;

  _ImportResult run() {
    _ensureDirectories();
    final source = _selectWorkbook();
    if (source == null) {
      final report = _ImportReport(
        processedAt: now,
        errors: const ['No Excel workbook found in $_inputDir.'],
      );
      _writeReport(report);
      return const _ImportResult(
        success: false,
        summary: 'No Excel workbook found in data_import/input.',
      );
    }

    final archivePath = _archiveWorkbook(source);
    final excel = Excel.decodeBytes(source.readAsBytesSync());
    final sheetMatch = _findJobsSheet(excel);
    if (sheetMatch == null) {
      final report = _ImportReport(
        processedAt: now,
        sourceFile: source.path,
        archiveFile: archivePath,
        errors: [
          'No sheet with recognizable job headers was found.',
          'Available sheets: ${excel.tables.keys.join(', ')}',
        ],
      );
      _writeReport(report);
      return _ImportResult(
        success: false,
        summary: 'No valid jobs sheet found in ${source.path}.',
      );
    }

    final missingHeaders = [
      for (final field in _requiredFields)
        if (!sheetMatch.headers.containsValue(field)) field,
    ];
    if (missingHeaders.isNotEmpty) {
      final report = _ImportReport(
        processedAt: now,
        sourceFile: source.path,
        archiveFile: archivePath,
        sheetName: sheetMatch.sheetName,
        totalRows: sheetMatch.rows.length,
        foundColumns: sheetMatch.foundColumns,
        missingColumns: sheetMatch.missingColumns,
        missingFields: missingHeaders,
        errors: [
          'Missing required headers: ${missingHeaders.join(', ')}.',
        ],
      );
      _writeReport(report);
      return _ImportResult(
        success: false,
        summary: 'Missing required job headers in ${sheetMatch.sheetName}.',
      );
    }

    final previousJobs = _readPreviousJobs();
    final imported = <Map<String, dynamic>>[];
    final duplicateIds = <String>[];
    final duplicateNumbers = <String>[];
    final ignoredLines = <String>[];
    final missingFields = <String>[];
    final defaultValues = <String>[];
    final addressWarnings = <String>[];
    final seenIds = <String>{};
    final seenNumbers = <String, int>{};

    for (var rowIndex = sheetMatch.headerRowIndex + 1;
        rowIndex < sheetMatch.rows.length;
        rowIndex++) {
      final row = sheetMatch.rows[rowIndex];
      final lineNumber = rowIndex + 1;
      if (_isBlankRow(row)) {
        ignoredLines.add('Line $lineNumber: blank row.');
        continue;
      }

      final values = <String, String>{};
      for (final field in _fields) {
        values[field] = '';
      }
      for (final entry in sheetMatch.headers.entries) {
        values[entry.value] = _cellText(
          entry.key < row.length ? row[entry.key] : null,
        );
      }
      final originalJobId = values['Job_ID']!.trim();
      final originalJobName = values['Job_Name']!.trim();
      final originalClient = values['Client']!.trim();
      final originalStatus = values['Status']!.trim();
      if (values['Job_ID']!.trim().isEmpty) {
        values['Job_ID'] = values['Job_Number']!;
      }
      if (values['Job_Number']!.trim().isEmpty) {
        values['Job_Number'] = values['Job_ID']!;
      }
      final jobId = values['Job_ID']!.trim();
      final jobNumber = values['Job_Number']!.trim();
      final rowMissing = [
        if (jobNumber.isEmpty) 'Job_Number',
        if (values['Address']!.trim().isEmpty) 'Address',
        if (values['City']!.trim().isEmpty) 'City',
        if (values['State']!.trim().isEmpty) 'State',
        if (values['ZIP_Code']!.trim().isEmpty) 'ZIP_Code',
      ];
      if (rowMissing.isNotEmpty) {
        missingFields.add('Line $lineNumber: ${rowMissing.join(', ')}.');
        ignoredLines.add('Line $lineNumber: missing required fields.');
        continue;
      }
      if (originalJobId.isEmpty) {
        defaultValues.add(
          'Line $lineNumber / Job_Number $jobNumber: Job_ID set from Job_Number.',
        );
      }
      if (values['Job_Name']!.trim().isEmpty) {
        values['Job_Name'] = 'Obra $jobNumber';
      }
      if (originalJobName.isEmpty) {
        defaultValues.add(
          'Line $lineNumber / Job_Number $jobNumber: Job_Name set to Obra $jobNumber.',
        );
      }
      if (originalClient.isEmpty) {
        defaultValues.add(
          'Line $lineNumber / Job_Number $jobNumber: Client set to $_client.',
        );
      }
      if (originalStatus.isEmpty) {
        defaultValues.add(
          'Line $lineNumber / Job_Number $jobNumber: Status set to active.',
        );
      }
      final jobName = values['Job_Name']!.trim();
      final client = _emptyToNull(values['Client']) ?? _client;

      if (seenIds.contains(jobId)) {
        duplicateIds.add('Line $lineNumber: duplicate Job_ID $jobId.');
        ignoredLines.add('Line $lineNumber: duplicate Job_ID.');
        continue;
      }
      seenIds.add(jobId);

      if (seenNumbers.containsKey(jobNumber)) {
        duplicateNumbers.add(
          'Line $lineNumber: duplicate Job_Number $jobNumber '
          '(first seen on line ${seenNumbers[jobNumber]}).',
        );
      } else {
        seenNumbers[jobNumber] = lineNumber;
      }

      final fullAddress = _firstNonEmpty([
        _composeFullAddress(
          address: values['Address'],
          city: values['City'],
          state: values['State'],
          zipCode: values['ZIP_Code'],
        ),
      ]);
      if (fullAddress.isEmpty) {
        addressWarnings.add(
          'Line $lineNumber / Job_ID $jobId: missing address.',
        );
      }

      final status = _normalizeStatus(values['Status']);
      imported.add({
        'Job_ID': jobId,
        'Job_Number': jobNumber,
        'Job_Name': jobName,
        'Full_Address': fullAddress,
        'Address': _emptyToNull(values['Address']),
        'City': _emptyToNull(values['City']),
        'County': _emptyToNull(values['County']),
        'State': _emptyToNull(values['State']),
        'ZIP_Code': _emptyToNull(values['ZIP_Code']),
        'Country': _emptyToNull(values['Country']),
        'Latitude': _nullableNumber(values['Latitude']),
        'Longitude': _nullableNumber(values['Longitude']),
        'Allowed_Radius_ft': _nullableNumber(values['Allowed_Radius_ft']),
        'Travel_Bonus_Hours': _travelBonusHours(values['Travel_Bonus_Hours']),
        'Status': status,
        'Client': client,
        'Supervisor': _emptyToNull(values['Supervisor']),
        'Start_Date': _emptyToNull(values['Start_Date']),
        'End_Date': _emptyToNull(values['End_Date']),
        'Notes': _emptyToNull(values['Notes']),
        'Access_Instructions': _emptyToNull(values['Access_Instructions']),
      });
    }

    imported.sort((left, right) => _compareJobNumbers(
          left['Job_Number'] as String,
          right['Job_Number'] as String,
        ));

    final changes = _detectChanges(previousJobs, imported);
    final activeJobs =
        imported.where((job) => job['Status'] == 'active').length;
    final inactiveJobs =
        imported.where((job) => job['Status'] != 'active').length;
    final errorCount = duplicateIds.length +
        duplicateNumbers.length +
        missingFields.length +
        addressWarnings.length;

    final payload = {
      'metadata': {
        'product': 'Field Time',
        'company': 'JKDD TECH',
        'client': _client,
        'subcontractor': _subcontractor,
        'sourceFile': _fileName(source.path),
        'sourceSheet': sheetMatch.sheetName,
        'processedAt': now.toIso8601String(),
        'totalRows': sheetMatch.rows.length - sheetMatch.headerRowIndex - 1,
        'validJobs': imported.length,
        'activeJobs': activeJobs,
        'inactiveJobs': inactiveJobs,
        'errors': errorCount,
        'reportPath': _reportPath,
      },
      'jobs': imported,
    };
    File(_jobsJsonPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
      encoding: utf8,
    );
    File('$_processedDir/jobs_last_import.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
      encoding: utf8,
    );

    final report = _ImportReport(
      processedAt: now,
      sourceFile: source.path,
      archiveFile: archivePath,
      sheetName: sheetMatch.sheetName,
      totalRows: sheetMatch.rows.length - sheetMatch.headerRowIndex - 1,
      foundColumns: sheetMatch.foundColumns,
      missingColumns: sheetMatch.missingColumns,
      validJobs: imported.length,
      activeJobs: activeJobs,
      inactiveJobs: inactiveJobs,
      duplicateIds: duplicateIds,
      duplicateNumbers: duplicateNumbers,
      ignoredLines: ignoredLines,
      missingFields: missingFields,
      defaultValues: defaultValues,
      addressWarnings: addressWarnings,
      changes: changes,
      jobsJsonPath: _jobsJsonPath,
    );
    _writeReport(report);

    return _ImportResult(
      success: true,
      summary:
          'Imported ${imported.length} jobs from ${_fileName(source.path)}.',
    );
  }

  void _ensureDirectories() {
    for (final path in [
      _inputDir,
      _processedDir,
      _archiveDir,
      _reportsDir,
      'assets/data',
    ]) {
      Directory(path).createSync(recursive: true);
    }
  }

  File? _selectWorkbook() {
    final input = Directory(_inputDir);
    if (!input.existsSync()) return null;
    final files = input.listSync().whereType<File>().where((file) {
      final name = _fileName(file.path);
      return name.toLowerCase().endsWith('.xlsx') && !name.startsWith('~\$');
    }).toList(growable: false);
    if (files.isEmpty) return null;
    File? byName(String name) {
      for (final file in files) {
        if (_fileName(file.path).toLowerCase() == name.toLowerCase()) {
          return file;
        }
      }
      return null;
    }

    final primary = byName(_primaryWorkbook);
    if (primary != null) return primary;
    final secondary = byName(_secondaryWorkbook);
    if (secondary != null) return secondary;
    files.sort((left, right) =>
        right.lastModifiedSync().compareTo(left.lastModifiedSync()));
    return files.first;
  }

  String _archiveWorkbook(File source) {
    final timestamp = _timestamp(now);
    final target = '$_archiveDir/${timestamp}_${_fileName(source.path)}';
    source.copySync(target);
    return target;
  }

  _SheetMatch? _findJobsSheet(Excel excel) {
    _SheetMatch? best;
    for (final entry in excel.tables.entries) {
      final rows = entry.value.rows;
      if (rows.isEmpty) continue;

      final headers = _readHeaders(rows.first);
      final foundColumns = [
        for (final field in _sheetDetectionFields)
          if (headers.containsValue(field)) field,
      ];
      if (foundColumns.length < _minimumSheetDetectionHits) continue;

      final missingColumns = [
        for (final field in _sheetDetectionFields)
          if (!headers.containsValue(field)) field,
      ];
      final filledRows = rows.skip(1).where((row) => !_isBlankRow(row)).length;
      final match = _SheetMatch(
        sheetName: entry.key,
        rows: rows,
        headerRowIndex: 0,
        headers: headers,
        foundColumns: foundColumns,
        missingColumns: missingColumns,
        filledRows: filledRows,
      );
      if (best == null ||
          match.filledRows > best.filledRows ||
          (match.filledRows == best.filledRows &&
              match.foundColumns.length > best.foundColumns.length)) {
        best = match;
      }
    }
    return best;
  }

  Map<int, String> _readHeaders(List<dynamic> row) {
    final headers = <int, String>{};
    for (var index = 0; index < row.length; index++) {
      final canonical = _canonicalHeader(_cellText(row[index]));
      if (canonical != null) headers[index] = canonical;
    }
    return headers;
  }

  Map<String, Map<String, dynamic>> _readPreviousJobs() {
    final file = File(_jobsJsonPath);
    if (!file.existsSync()) return const {};
    try {
      final decoded = jsonDecode(file.readAsStringSync(encoding: utf8));
      if (decoded is! Map<String, dynamic> || decoded['jobs'] is! List) {
        return const {};
      }
      return {
        for (final job in decoded['jobs'] as List)
          if (job is Map<String, dynamic> && job['Job_ID'] != null)
            job['Job_ID'].toString(): job,
      };
    } on Object {
      return const {};
    }
  }

  _Changes _detectChanges(
    Map<String, Map<String, dynamic>> previous,
    List<Map<String, dynamic>> current,
  ) {
    final currentById = {
      for (final job in current) job['Job_ID'].toString(): job,
    };
    final added = currentById.keys
        .where((id) => !previous.containsKey(id))
        .toList(growable: false);
    final removed = previous.keys
        .where((id) => !currentById.containsKey(id))
        .toList(growable: false);
    final updated = currentById.keys.where((id) {
      final old = previous[id];
      if (old == null) return false;
      return jsonEncode(old) != jsonEncode(currentById[id]);
    }).toList(growable: false);
    return _Changes(added: added, updated: updated, removed: removed);
  }

  void _writeReport(_ImportReport report) {
    File(_reportPath).writeAsStringSync(report.toMarkdown(), encoding: utf8);
  }
}

final class _ImportResult {
  const _ImportResult({required this.success, required this.summary});

  final bool success;
  final String summary;
}

final class _SheetMatch {
  const _SheetMatch({
    required this.sheetName,
    required this.rows,
    required this.headerRowIndex,
    required this.headers,
    required this.foundColumns,
    required this.missingColumns,
    required this.filledRows,
  });

  final String sheetName;
  final List<List<dynamic>> rows;
  final int headerRowIndex;
  final Map<int, String> headers;
  final List<String> foundColumns;
  final List<String> missingColumns;
  final int filledRows;
}

final class _Changes {
  const _Changes({
    required this.added,
    required this.updated,
    required this.removed,
  });

  final List<String> added;
  final List<String> updated;
  final List<String> removed;
}

final class _ImportReport {
  const _ImportReport({
    required this.processedAt,
    this.sourceFile,
    this.archiveFile,
    this.sheetName,
    this.totalRows = 0,
    this.validJobs = 0,
    this.activeJobs = 0,
    this.inactiveJobs = 0,
    this.foundColumns = const [],
    this.missingColumns = const [],
    this.duplicateIds = const [],
    this.duplicateNumbers = const [],
    this.ignoredLines = const [],
    this.missingFields = const [],
    this.defaultValues = const [],
    this.addressWarnings = const [],
    this.changes = const _Changes(added: [], updated: [], removed: []),
    this.jobsJsonPath,
    this.errors = const [],
  });

  final DateTime processedAt;
  final String? sourceFile;
  final String? archiveFile;
  final String? sheetName;
  final int totalRows;
  final int validJobs;
  final int activeJobs;
  final int inactiveJobs;
  final List<String> foundColumns;
  final List<String> missingColumns;
  final List<String> duplicateIds;
  final List<String> duplicateNumbers;
  final List<String> ignoredLines;
  final List<String> missingFields;
  final List<String> defaultValues;
  final List<String> addressWarnings;
  final _Changes changes;
  final String? jobsJsonPath;
  final List<String> errors;

  String toMarkdown() {
    final duplicateCount = duplicateIds.length + duplicateNumbers.length;
    final buffer = StringBuffer()
      ..writeln('# JOBS IMPORT REPORT')
      ..writeln()
      ..writeln('- Arquivo processado: ${sourceFile ?? 'N/A'}')
      ..writeln('- Backup da planilha: ${archiveFile ?? 'N/A'}')
      ..writeln('- Aba utilizada: ${sheetName ?? 'N/A'}')
      ..writeln('- Data e hora: ${processedAt.toIso8601String()}')
      ..writeln('- Total de linhas: $totalRows')
      ..writeln('- Colunas encontradas: ${_inlineList(foundColumns)}')
      ..writeln('- Colunas ausentes: ${_inlineList(missingColumns)}')
      ..writeln('- Obras válidas: $validJobs')
      ..writeln('- Obras ativas: $activeJobs')
      ..writeln('- Obras inativas: $inactiveJobs')
      ..writeln('- Duplicidades: $duplicateCount')
      ..writeln('- Linhas ignoradas: ${ignoredLines.length}')
      ..writeln('- Campos ausentes: ${missingFields.length}')
      ..writeln('- Caminho do jobs.json gerado: ${jobsJsonPath ?? 'N/A'}')
      ..writeln()
      ..writeln('## Alterações detectadas')
      ..writeln()
      ..writeln('- Adicionadas: ${changes.added.length}')
      ..writeln('- Atualizadas: ${changes.updated.length}')
      ..writeln('- Removidas da nova planilha: ${changes.removed.length}')
      ..writeln();
    _writeSection(buffer, 'Erros gerais', errors);
    _writeSection(buffer, 'Job_ID duplicados', duplicateIds);
    _writeSection(buffer, 'Job_Number duplicados', duplicateNumbers);
    _writeSection(buffer, 'Linhas ignoradas', ignoredLines);
    _writeSection(buffer, 'Campos obrigatórios ausentes', missingFields);
    _writeSection(buffer, 'Valores preenchidos por padrão', defaultValues);
    _writeSection(buffer, 'Obras sem endereço', addressWarnings);
    _writeSection(buffer, 'Job_ID adicionados', changes.added);
    _writeSection(buffer, 'Job_ID atualizados', changes.updated);
    _writeSection(buffer, 'Job_ID removidos da nova planilha', changes.removed);
    return buffer.toString();
  }

  void _writeSection(StringBuffer buffer, String title, List<String> items) {
    buffer
      ..writeln('## $title')
      ..writeln();
    if (items.isEmpty) {
      buffer.writeln('- Nenhum.');
    } else {
      for (final item in items) {
        buffer.writeln('- $item');
      }
    }
    buffer.writeln();
  }
}

String? _canonicalHeader(String header) {
  final normalized = _normalize(header);
  return _headerAliases[normalized];
}

final _headerAliases = {
  'jobid': 'Job_ID',
  'job': 'Job_ID',
  'idobra': 'Job_ID',
  'obraid': 'Job_ID',
  'jobnumber': 'Job_Number',
  'jobno': 'Job_Number',
  'jobnum': 'Job_Number',
  'code': 'Job_Number',
  'codigo': 'Job_Number',
  'numerodaobra': 'Job_Number',
  'numeroobra': 'Job_Number',
  'obra': 'Job_Number',
  'jobname': 'Job_Name',
  'name': 'Job_Name',
  'nomedaobra': 'Job_Name',
  'nomeobra': 'Job_Name',
  'fulladdress': 'Full_Address',
  'fulladdr': 'Full_Address',
  'enderecocompleto': 'Full_Address',
  'address': 'Address',
  'addr': 'Address',
  'endereco': 'Address',
  'city': 'City',
  'cidade': 'City',
  'county': 'County',
  'condado': 'County',
  'state': 'State',
  'estado': 'State',
  'zipcode': 'ZIP_Code',
  'zip': 'ZIP_Code',
  'cep': 'ZIP_Code',
  'country': 'Country',
  'pais': 'Country',
  'latitude': 'Latitude',
  'lat': 'Latitude',
  'longitude': 'Longitude',
  'lng': 'Longitude',
  'long': 'Longitude',
  'allowedradiusft': 'Allowed_Radius_ft',
  'radiusft': 'Allowed_Radius_ft',
  'travelbonushours': 'Travel_Bonus_Hours',
  'travelbonus': 'Travel_Bonus_Hours',
  'bonushours': 'Travel_Bonus_Hours',
  'status': 'Status',
  'client': 'Client',
  'customer': 'Client',
  'cliente': 'Client',
  'supervisor': 'Supervisor',
  'startdate': 'Start_Date',
  'datainicio': 'Start_Date',
  'enddate': 'End_Date',
  'datafim': 'End_Date',
  'notes': 'Notes',
  'observacoes': 'Notes',
  'accessinstructions': 'Access_Instructions',
  'instrucoesdeacesso': 'Access_Instructions',
};

String _normalize(String value) {
  const accents = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'õ': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final codeUnit in lower.codeUnits) {
    final char = String.fromCharCode(codeUnit);
    final normalized = accents[char] ?? char;
    if (RegExp(r'[a-z0-9]').hasMatch(normalized)) {
      buffer.write(normalized);
    }
  }
  return buffer.toString();
}

String _cellText(dynamic cell) {
  final value = cell?.value;
  if (value == null) return '';
  return value.toString().trim();
}

bool _isBlankRow(List<dynamic> row) =>
    row.every((cell) => _cellText(cell).trim().isEmpty);

String _normalizeStatus(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return 'active';
  if (['inactive', 'inativo', 'closed', 'cancelled', 'canceled'].contains(
    normalized,
  )) {
    return 'inactive';
  }
  return 'active';
}

Object? _nullableNumber(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return num.tryParse(text.replaceAll(',', '')) ?? text;
}

double _travelBonusHours(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 0.0;
  final cleaned = text
      .toLowerCase()
      .replaceAll('hours', '')
      .replaceAll('hour', '')
      .replaceAll('hrs', '')
      .replaceAll('hr', '')
      .replaceAll('h', '')
      .replaceAll('+', '')
      .replaceAll(',', '.')
      .trim();
  return double.tryParse(cleaned) ?? 0.0;
}

String? _emptyToNull(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}

String _composeFullAddress({
  required String? address,
  required String? city,
  required String? state,
  required String? zipCode,
}) {
  final cityStateZip = [
    city,
    state,
    zipCode,
  ].map((value) => value?.trim() ?? '').where((value) => value.isNotEmpty);
  return [
    address?.trim() ?? '',
    cityStateZip.join(', '),
  ].where((value) => value.isNotEmpty).join(', ');
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final text = value?.trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

int _compareJobNumbers(String left, String right) {
  final leftNumber = int.tryParse(left);
  final rightNumber = int.tryParse(right);
  if (leftNumber != null && rightNumber != null) {
    final numeric = leftNumber.compareTo(rightNumber);
    if (numeric != 0) return numeric;
  }
  return left.compareTo(right);
}

String _inlineList(List<String> values) =>
    values.isEmpty ? 'Nenhuma.' : values.join(', ');

String _timestamp(DateTime value) =>
    '${value.year}${value.month.toString().padLeft(2, '0')}'
    '${value.day.toString().padLeft(2, '0')}_'
    '${value.hour.toString().padLeft(2, '0')}'
    '${value.minute.toString().padLeft(2, '0')}'
    '${value.second.toString().padLeft(2, '0')}';

String _fileName(String path) => path.split(Platform.pathSeparator).last;
