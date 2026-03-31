import 'package:flutter/material.dart';
import 'package:nikki/theme/nikki_colors.dart';

class ShimmerBox extends StatefulWidget {
  final double widthFraction;
  final double height;

  const ShimmerBox({super.key, this.widthFraction = 1.0, this.height = 16});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.08, end: 0.24).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => FractionallySizedBox(
        widthFactor: widget.widthFraction,
        alignment: Alignment.centerLeft,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(_animation.value),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class ShimmerContent extends StatelessWidget {
  const ShimmerContent({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(widthFraction: 0.5, height: 28),
          SizedBox(height: 8),
          ShimmerBox(widthFraction: 0.3, height: 16),
          SizedBox(height: 24),
          ShimmerBox(widthFraction: 0.2, height: 12),
          SizedBox(height: 8),
          ShimmerBox(widthFraction: 1.0, height: 16),
          SizedBox(height: 20),
          ShimmerBox(widthFraction: 0.2, height: 12),
          SizedBox(height: 8),
          ShimmerBox(widthFraction: 0.85, height: 16),
          SizedBox(height: 4),
          ShimmerBox(widthFraction: 0.7, height: 16),
          SizedBox(height: 20),
          ShimmerBox(widthFraction: 0.2, height: 12),
          SizedBox(height: 8),
          ShimmerBox(widthFraction: 0.9, height: 16),
          SizedBox(height: 4),
          ShimmerBox(widthFraction: 0.75, height: 16),
          SizedBox(height: 4),
          ShimmerBox(widthFraction: 0.6, height: 16),
        ],
      ),
    );
  }
}
