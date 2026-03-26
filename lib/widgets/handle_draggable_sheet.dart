import 'package:flutter/material.dart';

/// A bottom-sheet body with two snap points: collapsed (initialFraction)
/// and expanded (maxFraction). Drag up on the handle → snaps to top.
/// Drag down → snaps to half, or dismisses if already at half.
class HandleDraggableSheet extends StatefulWidget {
  final double initialFraction;
  final double maxFraction;
  final Widget child;

  const HandleDraggableSheet({
    super.key,
    this.initialFraction = 0.45,
    this.maxFraction = 0.85,
    required this.child,
  });

  @override
  State<HandleDraggableSheet> createState() => _HandleDraggableSheetState();
}

class _HandleDraggableSheetState extends State<HandleDraggableSheet>
    with SingleTickerProviderStateMixin {
  late double _fraction;
  late AnimationController _animController;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _fraction = widget.initialFraction;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        setState(() => _fraction = _animation!.value);
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _snapTo(double target) {
    _animation = Tween<double>(begin: _fraction, end: target)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward(from: 0);
  }

  bool get _isExpanded =>
      (_fraction - widget.maxFraction).abs() < 0.01;

  void _onDragEnd(DragEndDetails details) {
    final dy = details.velocity.pixelsPerSecond.dy;

    final atOrBelowHalf = _fraction <= widget.initialFraction + 0.02;

    if (dy < -200) {
      // Swiped up → expand
      _snapTo(widget.maxFraction);
    } else if (dy > 200) {
      if (atOrBelowHalf) {
        // Swiped down while at half → dismiss
        Navigator.of(context).pop();
      } else {
        // Swiped down while above half → collapse to half
        _snapTo(widget.initialFraction);
      }
    }
    // Slow drag with no clear velocity → snap to nearest
    else if (_fraction > (widget.initialFraction + widget.maxFraction) / 2) {
      _snapTo(widget.maxFraction);
    } else {
      _snapTo(widget.initialFraction);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final minFraction = widget.initialFraction * 0.6; // allow slight over-drag down
    setState(() {
      _fraction = (_fraction - details.delta.dy / screenHeight)
          .clamp(minFraction, widget.maxFraction);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final theme = Theme.of(context);

    return SizedBox(
      height: screenHeight * _fraction,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
