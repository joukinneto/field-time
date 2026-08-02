import 'package:jkdd_field_time_records_production/src/domain/value_objects/geo_point.dart';

enum WorkDayStatus { open, completed }

enum LaborType { subcontractor }

enum ReceiptStatus { draft, submitted, underReview, approved, rejected, paid }

enum ApprovalStatus { pending, approved, rejected }

enum AttachmentKind { receipt, jobPhoto }

enum SyncOperation { create, update }

enum TimesheetPeriod { today, week, month, year }

final class Job {
  const Job({
    required this.id,
    required this.companyId,
    required this.subcontractorCompanyId,
    required this.number,
    required this.name,
    required this.address,
    this.city,
    this.status = 'active',
    this.travelBonusHours = 0,
    this.active = true,
  });

  final String id;
  final String companyId;
  final String subcontractorCompanyId;
  final String number;
  final String name;
  final String address;
  final String? city;
  final String status;
  final double travelBonusHours;
  final bool active;

  String get displayName => '$number - $name';

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'subcontractorCompanyId': subcontractorCompanyId,
        'number': number,
        'name': name,
        'address': address,
        'city': city,
        'status': status,
        'travelBonusHours': travelBonusHours,
        'active': active,
      };

  factory Job.fromJson(Map<String, dynamic> json) => Job(
        id: json['id'] as String,
        companyId: json['companyId'] as String,
        subcontractorCompanyId: json['subcontractorCompanyId'] as String,
        number: json['number'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        city: json['city'] as String?,
        status: json['status'] as String? ??
            ((json['active'] as bool? ?? true) ? 'active' : 'inactive'),
        travelBonusHours: (json['travelBonusHours'] as num? ?? 0).toDouble(),
        active: json['active'] as bool? ?? true,
      );
}

final class SubcontractorCompany {
  const SubcontractorCompany({
    required this.id,
    required this.companyId,
    required this.legalName,
    required this.displayName,
  });

  final String id;
  final String companyId;
  final String legalName;
  final String displayName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'legalName': legalName,
        'displayName': displayName,
      };

  factory SubcontractorCompany.fromJson(Map<String, dynamic> json) =>
      SubcontractorCompany(
        id: json['id'] as String,
        companyId: json['companyId'] as String,
        legalName: json['legalName'] as String,
        displayName: json['displayName'] as String,
      );
}

final class WorkerProfile {
  const WorkerProfile({
    required this.id,
    required this.companyId,
    required this.subcontractorCompanyId,
    required this.displayName,
    required this.laborType,
  });

  final String id;
  final String companyId;
  final String subcontractorCompanyId;
  final String displayName;
  final LaborType laborType;

  bool get isSubcontractor => laborType == LaborType.subcontractor;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'subcontractorCompanyId': subcontractorCompanyId,
        'displayName': displayName,
        'laborType': laborType.name,
      };

  factory WorkerProfile.fromJson(Map<String, dynamic> json) => WorkerProfile(
        id: json['id'] as String,
        companyId: json['companyId'] as String,
        subcontractorCompanyId: json['subcontractorCompanyId'] as String,
        displayName: json['displayName'] as String,
        laborType: LaborType.values.byName(json['laborType'] as String),
      );
}

final class WorkSegment {
  const WorkSegment({
    required this.id,
    required this.companyId,
    required this.subcontractorCompanyId,
    required this.workerId,
    required this.jobId,
    required this.jobNumber,
    required this.jobName,
    required this.jobAddress,
    required this.startedAt,
    required this.startedLocation,
    required this.laborType,
    this.endedAt,
    this.endedLocation,
    this.notes,
    this.travelBonusHours = 0,
  });

  final String id;
  final String companyId;
  final String subcontractorCompanyId;
  final String workerId;
  final String jobId;
  final String jobNumber;
  final String jobName;
  final String jobAddress;
  final DateTime startedAt;
  final GeoPoint startedLocation;
  final DateTime? endedAt;
  final GeoPoint? endedLocation;
  final String? notes;
  final LaborType laborType;
  final double travelBonusHours;

