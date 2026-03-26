import 'package:flutter/material.dart';
import 'package:nikki/providers/camera_provider.dart';

class TextOverlay extends StatefulWidget {
  final List<RecognizedBlock> blocks;
  final SelectedWord? selectedWord;
  final int imageWidth;
  final int imageHeight;
  final int rotationDegrees;
  final void Function(String selectedText, String blockText) onSelectionComplete;

  const TextOverlay({
    super.key,
    required this.blocks,
    required this.selectedWord,
    required this.imageWidth,
    required this.imageHeight,
    required this.rotationDegrees,
    required this.onSelectionComplete,
  });

  @override
  State<TextOverlay> createState() => _TextOverlayState();
}

class _TextOverlayState extends State<TextOverlay> {
  // Drag selection state
  int? _dragBlockIdx;
  int? _dragStartWordIdx;
  int? _dragEndWordIdx;

  /// Indices of words currently selected during drag.
  Set<int> get _dragSelectedWordIndices {
    if (_dragBlockIdx == null ||
        _dragStartWordIdx == null ||
        _dragEndWordIdx == null) {
      return {};
    }
    final lo = _dragStartWordIdx! < _dragEndWordIdx!
        ? _dragStartWordIdx!
        : _dragEndWordIdx!;
    final hi = _dragStartWordIdx! > _dragEndWordIdx!
        ? _dragStartWordIdx!
        : _dragEndWordIdx!;
    return {for (int i = lo; i <= hi; i++) i};
  }

  static ({double scale, double offsetX, double offsetY}) _computeTransform(
    double overlayWidth,
    double overlayHeight,
    double imgW,
    double imgH,
  ) {
    final imageAspect = imgW / imgH;
    final screenAspect = overlayWidth / overlayHeight;

    double scale;
    double offsetX;
    double offsetY;

    if (imageAspect > screenAspect) {
      scale = overlayHeight / imgH;
      offsetX = (imgW * scale - overlayWidth) / 2;
      offsetY = 0;
    } else {
      scale = overlayWidth / imgW;
      offsetX = 0;
      offsetY = (imgH * scale - overlayHeight) / 2;
    }

    return (scale: scale, offsetX: offsetX, offsetY: offsetY);
  }

  static Rect _transformRect(
    Rect r,
    double scale,
    double offsetX,
    double offsetY,
  ) {
    return Rect.fromLTRB(
      r.left * scale - offsetX,
      r.top * scale - offsetY,
      r.right * scale - offsetX,
      r.bottom * scale - offsetY,
    );
  }

  /// Find which block and element index is at [pos].
  /// Returns (blockIndex, elementIndex) or null.
  ({int blockIdx, int elemIdx})? _hitTest(
    Offset pos,
    double scale,
    double offsetX,
    double offsetY,
  ) {
    const padding = 6.0;
    for (int bi = 0; bi < widget.blocks.length; bi++) {
      final block = widget.blocks[bi];
      for (int ei = 0; ei < block.elements.length; ei++) {
        final bbox = block.elements[ei].boundingBox;
        if (bbox == null) continue;
        final r = _transformRect(bbox, scale, offsetX, offsetY);
        if (r.inflate(padding).contains(pos)) {
          return (blockIdx: bi, elemIdx: ei);
        }
      }
    }
    return null;
  }

