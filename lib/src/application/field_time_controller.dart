import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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

final jobAssetRepositoryProvider =
    Provider((ref) => const JobAssetRepository());

final fieldTimeControllerProvider =
    StateNotifierProvider<FieldTimeController, FieldTimeState>((ref) {
  final controller = FieldTimeController(
    repository: ref.watch(fieldTimeRepositoryProvider),
    jobRepository: ref.watch(jobAssetRepositoryProvider),
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
    this.error,
    this.jobsImportMetadata,
    this.jobsImportError,
    this.lastLocation,
    this.lastCompletedDay,
  });

  final FieldTimeSnapshot snapshot;
  final bool loading;
  final String? message;
  final String? error;
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
    required this.service,
    this.locationService = const TimeRecordLocationService(),
    this.uuid = const Uuid(),
  }) : super(FieldTimeState(snapshot: FieldTimeSnapshot.seeded()));

  final FieldTimeRepository repository;
  final JobAssetRepository jobRepository;
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
    state = FieldTimeState(
      snapshot: snapshot,
      jobsImportMetadata: jobsImportMetadata,
      jobsImportError: jobsImportError,
      message: 'Dados locais carregados.',
    );
  }

  Future<void> clockIn(Job job, String? notes) => _withLocation(
        progress: 'Registrando entrada...',
        success: 'Entrada registrada em ${job.number}.',
        mutate: (snapshot, at, location) => service.clockIn(
          snapshot: snapshot,
          job: job,
          at: at,
          location: location,
          notes: notes,
        ),
      );

  Future<void> switchJob(Job job, String? notes) => _withLocation(
        progress: 'Trocando obra...',
        success: 'Novo periodo iniciado em ${job.number}.',
        mutate: (snapshot, at, location) => service.switchJob(
          snapshot: snapshot,
          nextJob: job,
          at: at,
          location: location,
          notes: notes,
        ),
      );

  Future<void> endDay(String? notes) => _withLocation(
        progress: 'Encerrando o dia...',
        success: 'Expediente encerrado.',
        rememberCompletedDay: true,
        mutate: (snapshot, at, location) => service.endDay(
          snapshot: snapshot,
          at: at,
          location: location,
          notes: notes,
        ),
      );

  Future<void> addJobPhoto(XFile file, Job job) async {
    await _run('Salvando foto...', () async {
      final attachment = await _attachment(file, job, AttachmentKind.jobPhoto);
      final snapshot = service.addJobPhoto(
        snapshot: state.snapshot,
        attachment: attachment,
      );
      await repository.save(snapshot);
      return snapshot;
    }, 'Foto vinculada a obra ${job.number}.');
  }

  Future<void> saveReceipt(ReceiptDraft draft, XFile file) async {
    await _run('Salvando recibo...', () async {
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
    }, draft.submit ? 'Reembolso enviado para aprovacao.' : 'Rascunho salvo.');
  }

  Future<void> addObservation(String notes) async {
    await _run('Salvando observacao...', () async {
      final snapshot = service.addObservation(
        snapshot: state.snapshot,
        notes: notes,
        at: DateTime.now(),
      );
      await repository.save(snapshot);
      return snapshot;
    }, 'Observacao adicionada ao periodo atual.');
  }

  Future<void> _withLocation({
    required String progress,
    required String success,
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
        lastLocation: location,
        lastCompletedDay: rememberCompletedDay ? snapshot.workDays.last : null,
      );
    } on StateError catch (error) {
      state = FieldTimeState(snapshot: state.snapshot, error: error.message);
    } on Exception {
      state = FieldTimeState(
        snapshot: state.snapshot,
        error: 'Nao foi possivel concluir a operacao.',
      );
    }
  }

  Future<void> _run(
    String progress,
    Future<FieldTimeSnapshot> Function() action,
    String success,
  ) async {
    state = FieldTimeState(
        snapshot: state.snapshot, loading: true, message: progress);
    try {
      final snapshot = await action();
      state = FieldTimeState(snapshot: snapshot, message: success);
    } on StateError catch (error) {
      state = FieldTimeState(snapshot: state.snapshot, error: error.message);
    } on Exception {
      state = FieldTimeState(
        snapshot: state.snapshot,
        error: 'Nao foi possivel salvar os dados no dispositivo.',
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
