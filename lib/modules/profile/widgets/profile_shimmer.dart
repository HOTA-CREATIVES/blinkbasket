import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/design/app_tokens.dart';

class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: scheme.outlineVariant,
        highlightColor: scheme.surfaceContainerLowest,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(height: 180, color: scheme.surface),
                  Positioned(
                    bottom: -50,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60),

              // Name and Role text
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 160,
                      height: 20,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: AppTokens.s8),
                    Container(
                      width: 100,
                      height: 14,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.s32),

              // Card Groups
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(3, (cardIndex) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTokens.s24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 16,
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: AppTokens.s12),
                          Container(
                            height: 160,
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(AppTokens.rLg),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
