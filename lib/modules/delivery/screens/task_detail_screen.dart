import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/status_chip.dart';
import '../../../core/design/widgets/swipe_to_confirm_slider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../domain/entities/app_config.dart';
import '../../../domain/entities/order.dart';
import '../widgets/otp_verification_grid.dart';

/// Statuses where this order is actually assigned to the viewing rider and
/// the swipe-to-advance slider makes sense. A still-'pending' order reaching
/// this screen (e.g. a stale broadcast notification) has no rider action
/// here — accepting happens from the home Tasks tab's incoming-offers feed.
const _kAssignedStatuses = {'assigned', 'picked_up', 'out_for_delivery'};

/// Live wrapper: the screen used to render the order snapshot it was opened
/// with, so a customer/admin cancellation (or any status change) while the
/// rider was on it left stale swipe controls. The body below is rebuilt with
/// the latest order on every Firestore update.
class TaskDetailScreen extends StatefulWidget {
  final Order order;
  const TaskDetailScreen({super.key, required this.order});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenLiveState();
}

class _TaskDetailScreenLiveState extends State<TaskDetailScreen> {
  late final Stream<Order> _orderStream = Provider.of<OrderProvider>(
    context,
    listen: false,
  ).streamOrder(widget.order.id);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Order>(
      stream: _orderStream,
      initialData: widget.order,
      builder:
          (context, snapshot) =>
              _TaskDetailBody(order: snapshot.data ?? widget.order),
    );
  }
}

class _TaskDetailBody extends StatefulWidget {
  final Order order;
  const _TaskDetailBody({required this.order});

