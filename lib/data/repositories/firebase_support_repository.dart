import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/repositories/support_repository.dart';
import '../models/support_ticket_dto.dart';

class FirebaseSupportRepository implements SupportRepository {
  final FirebaseFirestore _firestore;

  FirebaseSupportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ticketsCollection =>
      _firestore.collection('supportTickets');

  @override
  Future<String> createTicket({
    required SupportTicket ticket,
    required String initialMessage,
    String? imageUrl,
  }) async {
    try {
      final now = DateTime.now();
      final docRef = _ticketsCollection.doc();
      final ticketId = docRef.id;

      final newTicket = ticket.copyWith(
        id: ticketId,
        createdAt: now,
        updatedAt: now,
        lastMessage: initialMessage,
        unreadAdminCount: 1,
        unreadCustomerCount: 0,
      );

      final batch = _firestore.batch();
      batch.set(docRef, SupportTicketDto.toMap(newTicket));

      // Initial user message
      final msgDoc = docRef.collection('messages').doc();
      final message = SupportMessage(
        id: msgDoc.id,
        ticketId: ticketId,
        senderId: ticket.customerId,
        senderName: ticket.customerName,
        senderRole: 'customer',
        message: initialMessage,
        imageUrl: imageUrl,
        timestamp: now,
        isRead: false,
      );
      batch.set(msgDoc, SupportMessageDto.toMap(message));

      // Automated system welcome message
      final systemMsgDoc = docRef.collection('messages').doc();
      final systemMsg = SupportMessage(
        id: systemMsgDoc.id,
        ticketId: ticketId,
        senderId: 'system',
        senderName: 'J C Mart Support Bot',
        senderRole: 'system',
        message: 'Hello ${ticket.customerName}! Your ticket has been logged with ID #${ticketId.substring(0, 6).toUpperCase()}. An executive from J C Mart is reviewing your query and will reply shortly.',
        timestamp: now.add(const Duration(milliseconds: 200)),
        isRead: true,
      );
      batch.set(systemMsgDoc, SupportMessageDto.toMap(systemMsg));

      await batch.commit();
      return ticketId;
    } catch (e) {
      debugPrint('Error creating support ticket: $e');
      rethrow;
    }
  }

  @override
  Stream<List<SupportTicket>> streamCustomerTickets(String customerId) {
    return _ticketsCollection
        .where('customerId', isEqualTo: customerId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupportTicketDto.fromMap(doc.data(), doc.id))
            .toList())
        .handleError((error) {
      debugPrint('Error streaming customer tickets: $error');
      return <SupportTicket>[];
    });
  }

  @override
  Stream<List<SupportTicket>> streamAllTickets({String? status, int limit = 100}) {
    Query<Map<String, dynamic>> query = _ticketsCollection;
    if (status != null && status.isNotEmpty && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    return query
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupportTicketDto.fromMap(doc.data(), doc.id))
            .toList())
        .handleError((error) {
      debugPrint('Error streaming all tickets: $error');
      return <SupportTicket>[];
    });
  }

  @override
  Stream<SupportTicket> streamTicket(String ticketId) {
    return _ticketsCollection.doc(ticketId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        throw Exception('Support ticket not found');
      }
      return SupportTicketDto.fromMap(doc.data()!, doc.id);
    });
  }

  @override
  Stream<List<SupportMessage>> streamMessages(String ticketId) {
    return _ticketsCollection
        .doc(ticketId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupportMessageDto.fromMap(doc.data(), doc.id))
            .toList())
        .handleError((error) {
      debugPrint('Error streaming ticket messages: $error');
      return <SupportMessage>[];
    });
  }

  @override
  Future<void> sendMessage({
    required String ticketId,
    required SupportMessage message,
  }) async {
    try {
      final now = DateTime.now();
      final msgDoc = _ticketsCollection.doc(ticketId).collection('messages').doc();

      final batch = _firestore.batch();
      batch.set(msgDoc, SupportMessageDto.toMap(message.copyWith(
        id: msgDoc.id,
        timestamp: now,
      )));

      final ticketUpdate = <String, dynamic>{
        'lastMessage': message.message.isNotEmpty ? message.message : 'Sent an attachment',
        'updatedAt': Timestamp.fromDate(now),
      };

      if (message.isFromAdmin) {
        ticketUpdate['status'] = 'in_progress';
        ticketUpdate['unreadCustomerCount'] = FieldValue.increment(1);
      } else if (message.isFromCustomer) {
        ticketUpdate['unreadAdminCount'] = FieldValue.increment(1);
      }

      batch.update(_ticketsCollection.doc(ticketId), ticketUpdate);
      await batch.commit();
    } catch (e) {
      debugPrint('Error sending support message: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateTicketStatus({
    required String ticketId,
    required String status,
  }) async {
    try {
      await _ticketsCollection.doc(ticketId).update({
        'status': status,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error updating ticket status: $e');
      rethrow;
    }
  }

  @override
  Future<void> markMessagesAsRead({
    required String ticketId,
    required bool isAdmin,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (isAdmin) {
        updateData['unreadAdminCount'] = 0;
      } else {
        updateData['unreadCustomerCount'] = 0;
      }
      await _ticketsCollection.doc(ticketId).update(updateData);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }
}

extension SupportMessageCopyWith on SupportMessage {
  SupportMessage copyWith({
    String? id,
    String? ticketId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? message,
    String? imageUrl,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return SupportMessage(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      message: message ?? this.message,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
