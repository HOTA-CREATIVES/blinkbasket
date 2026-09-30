import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/support_ticket.dart';

class SupportTicketDto {
  static SupportTicket fromMap(Map<String, dynamic> map, String id) {
    return SupportTicket(
      id: id,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      customerPhone: map['customerPhone'] as String? ?? '',
      orderId: map['orderId'] as String?,
      subject: map['subject'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      status: map['status'] as String? ?? 'open',
      priority: map['priority'] as String? ?? 'medium',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      lastMessage: map['lastMessage'] as String? ?? '',
      unreadCustomerCount: (map['unreadCustomerCount'] as num?)?.toInt() ?? 0,
      unreadAdminCount: (map['unreadAdminCount'] as num?)?.toInt() ?? 0,
    );
  }

  static Map<String, dynamic> toMap(SupportTicket ticket) {
    return {
      'customerId': ticket.customerId,
      'customerName': ticket.customerName,
      'customerPhone': ticket.customerPhone,
      if (ticket.orderId != null) 'orderId': ticket.orderId,
      'subject': ticket.subject,
      'category': ticket.category,
      'status': ticket.status,
      'priority': ticket.priority,
      'createdAt': Timestamp.fromDate(ticket.createdAt),
      'updatedAt': Timestamp.fromDate(ticket.updatedAt),
      'lastMessage': ticket.lastMessage,
      'unreadCustomerCount': ticket.unreadCustomerCount,
      'unreadAdminCount': ticket.unreadAdminCount,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}

class SupportMessageDto {
  static SupportMessage fromMap(Map<String, dynamic> map, String id) {
    return SupportMessage(
      id: id,
      ticketId: map['ticketId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      senderRole: map['senderRole'] as String? ?? 'customer',
      message: map['message'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      timestamp: _parseDateTime(map['timestamp']),
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> toMap(SupportMessage msg) {
    return {
      'ticketId': msg.ticketId,
      'senderId': msg.senderId,
      'senderName': msg.senderName,
      'senderRole': msg.senderRole,
      'message': msg.message,
      if (msg.imageUrl != null) 'imageUrl': msg.imageUrl,
      'timestamp': Timestamp.fromDate(msg.timestamp),
      'isRead': msg.isRead,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
