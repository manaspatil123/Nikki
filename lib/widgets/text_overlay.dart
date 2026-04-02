import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/models/ocr.dart';

enum _CharType { cjk, hiragana, katakana, latin, digit, other }

class TextOverlay extends StatefulWidget {
  final List<RecognizedBlock> blocks;
  final SelectedWord? selectedWord;
  final int imageWidth;
  final int imageHeight;
  final int rotationDegrees;
  final String? imagePath;
  /// Optional [TransformationController] from the parent [InteractiveViewer].
  /// Used to keep the magnifier at a constant screen size regardless of zoom.
  final TransformationController? transformController;
  /// Called when the user finishes selecting text.
  /// [selectionNormalizedY] is the selection center's Y position (0–1) relative to the overlay.
  final void Function(String selectedText, String blockText, double selectionNormalizedY) onSelectionComplete;

  const TextOverlay({
    super.key,
    required this.blocks,
    required this.selectedWord,
    required this.imageWidth,
    required this.imageHeight,
    required this.rotationDegrees,
    this.imagePath,
    this.transformController,
    required this.onSelectionComplete,
  });

  @override
  State<TextOverlay> createState() => _TextOverlayState();
}

class _TextOverlayState extends State<TextOverlay> {
  int? _dragStartGlobal;
  int? _dragEndGlobal;
  Set<int>? _finalSelectedGlobal;
  Offset? _dragPosition;

  // ── Global index helpers ──────────────────────────────────────────

  ({int blockIdx, int elemIdx}) _fromGlobal(int global) {
    int remaining = global;
    for (int bi = 0; bi < widget.blocks.length; bi++) {
      final count = widget.blocks[bi].elements.length;
      if (remaining < count) {
        return (blockIdx: bi, elemIdx: remaining);
      }
      remaining -= count;
    }
    final lastBi = widget.blocks.length - 1;
    return (
      blockIdx: lastBi,
      elemIdx: widget.blocks[lastBi].elements.length - 1,
    );
  }

  Set<int> get _dragSelectedGlobalIndices {
    if (_dragStartGlobal == null || _dragEndGlobal == null) return {};
    final lo = min(_dragStartGlobal!, _dragEndGlobal!);
    final hi = max(_dragStartGlobal!, _dragEndGlobal!);
    return {for (int i = lo; i <= hi; i++) i};
  }

  // ── Transform helpers ─────────────────────────────────────────────

  static ({double scale, double offsetX, double offsetY}) _computeTransform(
    double overlayWidth,
    double overlayHeight,
    double imgW,
    double imgH,
  ) {
    final imageAspect = imgW / imgH;
    final screenAspect = overlayWidth / overlayHeight;
    double scale, offsetX, offsetY;
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
      Rect r, double scale, double offsetX, double offsetY) {
    return Rect.fromLTRB(
      r.left * scale - offsetX,
      r.top * scale - offsetY,
      r.right * scale - offsetX,
      r.bottom * scale - offsetY,
    );
  }

  // ── Hit-testing ───────────────────────────────────────────────────

  int? _hitTest(Offset pos, double scale, double offsetX, double offsetY) {
    const padding = 6.0;
    int global = 0;
    for (int bi = 0; bi < widget.blocks.length; bi++) {
      for (int ei = 0; ei < widget.blocks[bi].elements.length; ei++) {
        final bbox = widget.blocks[bi].elements[ei].boundingBox;
        if (bbox != null) {
          final r = _transformRect(bbox, scale, offsetX, offsetY);
          if (r.inflate(padding).contains(pos)) return global;
        }
        global++;
      }
    }
    return null;
  }

