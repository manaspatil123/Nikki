import 'package:nikki/models/recognized_block.dart';

class OcrResult {
  final List<RecognizedBlock> blocks;
  final int width;
  final int height;

  OcrResult({required this.blocks, required this.width, required this.height});
}
