import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/status_chip.dart';
import '../../../core/design/widgets/swipe_to_confirm_slider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../domain/entities/app_config.dart';
import '../../../domain/entities/order.dart';
import '../widgets/otp_verification_grid.dart';

class TaskDetailScreen extends StatefulWidget {
  final Order order;
  const TaskDetailScreen({super.key, required this.order});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  // State to track checked items during packing
  final Map<String, bool> _checkedItems = {};

  @override
  void initState() {
    super.initState();
    for (var item in widget.order.items) {
      _checkedItems[item.productId] = false;
    }
  }

  Future<void> _launchMap(double lat, double lng) async {
    final urls = [
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
      Uri.parse('http://maps.apple.com/?q=$lat,$lng'),
    ];
    for (final uri in urls) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
  }

  Future<void> _callCustomer(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\s+|-'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _getNextStatusText(String status) {
    switch (status) {
      case 'assigned':
        return 'SWIPE TO PICK UP ITEMS';
      case 'picked_up':
        return 'SWIPE TO START DELIVERY';
      case 'out_for_delivery':
        return 'SWIPE TO VERIFY & DELIVER';
      default:
        return 'DELIVERY COMPLETED';
    }
  }

  String _getNextStatusValue(String status) {
    switch (status) {
      case 'assigned':
        return 'picked_up';
      case 'picked_up':
        return 'out_for_delivery';
      default:
        return 'delivered';
    }
  }

  void _showOtpVerification(BuildContext context, OrderProvider orderProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return OtpVerificationGrid(
          orderId: widget.order.id,
          onSuccess: () {
            Navigator.pop(dialogContext); // Close dialog
            Navigator.pop(context); // Go back to Home Tasks
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Order delivered successfully!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: AppTokens.statusDelivered,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final scheme = Theme.of(context).colorScheme;
    final nextStatus = _getNextStatusValue(widget.order.status);
    final nextColor = AppTokens.statusColor(nextStatus);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Order #${widget.order.id.substring(0, 6).toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Delivery Status',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    StatusChip(status: widget.order.status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Customer Details Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_pin_rounded, color: scheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Customer Details',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      widget.order.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${widget.order.deliveryAddress}, ${widget.order.village}',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (widget.order.latitude != null && widget.order.longitude != null) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.navigation_rounded, size: 18),
                              label: const Text('NAVIGATE', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: scheme.primary.withValues(alpha: 0.1),
                                foregroundColor: scheme.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTokens.rSm),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => _launchMap(widget.order.latitude!, widget.order.longitude!),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.call_rounded, size: 18),
                            label: const Text('CALL CUSTOMER', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade50,
                              foregroundColor: Colors.orange.shade800,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTokens.rSm),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => _callCustomer(widget.order.customerPhone),
                          ),
                        ),
                      ],
                    ),
                    const _ContactDispatchButton(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // COD Collection Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                side: BorderSide(color: AppTokens.statusDelivered.withValues(alpha: 0.2)),
              ),
              color: AppTokens.statusDelivered.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppTokens.statusDelivered,
                      radius: 18,
                      child: Icon(Icons.currency_rupee_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cash to Collect (COD)',
                          style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${widget.order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppTokens.statusDelivered,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items Checklist Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.fact_check_outlined, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Items Checklist',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        Text(
                          '${widget.order.items.length} items',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Verify and check off all items before departing:',
                      style: TextStyle(color: Colors.black54, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.order.items.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
                      itemBuilder: (context, idx) {
                        final item = widget.order.items[idx];
                        final isChecked = _checkedItems[item.productId] ?? false;

                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              decoration: isChecked ? TextDecoration.lineThrough : null,
                              color: isChecked ? Colors.grey : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Quantity: ${item.quantity}  •  ₹${item.price.toStringAsFixed(1)} / unit',
                            style: TextStyle(
                              fontSize: 12,
                              color: isChecked ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          value: isChecked,
                          activeColor: scheme.primary,
                          onChanged: (val) {
                            setState(() {
                              _checkedItems[item.productId] = val ?? false;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 100), // Extra space for swipe slider
          ],
        ),
      ),
      bottomSheet: widget.order.status != 'delivered' && widget.order.status != 'cancelled'
          ? Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: SafeArea(
                child: SwipeToConfirmSlider(
                  text: _getNextStatusText(widget.order.status),
                  color: nextColor,
                  onSwipeCompleted: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    if (nextStatus == 'delivered') {
                      _showOtpVerification(context, orderProvider);
                    } else {
                      await orderProvider.updateStatus(widget.order.id, nextStatus);
                      navigator.pop(); // Return to list view
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Status updated to: ${nextStatus.toUpperCase()}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: nextColor,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ),
            )
          : null,
    );
  }
}

/// Tap-to-call action for riders to reach dispatch/admin support directly
/// from the task screen. Hidden when the admin hasn't set a support phone
/// number in Store Settings.
class _ContactDispatchButton extends StatelessWidget {
  const _ContactDispatchButton();

  Future<void> _callSupport(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfig>(
      stream: Provider.of<ConfigProvider>(context, listen: false).streamAppConfig(),
      builder: (context, snapshot) {
        final phone = snapshot.data?.supportPhone;
        if (phone == null || phone.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _callSupport(phone),
              icon: const Icon(Icons.support_agent_rounded, size: 16),
              label: const Text('Contact Dispatch', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }
}
