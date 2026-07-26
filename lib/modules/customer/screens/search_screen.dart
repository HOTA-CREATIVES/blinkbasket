import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/design/widgets/product_card.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/product_provider.dart';
import '../../../domain/entities/product.dart';
import 'product_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  String _query = '';
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _recentSearches = prefs.getStringList('recent_searches') ?? [];
      });
    } catch (_) {}
  }

  Future<void> _saveRecentSearch(String search) async {
    final trimmed = search.trim();
    if (trimmed.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List<String>.from(_recentSearches);
      list.remove(trimmed); // Remove duplicate if it exists
      list.insert(0, trimmed); // Add to top of list
      if (list.length > 10) {
        list.removeLast(); // Keep list capped at 10 items
      }
      setState(() {
        _recentSearches = list;
      });
      await prefs.setStringList('recent_searches', list);
    } catch (_) {}
  }

  Future<void> _clearAllRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _recentSearches.clear();
      });
      await prefs.remove('recent_searches');
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _query = value.trim();
      });
      if (_query.isNotEmpty) {
        _saveRecentSearch(_query);
      }
    });
  }

  void _runSearch(String search) {
    _searchController.text = search;
    setState(() {
      _query = search;
    });
    _saveRecentSearch(search);
  }

  List<Product> _filterProducts(List<Product> allProducts) {
    if (_query.isEmpty) return [];
    final lowerQuery = _query.toLowerCase();
    return allProducts.where((p) {
      return p.name.toLowerCase().contains(lowerQuery) ||
          p.category.toLowerCase().contains(lowerQuery) ||
          p.description.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cartProvider = context.read<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: AppTokens.s16),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'Search fresh produce, dairy...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s16,
                vertical: AppTokens.s8,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
      ),
      body: StreamBuilder<List<Product>>(
        stream: Provider.of<ProductProvider>(context, listen: false).streamProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allProducts = snapshot.data ?? [];
          final filtered = _filterProducts(allProducts);

          if (_query.isEmpty) {
            if (_recentSearches.isEmpty) {
              return const EmptyState(
                icon: Icons.search_rounded,
                title: 'Search J C Mart',
                message: 'Type above to search fresh produce, daily essentials, and more.',
              );
            }

            return Padding(
              padding: const EdgeInsets.all(AppTokens.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Searches',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: _clearAllRecentSearches,
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.s8),
                  Wrap(
                    spacing: AppTokens.s8,
                    runSpacing: AppTokens.s8,
                    children: _recentSearches.map((search) {
                      return ActionChip(
                        label: Text(search),
                        onPressed: () => _runSearch(search),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTokens.rPill),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }

          if (filtered.isEmpty) {
            return EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No results found',
              message: 'We couldn\'t find any items matching "$_query".',
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(AppTokens.s16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: AppTokens.s16,
              mainAxisSpacing: AppTokens.s16,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final product = filtered[index];
              final inCartQty = context
                  .select<CartProvider, int>((c) => c.quantityOf(product.id));

              return ProductCard(
                product: product,
                quantityInCart: inCartQty,
                onAdd: () => cartProvider.addItem(product),
                onRemove: () => cartProvider.decrementItem(product.id),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailsScreen(product: product),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
