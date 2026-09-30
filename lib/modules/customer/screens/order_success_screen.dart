import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/biometric_reveal.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/utils/route_generator.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/money.dart';

/// Displayed immediately after a successful order placement.
/// Shows an animated checkmark, the delivery OTP, and navigation CTAs.
class OrderSuccessScreen extends StatefulWidget {
  final String orderId;
  final double total;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.total,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _checkScale = CurvedAnimation(
      parent: _checkCtrl,
      curve: Curves.elasticOut,
    );

    _fadeIn = CurvedAnimation(
      parent: _checkCtrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final orderProvider =
        Provider.of<OrderProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // -- Animated checkmark --
                ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTokens.statusDelivered.withValues(alpha: 0.1),
                      border: Border.all(
                          color: AppTokens.statusDelivered, width: 3),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 64,
                      color: AppTokens.statusDelivered,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // -- Title & subtitle --
                FadeTransition(
                  opacity: _fadeIn,
                  child: Column(
                    children: [
                      Text(
                        'Order Placed!',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Order #${widget.orderId.substring(0, 6).toUpperCase()} '
                        'is confirmed.\n'
                        'Total: ${formatRupees(widget.total)} (COD)',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 14,
                            height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // -- OTP card --
                      FutureBuilder<String?>(
                        future: orderProvider.getOrderOtp(widget.orderId),
                        builder: (context, snap) {
                          final otp = snap.data;
                          if (otp == null || otp.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return BiometricReveal(
                            reason: 'Authenticate to view the delivery OTP',
                            child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppTokens.s16),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius:
                                  BorderRadius.circular(AppTokens.rLg),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.vpn_key_rounded,
                                        size: 18,
                                        color: scheme.onPrimaryContainer),
                                    const SizedBox(width: AppTokens.s8),
                                    Text(
                                      'Delivery OTP',
                                      style: TextStyle(
                                          color: scheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTokens.s8),
                                Text(
                                  otp.split('').join(' '),
                                  style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      color: scheme.onPrimaryContainer,
                                      letterSpacing: 8),
                                ),
                                const SizedBox(height: AppTokens.s8),
                                Text(
                                  'Share this OTP with the delivery partner to confirm receipt.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onPrimaryContainer
                                          .withValues(alpha: 0.7)),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTokens.s8),
                                TextButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: otp));
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text('OTP copied!'),
                                      behavior: SnackBarBehavior.floating,
                                    ));
                                  },
                                  icon: Icon(Icons.copy_all_rounded,
                                      size: 16,
                                      color: scheme.onPrimaryContainer),
                                  label: Text('Copy OTP',
                                      style: TextStyle(
                                          color: scheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ));
                        },
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),

                // -- CTAs --
                FadeTransition(
                  opacity: _fadeIn,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                              context,
                              RouteGenerator.orderTracking,
                              arguments: widget.orderId,
                            );
                          },
                          icon: const Icon(Icons.location_on_rounded),
                          label: const Text('Track My Order',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTokens.s12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            // Pop back to the shop tab
                            Navigator.of(context)
                                .popUntil((r) => r.isFirst);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Continue Shopping',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