  @override
  State<_TaskDetailBody> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<_TaskDetailBody> {
  // State to track checked items during packing
  final Map<String, bool> _checkedItems = {};
  bool _isAdvancing = false;

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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open map application')),
      );
    }
  }

  /// Calls or WhatsApps the customer, and says when that isn't possible.
  Future<void> _contactCustomer({required bool whatsApp}) async {
    final messenger = ScaffoldMessenger.of(context);
    final order = widget.order;
    final launcher = ContactLauncher();
    final shortId = order.id.substring(0, 6).toUpperCase();
    final result =
        whatsApp
            ? await launcher.whatsApp(
              order.customerPhone,
              message:
                  "Hi ${order.customerName}, I'm your J C Mart delivery partner "
                  'for order #$shortId.',
            )
            : await launcher.call(order.customerPhone);
    final problem = ContactLauncher.messageFor(
      result,
      what: whatsApp ? 'WhatsApp' : 'the phone app',
    );
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
    }
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

  static const _kDeliveryFailureReasons = [
    'Customer unreachable',
    'Customer refused delivery',
    'Wrong or inaccessible address',
    'Other',
  ];

  /// Escape hatch for an order that can never actually be handed over —
  /// without this, an out-for-delivery order with an unreachable customer
  /// had no way out of that state for the rider (verifyDeliveryOtp is the
  /// only path to 'delivered', and rules only let a rider advance forward).
  void _showReportDeliveryFailure(OrderProvider orderProvider) {
    if (!mounted) return;
    String selectedReason = _kDeliveryFailureReasons.first;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text("Can't Deliver This Order?"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This cancels the order and releases its reserved stock. Pick a reason:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<String>(
                    groupValue: selectedReason,
                    onChanged: (val) {
                      if (!isSubmitting && val != null) {
                        setDialogState(() => selectedReason = val);
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          _kDeliveryFailureReasons
                              .map(
                                (reason) => RadioListTile<String>(
                                  value: reason,
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(
                                    reason,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Back'),
                ),
                ElevatedButton(
                  onPressed:
                      isSubmitting
                          ? null
                          : () async {
                            setDialogState(() => isSubmitting = true);
                            final error = await orderProvider
                                .reportDeliveryFailure(
                                  widget.order.id,
                                  selectedReason,
                                );
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            if (!mounted) return;
                            if (error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  backgroundColor: AppTokens.statusCancelled,
                                ),
                              );
                            } else {
                              Navigator.pop(context); // back to task list
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Order marked undelivered.'),
                                  backgroundColor: AppTokens.statusCancelled,
                                ),
                              );
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.statusCancelled,
                    foregroundColor: Colors.white,
                  ),
                  child:
                      isSubmitting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showOtpVerification(OrderProvider orderProvider) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return OtpVerificationGrid(
          orderId: widget.order.id,
          amountDue: widget.order.totalAmount,
          onSuccess: () {
            Navigator.pop(dialogContext); // Close dialog
            if (!mounted) return;
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

  /// Moves the order to its next status (or opens OTP verification for the
  /// final step). Guarded by [_isAdvancing]: the slider snaps back after a
  /// moment, so without the guard a second swipe during the network call sent
  /// a duplicate update and then reported a spurious failure.
  Future<void> _advance(
    OrderProvider orderProvider,
    String nextStatus,
    Color nextColor,
  ) async {
    if (_isAdvancing) return;
    setState(() => _isAdvancing = true);
    try {
      await _advanceOnce(orderProvider, nextStatus, nextColor);
    } finally {
      if (mounted) setState(() => _isAdvancing = false);
    }
  }

  Future<void> _advanceOnce(
    OrderProvider orderProvider,
    String nextStatus,
    Color nextColor,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (nextStatus == 'delivered') {
      if (!mounted) return;
      _showOtpVerification(orderProvider);
    } else {
      // The item checklist is a pickup step (the rider
      // is in the store) — gate it here, not at the
      // customer's door.
      if (nextStatus == 'picked_up' &&
          _checkedItems.values.any((checked) => !checked)) {
        final proceed = await showDialog<bool>(
          context: context,
          builder:
              (dialogCtx) => AlertDialog(
                title: const Text('Unchecked Items'),
                content: const Text(
                  'Some items in the checklist are not checked off yet. Have you collected all items?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx, false),
                    child: const Text('Review Checklist'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx, true),
                    child: const Text('Pick Up Anyway'),
                  ),
                ],
              ),
        );
        if (proceed != true || !mounted) return;
      }
      // Where the rider is when they take this step, recorded as proof.
      // Best effort and time-boxed: no fix never blocks the update.
      final location = await LocationService.quickFix();
      final err = await orderProvider.advanceStatus(
        widget.order.id,
        nextStatus,
        location: location,
      );
      if (!mounted) return;
      if (err != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      navigator.pop(); // Return to list view
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Status updated to: ${nextStatus.replaceAll("_", " ").toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: nextColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final scheme = Theme.of(context).colorScheme;
    final nextStatus = _getNextStatusValue(widget.order.status);
    final nextColor = AppTokens.statusColor(nextStatus);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerHighest,
      appBar: AppBar(
        title: Text(
          'Order #${widget.order.id.substring(0, 6).toUpperCase()}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.order.status == 'cancelled')
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppTokens.s12),
                padding: const EdgeInsets.all(AppTokens.s12),
                decoration: BoxDecoration(
                  color: AppTokens.statusCancelled.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTokens.rMd),
                ),
                child: const Text(
                  'This order was cancelled. No further action is needed — do not deliver it.',
                  style: TextStyle(
                    color: AppTokens.statusCancelled,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            // Status Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              color: scheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.s16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivery Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    StatusChip(status: widget.order.status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.s16),

            // Customer Details Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              color: scheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_pin_rounded, color: scheme.primary),
                        const SizedBox(width: AppTokens.s8),
                        Text(
                          'Customer Details',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      widget.order.customerName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTokens.s8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${widget.order.deliveryAddress}, ${widget.order.village}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.s16),
                    if (widget.order.latitude != null &&
                        widget.order.longitude != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: const Text(
                            'Navigate',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            foregroundColor: scheme.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTokens.rSm,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed:
                              () => _launchMap(
                                widget.order.latitude!,
                                widget.order.longitude!,
                              ),
                        ),
                      ),
                      const SizedBox(height: AppTokens.s8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.call_rounded, size: 18),
                            label: const Text(
                              'Call',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: scheme.primaryContainer,
                              foregroundColor: scheme.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTokens.rSm,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => _contactCustomer(whatsApp: false),
                          ),
                        ),
                        const SizedBox(width: AppTokens.s12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: const Text(
                              'WhatsApp',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTokens.rSm,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => _contactCustomer(whatsApp: true),
                          ),
                        ),
                      ],
                    ),
                    const _ContactDispatchButton(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.s16),

            // COD Collection Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                side: BorderSide(
                  color: AppTokens.statusDelivered.withValues(alpha: 0.2),
                ),
              ),
              color: AppTokens.statusDelivered.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.s16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppTokens.statusDelivered,
                      radius: 18,
                      child: Icon(
                        Icons.currency_rupee_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppTokens.s12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cash to Collect (COD)',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
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
            const SizedBox(height: AppTokens.s16),

            // Items Checklist Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              color: scheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.fact_check_outlined,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: AppTokens.s8),
                            Text(
                              'Items Checklist',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        Text(
                          '${widget.order.items.length} items',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Verify and check off all items before departing:',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: AppTokens.s12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.order.items.length,
                      separatorBuilder:
                          (_, __) =>
                              Divider(color: scheme.outlineVariant, height: 1),
                      itemBuilder: (context, idx) {
                        final item = widget.order.items[idx];
                        final isChecked =
                            _checkedItems[item.productId] ?? false;

                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              decoration:
                                  isChecked ? TextDecoration.lineThrough : null,
                              color:
                                  isChecked
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            'Quantity: ${item.quantity}  •  ₹${item.price.toStringAsFixed(1)} / unit',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isChecked
                                      ? scheme.onSurfaceVariant.withValues(
                                        alpha: 0.5,
                                      )
                                      : scheme.onSurfaceVariant,
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
      bottomSheet:
          _kAssignedStatuses.contains(widget.order.status)
              ? Container(
                color: scheme.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: AppTokens.s16,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            () => _showReportDeliveryFailure(orderProvider),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(
                            color: scheme.error.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text(
                          "Cancel Delivery / Report Failure",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTokens.s8),
                      SwipeToConfirmSlider(
                        text: _getNextStatusText(widget.order.status),
                        color: nextColor,
                        enabled: !_isAdvancing,
                        onSwipeCompleted:
                            () =>
                                _advance(orderProvider, nextStatus, nextColor),
                      ),
                    ],
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
      stream:
          Provider.of<ConfigProvider>(context, listen: false).streamAppConfig(),
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
              label: const Text(
                'Contact Dispatch',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }
}
