import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/design/app_tokens.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/order_provider.dart';
import '../../../../core/providers/support_provider.dart';
import '../../../../core/utils/route_generator.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/support_ticket.dart';
import '../../../../core/utils/app_exception.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/date_format.dart';

class SupportChatScreen extends StatefulWidget {
  final SupportTicket ticket;

  const SupportChatScreen({
    super.key,
    required this.ticket,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocus = FocusNode();
  final ImagePicker _picker = ImagePicker();
  File? _selectedAttachment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isAdmin = auth.currentUserModel?.role == 'admin';
      Provider.of<SupportProvider>(context, listen: false)
          .markMessagesAsRead(widget.ticket.id, isAdmin: isAdmin);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (file != null) {
        setState(() {
          _selectedAttachment = File(file.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessageFor(e, fallback: "Couldn't open the photo library."))),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedAttachment == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUserModel;
    final support = Provider.of<SupportProvider>(context, listen: false);

    final senderId = user?.uid ?? 'guest';
    final senderName = user?.name ?? 'Customer';
    final senderRole = user?.role == 'admin' ? 'admin' : 'customer';

    final attachment = _selectedAttachment;
    _messageController.clear();
    setState(() {
      _selectedAttachment = null;
    });

    try {
      final success = await support.sendMessage(
        ticketId: widget.ticket.id,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        text: text,
        attachment: attachment,
      );

      if (!mounted) return;

      if (success) {
        _scrollToBottom();
      } else if (support.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(support.errorMessage!),
            backgroundColor: AppTokens.statusCancelled,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessageFor(e, fallback: "Couldn't send your message. Please try again.")),
          backgroundColor: AppTokens.statusCancelled,
        ),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleResolveTicket() async {
    final support = Provider.of<SupportProvider>(context, listen: false);
    final newStatus = widget.ticket.isResolved ? 'open' : 'resolved';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rLg)),
        title: Text(
          newStatus == 'resolved' ? 'Resolve Support Ticket?' : 'Reopen Ticket?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          newStatus == 'resolved'
              ? 'Has your query or issue been completely resolved?'
              : 'Would you like to reopen this ticket for further discussion?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'resolved' ? AppTokens.statusDelivered : AppTokens.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(newStatus == 'resolved' ? 'Mark Resolved' : 'Reopen'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await support.updateTicketStatus(widget.ticket.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket status updated to ${newStatus.toUpperCase()}'),
            backgroundColor: newStatus == 'resolved' ? AppTokens.statusDelivered : AppTokens.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final support = Provider.of<SupportProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final currentUid = auth.currentUserModel?.uid;
    final isAdmin = auth.currentUserModel?.role == 'admin';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        titleSpacing: 0,
        title: StreamBuilder<SupportTicket>(
          stream: support.streamTicket(widget.ticket.id),
          initialData: widget.ticket,
          builder: (context, snapshot) {
            final ticket = snapshot.data ?? widget.ticket;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ticket.subject.isNotEmpty ? ticket.subject : 'Support Ticket',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusChip(ticket.status),
                  ],
                ),
                Text(
                  'Ticket #${ticket.id.substring(0, ticket.id.length < 6 ? ticket.id.length : 6).toUpperCase()} · ${ticket.category}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Resolve / Status',
            icon: Icon(
              widget.ticket.isResolved ? Icons.restart_alt_rounded : Icons.check_circle_outline_rounded,
              color: widget.ticket.isResolved ? Colors.orange : AppTokens.statusDelivered,
            ),
            onPressed: _toggleResolveTicket,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Optional Linked Order Banner
          if (widget.ticket.orderId != null && widget.ticket.orderId!.isNotEmpty)
            _buildLinkedOrderBanner(widget.ticket.orderId!),

          // 2. Real-time Messages Feed
          Expanded(
            child: StreamBuilder<List<SupportMessage>>(
              stream: support.streamMessages(widget.ticket.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: AppTokens.primary));
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Send a message below to start.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUid ||
                        (isAdmin && msg.senderRole == 'admin') ||
                        (!isAdmin && msg.senderRole == 'customer');
                    return _buildMessageBubble(msg, isMe, scheme);
                  },
                );
              },
            ),
          ),