  bool get isOpen => endedAt == null;
  Duration duration([DateTime? now]) =>
      (endedAt ?? now ?? DateTime.now()).difference(startedAt);
  double regularHours([DateTime? now]) => duration(now).inMinutes / 60;
  double totalHours([DateTime? now]) => regularHours(now) + travelBonusHours;

  WorkSegment close(DateTime at, GeoPoint location, {String? notes}) =>
      WorkSegment(
        id: id,
        companyId: companyId,
        subcontractorCompanyId: subcontractorCompanyId,
        workerId: workerId,
        jobId: jobId,
        jobNumber: jobNumber,
        jobName: jobName,
        jobAddress: jobAddress,
        startedAt: startedAt,
        startedLocation: startedLocation,
        endedAt: at,
        endedLocation: location,
        notes: notes?.trim().isNotEmpty == true ? notes!.trim() : this.notes,
        laborType: laborType,
        travelBonusHours: travelBonusHours,
      );

  WorkSegment withNotes(String value) => WorkSegment(
        id: id,
        companyId: companyId,
        subcontractorCompanyId: subcontractorCompanyId,
        workerId: workerId,
        jobId: jobId,
        jobNumber: jobNumber,
        jobName: jobName,
        jobAddress: jobAddress,
        startedAt: startedAt,
        startedLocation: startedLocation,
        endedAt: endedAt,
        endedLocation: endedLocation,
        notes: value.trim(),
        laborType: laborType,
        travelBonusHours: travelBonusHours,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'subcontractorCompanyId': subcontractorCompanyId,
        'workerId': workerId,
        'jobId': jobId,
        'jobNumber': jobNumber,
        'jobName': jobName,
        'jobAddress': jobAddress,
        'startedAt': startedAt.toIso8601String(),
        'startedLocation': startedLocation.toJson(),
        'endedAt': endedAt?.toIso8601String(),
        'endedLocation': endedLocation?.toJson(),
        'notes': notes,
        'laborType': laborType.name,
        'travelBonusHours': travelBonusHours,
      };

  factory WorkSegment.fromJson(Map<String, dynamic> json) => WorkSegment(
        id: json['id'] as String,
        companyId: json['companyId'] as String,
        subcontractorCompanyId: json['subcontractorCompanyId'] as String,
        workerId: json['workerId'] as String,
        jobId: json['jobId'] as String,
        jobNumber: json['jobNumber'] as String,
        jobName: json['jobName'] as String,
        jobAddress: json['jobAddress'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        startedLocation: GeoPointJson.fromJson(
            json['startedLocation'] as Map<String, dynamic>),
        endedAt: json['endedAt'] == null
            ? null
            : DateTime.parse(json['endedAt'] as String),
        endedLocation: json['endedLocation'] == null
            ? null
            : GeoPointJson.fromJson(
                json['endedLocation'] as Map<String, dynamic>),
        notes: json['notes'] as String?,
        laborType: LaborType.values.byName(json['laborType'] as String),
        travelBonusHours: (json['travelBonusHours'] as num? ?? 0).toDouble(),
      );
}

final class WorkDay {
  const WorkDay({
    required this.id,
    required this.companyId,
    required this.subcontractorCompanyId,
    required this.workerId,
    required this.workDate,
    required this.status,
    required this.segments,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.notes,
  });

  final String id;
  final String companyId;
  final String subcontractorCompanyId;
  final String workerId;
  final DateTime workDate;
  final WorkDayStatus status;
  final List<WorkSegment> segments;
  final DateTime? completedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen => status == WorkDayStatus.open;
  WorkSegment? get openSegment {
    for (final segment in segments.reversed) {
      if (segment.isOpen) return segment;
    }
    return null;
  }

  DateTime? get firstClockIn =>
      segments.isEmpty ? null : segments.first.startedAt;
  DateTime? get lastClockOut => segments.isEmpty ? null : segments.last.endedAt;
  Duration get workedDuration => segments.fold(
        Duration.zero,
        (total, segment) => total + segment.duration(),
      );
  double get travelBonusHours => segments.fold(
        0,
        (total, segment) => total + segment.travelBonusHours,
      );
  double get totalHours => workedDuration.inMinutes / 60 + travelBonusHours;
  Set<String> get visitedJobIds => segments.map((item) => item.jobId).toSet();

