import '../entities/support_ticket.dart';

abstract class SupportRepository {
  /// Creates a new support ticket and sends the first message.
  /// Returns the newly generated ticket ID.
  Future<String> createTicket({
    required SupportTicket ticket,
    required String initialMessage,
    String? imageUrl,
  });

  /// Streams real-time tickets for a given customer.
  Stream<List<SupportTicket>> streamCustomerTickets(String customerId);

  /// Streams all support tickets for admin operations, optionally filtered by status.
  Stream<List<SupportTicket>> streamAllTickets({String? status, int limit = 100});

  /// Streams a single support ticket by ID.
  Stream<SupportTicket> streamTicket(String ticketId);

  /// Streams all messages within a specific support ticket.
  Stream<List<SupportMessage>> streamMessages(String ticketId);

  /// Appends a new message to a ticket thread.
  Future<void> sendMessage({
    required String ticketId,
    required SupportMessage message,
  });

  /// Updates ticket status (e.g. 'open', 'in_progress', 'resolved', 'closed').
  Future<void> updateTicketStatus({
    required String ticketId,
    required String status,
  });

  /// Marks messages as read by the current viewer.
  Future<void> markMessagesAsRead({
    required String ticketId,
    required bool isAdmin,
  });
}
