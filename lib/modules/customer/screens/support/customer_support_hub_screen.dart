import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/app_tokens.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/config_provider.dart';
import '../../../../core/providers/order_provider.dart';
import '../../../../core/providers/support_provider.dart';
import '../../../../core/utils/route_generator.dart';
import '../../../../domain/entities/app_config.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/support_ticket.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/date_format.dart';

class CustomerSupportHubScreen extends StatefulWidget {
  final String? initialOrderId;

  const CustomerSupportHubScreen({
    super.key,
    this.initialOrderId,
  });

  @override
  State<CustomerSupportHubScreen> createState() => _CustomerSupportHubScreenState();
}

class _CustomerSupportHubScreenState extends State<CustomerSupportHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // If navigated with a pre-linked order ID, automatically open the ticket creator
    if (widget.initialOrderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRaiseTicketModal(preselectedOrderId: widget.initialOrderId);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String number) async {
    final clean = number.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$clean?text=Hello%20JC%20Mart%20Support');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showRaiseTicketModal({String? preselectedOrderId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RaiseTicketSheet(initialOrderId: preselectedOrderId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUserModel;
    final configProvider = Provider.of<ConfigProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Help & Support Hub',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTokens.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: AppTokens.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Help & FAQs'),
            Tab(text: 'My Tickets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: FAQs & Quick Channels
          _buildFaqAndHotlinesTab(configProvider),

          // Tab 2: My Support Tickets
          user != null
              ? _buildMyTicketsTab(user.uid)
              : const Center(child: Text('Sign in to view your support tickets')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRaiseTicketModal(),
        backgroundColor: AppTokens.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Raise Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFaqAndHotlinesTab(ConfigProvider configProvider) {
    return StreamBuilder<AppConfig>(
      stream: configProvider.streamAppConfig(),
      builder: (context, snapshot) {
        final config = snapshot.data;
        final phone = config?.supportPhone ?? '+919876543210';
        final whatsapp = config?.supportWhatsapp ?? '+919876543210';

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // 1. Direct Contact Channels Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF16A34A), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTokens.rXl),
                boxShadow: AppTokens.shadowMd(AppTokens.primary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.headset_mic_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Immediate Assistance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Our Bhimavaram support desk is live daily from 6:00 AM to 11:00 PM.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _callPhone(phone),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTokens.primary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
                          ),
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text('Call Hotline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openWhatsApp(whatsapp),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
                          ),
                          icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                          label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. FAQ Section Header
            Row(
              children: [
                const Icon(Icons.help_outline_rounded, size: 18, color: AppTokens.primary),
                const SizedBox(width: 6),
                Text(
                  'FREQUENTLY ASKED QUESTIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. FAQ Accordion Items
            _buildFaqTile(
              question: 'How fast is the 20-minute delivery promise?',
              answer:
                  'We dispatch orders from our local Bhimavaram micro-hub. Orders placed within active service hours are packed in under 3 minutes and routed to our nearest on-duty rider.',
            ),
            _buildFaqTile(
              question: 'Can I cancel my order after placing it?',
              answer:
                  'Yes! You can cancel anytime while the order is in "Order Placed" or "Rider Assigned" status from the Order Tracking screen. Any reserved stock is released immediately.',
            ),
            _buildFaqTile(
              question: 'What if an item is missing or damaged?',
              answer:
                  'Simply tap "Raise Ticket" below, select "Item Missing/Damaged", link your order, and attach a photo. Our support staff will immediately arrange a free replacement or instant COD refund credit.',
            ),
            _buildFaqTile(
              question: 'How does Cash on Delivery (COD) work?',
              answer:
                  'You pay the rider in cash when your order arrives. Share your 4-digit delivery OTP with the rider once you have checked the items.',
            ),
            _buildFaqTile(
              question: 'Which villages and areas are covered?',
              answer:
                  'We actively serve Bhimavaram, Veeravasaram, Rayakuduru, Srungavruksham, and Mentada within our dedicated logistics radius.',
            ),

            const SizedBox(height: 80), // Fab padding
          ],
        );
      },
    );
  }

  Widget _buildFaqTile({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTokens.rLg),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
            iconColor: AppTokens.primary,
            collapsedIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            title: Text(
              question,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Theme.of(context).colorScheme.onSurface),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                answer,
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTicketsTab(String customerId) {
    final support = Provider.of<SupportProvider>(context);

    return StreamBuilder<List<SupportTicket>>(
      stream: support.streamCustomerTickets(customerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tickets = snapshot.data ?? [];
        if (tickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.support_agent_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                const Text(
                  'No Support Tickets Yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Have an issue with an order? Tap below to raise a ticket.',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tickets.length + 1,
          itemBuilder: (context, index) {
            if (index == tickets.length) return const SizedBox(height: 80);
            final ticket = tickets[index];
            return _buildTicketCard(ticket);
          },
        );
      },
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    final isUnread = ticket.unreadCustomerCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.rXl),
        border: Border.all(
          color: isUnread ? AppTokens.primary.withValues(alpha: 0.5) : Theme.of(context).colorScheme.outlineVariant,
          width: isUnread ? 1.5 : 1.0,
        ),
        boxShadow: AppTokens.shadowSm(Colors.black),
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
                        _buildCategoryBadge(ticket.category),
                        const SizedBox(width: 8),
                        Text(
                          '#${ticket.id.substring(0, ticket.id.length < 6 ? ticket.id.length : 6).toUpperCase()}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    _buildStatusChip(ticket.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ticket.subject,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ticket.lastMessage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    ticket.lastMessage,
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(ticket.updatedAt),
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    if (isUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTokens.primary,
                          borderRadius: BorderRadius.circular(AppTokens.rPill),
                        ),
                        child: Text(
                          '${ticket.unreadCustomerCount} New',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      const Row(
                        children: [
                          Text('Open Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTokens.primary)),
                          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTokens.primary),
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

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTokens.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.rMd),
      ),
      child: Text(
        category,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTokens.primary),
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

  String _formatDate(DateTime dt) => formatDateTime(dt);
}

class _RaiseTicketSheet extends StatefulWidget {
  final String? initialOrderId;

  const _RaiseTicketSheet({this.initialOrderId});

  @override
  State<_RaiseTicketSheet> createState() => _RaiseTicketSheetState();
}

class _RaiseTicketSheetState extends State<_RaiseTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedCategory = 'Order Issue';
  String? _selectedOrderId;
  File? _attachment;

  final List<String> _categories = [
    'Order Issue',
    'Delivery Delay',
    'Item Missing/Damaged',
    'Payment & Refund',
    'Product Quality',
    'General Inquiry',
  ];

  @override
  void initState() {
    super.initState();
    _selectedOrderId = widget.initialOrderId;
    if (_selectedOrderId != null) {
      _subjectController.text = 'Issue with Order #${_selectedOrderId!.substring(0, _selectedOrderId!.length < 6 ? _selectedOrderId!.length : 6).toUpperCase()}';
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (file != null) {
        setState(() {
          _attachment = File(file.path);
        });
      }
    } catch (_) {}
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUserModel;
    if (user == null) return;

    final support = Provider.of<SupportProvider>(context, listen: false);
    // Captured before the sheet is popped — showing a SnackBar via the
    // sheet's own (defunct) context afterwards silently no-ops.
    final messenger = ScaffoldMessenger.of(context);

    final ticketId = await support.createTicket(
      customerId: user.uid,
      customerName: user.name.isNotEmpty ? user.name : 'Customer',
      customerPhone: user.phone,
      orderId: _selectedOrderId,
      subject: _subjectController.text.trim(),
      category: _selectedCategory,
      message: _messageController.text.trim(),
      attachment: _attachment,
    );

    if (ticketId != null && mounted) {
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Support ticket raised successfully!'),
          backgroundColor: AppTokens.statusDelivered,
        ),
      );
    } else if (mounted && support.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(support.errorMessage!),
          backgroundColor: AppTokens.statusCancelled,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final support = Provider.of<SupportProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final customerId = auth.currentUserModel?.uid ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.rXl)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Raise Support Ticket',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Category Dropdown
                  const Text('Issue Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.rLg)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Optional Link Order Dropdown
                  const Text('Link to an Order (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  StreamBuilder<List<Order>>(
                    stream: orderProvider.streamCustomerOrders(customerId),
                    builder: (context, snapshot) {
                      final orders = snapshot.data ?? [];
                      return DropdownButtonFormField<String?>(
                        initialValue: _selectedOrderId,
                        decoration: InputDecoration(
                          hintText: 'Select an order...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.rLg)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('None (General Inquiry)')),
                          ...orders.take(10).map((o) => DropdownMenuItem<String?>(
                                value: o.id,
                                child: Text('#${o.id.substring(0, o.id.length < 6 ? o.id.length : 6).toUpperCase()} · ${formatRupees(o.totalAmount)} · ${o.status.toUpperCase()}'),
                              )),
                        ],
                        onChanged: (val) => setState(() => _selectedOrderId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Subject
                  const Text('Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      hintText: 'Brief summary of your issue',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.rLg)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a subject' : null,
                  ),
                  const SizedBox(height: 16),

                  // Message Description
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Explain the issue in detail so we can help quickly...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.rLg)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe your issue' : null,
                  ),
                  const SizedBox(height: 16),

                  // Optional Image Attachment
                  const Text('Attach Photo (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (_attachment != null)
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTokens.rMd),
                          child: Image.file(_attachment!, width: 64, height: 64, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () => setState(() => _attachment = null),
                          icon: const Icon(Icons.delete, color: AppTokens.statusCancelled),
                          label: const Text('Remove Photo', style: TextStyle(color: AppTokens.statusCancelled)),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Camera'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Submit Action Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: support.isLoading ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTokens.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rLg)),
                ),
                child: support.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Ticket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
