import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/app_tokens.dart';
import '../../../../core/providers/support_provider.dart';
import '../../../../core/utils/route_generator.dart';
import '../../../../domain/entities/support_ticket.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  String _selectedFilter = 'all'; // 'all', 'open', 'in_progress', 'resolved'

  Future<void> _callCustomer(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsappCustomer(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final support = Provider.of<SupportProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Customer Support Desk',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // 1. Status Filter Header
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Tickets'),
                  const SizedBox(width: 8),
                  _buildFilterChip('open', 'Open'),
                  const SizedBox(width: 8),
                  _buildFilterChip('in_progress', 'In Progress'),
                  const SizedBox(width: 8),
                  _buildFilterChip('resolved', 'Resolved'),
                ],
              ),
            ),
          ),

          // 2. Stream of Tickets
          Expanded(
            child: StreamBuilder<List<SupportTicket>>(
              stream: support.streamAllTickets(status: _selectedFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: AppTokens.primary));
                }

                final tickets = snapshot.data ?? [];
                if (tickets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mark_email_read_outlined, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                          'No ${_selectedFilter == 'all' ? '' : _selectedFilter.replaceAll('_', ' ')} tickets found.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All customer queries in this category are addressed!',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return _buildAdminTicketCard(ticket, support);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = value);
      },
      selectedColor: AppTokens.primary,
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    );
  }

  Widget _buildAdminTicketCard(SupportTicket ticket, SupportProvider support) {
    final isUnread = ticket.unreadAdminCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.rXl),
        border: Border.all(
          color: isUnread ? AppTokens.primary : Theme.of(context).colorScheme.outlineVariant,
          width: isUnread ? 1.5 : 1.0,
        ),
        boxShadow: AppTokens.shadowSm(Theme.of(context).colorScheme.onSurface),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.rXl),
          onTap: () {
            Navigator.pushNamed(
              context,
              RouteGenerator.supportChat,
              arguments: ticket,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTokens.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppTokens.rMd),
                          ),
                          child: Text(
                            ticket.category,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTokens.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${ticket.id.substring(0, ticket.id.length < 6 ? ticket.id.length : 6).toUpperCase()}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    _buildStatusBadge(ticket.status),
                  ],
                ),
                const SizedBox(height: 10),

                // Subject
                Text(
                  ticket.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 4),

                // Customer Info Row
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        ticket.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (ticket.customerPhone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${ticket.customerPhone})',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),

                if (ticket.orderId != null && ticket.orderId!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 14, color: AppTokens.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Order #${ticket.orderId!.substring(0, ticket.orderId!.length < 6 ? ticket.orderId!.length : 6).toUpperCase()}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTokens.primary),
                      ),
                    ],
                  ),
                ],

                if (ticket.lastMessage.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ticket.lastMessage,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Actions Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(AppTokens.rPill),
                        ),
                        child: Text(
                          '${ticket.unreadAdminCount} New Customer Message${ticket.unreadAdminCount > 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onError, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      Text(
                        _formatDate(ticket.updatedAt),
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),

                    Row(
                      children: [
                        if (ticket.customerPhone.isNotEmpty) ...[
                          IconButton(
                            icon: const Icon(Icons.call_rounded, color: AppTokens.primary, size: 20),
                            tooltip: 'Call Customer',
                            onPressed: () => _callCustomer(ticket.customerPhone),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 20),
                            tooltip: 'WhatsApp Customer',
                            onPressed: () => _whatsappCustomer(ticket.customerPhone),
                          ),
                        ],
                        const SizedBox(width: 4),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              RouteGenerator.supportChat,
                              arguments: ticket,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTokens.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
                          ),
                          icon: const Icon(Icons.reply_rounded, size: 16),
                          label: const Text('Open Desk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month} ${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }
}
