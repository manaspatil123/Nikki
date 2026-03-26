import 'dart:ui' show Rect;

import 'package:nikki/models/recognized_element.dart';

class RecognizedBlock {
  final String text;
  final Rect? boundingBox;
  final List<RecognizedElement> elements;

  RecognizedBlock({
    required this.text,
    this.boundingBox,
    required this.elements,
  });
}
