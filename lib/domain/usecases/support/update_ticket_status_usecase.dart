import '../../repositories/support_repository.dart';

class UpdateTicketStatusUseCase {
  final SupportRepository _repository;

  UpdateTicketStatusUseCase(this._repository);

  Future<void> call({
    required String ticketId,
    required String status,
  }) {
    return _repository.updateTicketStatus(
      ticketId: ticketId,
      status: status,
    );
  }
}
