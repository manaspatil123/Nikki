import 'dart:ui' show Rect;

import 'package:flutter/material.dart';
import 'package:nikki/providers/camera_provider.dart';

class TextOverlay extends StatelessWidget {
  final List<RecognizedBlock> blocks;
  final SelectedWord? selectedWord;
  final int imageWidth;
  final int imageHeight;
  final int rotationDegrees;
  final void Function(RecognizedElement element, String blockText)
      onElementTapped;

  const TextOverlay({
    super.key,
    required this.blocks,
    required this.selectedWord,
    required this.imageWidth,
    required this.imageHeight,
    required this.rotationDegrees,
    required this.onElementTapped,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final overlayWidth = constraints.maxWidth;
        final overlayHeight = constraints.maxHeight;

        final uprightW =
            (rotationDegrees == 90 || rotationDegrees == 270)
                ? imageHeight
                : imageWidth;
        final uprightH =
            (rotationDegrees == 90 || rotationDegrees == 270)
                ? imageWidth
                : imageHeight;

        if (uprightW == 0 || uprightH == 0) return const SizedBox.expand();

        final scaleX = overlayWidth / uprightW;
        final scaleY = overlayHeight / uprightH;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            final pos = details.localPosition;
            for (final block in blocks) {
              for (final element in block.elements) {
                if (element.boundingBox == null) continue;
                final r = element.boundingBox!;
                final transformed = Rect.fromLTRB(
                  r.left * scaleX,
                  r.top * scaleY,
                  r.right * scaleX,
                  r.bottom * scaleY,
                );
                if (transformed.contains(pos)) {
                  onElementTapped(element, block.text);
                  return;
                }
              }
            }
          },
          child: CustomPaint(
            size: Size(overlayWidth, overlayHeight),
            painter: _TextOverlayPainter(
              blocks: blocks,
              selectedWord: selectedWord,
              scaleX: scaleX,
              scaleY: scaleY,
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
  final double scaleX;
  final double scaleY;

  _TextOverlayPainter({
    required this.blocks,
    required this.selectedWord,
    required this.scaleX,
    required this.scaleY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final selectedPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final selectedOutlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final block in blocks) {
      for (final element in block.elements) {
        if (element.boundingBox == null) continue;
        final r = element.boundingBox!;
        final transformed = Rect.fromLTRB(
          r.left * scaleX,
          r.top * scaleY,
          r.right * scaleX,
          r.bottom * scaleY,
        );

        final isSelected =
            selectedWord != null && element.text == selectedWord!.text;

        if (isSelected) {
          canvas.drawRect(transformed, selectedPaint);
          canvas.drawRect(transformed, selectedOutlinePaint);
        } else {
          canvas.drawRect(transformed, outlinePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TextOverlayPainter oldDelegate) {
    return oldDelegate.blocks != blocks ||
        oldDelegate.selectedWord != selectedWord ||
        oldDelegate.scaleX != scaleX ||
        oldDelegate.scaleY != scaleY;
  }
}
