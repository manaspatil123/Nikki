import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nikki/core/constants/languages.dart';
import 'package:nikki/models/ocr.dart';

/// On-device OCR using Apple's Vision framework (VNRecognizeTextRequest).
///
/// This is the same engine that powers "select text from photos" / Live Text
/// on iOS. Works fully offline, with excellent CJK support from iOS 16+.
///
/// For Japanese / Chinese / Korean the native side returns character-level
/// bounding boxes so the user can tap a single character or drag to select
/// a phrase. For Latin scripts it returns word-level boxes.
class AppleOcrService {
  static const _channel = MethodChannel('com.nikki/text_recognition');

  Future<OcrResult> processImageFile(
    String filePath,
    String sourceLanguage,
  ) async {
    final langCode = Languages.appleOcrLanguageCode(sourceLanguage);

    debugPrint('Apple OCR: processing (lang=$langCode)');

    final result = await _channel.invokeMethod<Map>('recognizeText', {
      'imagePath': filePath,
      'languages': [langCode],
    });

    if (result == null) {
      throw Exception('Apple Vision returned null');
    }

    final width = result['width'] as int;
    final height = result['height'] as int;
    final rawBlocks = result['blocks'] as List<dynamic>;

    debugPrint('Apple OCR: image ${width}x$height, ${rawBlocks.length} lines');

    final blocks = <RecognizedBlock>[];

    for (final rawBlock in rawBlocks) {
      final b = rawBlock as Map;
      final text = b['text'] as String;
      final blockRect = Rect.fromLTRB(
        (b['left'] as num).toDouble(),
        (b['top'] as num).toDouble(),
        (b['right'] as num).toDouble(),
        (b['bottom'] as num).toDouble(),
      );

      final rawElements = b['elements'] as List<dynamic>;
      final elements = <RecognizedElement>[];

      for (final rawEl in rawElements) {
        final e = rawEl as Map;
        elements.add(RecognizedElement(
          text: e['text'] as String,
          boundingBox: Rect.fromLTRB(
            (e['left'] as num).toDouble(),
            (e['top'] as num).toDouble(),
            (e['right'] as num).toDouble(),
            (e['bottom'] as num).toDouble(),
          ),
        ));
      }

      if (elements.isNotEmpty) {
        blocks.add(RecognizedBlock(
          text: text,
          boundingBox: blockRect,
          elements: elements,
        ));
      }
    }

    debugPrint('Apple OCR: ${blocks.length} blocks, '
        '${blocks.fold<int>(0, (sum, b) => sum + b.elements.length)} elements');

    for (final block in blocks.take(3)) {
      for (final el in block.elements.take(5)) {
        debugPrint('  char: "${el.text}" @ ${el.boundingBox}');
      }
    }

    return OcrResult(blocks: blocks, width: width, height: height);
  }

  void dispose() {
    // No resources to release.
  }
}
