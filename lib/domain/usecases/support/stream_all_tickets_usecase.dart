import '../../entities/support_ticket.dart';
import '../../repositories/support_repository.dart';

class StreamAllTicketsUseCase {
  final SupportRepository _repository;

  StreamAllTicketsUseCase(this._repository);

  Stream<List<SupportTicket>> call({String? status, int limit = 100}) {
    return _repository.streamAllTickets(status: status, limit: limit);
  }
}
