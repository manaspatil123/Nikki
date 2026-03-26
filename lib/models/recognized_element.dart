import 'dart:ui' show Rect;

class RecognizedElement {
  final String text;
  final Rect? boundingBox;

  RecognizedElement({required this.text, this.boundingBox});
}
