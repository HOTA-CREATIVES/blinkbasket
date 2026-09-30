enum TicketStatus {
  open,
  inProgress,
  resolved,
  closed,
}

enum TicketPriority {
  low,
  medium,
  high,
  urgent,
}

class SupportTicket {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? orderId;
  final String subject;
  final String category;
  final String status; // 'open', 'in_progress', 'resolved', 'closed'
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastMessage;
  final int unreadCustomerCount;
  final int unreadAdminCount;

  const SupportTicket({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.orderId,
    required this.subject,
    required this.category,
    this.status = 'open',
    this.priority = 'medium',
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage = '',
    this.unreadCustomerCount = 0,
    this.unreadAdminCount = 0,
  });

  bool get isOpen => status == 'open' || status == 'in_progress';
  bool get isResolved => status == 'resolved' || status == 'closed';

  SupportTicket copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? orderId,
    String? subject,
    String? category,
    String? status,
    String? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    int? unreadCustomerCount,
    int? unreadAdminCount,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      orderId: orderId ?? this.orderId,
      subject: subject ?? this.subject,
      category: category ?? this.category,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCustomerCount: unreadCustomerCount ?? this.unreadCustomerCount,
      unreadAdminCount: unreadAdminCount ?? this.unreadAdminCount,
    );
  }
}

class SupportMessage {
  final String id;
  final String ticketId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'customer', 'admin', 'system'
  final String message;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isRead;

  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    this.imageUrl,
    required this.timestamp,
    this.isRead = false,
  });

  bool get isFromCustomer => senderRole == 'customer';
  bool get isFromAdmin => senderRole == 'admin';
  bool get isSystem => senderRole == 'system';
}
