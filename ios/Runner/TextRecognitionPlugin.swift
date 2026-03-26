import Flutter
import Vision
import UIKit

/// Platform channel plugin that uses Apple's Vision framework (VNRecognizeTextRequest)
/// for on-device text recognition. This is the same engine that powers Live Text /
/// "select text from photos" on iOS.
///
/// Returns bounding boxes in pixel coordinates (origin top-left) matching
/// Flutter's Image.file() display after EXIF rotation.
class TextRecognitionPlugin: NSObject {

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.nikki/text_recognition",
            binaryMessenger: registrar.messenger()
        )
        let instance = TextRecognitionPlugin()
        channel.setMethodCallHandler(instance.handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "recognizeText":
            guard let args = call.arguments as? [String: Any],
                  let imagePath = args["imagePath"] as? String,
                  let languages = args["languages"] as? [String] else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "Missing imagePath or languages",
                                    details: nil))
                return
            }
            recognizeText(imagePath: imagePath, languages: languages, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func recognizeText(
        imagePath: String,
        languages: [String],
        result: @escaping FlutterResult
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Load via UIImage to get EXIF orientation.
            guard let uiImage = UIImage(contentsOfFile: imagePath),
                  let cgImage = uiImage.cgImage else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "IMAGE_ERROR",
                                        message: "Failed to load image at \(imagePath)",
                                        details: nil))
                }
                return
            }

            let orientation = CGImagePropertyOrientation(uiImage.imageOrientation)

            // Visual dimensions after EXIF rotation (matches Flutter's Image.file()).
            let visualWidth  = Int(uiImage.size.width * uiImage.scale)
            let visualHeight = Int(uiImage.size.height * uiImage.scale)

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: orientation,
                options: [:]
            )

            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "RECOGNITION_ERROR",
                                        message: error.localizedDescription,
                                        details: nil))
                }
                return
            }

            guard let observations = request.results, !observations.isEmpty else {
                DispatchQueue.main.async {
                    result([
                        "blocks": [] as [[String: Any]],
                        "width": visualWidth,
                        "height": visualHeight,
                    ] as [String: Any])
                }
                return
            }

            let useCharLevel = languages.first.map {
                ["ja", "zh-Hans", "zh-Hant", "ko"].contains($0)
            } ?? false

            var blocks: [[String: Any]] = []

            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                let text = candidate.string
                if text.isEmpty { continue }

                // Block (line) bounding box
                let blockRect = self.visionRectToPixel(
                    observation.boundingBox,
                    width: visualWidth,
                    height: visualHeight
                )

                var elements: [[String: Any]] = []

                if useCharLevel {
                    // Character-level bounding boxes for CJK — gives precise
                    // per-character selection control.
                    for i in text.indices {
                        let range = i ..< text.index(after: i)
                        guard let boxObs = try? candidate.boundingBox(for: range) else {
                            continue
                        }
                        let charRect = self.visionRectToPixel(
                            boxObs.boundingBox,
                            width: visualWidth,
                            height: visualHeight
                        )
                        elements.append([
                            "text": String(text[range]),
                            "left": charRect.minX,
                            "top": charRect.minY,
                            "right": charRect.maxX,
                            "bottom": charRect.maxY,
                        ])
                    }
                } else {
                    // Word-level for Latin scripts (split by space).
                    var searchStart = text.startIndex
                    for word in text.split(separator: " ") {
                        guard let wordRange = text.range(
                            of: word,
                            range: searchStart ..< text.endIndex
                        ) else { continue }
                        if let boxObs = try? candidate.boundingBox(for: wordRange) {
                            let wordRect = self.visionRectToPixel(
                                boxObs.boundingBox,
                                width: visualWidth,
                                height: visualHeight
                            )
                            elements.append([
                                "text": String(word),
                                "left": wordRect.minX,
                                "top": wordRect.minY,
                                "right": wordRect.maxX,
                                "bottom": wordRect.maxY,
                            ])
                        }
                        searchStart = wordRange.upperBound
                    }
                }

                blocks.append([
                    "text": text,
                    "left": blockRect.minX,
                    "top": blockRect.minY,
                    "right": blockRect.maxX,
                    "bottom": blockRect.maxY,
                    "elements": elements,
                ])
            }

            DispatchQueue.main.async {
                result([
                    "blocks": blocks,
                    "width": visualWidth,
                    "height": visualHeight,
                ] as [String: Any])
            }
        }
    }

    /// Convert Vision framework normalized rect (origin bottom-left, 0→1)
    /// to pixel rect (origin top-left) matching Flutter's coordinate system.
    private func visionRectToPixel(
        _ rect: CGRect,
        width: Int,
        height: Int
    ) -> CGRect {
        let w = CGFloat(width)
        let h = CGFloat(height)
        return CGRect(
            x: rect.origin.x * w,
            y: (1.0 - rect.origin.y - rect.height) * h,
            width: rect.width * w,
            height: rect.height * h
        )
    }
}

// MARK: – UIImage.Orientation → CGImagePropertyOrientation

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:            self = .up
        case .upMirrored:    self = .upMirrored
        case .down:          self = .down
        case .downMirrored:  self = .downMirrored
        case .left:          self = .left
        case .leftMirrored:  self = .leftMirrored
        case .right:         self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}