  /// Find the closest element in a specific block to [pos].
  int? _closestInBlock(
    int blockIdx,
    Offset pos,
    double scale,
    double offsetX,
    double offsetY,
  ) {
    final block = widget.blocks[blockIdx];
    double bestDist = double.infinity;
    int? bestIdx;
    for (int ei = 0; ei < block.elements.length; ei++) {
      final bbox = block.elements[ei].boundingBox;
      if (bbox == null) continue;
      final r = _transformRect(bbox, scale, offsetX, offsetY);
      final center = r.center;
      final dist = (center - pos).distance;
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = ei;
      }
    }
    return bestIdx;
  }

  void _finalizeDragSelection() {
    if (_dragBlockIdx == null) return;

    final indices = _dragSelectedWordIndices;
    if (indices.isEmpty) {
      setState(() {
        _dragBlockIdx = null;
        _dragStartWordIdx = null;
        _dragEndWordIdx = null;
      });
      return;
    }

    final block = widget.blocks[_dragBlockIdx!];
    final sorted = indices.toList()..sort();
    final selectedText =
        sorted.map((i) => block.elements[i].text).join();
    final blockText = block.text;

    setState(() {
      _dragBlockIdx = null;
      _dragStartWordIdx = null;
      _dragEndWordIdx = null;
    });

    widget.onSelectionComplete(selectedText, blockText);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final overlayWidth = constraints.maxWidth;
        final overlayHeight = constraints.maxHeight;

        final imgW =
            (widget.rotationDegrees == 90 || widget.rotationDegrees == 270)
                ? widget.imageHeight.toDouble()
                : widget.imageWidth.toDouble();
        final imgH =
            (widget.rotationDegrees == 90 || widget.rotationDegrees == 270)
                ? widget.imageWidth.toDouble()
                : widget.imageHeight.toDouble();

        if (imgW == 0 || imgH == 0) return const SizedBox.expand();

        final t = _computeTransform(overlayWidth, overlayHeight, imgW, imgH);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,

          // Single tap → select one word
          onTapUp: (details) {
            final hit = _hitTest(
                details.localPosition, t.scale, t.offsetX, t.offsetY);
            if (hit != null) {
              final block = widget.blocks[hit.blockIdx];
              final element = block.elements[hit.elemIdx];
              widget.onSelectionComplete(element.text, block.text);
            }
          },

          // Long press + drag → select phrase
          onLongPressStart: (details) {
            final hit = _hitTest(
                details.localPosition, t.scale, t.offsetX, t.offsetY);
            if (hit != null) {
              setState(() {
                _dragBlockIdx = hit.blockIdx;
                _dragStartWordIdx = hit.elemIdx;
                _dragEndWordIdx = hit.elemIdx;
              });
            }
          },
          onLongPressMoveUpdate: (details) {
            if (_dragBlockIdx == null) return;
            // Find closest word in the same block
            final closest = _closestInBlock(
              _dragBlockIdx!,
              details.localPosition,
              t.scale,
              t.offsetX,
              t.offsetY,
            );
            if (closest != null && closest != _dragEndWordIdx) {
              setState(() => _dragEndWordIdx = closest);
            }
          },
          onLongPressEnd: (_) => _finalizeDragSelection(),

          child: CustomPaint(
            size: Size(overlayWidth, overlayHeight),
            painter: _TextOverlayPainter(
              blocks: widget.blocks,
              selectedWord: widget.selectedWord,
              dragBlockIdx: _dragBlockIdx,
              dragSelectedIndices: _dragSelectedWordIndices,
              scale: t.scale,
              offsetX: t.offsetX,
              offsetY: t.offsetY,
            ),
          ),
        );
      },
    );
  }
}

class _TextOverlayPainter extends CustomPainter {
  final List<RecognizedBlock> blocks;
  final SelectedWord? selectedWord;
  final int? dragBlockIdx;
  final Set<int> dragSelectedIndices;
  final double scale;
  final double offsetX;
  final double offsetY;

  _TextOverlayPainter({
    required this.blocks,
    required this.selectedWord,
    required this.dragBlockIdx,
    required this.dragSelectedIndices,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  Rect _transform(Rect r) {
    return Rect.fromLTRB(
      r.left * scale - offsetX,
      r.top * scale - offsetY,
      r.right * scale - offsetX,
      r.bottom * scale - offsetY,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final underlinePaint = Paint()
      ..color = const Color(0x30FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Drag selection highlight (blue tint)
    final dragFillPaint = Paint()
      ..color = const Color(0x442196F3)
      ..style = PaintingStyle.fill;

    final dragBorderPaint = Paint()
      ..color = const Color(0xAA2196F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Final selection highlight (white)
    final selectedFillPaint = Paint()
      ..color = const Color(0x55FFFFFF)
      ..style = PaintingStyle.fill;

    final selectedBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final bool isDragging = dragBlockIdx != null && dragSelectedIndices.isNotEmpty;

    for (int bi = 0; bi < blocks.length; bi++) {
      final block = blocks[bi];
      for (int ei = 0; ei < block.elements.length; ei++) {
        final element = block.elements[ei];
        if (element.boundingBox == null) continue;
        final r = _transform(element.boundingBox!);

        if (r.right < 0 || r.bottom < 0 ||
            r.left > size.width || r.top > size.height) {
          continue;
        }

        // Check if this element is part of the active drag selection
        final isDragSelected =
            isDragging && bi == dragBlockIdx && dragSelectedIndices.contains(ei);

        // Check if this element matches the finalized selection
        final isFinalSelected = !isDragging &&
            selectedWord != null &&
            selectedWord!.text.contains(element.text);

        if (isDragSelected) {
          final rr = RRect.fromRectAndRadius(r, const Radius.circular(3));
          canvas.drawRRect(rr, dragFillPaint);
          canvas.drawRRect(rr, dragBorderPaint);
        } else if (isFinalSelected) {
          final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
          canvas.drawRRect(rr, selectedFillPaint);
          canvas.drawRRect(rr, selectedBorderPaint);
        } else {
          // Subtle underline
          canvas.drawLine(
            Offset(r.left, r.bottom),
            Offset(r.right, r.bottom),
            underlinePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TextOverlayPainter oldDelegate) {
    return oldDelegate.blocks != blocks ||
        oldDelegate.selectedWord != selectedWord ||
        oldDelegate.dragBlockIdx != dragBlockIdx ||
        oldDelegate.dragSelectedIndices != dragSelectedIndices ||
        oldDelegate.scale != scale ||
        oldDelegate.offsetX != offsetX ||
        oldDelegate.offsetY != offsetY;
  }
}
