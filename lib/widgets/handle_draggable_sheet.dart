import 'package:flutter/material.dart';
import 'package:nikki/theme/nikki_colors.dart';

/// A bottom-sheet body with two snap points: collapsed (initialFraction)
/// and expanded (maxFraction). Drag up on the handle -> snaps to top.
/// Drag down -> snaps to half, or dismisses if already at half.
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

  void _onDragEnd(DragEndDetails details) {
    final dy = details.velocity.pixelsPerSecond.dy;
    final atOrBelowHalf = _fraction <= widget.initialFraction + 0.02;

    if (dy < -200) {
      _snapTo(widget.maxFraction);
    } else if (dy > 200) {
      if (atOrBelowHalf) {
        Navigator.of(context).pop();
      } else {
        _snapTo(widget.initialFraction);
      }
    } else if (_fraction > (widget.initialFraction + widget.maxFraction) / 2) {
      _snapTo(widget.maxFraction);
    } else {
      _snapTo(widget.initialFraction);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final minFraction = widget.initialFraction * 0.6;
    setState(() {
      _fraction = (_fraction - details.delta.dy / screenHeight)
          .clamp(minFraction, widget.maxFraction);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = screenHeight - keyboardHeight;

    // When keyboard is open, use available height (minus keyboard)
    // so content starts from the top of the visible area.
    final effectiveHeight = keyboardHeight > 0
        ? availableHeight * widget.maxFraction
        : screenHeight * _fraction;

    return SizedBox(
      height: effectiveHeight,
      child: Column(
        children: [
          // Handle bar — drag target
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colors.dialogBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.handle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          // Content
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
