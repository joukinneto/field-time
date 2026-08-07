import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jkdd_field_time_records_production/features/employees/data/employee_asset_repository.dart';
import 'package:jkdd_field_time_records_production/features/jobs/data/job_asset_repository.dart';
import 'package:jkdd_field_time_records_production/src/application/field_time_application_service.dart';
import 'package:jkdd_field_time_records_production/src/data/repositories/field_time_repository.dart';
import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';
import 'package:jkdd_field_time_records_production/src/domain/value_objects/geo_point.dart';
import 'package:jkdd_field_time_records_production/src/gps/time_record_location_service.dart';
import 'package:jkdd_field_time_records_production/src/platform/network_status.dart';
import 'package:uuid/uuid.dart';

final fieldTimeRepositoryProvider = Provider<FieldTimeRepository>(
    (ref) => SharedPreferencesFieldTimeRepository());

final fieldTimeApplicationServiceProvider =
    Provider((ref) => const FieldTimeApplicationService());

final fieldTimeControllerProvider =
    StateNotifierProvider<FieldTimeController, FieldTimeState>((ref) {
  final controller = FieldTimeController(
    repository: ref.watch(fieldTimeRepositoryProvider),
    jobRepository: ref.watch(jobAssetRepositoryProvider),
    employeeRepository: ref.watch(employeeAssetRepositoryProvider),
    service: ref.watch(fieldTimeApplicationServiceProvider),
  );
  controller.initialize();
  return controller;
});

final class FieldTimeState {
  const FieldTimeState({
    required this.snapshot,
    this.loading = false,
    this.message,
    this.messageValues,
    this.error,
    this.errorValues,
    this.jobsImportMetadata,
    this.jobsImportError,
    this.lastLocation,
    this.lastCompletedDay,
  });

  final FieldTimeSnapshot snapshot;
  final bool loading;
  final String? message;
  final Map<String, Object?>? messageValues;
  final String? error;
  final Map<String, Object?>? errorValues;
  final JobCatalogMetadata? jobsImportMetadata;
  final String? jobsImportError;
  final GeoPoint? lastLocation;
  final WorkDay? lastCompletedDay;

  bool get online => isDeviceOnline;
  int get pendingItems => snapshot.syncQueue.length;
  WorkDay? get activeDay => snapshot.activeWorkDay;
  WorkSegment? get activeSegment => activeDay?.openSegment;
}

final class ReceiptDraft {
  const ReceiptDraft({
    required this.job,
    required this.merchant,
    required this.purchaseDate,
    required this.total,
    required this.tax,
    required this.description,
    required this.submit,
    required this.userReviewed,
    this.receiptNumber,
    this.notes,
  });

  final Job job;
  final String merchant;
  final DateTime purchaseDate;
  final double total;
  final double tax;
  final String? receiptNumber;
  final String description;
  final String? notes;
  final bool submit;
  final bool userReviewed;
}

final class FieldTimeController extends StateNotifier<FieldTimeState> {
  FieldTimeController({
    required this.repository,
    required this.jobRepository,
    required this.employeeRepository,
    required this.service,
    this.locationService = const TimeRecordLocationService(),
    this.uuid = const Uuid(),
  }) : super(FieldTimeState(snapshot: FieldTimeSnapshot.seeded()));

  final FieldTimeRepository repository;
  final JobAssetRepository jobRepository;
  final EmployeeAssetRepository employeeRepository;
  final FieldTimeApplicationService service;
  final TimeRecordLocationService locationService;
  final Uuid uuid;

  Future<void> initialize() async {
    state = FieldTimeState(snapshot: state.snapshot, loading: true);
    var snapshot = await repository.load();
    JobCatalogMetadata? jobsImportMetadata;
    String? jobsImportError;
    try {
      final catalog = await jobRepository.loadCatalog();
      jobsImportMetadata = catalog.metadata;
      if (catalog.jobs.isNotEmpty) {
        snapshot = snapshot.copyWith(
          jobs: jobRepository.toFieldTimeJobs(catalog.jobs),
        );
      }
    } on JobAssetRepositoryException catch (error) {
      jobsImportError = error.message;
    }
    try {
      final employeeCatalog = await employeeRepository.loadCatalog();
      final activeEmployees = employeeCatalog.activeEmployees;
      if (activeEmployees.isNotEmpty) {
        final employee = activeEmployees.firstWhere(
          (employee) => employee.employeeId == FieldTimeSnapshot.workerIdPilot,
          orElse: () => activeEmployees.first,
        );
        snapshot = snapshot.copyWith(
          worker: employeeRepository.toWorkerProfile(employee),
          subcontractor: SubcontractorCompany(
            id: FieldTimeSnapshot.subcontractorIdJkdd,
            companyId: FieldTimeSnapshot.companyIdEww,
            legalName: employee.company,
            displayName: employee.company,
            registrationNumber: 'SUB-0001',
          ),
        );
      }
    } on EmployeeAssetRepositoryException {
      // Keep the last local worker profile if the employees asset is unavailable.
    }
    state = FieldTimeState(
      snapshot: snapshot,
      jobsImportMetadata: jobsImportMetadata,
      jobsImportError: jobsImportError,
      message: 'fieldTime.localDataLoaded',
    );
  }

