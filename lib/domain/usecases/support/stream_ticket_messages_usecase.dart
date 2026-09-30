import '../../entities/support_ticket.dart';
import '../../repositories/support_repository.dart';

class StreamTicketMessagesUseCase {
  final SupportRepository _repository;

  StreamTicketMessagesUseCase(this._repository);

  Stream<List<SupportMessage>> call(String ticketId) {
    return _repository.streamMessages(ticketId);
  }
}
