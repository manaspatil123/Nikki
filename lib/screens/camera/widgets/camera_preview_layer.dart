import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPreviewLayer extends StatelessWidget {
  final CameraController? controller;
  final bool isCaptured;
  final bool isSleeping;
  final String? lastFramePath;
  final VoidCallback onWakeTap;

  const CameraPreviewLayer({
    super.key,
    required this.controller,
    required this.isCaptured,
    required this.isSleeping,
    required this.lastFramePath,
    required this.onWakeTap,
  });

  @override
  Widget build(BuildContext context) {
    final cameraReady =
        controller != null && controller!.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred last frame — shown during retake/wake while camera
        // re-initializes, to hide the init delay.
        if (!cameraReady && !isCaptured && lastFramePath != null)
          SizedBox.expand(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Image.file(
                File(lastFramePath!),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),

        // Live camera preview — stays visible during capture (freezes
        // naturally while the picture is being taken).
        if (cameraReady)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller!.value.previewSize!.height,
                height: controller!.value.previewSize!.width,
                child: CameraPreview(controller!),
              ),
            ),
          ),

        // Sleep overlay — tap to wake.
        if (isSleeping && !isCaptured)
          GestureDetector(
            onTap: onWakeTap,
            child: Container(
              color: Colors.black26,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white38,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Tap to wake camera',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
