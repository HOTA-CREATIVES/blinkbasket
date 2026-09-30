import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/design/app_tokens.dart';
import '../../../../core/providers/product_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../domain/entities/product.dart' as ent;
import '../../../../domain/entities/inventory_ledger.dart';

class ProductLedgerSheet extends StatefulWidget {
  final ent.Product product;
  const ProductLedgerSheet({super.key, required this.product});

  @override
  State<ProductLedgerSheet> createState() => _ProductLedgerSheetState();
}

class _ProductLedgerSheetState extends State<ProductLedgerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _deltaController = TextEditingController();
  final _notesController = TextEditingController();
  String _changeType = 'restock';
  bool _isSubmitting = false;

  final List<Map<String, String>> _reasons = [
    {'value': 'restock', 'label': 'Restock (Add Stock)'},
    {'value': 'spoilage', 'label': 'Damage / Spoilage (Reduce Stock)'},
    {'value': 'correction', 'label': 'Inventory Correction (Manual Change)'},
  ];

  @override
  void dispose() {
    _deltaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : AppTokens.statusDelivered,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitAdjustment() async {
    if (!_formKey.currentState!.validate()) return;

    final rawDelta = int.parse(_deltaController.text.trim());
    int physicalDelta = rawDelta;
    if (_changeType == 'spoilage') {
      physicalDelta = -rawDelta.abs();
    } else if (_changeType == 'correction') {
      physicalDelta = rawDelta;
    } else {
      physicalDelta = rawDelta.abs();
    }

    setState(() {
      _isSubmitting = true;
    });

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // No fake fallback id — a ledger entry must belong to a real signed-in admin.
    final adminId = authProvider.currentUserModel?.uid ?? '';
    if (adminId.isEmpty) {
      _showSnackBar('Sign in again to adjust stock.');
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final success = await productProvider.adjustStock(
        productId: widget.product.id,
        physicalDelta: physicalDelta,
        reservedDelta: 0,
        changeType: _changeType,
        notes: _notesController.text.trim(),
        adminId: adminId,
      );

      if (success) {
        _showSnackBar('Stock adjusted successfully and logged!', isError: false);
        if (mounted) {
          _deltaController.clear();
          _notesController.clear();
          setState(() {
            _isSubmitting = false;
          });
        }
      } else {
        _showSnackBar('Failed to adjust stock: ${productProvider.errorMessage}');
        setState(() {
          _isSubmitting = false;
        });
      }
    } catch (e) {
      _showSnackBar('Error adjusting stock: $e');
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.product.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text(
                widget.product.category,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPillCard(
                    title: 'Physical',
                    value: '${widget.product.physicalStock}',
                    color: AppTokens.statusAssigned,
                    bgColor: AppTokens.statusAssigned.withValues(alpha: 0.1),
                  ),
                  _buildPillCard(
                    title: 'Reserved',
                    value: '${widget.product.reservedStock}',
                    color: AppTokens.accent,
                    bgColor: AppTokens.accent.withValues(alpha: 0.1),
                  ),
                  _buildPillCard(
                    title: 'Available',
                    value: '${widget.product.availableStock}',
                    color: AppTokens.statusDelivered,
                    bgColor: AppTokens.statusDelivered.withValues(alpha: 0.1),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'New Adjustment Entry',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _changeType,
                      decoration: InputDecoration(
                        labelText: 'Adjustment Reason',
                        prefixIcon: const Icon(Icons.assignment_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _reasons.map((r) {
                        return DropdownMenuItem(value: r['value'], child: Text(r['label']!));
                      }).toList(),
                      onChanged: _isSubmitting ? null : (val) {
                        if (val != null) {
                          setState(() {
                            _changeType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _deltaController,
                            enabled: !_isSubmitting,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Quantity Change',
                              prefixIcon: const Icon(Icons.exposure),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Enter quantity';
                              final val = int.tryParse(value.trim());
                              if (val == null) return 'Invalid number';
                              if (val == 0) return 'Cannot be 0';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Audit Memo / Notes',
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter note/reason' : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitAdjustment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2),
                                ),
                                const SizedBox(width: 12),
                                const Text('Saving Ledger Entry...'),
                              ],
                            )
                          : const Text('SUBMIT ADJUSTMENT', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Text(
                'Audit Ledger Logs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              StreamBuilder<List<InventoryLedger>>(
                stream: productProvider.streamInventoryLogs(widget.product.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No audit transactions recorded yet.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final logs = snapshot.data!;
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return _buildLedgerTimelineTile(log);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillCard({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTimelineTile(InventoryLedger log) {
    IconData icon;
    Color color;
    String prefix = "";

    switch (log.changeType) {
      case 'restock':
        icon = Icons.add_business_rounded;
        color = AppTokens.statusDelivered;
        prefix = "+${log.physicalDelta}";
        break;
      case 'sale':
        icon = Icons.shopping_bag_outlined;
        color = AppTokens.statusAssigned;
        prefix = "${log.physicalDelta}";
        break;
      case 'return':
        icon = Icons.undo_rounded;
        color = AppTokens.statusPending;
        prefix = "+${log.reservedDelta.abs()}";
        break;
      case 'reserve':
        icon = Icons.lock_outline_rounded;
        color = AppTokens.statusPickedUp;
        prefix = "${log.reservedDelta}";
        break;
      case 'spoilage':
        icon = Icons.delete_outline;
        color = AppTokens.statusCancelled;
        prefix = "${log.physicalDelta}";
        break;
      case 'correction':
        icon = Icons.tune;
        color = AppTokens.statusPending;
        prefix = log.physicalDelta >= 0 ? "+${log.physicalDelta}" : "${log.physicalDelta}";
        break;
      default:
        icon = Icons.history_rounded;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        prefix = log.physicalDelta >= 0 ? "+${log.physicalDelta}" : "${log.physicalDelta}";
    }

    final formattedTime = "${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year} ${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      log.changeType.toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                    ),
                    Text(
                      prefix,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(log.notes, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text(
                  "$formattedTime \u2022 User: ${log.adminId}",
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