  WorkDay copyWith({
    WorkDayStatus? status,
    List<WorkSegment>? segments,
    DateTime? completedAt,
    String? notes,
    DateTime? updatedAt,
  }) =>
      WorkDay(
        id: id,
        companyId: companyId,
        subcontractorCompanyId: subcontractorCompanyId,
        workerId: workerId,
        workDate: workDate,
        status: status ?? this.status,
        segments: segments ?? this.segments,
        completedAt: completedAt ?? this.completedAt,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'subcontractorCompanyId': subcontractorCompanyId,
        'workerId': workerId,
        'workDate': workDate.toIso8601String(),
        'status': status.name,
        'segments': segments.map((item) => item.toJson()).toList(),
        'completedAt': completedAt?.toIso8601String(),
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WorkDay.fromJson(Map<String, dynamic> json) => WorkDay(
        id: json['id'] as String,
        companyId: json['companyId'] as String,
        subcontractorCompanyId: json['subcontractorCompanyId'] as String,
        workerId: json['workerId'] as String,
        workDate: DateTime.parse(json['workDate'] as String),
        status: WorkDayStatus.values.byName(json['status'] as String),
        segments: (json['segments'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(WorkSegment.fromJson)
            .toList(growable: false),
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.parse(json['completedAt'] as String),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

final class ReceiptItem {
  const ReceiptItem({required this.description, this.amount});
  final String description;
  final double? amount;
  Map<String, dynamic> toJson() =>
      {'description': description, 'amount': amount};
  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        description: json['description'] as String,
        amount: (json['amount'] as num?)?.toDouble(),
      );
}

final class ReceiptExtractionResult {
  const ReceiptExtractionResult({
    required this.id,
    required this.companyId,
    required this.subcontractorCompanyId,
    required this.receiptId,
    required this.createdAt,
    this.merchant,
    this.purchaseDate,
    this.total,
    this.tax,
    this.receiptNumber,
    this.items = const [],
    this.paymentMethod,
    this.message,
  });

  final String id;
  final String companyId;
  final String subcontractorCompanyId;
  final String receiptId;
  final String? merchant;
  final DateTime? purchaseDate;
  final double? total;
  final double? tax;
  final String? receiptNumber;
  final List<ReceiptItem> items;
  final String? paymentMethod;
  final String? message;
  final DateTime createdAt;

  bool get hasExtractedData =>
      merchant != null ||
      purchaseDate != null ||
      total != null ||
      tax != null ||
      receiptNumber != null ||
      items.isNotEmpty ||
      paymentMethod != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'subcontractorCompanyId': subcontractorCompanyId,
        'receiptId': receiptId,
        'merchant': merchant,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'total': total,
        'tax': tax,
        'receiptNumber': receiptNumber,
        'items': items.map((item) => item.toJson()).toList(),
        'paymentMethod': paymentMethod,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReceiptExtractionResult.fromJson(Map<String, dynamic> json) =>
      ReceiptExtractionResult(
        id: json['id'] as String,
        companyId: json['companyId'] as String,
        subcontractorCompanyId: json['subcontractorCompanyId'] as String,
        receiptId: json['receiptId'] as String,
        merchant: json['merchant'] as String?,
        purchaseDate: json['purchaseDate'] == null
            ? null
            : DateTime.parse(json['purchaseDate'] as String),
        total: (json['total'] as num?)?.toDouble(),
        tax: (json['tax'] as num?)?.toDouble(),
        receiptNumber: json['receiptNumber'] as String?,
        items: (json['items'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ReceiptItem.fromJson)
            .toList(growable: false),
        paymentMethod: json['paymentMethod'] as String?,
        message: json['message'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

final class Attachment {
  const Attachment({
    required this.id,
    required this.companyId,
    required this.subcontractorCompanyId,
    required this.workerId,
    required this.jobId,
    required this.kind,
    required this.fileName,
    required this.mimeType,
    required this.dataBase64,
    required this.createdAt,
  });

  final String id;
  final String companyId;
  final String subcontractorCompanyId;
  final String workerId;
  final String jobId;
  final AttachmentKind kind;
  final String fileName;
  final String mimeType;
  final String dataBase64;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'subcontractorCompanyId': subcontractorCompanyId,
        'workerId': workerId,
        'jobId': jobId,
        'kind': kind.name,
        'fileName': fileName,
        'mimeType': mimeType,
        'dataBase64': dataBase64,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: json['id'] as String,
        companyId: json['companyId'] as String,
        subcontractorCompanyId: json['subcontractorCompanyId'] as String,
        workerId: json['workerId'] as String,
        jobId: json['jobId'] as String,
        kind: AttachmentKind.values.byName(json['kind'] as String),
        fileName: json['fileName'] as String,
        mimeType: json['mimeType'] as String,
        dataBase64: json['dataBase64'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

final class Receipt {
  const Receipt({
    required this.id,
    required this.companyId,
    required this.subcontractorCompanyId,
    required this.workerId,
    required this.jobId,
    required this.purchaseDate,
    required this.merchant,
    required this.total,
    required this.tax,
    required this.description,
    required this.status,
    required this.attachmentIds,
    required this.userReviewed,
    required this.createdAt,
    required this.updatedAt,
    this.receiptNumber,
    this.notes,
    this.extractionResult,
  });

  final String id;
  final String companyId;
  final String subcontractorCompanyId;
  final String workerId;
  final String jobId;
  final DateTime purchaseDate;
  final String merchant;
  final double total;
  final double tax;
  final String? receiptNumber;
  final String description;
  final String? notes;
  final ReceiptStatus status;
  final List<String> attachmentIds;
  final ReceiptExtractionResult? extractionResult;
  final bool userReviewed;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'subcontractorCompanyId': subcontractorCompanyId,
        'workerId': workerId,
        'jobId': jobId,
        'purchaseDate': purchaseDate.toIso8601String(),
        'merchant': merchant,
        'total': total,
        'tax': tax,
        'receiptNumber': receiptNumber,
        'description': description,
        'notes': notes,
        'status': status.name,
        'attachmentIds': attachmentIds,
        'extractionResult': extractionResult?.toJson(),
        'userReviewed': userReviewed,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Receipt.fromJson(Map<String, dynamic> json) => Receipt(
        id: json['id'] as String,
        companyId: json['companyId'] as String,
        subcontractorCompanyId: json['subcontractorCompanyId'] as String,
        workerId: json['workerId'] as String,
        jobId: json['jobId'] as String,
        purchaseDate: DateTime.parse(json['purchaseDate'] as String),
        merchant: json['merchant'] as String,
        total: (json['total'] as num).toDouble(),
        tax: (json['tax'] as num).toDouble(),
        receiptNumber: json['receiptNumber'] as String?,
        description: json['description'] as String,
        notes: json['notes'] as String?,
        status: ReceiptStatus.values.byName(json['status'] as String),
        attachmentIds: (json['attachmentIds'] as List<dynamic>).cast<String>(),
        extractionResult: json['extractionResult'] == null
            ? null
            : ReceiptExtractionResult.fromJson(
                json['extractionResult'] as Map<String, dynamic>),
        userReviewed: json['userReviewed'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

final class ReimbursementRequest {
  const ReimbursementRequest({
    required this.id,
    required this.companyId,
    required this.subcontractorCompanyId,
    required this.workerId,
    required this.jobId,
    required this.receiptIds,
    required this.attachmentIds,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String subcontractorCompanyId;
  final String workerId;
  final String jobId;
  final List<String> receiptIds;
  final List<String> attachmentIds;
  final double amount;
  final ReceiptStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'subcontractorCompanyId': subcontractorCompanyId,
        'workerId': workerId,
        'jobId': jobId,
        'receiptIds': receiptIds,
        'attachmentIds': attachmentIds,
        'amount': amount,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ReimbursementRequest.fromJson(Map<String, dynamic> json) =>
      ReimbursementRequest(
        id: json['id'] as String,
        companyId: json['companyId'] as String,
        subcontractorCompanyId: json['subcontractorCompanyId'] as String,
        workerId: json['workerId'] as String,
        jobId: json['jobId'] as String,
        receiptIds: (json['receiptIds'] as List<dynamic>).cast<String>(),
        attachmentIds: (json['attachmentIds'] as List<dynamic>).cast<String>(),
        amount: (json['amount'] as num).toDouble(),
        status: ReceiptStatus.values.byName(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

final class Approval {
  const Approval({
    required this.id,
    required this.companyId,
    required this.subcontractorCompanyId,
    required this.subjectId,
    required this.status,
    required this.createdAt,
    this.reviewerId,
    this.notes,
  });

  final String id;
  final String companyId;
  final String subcontractorCompanyId;
  final String subjectId;
  final ApprovalStatus status;
  final String? reviewerId;
  final String? notes;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'subcontractorCompanyId': subcontractorCompanyId,
        'subjectId': subjectId,
        'status': status.name,
        'reviewerId': reviewerId,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Approval.fromJson(Map<String, dynamic> json) => Approval(
        id: json['id'] as String,
        companyId: json['companyId'] as String,
        subcontractorCompanyId: json['subcontractorCompanyId'] as String,
        subjectId: json['subjectId'] as String,
        status: ApprovalStatus.values.byName(json['status'] as String),
        reviewerId: json['reviewerId'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

final class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.companyId,
    required this.subcontractorCompanyId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.createdAt,
  });

  final String id;
  final String companyId;
  final String subcontractorCompanyId;
  final String entityType;
  final String entityId;
  final SyncOperation operation;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'subcontractorCompanyId': subcontractorCompanyId,
        'entityType': entityType,
        'entityId': entityId,
        'operation': operation.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) => SyncQueueItem(
        id: json['id'] as String,
        companyId: json['companyId'] as String,
        subcontractorCompanyId: json['subcontractorCompanyId'] as String,
        entityType: json['entityType'] as String,
        entityId: json['entityId'] as String,
        operation: SyncOperation.values.byName(json['operation'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

final class FieldTimeSnapshot {
  const FieldTimeSnapshot({
    required this.companyId,
    required this.companyName,
    required this.subcontractor,
    required this.worker,
    required this.jobs,
    this.workDays = const [],
    this.receipts = const [],
    this.reimbursements = const [],
    this.attachments = const [],
    this.approvals = const [],
    this.syncQueue = const [],
  });

  static const companyIdEww = 'eww';
  static const subcontractorIdJkdd = 'jkdd-finish-remodeling';
  static const workerIdPilot = 'jkdd-pilot';

  final String companyId;
  final String companyName;
  final SubcontractorCompany subcontractor;
  final WorkerProfile worker;
  final List<Job> jobs;
  final List<WorkDay> workDays;
  final List<Receipt> receipts;
  final List<ReimbursementRequest> reimbursements;
  final List<Attachment> attachments;
  final List<Approval> approvals;
  final List<SyncQueueItem> syncQueue;

  factory FieldTimeSnapshot.seeded() => const FieldTimeSnapshot(
        companyId: companyIdEww,
        companyName: 'EWW',
        subcontractor: SubcontractorCompany(
          id: subcontractorIdJkdd,
          companyId: companyIdEww,
          legalName: 'JKDD Finish & Remodeling Corp',
          displayName: 'JKDD Finish & Remodeling Corp',
        ),
        worker: WorkerProfile(
          id: workerIdPilot,
          companyId: companyIdEww,
          subcontractorCompanyId: subcontractorIdJkdd,
          displayName: 'JKDD Finish & Remodeling Corp',
          laborType: LaborType.subcontractor,
        ),
        jobs: [
          Job(
            id: 'eww-3099',
            companyId: companyIdEww,
            subcontractorCompanyId: subcontractorIdJkdd,
            number: '3099',
            name: 'Banyan Rd',
            address: '3099 Banyan Rd, Parkland, FL',
          ),
          Job(
            id: 'eww-315',
            companyId: companyIdEww,
            subcontractorCompanyId: subcontractorIdJkdd,
            number: '315',
            name: 'Palm Beach Gardens',
            address: 'Palm Beach Gardens, FL',
          ),
          Job(
            id: 'eww-630',
            companyId: companyIdEww,
            subcontractorCompanyId: subcontractorIdJkdd,
            number: '630',
            name: 'Golden Beach',
            address: 'Golden Beach, FL',
          ),
          Job(
            id: 'eww-2856',
            companyId: companyIdEww,
            subcontractorCompanyId: subcontractorIdJkdd,
            number: '2856',
            name: 'NE 26th St',
            address: '2856 NE 26th St, Fort Lauderdale, FL',
          ),
          Job(
            id: 'eww-11129',
            companyId: companyIdEww,
            subcontractorCompanyId: subcontractorIdJkdd,
            number: '11129',
            name: 'Green Bayberry Dr',
            address: '11129 Green Bayberry Dr, FL',
          ),
        ],
      );

  WorkDay? get activeWorkDay {
    for (final day in workDays.reversed) {
      if (day.isOpen) return day;
    }
    return null;
  }

  FieldTimeSnapshot copyWith({
    List<Job>? jobs,
    List<WorkDay>? workDays,
    List<Receipt>? receipts,
    List<ReimbursementRequest>? reimbursements,
    List<Attachment>? attachments,
    List<Approval>? approvals,
    List<SyncQueueItem>? syncQueue,
  }) =>
      FieldTimeSnapshot(
        companyId: companyId,
        companyName: companyName,
        subcontractor: subcontractor,
        worker: worker,
        jobs: jobs ?? this.jobs,
        workDays: workDays ?? this.workDays,
        receipts: receipts ?? this.receipts,
        reimbursements: reimbursements ?? this.reimbursements,
        attachments: attachments ?? this.attachments,
        approvals: approvals ?? this.approvals,
        syncQueue: syncQueue ?? this.syncQueue,
      );

  Map<String, dynamic> toJson() => {
        'companyId': companyId,
        'companyName': companyName,
        'subcontractor': subcontractor.toJson(),
        'worker': worker.toJson(),
        'jobs': jobs.map((item) => item.toJson()).toList(),
        'workDays': workDays.map((item) => item.toJson()).toList(),
        'receipts': receipts.map((item) => item.toJson()).toList(),
        'reimbursements': reimbursements.map((item) => item.toJson()).toList(),
        'attachments': attachments.map((item) => item.toJson()).toList(),
        'approvals': approvals.map((item) => item.toJson()).toList(),
        'syncQueue': syncQueue.map((item) => item.toJson()).toList(),
      };

  factory FieldTimeSnapshot.fromJson(Map<String, dynamic> json) =>
      FieldTimeSnapshot(
        companyId: json['companyId'] as String,
        companyName: json['companyName'] as String,
        subcontractor: SubcontractorCompany.fromJson(
            json['subcontractor'] as Map<String, dynamic>),
        worker: WorkerProfile.fromJson(json['worker'] as Map<String, dynamic>),
        jobs: _decodeList(json['jobs'], Job.fromJson),
        workDays: _decodeList(json['workDays'], WorkDay.fromJson),
        receipts: _decodeList(json['receipts'], Receipt.fromJson),
        reimbursements:
            _decodeList(json['reimbursements'], ReimbursementRequest.fromJson),
        attachments: _decodeList(json['attachments'], Attachment.fromJson),
        approvals: _decodeList(json['approvals'], Approval.fromJson),
        syncQueue: _decodeList(json['syncQueue'], SyncQueueItem.fromJson),
      );
}

List<T> _decodeList<T>(
  Object? value,
  T Function(Map<String, dynamic>) decoder,
) =>
    (value as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(decoder)
        .toList(growable: false);

extension GeoPointJson on GeoPoint {
  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'capturedAt': capturedAt.toIso8601String(),
        'isOfflineFallback': isOfflineFallback,
      };

  static GeoPoint fromJson(Map<String, dynamic> json) => GeoPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracyMeters: (json['accuracyMeters'] as num).toDouble(),
        capturedAt: DateTime.parse(json['capturedAt'] as String),
        isOfflineFallback: json['isOfflineFallback'] as bool? ?? false,
      );
}
