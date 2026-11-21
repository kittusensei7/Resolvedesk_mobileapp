import 'package:flutter/material.dart';

/// Professional Executive Shimmer Skeleton Loader for Paradesk
/// Implements a smooth 60fps wave gradient from #f1f5f9 to #ffffff to #f1f5f9
class ParadeskShimmer extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const ParadeskShimmer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<ParadeskShimmer> createState() => _ParadeskShimmerState();
}

class _ParadeskShimmerState extends State<ParadeskShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final double value = _controller.value;
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xfff1f5f9),
                Color(0xffffffff),
                Color(0xfff1f5f9),
              ],
              stops: [
                (value - 0.3).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Reusable bone/placeholder box for skeleton screens
class ShimmerBone extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color color;

  const ShimmerBone({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
    this.color = const Color(0xffe2e8f0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton for the 6-Metric Dashboard Grid
class DashboardMetricsSkeleton extends StatelessWidget {
  const DashboardMetricsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ParadeskShimmer(
      child: Column(
        children: [
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: index < 2 ? 8 : 0,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xffe2e8f0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ShimmerBone(width: 44, height: 10, borderRadius: 4),
                          ShimmerBone(width: 20, height: 20, borderRadius: 6),
                        ],
                      ),
                      SizedBox(height: 10),
                      ShimmerBone(width: 32, height: 22, borderRadius: 6),
                      SizedBox(height: 6),
                      ShimmerBone(width: 50, height: 8, borderRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: index < 2 ? 8 : 0,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xffe2e8f0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ShimmerBone(width: 44, height: 10, borderRadius: 4),
                          ShimmerBone(width: 20, height: 20, borderRadius: 6),
                        ],
                      ),
                      SizedBox(height: 10),
                      ShimmerBone(width: 32, height: 22, borderRadius: 6),
                      SizedBox(height: 6),
                      ShimmerBone(width: 50, height: 8, borderRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for Complaint & Service Report Cards
class ComplaintCardSkeleton extends StatelessWidget {
  const ComplaintCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ParadeskShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xffe2e8f0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Row(
                  children: [
                    ShimmerBone(width: 100, height: 16, borderRadius: 6),
                    SizedBox(width: 8),
                    ShimmerBone(width: 48, height: 16, borderRadius: 6),
                  ],
                ),
                ShimmerBone(width: 64, height: 18, borderRadius: 12),
              ],
            ),
            const SizedBox(height: 12),
            const ShimmerBone(width: 160, height: 18, borderRadius: 6),
            const SizedBox(height: 6),
            const ShimmerBone(width: 200, height: 12, borderRadius: 4),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xfff1f5f9)),
              ),
              child: const Row(
                children: [
                  ShimmerBone(width: 28, height: 28, borderRadius: 8),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBone(width: 120, height: 12, borderRadius: 4),
                        SizedBox(height: 4),
                        ShimmerBone(width: 180, height: 10, borderRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(child: ShimmerBone(height: 36, borderRadius: 12)),
                SizedBox(width: 8),
                Expanded(child: ShimmerBone(height: 36, borderRadius: 12)),
                SizedBox(width: 8),
                Expanded(child: ShimmerBone(height: 36, borderRadius: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for Service Call Report & Installation Report Cards
class ReportCardSkeleton extends StatelessWidget {
  const ReportCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ParadeskShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffe2e8f0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060f172a),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBone(width: 140, height: 18, borderRadius: 6),
                Row(
                  children: [
                    ShimmerBone(width: 70, height: 20, borderRadius: 8),
                    SizedBox(width: 6),
                    ShimmerBone(width: 60, height: 20, borderRadius: 8),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const ShimmerBone(width: 220, height: 12, borderRadius: 4),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xfff1f5f9)),
              ),
              child: Column(
                children: const [
                  Row(
                    children: [
                      ShimmerBone(width: 16, height: 16, borderRadius: 4),
                      SizedBox(width: 8),
                      ShimmerBone(width: 150, height: 12, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          ShimmerBone(width: 16, height: 16, borderRadius: 4),
                          SizedBox(width: 8),
                          ShimmerBone(width: 100, height: 12, borderRadius: 4),
                        ],
                      ),
                      ShimmerBone(width: 70, height: 12, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                Expanded(child: ShimmerBone(height: 38, borderRadius: 10)),
                SizedBox(width: 10),
                Expanded(flex: 2, child: ShimmerBone(height: 38, borderRadius: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for Customer Enquiry Cards
class EnquiryCardSkeleton extends StatelessWidget {
  const EnquiryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ParadeskShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffe2e8f0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060f172a),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBone(width: 130, height: 16, borderRadius: 6),
                Row(
                  children: [
                    ShimmerBone(width: 50, height: 20, borderRadius: 8),
                    SizedBox(width: 6),
                    ShimmerBone(width: 90, height: 22, borderRadius: 8),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                ShimmerBone(width: 32, height: 32, borderRadius: 16),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBone(width: 110, height: 14, borderRadius: 4),
                    SizedBox(height: 4),
                    ShimmerBone(width: 150, height: 11, borderRadius: 4),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const ShimmerBone(height: 38, borderRadius: 10),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBone(width: 100, height: 12, borderRadius: 4),
                ShimmerBone(width: 80, height: 12, borderRadius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
