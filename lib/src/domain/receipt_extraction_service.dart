import 'package:jkdd_field_time_records_production/src/domain/field_time_models.dart';

/// Contract for a future OCR/Vision provider.
///
/// Implementations may use OpenAI Vision, Google ML Kit, or another provider.
/// Extracted values are suggestions only and must never approve a receipt.
abstract interface class ReceiptExtractionService {
  Future<ReceiptExtractionResult> extract({
    required String receiptId,
    required String companyId,
    required String subcontractorCompanyId,
    required Attachment attachment,
  });
}

final class MockReceiptExtractionService implements ReceiptExtractionService {
  const MockReceiptExtractionService();

  @override
  Future<ReceiptExtractionResult> extract({
    required String receiptId,
    required String companyId,
    required String subcontractorCompanyId,
    required Attachment attachment,
  }) async =>
      ReceiptExtractionResult(
        id: 'mock-$receiptId',
        companyId: companyId,
        subcontractorCompanyId: subcontractorCompanyId,
        receiptId: receiptId,
        message:
            'Leitura automatica ainda nao integrada. Revise e preencha os campos.',
        createdAt: DateTime.now(),
      );
}