  Future<void> clockIn(Job job, String? notes) => _withLocation(
        progress: 'fieldTime.clockInProgress',
        success: 'fieldTime.clockInSuccess',
        successValues: {'job': job.number},
        mutate: (snapshot, at, location) => service.clockIn(
          snapshot: snapshot,
          job: job,
          at: at,
          location: location,
          notes: notes,
        ),
      );

  Future<void> switchJob(Job job, String? notes) => _withLocation(
        progress: 'fieldTime.switchJobProgress',
        success: 'fieldTime.switchJobSuccess',
        successValues: {'job': job.number},
        mutate: (snapshot, at, location) => service.switchJob(
          snapshot: snapshot,
          nextJob: job,
          at: at,
          location: location,
          notes: notes,
        ),
      );

  Future<void> endDay(String? notes) => _withLocation(
        progress: 'fieldTime.endDayProgress',
        success: 'fieldTime.endDaySuccess',
        rememberCompletedDay: true,
        mutate: (snapshot, at, location) => service.endDay(
          snapshot: snapshot,
          at: at,
          location: location,
          notes: notes,
        ),
      );

  Future<void> addJobPhoto(XFile file, Job job) async {
    await _run('fieldTime.savePhotoProgress', () async {
      final attachment = await _attachment(file, job, AttachmentKind.jobPhoto);
      final snapshot = service.addJobPhoto(
        snapshot: state.snapshot,
        attachment: attachment,
      );
      await repository.save(snapshot);
      return snapshot;
    }, 'fieldTime.photoLinked', successValues: {'job': job.number});
  }

  Future<void> saveReceipt(ReceiptDraft draft, XFile? file) async {
    await _run('fieldTime.saveReceiptProgress', () async {
      if (file == null) {
        throw StateError('receipts.attachPhotoRequired');
      }
      final attachment =
          await _attachment(file, draft.job, AttachmentKind.receipt);
      final snapshot = await service.saveReceipt(
        snapshot: state.snapshot,
        job: draft.job,
        attachment: attachment,
        merchant: draft.merchant,
        purchaseDate: draft.purchaseDate,
        total: draft.total,
        tax: draft.tax,
        receiptNumber: draft.receiptNumber,
        description: draft.description,
        notes: draft.notes,
        submit: draft.submit,
        userReviewed: draft.userReviewed,
      );
      await repository.save(snapshot);
      return snapshot;
    },
        draft.submit
            ? 'fieldTime.reimbursementSubmitted'
            : 'fieldTime.draftSaved');
  }