  int? _closestGlobal(
      Offset pos, double scale, double offsetX, double offsetY) {
    double bestDist = double.infinity;
    int? bestGlobal;
    int global = 0;
    for (int bi = 0; bi < widget.blocks.length; bi++) {
      for (int ei = 0; ei < widget.blocks[bi].elements.length; ei++) {
        final bbox = widget.blocks[bi].elements[ei].boundingBox;
        if (bbox != null) {
          final r = _transformRect(bbox, scale, offsetX, offsetY);
          final dist = (r.center - pos).distance;
          if (dist < bestDist) {
            bestDist = dist;
            bestGlobal = global;
          }
        }
        global++;
      }
    }
    return bestGlobal;
  }

  // ── Word expansion for tap ─────────────────────────────────────

  /// Given a tapped character's global index, expand the selection to
  /// cover the full word it belongs to. Uses simple character-type grouping:
  /// consecutive CJK ideographs / kana / letters form a word.
  Set<int> _expandToWord(int tappedGlobal) {
    final loc = _fromGlobal(tappedGlobal);
    final block = widget.blocks[loc.blockIdx];
    final elements = block.elements;
    final tappedIdx = loc.elemIdx;

    // Determine the character type of the tapped element.
    final tappedChar = elements[tappedIdx].text;
    final type = _charType(tappedChar);

    // If it's punctuation or whitespace, just select the single character.
    if (type == _CharType.other) return {tappedGlobal};

    // Expand left.
    int startIdx = tappedIdx;
    while (startIdx > 0 && _charType(elements[startIdx - 1].text) == type) {
      startIdx--;
    }

    // Expand right.
    int endIdx = tappedIdx;
    while (endIdx < elements.length - 1 &&
        _charType(elements[endIdx + 1].text) == type) {
      endIdx++;
    }

    // Convert back to global indices.
    final blockStart = _toGlobal(loc.blockIdx, 0);
    return {for (int i = startIdx; i <= endIdx; i++) blockStart + i};
  }

