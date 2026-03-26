import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nikki/core/constants/languages.dart';
import 'package:nikki/models/ocr.dart';

class OcrService {
  /// Process a captured image file using Google Cloud Vision API.
  ///
  /// Uses DOCUMENT_TEXT_DETECTION which returns a structured hierarchy:
  ///   fullTextAnnotation -> pages -> blocks -> paragraphs -> words -> symbols
  ///
  /// Bounding boxes may use either `vertices` (pixel coordinates) or
  /// `normalizedVertices` (0-1 fractions of image dimensions). We handle both.
  ///
  /// Per the API docs, zero-valued coordinates ("x" or "y" = 0) are omitted
  /// from the response JSON.
  Future<OcrResult> processImageFile(
    String filePath,
    String sourceLanguage,
    String googleCloudApiKey,
  ) async {
    if (googleCloudApiKey.isEmpty) {
      throw Exception('Google Cloud API key not set. Add it in Settings.');
    }

    final imageBytes = await File(filePath).readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final langHint = Languages.googleOcrLanguageHint(sourceLanguage);

    debugPrint('OCR: sending to Cloud Vision (lang=$langHint, '
        'imageSize=${(imageBytes.length / 1024).toStringAsFixed(0)}KB)');

    final url = Uri.parse(
      'https://vision.googleapis.com/v1/images:annotate?key=$googleCloudApiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'DOCUMENT_TEXT_DETECTION'}
            ],
            'imageContext': {
              'languageHints': [langHint],
            },
          }
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Cloud Vision API returned HTTP ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json.containsKey('error')) {
      final error = json['error'] as Map<String, dynamic>;
      throw Exception(error['message'] ?? 'Cloud Vision API error');
    }

    final responses = json['responses'] as List<dynamic>;
    if (responses.isEmpty) {
      throw Exception('Cloud Vision API returned empty responses');
    }

    final firstResponse = responses[0] as Map<String, dynamic>;

    if (firstResponse.containsKey('error')) {
      final error = firstResponse['error'] as Map<String, dynamic>;
      throw Exception(error['message'] ?? 'Cloud Vision API error');
    }

    final fullTextAnnotation =
        firstResponse['fullTextAnnotation'] as Map<String, dynamic>?;

    if (fullTextAnnotation == null) {
      debugPrint('OCR: no text detected');
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      return OcrResult(blocks: [], width: w, height: h);
    }

    final pages = fullTextAnnotation['pages'] as List<dynamic>;
    if (pages.isEmpty) {
      debugPrint('OCR: no pages in response');
      return OcrResult(blocks: [], width: 0, height: 0);
    }

    final firstPage = pages[0] as Map<String, dynamic>;
    final apiW = (firstPage['width'] as num).toInt();
    final apiH = (firstPage['height'] as num).toInt();

    debugPrint('OCR: API dimensions = ${apiW}x$apiH');

    // Cloud Vision may return dimensions in raw sensor orientation (landscape)
    // while Flutter's Image.file() displays with EXIF rotation applied (portrait).
    // For a portrait-locked app: if API returned landscape (w > h), we need to
    // rotate bounding boxes 90 CW to match the visual portrait display.
    final bool needsRotation = apiW > apiH;
    final int visualW = needsRotation ? apiH : apiW;
    final int visualH = needsRotation ? apiW : apiH;

    if (needsRotation) {
      debugPrint('OCR: rotating coords 90 CW -> visual ${visualW}x$visualH');
    }

    final apiBlocks = firstPage['blocks'] as List<dynamic>? ?? [];

    final blocks = <RecognizedBlock>[];

    for (final blockJson in apiBlocks) {
      final blockMap = blockJson as Map<String, dynamic>;
      final blockBBox = _parseBoundingBox(
          blockMap['boundingBox'], apiW, apiH, needsRotation);

      final paragraphs = blockMap['paragraphs'] as List<dynamic>? ?? [];
      final blockTextBuffer = StringBuffer();
      final elements = <RecognizedElement>[];

      for (final paragraph in paragraphs) {
        final paraMap = paragraph as Map<String, dynamic>;
        final words = paraMap['words'] as List<dynamic>? ?? [];

        for (final word in words) {
          final wordMap = word as Map<String, dynamic>;
          final symbols = wordMap['symbols'] as List<dynamic>? ?? [];

          final wordText = symbols
              .map((s) => (s as Map<String, dynamic>)['text'] as String? ?? '')
              .join();

          if (wordText.isEmpty) continue;

          if (blockTextBuffer.isNotEmpty) blockTextBuffer.write(' ');
          blockTextBuffer.write(wordText);

          final wordBBox = _parseBoundingBox(
              wordMap['boundingBox'], apiW, apiH, needsRotation);

          elements.add(RecognizedElement(
            text: wordText,
            boundingBox: wordBBox,
          ));
        }
      }

      if (elements.isNotEmpty) {
        blocks.add(RecognizedBlock(
          text: blockTextBuffer.toString(),
          boundingBox: blockBBox,
          elements: elements,
        ));
      }
    }

    debugPrint('OCR: ${blocks.length} blocks, '
        '${blocks.fold<int>(0, (sum, b) => sum + b.elements.length)} elements');

    for (final block in blocks.take(3)) {
      for (final el in block.elements.take(3)) {
        debugPrint('  word: "${el.text}" @ ${el.boundingBox}');
      }
    }

    return OcrResult(blocks: blocks, width: visualW, height: visualH);
  }

  /// Parse a Cloud Vision boundingBox into a [Rect].
  ///
  /// Handles both `vertices` (pixel) and `normalizedVertices` (0-1 fractions).
  /// If [needsRotation] is true, rotates coordinates 90 CW to convert from
  /// raw landscape sensor space to visual portrait space:
  ///   raw(x, y) in WxH -> visual(H - y, x) in HxW
  ///
  /// Per the API docs, zero-valued "x" or "y" fields are omitted entirely.
  static Rect? _parseBoundingBox(
    Map<String, dynamic>? boundingBox,
    int apiW,
    int apiH,
    bool needsRotation,
  ) {
    if (boundingBox == null) return null;

    // Try pixel-based vertices first
    var verticesList = boundingBox['vertices'] as List<dynamic>?;
    bool isNormalized = false;

    // Fall back to normalizedVertices (used in PDF/TIFF responses)
    if (verticesList == null || verticesList.isEmpty) {
      verticesList = boundingBox['normalizedVertices'] as List<dynamic>?;
      isNormalized = true;
    }

    if (verticesList == null || verticesList.isEmpty) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final v in verticesList) {
      final vMap = v as Map<String, dynamic>;
      // Zero coordinates are omitted by the API — default to 0.0
      double x = (vMap['x'] as num?)?.toDouble() ?? 0.0;
      double y = (vMap['y'] as num?)?.toDouble() ?? 0.0;

      if (isNormalized) {
        x *= apiW;
        y *= apiH;
      }

      // Rotate 90 CW: raw(x,y) in WxH -> visual(H-y, x) in HxW
      if (needsRotation) {
        final rotX = apiH - y;
        final rotY = x;
        x = rotX;
        y = rotY;
      }

      minX = min(minX, x);
      minY = min(minY, y);
      maxX = max(maxX, x);
      maxY = max(maxY, y);
    }

    // Guard against degenerate rects
    if (minX >= maxX || minY >= maxY) return null;

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void dispose() {
    // No resources to release for HTTP-based OCR.
  }
}
