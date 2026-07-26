import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../domain/entities/app_config.dart';
import '../../../domain/entities/order.dart';

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

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Authentication error')),
      );
    }

    return StreamBuilder<AppConfig>(
      stream: configProvider.streamAppConfig(),
      builder: (context, configSnapshot) {
        final payoutPerDelivery = configSnapshot.data?.riderPayoutPerDelivery ?? 30.0;
        return _buildScaffold(context, orderProvider, user.uid, payoutPerDelivery);
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    OrderProvider orderProvider,
    String uid,
    double payoutPerDelivery,
  ) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Earnings & Remittances',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          final orders = snapshot.data ?? [];
          final completed = orders.where((o) => o.status == 'delivered').toList();
          final cancelled = orders.where((o) => o.status == 'cancelled').toList();

          // Calculate financials — payout rate is admin-configurable (Store
          // Settings), applied forward-looking to all completed runs shown.
          double totalCodCollected = 0.0;
          double riderEarnings = 0.0;

          for (var o in completed) {
            totalCodCollected += o.totalAmount;
            riderEarnings += payoutPerDelivery;
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, isEmbedded ? 100.0 : 16.0),
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
                          side: BorderSide(color: Colors.green.shade200),
                        ),
                        color: Colors.green.shade50.withValues(alpha: 0.5),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Payout',
                                style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₹${riderEarnings.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${payoutPerDelivery.toStringAsFixed(0)} per delivery run',
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTokens.rMd),
                          side: BorderSide(color: Colors.orange.shade200),
                        ),
                        color: Colors.orange.shade50.withValues(alpha: 0.5),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'COD Cash Held',
                                style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₹${totalCodCollected.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Remit to Admin HQ',
                                style: TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Statistics Grid Card
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
                        const Text(
                          'Performance Summary',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Completed', '${completed.length} runs', Colors.green),
                            _buildStatItem('Cancelled', '${cancelled.length} runs', Colors.red),
                            _buildStatItem('Total Tasks', '${orders.length} assigned', Colors.blue),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Runs Timeline / Completed Runs List
                const Text(
                  'Recent Completed Runs Logs',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                if (completed.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                    child: Text(
                      'No completed runs logged today.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: completed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final order = completed[idx];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTokens.rMd),
                          side: BorderSide(color: Colors.grey.shade100),
                        ),
                        color: Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            radius: 18,
                            child: Icon(Icons.check_rounded, color: Colors.white, size: 18),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order #${order.id.substring(0, 6).toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '₹${order.totalAmount.toStringAsFixed(1)} (COD)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'To: ${order.customerName}  •  ${order.village}\nCompleted on: ${_formatDateTime(order.updatedAt)}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4),
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

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
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