  static _CharType _charType(String s) {
    if (s.isEmpty) return _CharType.other;
    final c = s.codeUnitAt(0);
    // CJK Unified Ideographs
    if (c >= 0x4E00 && c <= 0x9FFF) return _CharType.cjk;
    // CJK Extension A
    if (c >= 0x3400 && c <= 0x4DBF) return _CharType.cjk;
    // Hiragana
    if (c >= 0x3040 && c <= 0x309F) return _CharType.hiragana;
    // Katakana
    if (c >= 0x30A0 && c <= 0x30FF) return _CharType.katakana;
    // Half-width katakana
    if (c >= 0xFF65 && c <= 0xFF9F) return _CharType.katakana;
    // Latin letters
    if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)) {
      return _CharType.latin;
    }
    // Digits
    if (c >= 0x30 && c <= 0x39) return _CharType.digit;
    // Full-width digits/letters
    if (c >= 0xFF10 && c <= 0xFF5A) return _CharType.latin;
    return _CharType.other;
  }

  int _toGlobal(int blockIdx, int elemIdx) {
    int idx = 0;
    for (int bi = 0; bi < blockIdx; bi++) {
      idx += widget.blocks[bi].elements.length;
    }
    return idx + elemIdx;
  }

  // ── Selection helpers ─────────────────────────────────────────────

  void _commitSelection(Set<int> globalIndices) {
    if (globalIndices.isEmpty) return;
    final sorted = globalIndices.toList()..sort();
    final selectedText = sorted.map((g) {
      final loc = _fromGlobal(g);
      return widget.blocks[loc.blockIdx].elements[loc.elemIdx].text;
    }).join();
    final involvedBlockIndices = <int>{};
    for (final g in sorted) {
      involvedBlockIndices.add(_fromGlobal(g).blockIdx);
    }
    final blockText =
        involvedBlockIndices.toList().map((bi) => widget.blocks[bi].text).join(' ');

    // Compute the average Y of selected elements in image coordinates,
    // then normalize to 0–1 relative to image height.
    double avgY = 0;
    int count = 0;
    for (final g in sorted) {
      final loc = _fromGlobal(g);
      final bbox = widget.blocks[loc.blockIdx].elements[loc.elemIdx].boundingBox;
      if (bbox != null) {
        avgY += bbox.center.dy;
        count++;
      }
    }
    final imgH = widget.imageHeight.toDouble();
    final normalizedY = (count > 0 && imgH > 0) ? (avgY / count / imgH) : 0.0;

    setState(() => _finalSelectedGlobal = Set.of(globalIndices));
    widget.onSelectionComplete(selectedText, blockText, normalizedY);
  }

  void _finalizeDragSelection() {
    final indices = _dragSelectedGlobalIndices;
    setState(() {
      _dragStartGlobal = null;
      _dragEndGlobal = null;
      _dragPosition = null;
    });
    _commitSelection(indices);
  }

  @override
  void didUpdateWidget(covariant TextOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedWord == null && oldWidget.selectedWord != null) {
      _finalSelectedGlobal = null;
    }
  }

  // ── Magnifier loupe ───────────────────────────────────────────────

  static const _kLoupeDiameter = 90.0;
  static const _kLoupeRadius = _kLoupeDiameter / 2;
  static const _kLoupeGap = 60.0;
  static const _kLoupeMag = 2.0;

  /// Build a magnifier that renders the actual image zoomed in, centered
  /// on the exact touch point. No BackdropFilter — just a second Image
  /// widget clipped to a circle, translated so the touch point sits at
  /// the loupe center.
  Widget _buildLoupe(
    Offset touchLocal,
    double overlayWidth,
    double overlayHeight,
  ) {
    if (widget.imagePath == null) return const SizedBox.shrink();

    // Counter-scale to keep the loupe at a constant screen size when the
    // parent InteractiveViewer is zoomed in.
    final matrix =
        widget.transformController?.value ?? Matrix4.identity();
    final viewerScale = matrix.getMaxScaleOnAxis();
    final loupeDiameter = _kLoupeDiameter / viewerScale;
    final loupeRadius = loupeDiameter / 2;
    final loupeGap = _kLoupeGap / viewerScale;
    // Use the base magnification — the InteractiveViewer already scales
    // everything by viewerScale, so _kLoupeMag gives 2× relative to the
    // *current* zoomed view, which is what the user expects.
    const mag = _kLoupeMag;

    // Position above the finger by default; flip below when the loupe
    // would be in the top ~30% of the visible screen.
    final loupeLeft = touchLocal.dx - loupeRadius;
    final aboveTop = touchLocal.dy - loupeGap - loupeDiameter;
    // Convert the touch point to screen coordinates and check if it's
    // in the upper portion of the viewport.
    final screenTouchY =
        MatrixUtils.transformPoint(matrix, Offset(0, touchLocal.dy)).dy;
    final loupeTop = screenTouchY > overlayHeight * 0.3
        ? aboveTop
        : touchLocal.dy + loupeGap;

    // The image is displayed with BoxFit.cover at (overlayWidth x overlayHeight).
    // We render a second copy of the image at the same cover size * mag,
    // then translate so the touch point lands at the loupe center.
    //
    // Cover size = the size the image is rendered at before clipping.
    final imgW = widget.imageWidth.toDouble();
    final imgH = widget.imageHeight.toDouble();
    final imageAspect = imgW / imgH;
    final screenAspect = overlayWidth / overlayHeight;

    double coverW, coverH;
    if (imageAspect > screenAspect) {
      coverH = overlayHeight;
      coverW = overlayHeight * imageAspect;
    } else {
      coverW = overlayWidth;
      coverH = overlayWidth / imageAspect;
    }

    // How the cover image is offset (centered crop).
    final coverOffsetX = (coverW - overlayWidth) / 2;
    final coverOffsetY = (coverH - overlayHeight) / 2;

    // The touch point in the overlay corresponds to this point in the
    // cover-sized image:
    final imgX = touchLocal.dx + coverOffsetX;
    final imgY = touchLocal.dy + coverOffsetY;

    // Scale the cover image by mag. The touch point in the scaled image:
    final scaledImgX = imgX * mag;
    final scaledImgY = imgY * mag;

    // Translate so that (scaledImgX, scaledImgY) sits at loupe center.
    final translateX = loupeRadius - scaledImgX;
    final translateY = loupeRadius - scaledImgY;

    return Positioned(
      left: loupeLeft,
      top: loupeTop,
      child: IgnorePointer(
        child: Container(
          width: loupeDiameter,
          height: loupeDiameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8 / viewerScale,
                spreadRadius: 1 / viewerScale,
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              children: [
                // Magnified image
                Positioned(
                  left: translateX,
                  top: translateY,
                  width: coverW * mag,
                  height: coverH * mag,
                  child: Image.file(
                    File(widget.imagePath!),
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
                // Magnified selection overlay (same position/size)
                Positioned(
                  left: translateX,
                  top: translateY,
                  width: coverW * mag,
                  height: coverH * mag,
                  child: CustomPaint(
                    size: Size(coverW * mag, coverH * mag),
                    painter: _LoupeSelectionPainter(
                      blocks: widget.blocks,
                      selectedGlobal: _dragSelectedGlobalIndices,
                      scale: (coverW * mag) / widget.imageWidth,
                    ),
                  ),
                ),
                // Glass border
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5 / viewerScale,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

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

        return Stack(
          clipBehavior: Clip.none,
          children: [
            RawGestureDetector(
              behavior: HitTestBehavior.translucent,
              gestures: <Type, GestureRecognizerFactory>{
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (instance) {
                    instance.onTapUp = (details) {
                      final hit = _hitTest(details.localPosition, t.scale,
                          t.offsetX, t.offsetY);
                      if (hit != null) _commitSelection(_expandToWord(hit));
                    };
                  },
                ),
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        LongPressGestureRecognizer>(
                  () => LongPressGestureRecognizer(
                    duration: const Duration(milliseconds: 350),
                  ),
                  (instance) {
                    instance.onLongPressStart = (details) {
                      final hit = _hitTest(details.localPosition, t.scale,
                          t.offsetX, t.offsetY);
                      if (hit != null) {
                        setState(() {
                          _dragStartGlobal = hit;
                          _dragEndGlobal = hit;
                          _dragPosition = details.localPosition;
                        });
                      }
                    };
                    instance.onLongPressMoveUpdate = (details) {
                      if (_dragStartGlobal == null) return;
                      final closest = _closestGlobal(details.localPosition,
                          t.scale, t.offsetX, t.offsetY);
                      if (closest != null) {
                        setState(() {
                          if (closest != _dragEndGlobal) {
                            _dragEndGlobal = closest;
                          }
                          _dragPosition = details.localPosition;
                        });
                      }
                    };
                    instance.onLongPressEnd = (_) => _finalizeDragSelection();
                  },
                ),
              },
              child: CustomPaint(
                size: Size(overlayWidth, overlayHeight),
                painter: _TextOverlayPainter(
                  blocks: widget.blocks,
                  dragSelectedGlobal: _dragSelectedGlobalIndices,
                  finalSelectedGlobal: _finalSelectedGlobal,
                  scale: t.scale,
                  offsetX: t.offsetX,
                  offsetY: t.offsetY,
                ),
              ),
            ),
            if (_dragPosition != null)
              _buildLoupe(_dragPosition!, overlayWidth, overlayHeight),
          ],
        );
      },
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────

class _TextOverlayPainter extends CustomPainter {
  final List<RecognizedBlock> blocks;
  final Set<int> dragSelectedGlobal;
  final Set<int>? finalSelectedGlobal;
  final double scale;
  final double offsetX;
  final double offsetY;

  _TextOverlayPainter({
    required this.blocks,
    required this.dragSelectedGlobal,
    required this.finalSelectedGlobal,
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
    final bool isDragging = dragSelectedGlobal.isNotEmpty;
    final bool hasFinal =
        !isDragging && finalSelectedGlobal != null && finalSelectedGlobal!.isNotEmpty;

    final selectedIndices =
        isDragging ? dragSelectedGlobal : (hasFinal ? finalSelectedGlobal! : <int>{});

    if (selectedIndices.isNotEmpty) {
      final fillPaint = Paint()
        ..color = isDragging
            ? CameraColors.selectionDrag
            : CameraColors.selectionFinal
        ..style = PaintingStyle.fill;

      int g = 0;
      for (int bi = 0; bi < blocks.length; bi++) {
        for (int ei = 0; ei < blocks[bi].elements.length; ei++) {
          if (selectedIndices.contains(g)) {
            final bbox = blocks[bi].elements[ei].boundingBox;
            if (bbox != null) {
              canvas.drawRRect(
                RRect.fromRectAndRadius(_transform(bbox), const Radius.circular(2)),
                fillPaint,
              );
            }
          }
          g++;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TextOverlayPainter oldDelegate) {
    return oldDelegate.blocks != blocks ||
        oldDelegate.dragSelectedGlobal != dragSelectedGlobal ||
        oldDelegate.finalSelectedGlobal != finalSelectedGlobal ||
        oldDelegate.scale != scale ||
        oldDelegate.offsetX != offsetX ||
        oldDelegate.offsetY != offsetY;
  }
}

/// Paints the blue selection fill inside the magnifier loupe.
/// Coordinates are in the magnified cover-image space (image pixels * scale).
class _LoupeSelectionPainter extends CustomPainter {
  final List<RecognizedBlock> blocks;
  final Set<int> selectedGlobal;
  final double scale;

  _LoupeSelectionPainter({
    required this.blocks,
    required this.selectedGlobal,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedGlobal.isEmpty) return;

    final fillPaint = Paint()
      ..color = CameraColors.selectionLoupe
      ..style = PaintingStyle.fill;

    final minSelected = selectedGlobal.reduce(min);
    final maxSelected = selectedGlobal.reduce(max);
    Rect? firstRect;
    Rect? lastRect;

    int g = 0;
    for (int bi = 0; bi < blocks.length; bi++) {
      for (int ei = 0; ei < blocks[bi].elements.length; ei++) {
        if (selectedGlobal.contains(g)) {
          final bbox = blocks[bi].elements[ei].boundingBox;
          if (bbox != null) {
            final r = Rect.fromLTRB(
              bbox.left * scale,
              bbox.top * scale,
              bbox.right * scale,
              bbox.bottom * scale,
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(r, const Radius.circular(3)),
              fillPaint,
            );
            if (g == minSelected) firstRect = r;
            if (g == maxSelected) lastRect = r;
          }
        }
        g++;
      }
    }

    // Draw cursor markers at both ends of the selection.
    final cursorPaint = Paint()
      ..color = CameraColors.selectionCursor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = CameraColors.selectionCursor;

    // Left cursor — left edge of first selected element, dot at bottom.
    if (firstRect != null) {
      canvas.drawLine(
        Offset(firstRect!.left, firstRect!.top - 2),
        Offset(firstRect!.left, firstRect!.bottom + 2),
        cursorPaint,
      );
      canvas.drawCircle(
        Offset(firstRect!.left, firstRect!.bottom + 5),
        3.0,
        dotPaint,
      );
    }

    // Right cursor — right edge of last selected element, dot at top.
    if (lastRect != null) {
      canvas.drawLine(
        Offset(lastRect!.right, lastRect!.top - 2),
        Offset(lastRect!.right, lastRect!.bottom + 2),
        cursorPaint,
      );
      canvas.drawCircle(
        Offset(lastRect!.right, lastRect!.top - 5),
        3.0,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoupeSelectionPainter oldDelegate) {
    return oldDelegate.selectedGlobal != selectedGlobal ||
        oldDelegate.blocks != blocks ||
        oldDelegate.scale != scale;
  }
}
