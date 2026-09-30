import '../../entities/support_ticket.dart';
import '../../repositories/support_repository.dart';

class SendSupportMessageUseCase {
  final SupportRepository _repository;

  SendSupportMessageUseCase(this._repository);

  Future<void> call({
    required String ticketId,
    required SupportMessage message,
  }) {
    return _repository.sendMessage(
      ticketId: ticketId,
      message: message,
    );
  }
}
