import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/delivery_otp.dart';
import '../../providers/order_provider.dart';
import '../../utils/app_exception.dart';
import '../../utils/date_format.dart';
import '../app_tokens.dart';

/// The customer's delivery code for an active order: shown large for the rider,
/// with its expiry, and a way to replace it if it was shared by mistake or has
/// expired. Reads the code from the order's private document, which only the
/// ordering customer can read.
class DeliveryOtpCard extends StatefulWidget {
  final String orderId;

  /// The order's status. The code's validity window starts when it goes out for
  /// delivery, so a change here reloads the code and its expiry.
  final String status;

  /// Current time; injectable for tests.
  final DateTime Function() now;

  const DeliveryOtpCard({
    super.key,
    required this.orderId,
    required this.status,
    this.now = DateTime.now,
  });

  @override
  State<DeliveryOtpCard> createState() => _DeliveryOtpCardState();
}

class _DeliveryOtpCardState extends State<DeliveryOtpCard> {
  DeliveryOtp? _otp;
  bool _loading = true;
  bool _loadFailed = false;
  bool _refreshing = false;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DeliveryOtpCard old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status || old.orderId != widget.orderId) _load();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final otp = await context.read<OrderProvider>().getDeliveryOtp(widget.orderId);
    if (!mounted) return;
    setState(() {
      _otp = otp;
      _loading = false;
      _loadFailed = otp == null;
    });
    _scheduleExpiryRebuild();
  }

  /// Flip the card to "expired" the moment the code lapses, without waiting for
  /// some unrelated rebuild.
  void _scheduleExpiryRebuild() {
    _expiryTimer?.cancel();
    final expiresAt = _otp?.expiresAt;
    if (expiresAt == null) return;
    final wait = expiresAt.difference(widget.now());
    if (wait.isNegative) return;
    _expiryTimer = Timer(wait + const Duration(seconds: 1), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _confirmAndRefresh() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Get a new code?'),
        content: const Text(
            'Your current code will stop working. Only do this if it was shared by mistake or has expired.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep current code'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Get new code'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<OrderProvider>();
    setState(() => _refreshing = true);
    try {
      final fresh = await provider.regenerateDeliveryOtp(widget.orderId);
      if (!mounted) return;
      setState(() => _otp = fresh);
      _scheduleExpiryRebuild();
      messenger.showSnackBar(const SnackBar(content: Text('New delivery code ready.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(userMessageFor(e, fallback: "Couldn't get a new code. Please try again.")),
      ));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final otp = _otp;
    final expired = otp?.isExpiredAt(widget.now()) ?? false;
    final outForDelivery = widget.status == 'out_for_delivery';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pin_outlined, color: scheme.primary),
                const SizedBox(width: AppTokens.s8),
                Expanded(
                  child: Text(
                    outForDelivery ? 'Give this code to your rider' : 'Your delivery code',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.s4),
            Text(
              outForDelivery
                  ? 'Share it only when your order is in your hands.'
                  : "You'll need it when your order arrives. Don't share it before then.",
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppTokens.s12),
            if (_loading && otp == null)
              const Center(
                child: SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (otp == null || _loadFailed)
              Row(
                children: [
                  Expanded(
                    child: Text("Couldn't load your code.",
                        style: TextStyle(color: scheme.error)),
                  ),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              )
            else ...[
              Row(
                children: [
                  Semantics(
                    label: 'Delivery code ${otp.code.split('').join(' ')}',
                    child: ExcludeSemantics(
                      child: Text(
                        otp.code.split('').join(' '),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: expired ? scheme.onSurfaceVariant : scheme.primary,
                          decoration: expired ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Copy code',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: expired
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(ClipboardData(text: otp.code));
                            messenger.showSnackBar(
                                const SnackBar(content: Text('Code copied')));
                          },
                  ),
                ],
              ),
              if (otp.expiresAt != null) ...[
                const SizedBox(height: AppTokens.s4),
                Text(
                  expired
                      ? 'This code has expired. Get a new one.'
                      : 'Valid until ${formatTime(otp.expiresAt!)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: expired ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppTokens.s8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _refreshing ? null : _confirmAndRefresh,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Get a new code'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