          // 3. Quick Suggestion Chips
          _buildQuickActionChips(),

          // 4. Selected Attachment Preview
          if (_selectedAttachment != null) _buildAttachmentPreview(),

          // 5. Message Input Composer
          _buildMessageComposer(support.isUploadingAttachment, scheme),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'resolved':
      case 'closed':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = 'Resolved';
        break;
      case 'in_progress':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = 'In Progress';
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'Open';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.rPill),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildLinkedOrderBanner(String orderId) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    return StreamBuilder<Order>(
      stream: orderProvider.streamOrder(orderId),
      builder: (context, snapshot) {
        final order = snapshot.data;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTokens.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.rMd),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppTokens.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linked Order #${orderId.substring(0, orderId.length < 6 ? orderId.length : 6).toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      order != null
                          ? '${order.items.length} items · ${formatRupees(order.totalAmount)} · ${order.status.toUpperCase()}'
                          : 'Loading order details...',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    RouteGenerator.orderTracking,
                    arguments: orderId,
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(SupportMessage msg, bool isMe, ColorScheme scheme) {
    if (msg.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(AppTokens.rPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  msg.message,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isFromAdmin = msg.senderRole == 'admin';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: isMe ? AppTokens.primary : scheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppTokens.rLg),
            topRight: const Radius.circular(AppTokens.rLg),
            bottomLeft: Radius.circular(isMe ? AppTokens.rLg : 2),
            bottomRight: Radius.circular(isMe ? 2 : AppTokens.rLg),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.senderName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isFromAdmin ? AppTokens.primary : scheme.onSurface,
                    ),
                  ),
                  if (isFromAdmin) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTokens.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'STAFF',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: AppTokens.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            if (!isMe) const SizedBox(height: 3),

            // Image Attachment
            if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                child: CachedNetworkImage(
                  imageUrl: msg.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 160,
                    color: Colors.grey.shade100,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 160,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],

            if (msg.message.isNotEmpty)
              Text(
                msg.message,
                style: TextStyle(
                  color: isMe ? scheme.onPrimary : scheme.onSurface,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTime(msg.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? scheme.onPrimary.withValues(alpha: 0.7) : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChips() {
    final chips = [
      'Where is my delivery?',
      'Need item replacement',
      'Rider contact issue',
      'Refund status',
    ];

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(chips[index], style: const TextStyle(fontSize: 11)),
            backgroundColor: Theme.of(context).colorScheme.surface,
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            onPressed: () {
              // Prefill the composer so the customer can edit/confirm before
              // sending — tapping a chip used to fire the message immediately.
              _messageController.value = TextEditingValue(
                text: chips[index],
                selection:
                    TextSelection.collapsed(offset: chips[index].length),
              );
              _composerFocus.requestFocus();
            },
          );
        },
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            child: Image.file(
              _selectedAttachment!,
              height: 48,
              width: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Photo attached (ready to send)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Tooltip(
            message: 'Remove',
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 20),
              onPressed: () {
                setState(() {
                  _selectedAttachment = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer(bool isUploading, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Tooltip(
              message: 'Attach Photo',
              child: IconButton(
                icon: const Icon(Icons.add_photo_alternate_outlined, color: AppTokens.primary),
                onPressed: () => _showMediaPickerSheet(),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(AppTokens.rPill),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _composerFocus,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppTokens.primary,
                shape: BoxShape.circle,
              ),
              child: isUploading
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : Tooltip(
                      message: 'Send',
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        onPressed: _sendMessage,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaPickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.rXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Attach Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMediaOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAttachment(ImageSource.camera);
                    },
                  ),
                  _buildMediaOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAttachment(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.rLg),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(AppTokens.rLg),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTokens.primary, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) => formatTime(dt);
}
