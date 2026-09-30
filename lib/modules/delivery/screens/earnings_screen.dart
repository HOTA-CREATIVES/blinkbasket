import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../domain/entities/app_config.dart';
import '../../../domain/entities/order.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/design/widgets/empty_state.dart';

class EarningsScreen extends StatelessWidget {
  final bool isEmbedded;
  const EarningsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    // Non-listening: all reactivity here comes from the nested StreamBuilders
    // below, not from these providers' own notifyListeners() (which fire for
    // unrelated reasons elsewhere in the app and would otherwise rebuild this
    // whole screen, including re-running the completed-runs list itemBuilder).
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final user = authProvider.currentUserModel;
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Authentication error')),
      );
    }

    return StreamBuilder<AppConfig>(
      stream: configProvider.streamAppConfig(),
      builder: (context, configSnapshot) {
        final payoutPerDelivery = configSnapshot.data?.riderPayoutPerDelivery ?? 30.0;
        return _buildScaffold(context, orderProvider, user.uid, payoutPerDelivery, scheme);
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    OrderProvider orderProvider,
    String uid,
    double payoutPerDelivery,
    ColorScheme scheme,
  ) {
    return Scaffold(
      backgroundColor: scheme.surfaceContainerHighest,
      appBar: AppBar(
        title: Text(
          'Earnings & Remittances',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        automaticallyImplyLeading: !isEmbedded,
        leading: isEmbedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: StreamBuilder<List<Order>>(
        stream: orderProvider.streamDeliveryBoyOrders(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: scheme.primary));
          }
          if (snapshot.hasError) {
            return EmptyState.error(
              title: "Couldn't load your earnings",
              message: userMessageFor(snapshot.error),
              onAction: () => orderProvider.retryDeliveryOrders(uid),
            );
          }

          final orders = snapshot.data ?? [];
          final completed = orders.where((o) => o.status == 'delivered').toList();
          final cancelled = orders.where((o) => o.status == 'cancelled').toList();

          // Each delivery is paid at the rate frozen on the order when it was
          // delivered. The current Store Settings rate is only the fallback for
          // deliveries that predate that field — so an admin editing the rate
          // never reprices a rider's history.
          double totalCodCollected = 0.0;
          double riderEarnings = 0.0;

          for (var o in completed) {
            totalCodCollected += o.totalAmount;
            riderEarnings += o.riderPayout ?? payoutPerDelivery;
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s16, AppTokens.s16, isEmbedded ? 100.0 : AppTokens.s16.toDouble()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Highlight Cards: Earnings vs Cash Held
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTokens.rMd),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTokens.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Payout',
                              style: TextStyle(color: scheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: AppTokens.s8),
                            Text(
                              '₹${riderEarnings.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Current rate ₹${payoutPerDelivery.toStringAsFixed(0)} / delivery',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                            ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.s12),
                    Expanded(
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTokens.rMd),
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        color: scheme.primaryContainer.withValues(alpha: 0.5),
                        child: Padding(
                          padding: const EdgeInsets.all(AppTokens.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'COD Cash Held',
                                style: TextStyle(color: scheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: AppTokens.s8),
                              Text(
                                '₹${totalCodCollected.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Remit to Admin HQ',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.s16),

                // Statistics Grid Card
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
                        const Text(
                          'Performance Summary',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Completed', '${completed.length} runs', scheme.primary, scheme),
                            _buildStatItem('Cancelled', '${cancelled.length} runs', scheme.error, scheme),
                            _buildStatItem('Total Tasks', '${orders.length} assigned', scheme.primary, scheme),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.s24),

                // Runs Timeline / Completed Runs List
                Text(
                  'Recent Completed Runs Logs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: AppTokens.s12),
                if (completed.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                      child: Text(
                        'No completed runs logged today.',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                      ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: completed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s12),
                    itemBuilder: (context, idx) {
                      final order = completed[idx];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTokens.rMd),
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        color: scheme.surface,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.s16, vertical: AppTokens.s8),
                          leading: CircleAvatar(
                            backgroundColor: scheme.primary,
                            radius: 18,
                            child: Icon(Icons.check_rounded, color: scheme.onPrimary, size: 18),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order #${order.id.substring(0, 6).toUpperCase()}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '₹${order.totalAmount.toStringAsFixed(1)} (COD)',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: scheme.onSurface),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'To: ${order.customerName}  •  ${order.village}\nCompleted on: ${_formatDateTime(order.updatedAt)}',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.4),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, ColorScheme scheme) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $hour:$minute $ampm';
  }
}
