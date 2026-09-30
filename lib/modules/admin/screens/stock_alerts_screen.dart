import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/providers/product_provider.dart';
import '../../../core/utils/route_generator.dart';
import '../../../domain/entities/product.dart' as ent;
import 'widgets/product_ledger_sheet.dart';
import '../../../core/utils/app_exception.dart';

enum _AlertFilter { out, low, all }

/// Every product that needs attention: out of stock, or below its own
/// low-stock threshold. Tapping a card opens the product editor; the Restock
/// button jumps straight to the stock ledger.
class StockAlertsScreen extends StatefulWidget {
  const StockAlertsScreen({super.key});

  @override
  State<StockAlertsScreen> createState() => _StockAlertsScreenState();
}

class _StockAlertsScreenState extends State<StockAlertsScreen> {
  late final Stream<List<ent.Product>> _productsStream =
      Provider.of<ProductProvider>(context, listen: false).streamProducts();

  _AlertFilter? _filter; // null until the first data decides the default
  String _query = '';

  static bool _isOut(ent.Product p) => p.availableStock <= 0;
  static bool _isLow(ent.Product p) => p.availableStock > 0 && p.availableStock < p.lowStockThreshold;

  void _openEditor(ent.Product product) {
    Navigator.pushNamed(context, RouteGenerator.productEditor, arguments: product);
  }

  void _openRestock(ent.Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProductLedgerSheet(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Stock Alerts', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: scheme.surface,
        elevation: 0.5,
      ),
      body: StreamBuilder<List<ent.Product>>(
        stream: _productsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTokens.primary));
          }
          if (snapshot.hasError) {
            return EmptyState.error(
              title: "Couldn't load products",
              message: userMessageFor(snapshot.error),
              onAction: context.read<ProductProvider>().retryProducts,
            );
          }

          final products = snapshot.data ?? const <ent.Product>[];
          final out = products.where(_isOut).toList();
          final low = products.where(_isLow).toList();
          final filter = _filter ?? (out.isNotEmpty ? _AlertFilter.out : (low.isNotEmpty ? _AlertFilter.low : _AlertFilter.all));

          var shown = switch (filter) {
            _AlertFilter.out => out,
            _AlertFilter.low => low,
            _AlertFilter.all => [...out, ...low],
          };
          final q = _query.trim().toLowerCase();
          if (q.isNotEmpty) {
            shown = shown
                .where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q))
                .toList();
          }

          return Column(
            children: [
              Container(
                color: scheme.surface,
                padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s8, AppTokens.s16, AppTokens.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search products…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        filled: true,
                        fillColor: scheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTokens.rMd),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.s12),
                    Wrap(
                      spacing: AppTokens.s8,
                      runSpacing: AppTokens.s8,
                      children: [
                        _filterChip('Out of stock (${out.length})', _AlertFilter.out, filter, scheme.error),
                        _filterChip('Low stock (${low.length})', _AlertFilter.low, filter, AppTokens.accent),
                        _filterChip('All (${out.length + low.length})', _AlertFilter.all, filter, scheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? EmptyState(
                        icon: Icons.check_circle_outline_rounded,
                        title: q.isNotEmpty ? 'No matches' : 'Nothing to restock',
                        message: q.isNotEmpty
                            ? 'No alert matches "$_query".'
                            : 'Every product is above its low-stock level.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppTokens.s16),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s12),
                        itemBuilder: (context, i) => _alertCard(shown[i], scheme),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, _AlertFilter value, _AlertFilter current, Color color) {
    final selected = value == current;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? color : null),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _alertCard(ent.Product p, ColorScheme scheme) {
    final out = _isOut(p);
    final color = out ? scheme.error : AppTokens.accent;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppTokens.rLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        onTap: () => _openEditor(p),
        child: Container(
          padding: const EdgeInsets.all(AppTokens.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.rLg),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: p.imageUrl.isEmpty
                      ? ColoredBox(
                          color: scheme.surfaceContainerLow,
                          child: const Icon(Icons.image_outlined),
                        )
                      : CachedNetworkImage(
                          imageUrl: p.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: scheme.surfaceContainerLow,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        Text(
                          out ? 'OUT OF STOCK' : '${p.availableStock} left',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color),
                        ),
                        Text(
                          'Physical ${p.physicalStock} · Reserved ${p.reservedStock}',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.s8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonal(
                    onPressed: () => _openRestock(p),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Restock', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
