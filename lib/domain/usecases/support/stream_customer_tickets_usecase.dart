import '../../entities/support_ticket.dart';
import '../../repositories/support_repository.dart';

class StreamCustomerTicketsUseCase {
  final SupportRepository _repository;

  StreamCustomerTicketsUseCase(this._repository);

  Stream<List<SupportTicket>> call(String customerId) {
    return _repository.streamCustomerTickets(customerId);
  }
}
