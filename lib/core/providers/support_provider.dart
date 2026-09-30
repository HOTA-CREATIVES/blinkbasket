import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/repositories/support_repository.dart';
import '../../domain/usecases/support/create_ticket_usecase.dart';
import '../../domain/usecases/support/stream_customer_tickets_usecase.dart';
import '../../domain/usecases/support/stream_all_tickets_usecase.dart';
import '../../domain/usecases/support/stream_ticket_messages_usecase.dart';
import '../../domain/usecases/support/send_support_message_usecase.dart';
import '../../domain/usecases/support/update_ticket_status_usecase.dart';
import '../../data/repositories/firebase_support_repository.dart';
import '../services/cloudinary_service.dart';

class SupportProvider with ChangeNotifier {
  final SupportRepository _repository;
  final CloudinaryService _cloudinaryService;

  late final CreateTicketUseCase _createTicketUseCase;
  late final StreamCustomerTicketsUseCase _streamCustomerTicketsUseCase;
  late final StreamAllTicketsUseCase _streamAllTicketsUseCase;
  late final StreamTicketMessagesUseCase _streamTicketMessagesUseCase;
  late final SendSupportMessageUseCase _sendSupportMessageUseCase;
  late final UpdateTicketStatusUseCase _updateTicketStatusUseCase;

  bool _isLoading = false;
  bool _isUploadingAttachment = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isUploadingAttachment => _isUploadingAttachment;
  String? get errorMessage => _errorMessage;

  SupportProvider({
    SupportRepository? repository,
    CloudinaryService? cloudinaryService,
  })  : _repository = repository ?? FirebaseSupportRepository(),
        _cloudinaryService = cloudinaryService ?? CloudinaryService() {
    _createTicketUseCase = CreateTicketUseCase(_repository);
    _streamCustomerTicketsUseCase = StreamCustomerTicketsUseCase(_repository);
    _streamAllTicketsUseCase = StreamAllTicketsUseCase(_repository);
    _streamTicketMessagesUseCase = StreamTicketMessagesUseCase(_repository);
    _sendSupportMessageUseCase = SendSupportMessageUseCase(_repository);
    _updateTicketStatusUseCase = UpdateTicketStatusUseCase(_repository);
  }

  Stream<List<SupportTicket>> streamCustomerTickets(String customerId) {
    return _streamCustomerTicketsUseCase(customerId);
  }

  Stream<List<SupportTicket>> streamAllTickets({String? status, int limit = 100}) {
    return _streamAllTicketsUseCase(status: status, limit: limit);
  }

  Stream<SupportTicket> streamTicket(String ticketId) {
    return _repository.streamTicket(ticketId);
  }

  Stream<List<SupportMessage>> streamMessages(String ticketId) {
    return _streamTicketMessagesUseCase(ticketId);
  }

  Future<String?> createTicket({
    required String customerId,
    required String customerName,
    required String customerPhone,
    String? orderId,
    required String subject,
    required String category,
    required String message,
    String? priority,
    File? attachment,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? imageUrl;
      if (attachment != null) {
        _isUploadingAttachment = true;
        notifyListeners();
        imageUrl = await _cloudinaryService.uploadImage(attachment);
        _isUploadingAttachment = false;
      }

      final ticket = SupportTicket(
        id: '',
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        orderId: orderId,
        subject: subject,
        category: category,
        status: 'open',
        priority: priority ?? 'medium',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final ticketId = await _createTicketUseCase(
        ticket: ticket,
        initialMessage: message,
        imageUrl: imageUrl,
      );

      _isLoading = false;
      notifyListeners();
      return ticketId;
    } catch (e) {
      _isLoading = false;
      _isUploadingAttachment = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> sendMessage({
    required String ticketId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
    File? attachment,
  }) async {
    if (text.trim().isEmpty && attachment == null) return false;

    _errorMessage = null;
    try {
      String? imageUrl;
      if (attachment != null) {
        _isUploadingAttachment = true;
        notifyListeners();
        imageUrl = await _cloudinaryService.uploadImage(attachment);
        _isUploadingAttachment = false;
      }

      final msg = SupportMessage(
        id: '',
        ticketId: ticketId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        message: text.trim(),
        imageUrl: imageUrl,
        timestamp: DateTime.now(),
      );

      await _sendSupportMessageUseCase(ticketId: ticketId, message: msg);
      notifyListeners();
      return true;
    } catch (e) {
      _isUploadingAttachment = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> updateTicketStatus(String ticketId, String status) async {
    try {
      await _updateTicketStatusUseCase(ticketId: ticketId, status: status);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> markMessagesAsRead(String ticketId, {required bool isAdmin}) async {
    await _repository.markMessagesAsRead(ticketId: ticketId, isAdmin: isAdmin);
  }
}
