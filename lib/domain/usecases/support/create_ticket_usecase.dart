import '../../entities/support_ticket.dart';
import '../../repositories/support_repository.dart';

class CreateTicketUseCase {
  final SupportRepository _repository;

  CreateTicketUseCase(this._repository);

  Future<String> call({
    required SupportTicket ticket,
    required String initialMessage,
    String? imageUrl,
  }) {
    return _repository.createTicket(
      ticket: ticket,
      initialMessage: initialMessage,
      imageUrl: imageUrl,
    );
  }
}
