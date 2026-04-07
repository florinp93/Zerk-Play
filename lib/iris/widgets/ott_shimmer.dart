import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

final class OttSkeleton extends StatelessWidget {
  const OttSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Color.lerp(base, Colors.white, 0.08) ?? base;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: width,
          height: height,
          child: const ColoredBox(color: Colors.white),
        ),
      ),
    );
  }
}

final class OttSkeletonList extends StatelessWidget {
  const OttSkeletonList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 12,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < itemCount; i++) ...[
          if (i != 0) SizedBox(width: spacing),
          itemBuilder(context, i),
        ],
      ],
    );
  }
}

