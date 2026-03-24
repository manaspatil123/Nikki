import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:nikki/providers/camera_provider.dart';

class OcrService {
  TextRecognizer? _recognizer;

  TextRecognizer get recognizer {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.japanese);
    return _recognizer!;
  }

  InputImage? buildInputImage(CameraImage image, CameraDescription camera) {
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format ?? InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<List<RecognizedBlock>> processImage(InputImage inputImage) async {
    final result = await recognizer.processImage(inputImage);
    return result.blocks.map((block) {
      return RecognizedBlock(
        text: block.text,
        boundingBox: block.boundingBox,
        elements: block.lines.expand((line) {
          return line.elements.map((element) {
            return RecognizedElement(
              text: element.text,
              boundingBox: element.boundingBox,
            );
          });
        }).toList(),
      );
    }).toList();
  }

  void dispose() {
    _recognizer?.close();
  }
}
