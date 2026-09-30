import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/banner_provider.dart';
import '../../../domain/entities/banner_item.dart';
import '../app_tokens.dart';

class BannerCarousel extends StatefulWidget {
  final void Function(String category) onBannerTap;

  const BannerCarousel({
    super.key,
    required this.onBannerTap,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(0);
  Stream<List<BannerItem>>? _bannersStream;
  Timer? _autoPlayTimer;
  List<BannerItem> _banners = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bannersStream ??= context.read<BannerProvider>().streamActiveBanners();
  }

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _pageController.dispose();
    _currentPageNotifier.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_banners.length <= 1 || !mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPageNotifier.value + 1) % _banners.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<BannerItem>>(
      stream: _bannersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        _banners = snapshot.data!;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 160,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _banners.length,
                onPageChanged: (index) {
                  _currentPageNotifier.value = index;
                },
                itemBuilder: (context, index) {
                  final banner = _banners[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
                    child: GestureDetector(
                      onTap: () {
                        if (banner.category != null && banner.category!.isNotEmpty) {
                          widget.onBannerTap(banner.category!);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTokens.rLg),
                        child: CachedNetworkImage(
                          imageUrl: banner.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            child: Center(
                              child: Icon(Icons.broken_image, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppTokens.s8),
            ValueListenableBuilder<int>(
              valueListenable: _currentPageNotifier,
              builder: (context, currentPage, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_banners.length, (index) {
                    final isSelected = currentPage == index;
                    return AnimatedContainer(
                      duration: AppTokens.fast,
                      margin: const EdgeInsets.symmetric(horizontal: 3.0),
                      height: 6.0,
                      width: isSelected ? 16.0 : 6.0,
                      decoration: BoxDecoration(
                        color: isSelected ? scheme.primary : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