  Future<void> updateReceipt(
    Receipt receipt,
    ReceiptDraft draft,
    XFile? file,
  ) async {
    await _run('fieldTime.saveReceiptProgress', () async {
      if (receipt.status != ReceiptStatus.draft) {
        throw StateError('receipts.onlyDraftCanBeEdited');
      }

      final snapshot = state.snapshot;
      final now = DateTime.now();
      final nextStatus =
          draft.submit ? ReceiptStatus.submitted : ReceiptStatus.draft;
      Attachment? replacementAttachment;
      if (file != null) {
        replacementAttachment =
            await _attachment(file, draft.job, AttachmentKind.receipt);
      }
      final attachmentIds = replacementAttachment == null
          ? receipt.attachmentIds
          : [replacementAttachment.id];

      final updatedReceipt = Receipt(
        id: receipt.id,
        registrationNumber: receipt.registrationNumber,
        companyId: receipt.companyId,
        subcontractorCompanyId: receipt.subcontractorCompanyId,
        workerId: receipt.workerId,
        jobId: draft.job.id,
        purchaseDate: draft.purchaseDate,
        merchant: draft.merchant.trim(),
        total: draft.total,
        tax: draft.tax,
        receiptNumber: draft.receiptNumber?.trim().isEmpty == true
            ? null
            : draft.receiptNumber?.trim(),
        description: draft.description.trim(),
        notes: draft.notes?.trim().isEmpty == true ? null : draft.notes?.trim(),
        status: nextStatus,
        attachmentIds: attachmentIds,
        extractionResult:
            replacementAttachment == null ? receipt.extractionResult : null,
        userReviewed: draft.userReviewed,
        createdAt: receipt.createdAt,
        updatedAt: now,
      );

      final updatedReimbursements = <ReimbursementRequest>[];
      final changedReimbursementIds = <String>[];
      for (final reimbursement in snapshot.reimbursements) {
        if (!reimbursement.receiptIds.contains(receipt.id)) {
          updatedReimbursements.add(reimbursement);
          continue;
        }
        changedReimbursementIds.add(reimbursement.id);
        updatedReimbursements.add(
          ReimbursementRequest(
            id: reimbursement.id,
            registrationNumber: reimbursement.registrationNumber,
            companyId: reimbursement.companyId,
            subcontractorCompanyId: reimbursement.subcontractorCompanyId,
            workerId: reimbursement.workerId,
            jobId: draft.job.id,
            receiptIds: reimbursement.receiptIds,
            attachmentIds: attachmentIds,
            amount: draft.total,
            status: nextStatus,
            createdAt: reimbursement.createdAt,
            updatedAt: now,
          ),
        );
      }

      final updatedSnapshot = snapshot.copyWith(
        receipts: [
          for (final current in snapshot.receipts)
            if (current.id == receipt.id) updatedReceipt else current,
        ],
        reimbursements: updatedReimbursements,
        attachments: replacementAttachment == null
            ? snapshot.attachments
            : [...snapshot.attachments, replacementAttachment],
        syncQueue: [
          ...snapshot.syncQueue,
          SyncQueueItem(
            id: uuid.v7(),
            companyId: snapshot.companyId,
            subcontractorCompanyId: snapshot.subcontractor.id,
            entityType: 'Receipt',
            entityId: receipt.id,
            operation: SyncOperation.update,
            createdAt: now,
          ),
          for (final reimbursementId in changedReimbursementIds)
            SyncQueueItem(
              id: uuid.v7(),
              companyId: snapshot.companyId,
              subcontractorCompanyId: snapshot.subcontractor.id,
              entityType: 'ReimbursementRequest',
              entityId: reimbursementId,
              operation: SyncOperation.update,
              createdAt: now,
            ),
        ],
      );
      await repository.save(updatedSnapshot);
      return updatedSnapshot;
    },
        draft.submit
            ? 'fieldTime.reimbursementSubmitted'
            : 'fieldTime.draftSaved');
  }

  Future<void> addObservation(String notes) async {
    await _run('fieldTime.saveObservationProgress', () async {
      final snapshot = service.addObservation(
        snapshot: state.snapshot,
        notes: notes,
        at: DateTime.now(),
      );
      await repository.save(snapshot);
      return snapshot;
    }, 'fieldTime.observationAdded');
  }

  Future<void> _withLocation({
    required String progress,
    required String success,
    Map<String, Object?>? successValues,
    required FieldTimeSnapshot Function(
      FieldTimeSnapshot snapshot,
      DateTime at,
      GeoPoint location,
    ) mutate,
    bool rememberCompletedDay = false,
  }) async {
    state = FieldTimeState(
        snapshot: state.snapshot, loading: true, message: progress);
    try {
      final location = await locationService.currentLocation();
      final snapshot = mutate(state.snapshot, DateTime.now(), location);
      await repository.save(snapshot);
      state = FieldTimeState(
        snapshot: snapshot,
        message: success,
        messageValues: successValues,
        lastLocation: location,
        lastCompletedDay: rememberCompletedDay ? snapshot.workDays.last : null,
      );
    } on StateError catch (error) {
      state = FieldTimeState(snapshot: state.snapshot, error: error.message);
    } on Exception {
      state = FieldTimeState(
        snapshot: state.snapshot,
        error: 'fieldTime.operationFailed',
      );
    }
  }

  Future<void> _run(
    String progress,
    Future<FieldTimeSnapshot> Function() action,
    String success, {
    Map<String, Object?>? successValues,
  }) async {
    state = FieldTimeState(
        snapshot: state.snapshot, loading: true, message: progress);
    try {
      final snapshot = await action();
      state = FieldTimeState(
        snapshot: snapshot,
        message: success,
        messageValues: successValues,
      );
    } on StateError catch (error) {
      state = FieldTimeState(snapshot: state.snapshot, error: error.message);
    } on Exception {
      state = FieldTimeState(
        snapshot: state.snapshot,
        error: 'fieldTime.deviceSaveFailed',
      );
    }
  }

  Future<Attachment> _attachment(
    XFile file,
    Job job,
    AttachmentKind kind,
  ) async {
    final bytes = await file.readAsBytes();
    return Attachment(
      id: uuid.v7(),
      companyId: state.snapshot.companyId,
      subcontractorCompanyId: state.snapshot.subcontractor.id,
      workerId: state.snapshot.worker.id,
      jobId: job.id,
      kind: kind,
      fileName: file.name,
      mimeType: file.mimeType ?? _mimeType(file.name),
      dataBase64: base64Encode(bytes),
      createdAt: DateTime.now(),
    );
  }

  String _mimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
