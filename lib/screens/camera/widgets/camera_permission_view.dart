import 'package:flutter/material.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permission request view — NOT a full Scaffold.
/// Rendered inside the camera screen's Stack, below the top/bottom bars.
class CameraPermissionView extends StatelessWidget {
  final bool isPermanentlyDenied;
  final VoidCallback onRequestPermission;

  const CameraPermissionView({
    super.key,
    required this.isPermanentlyDenied,
    required this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white38,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                isPermanentlyDenied
                    ? 'Camera permission is permanently denied.\nPlease enable it in Settings.'
                    : 'Camera permission is required to scan text.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: isPermanentlyDenied
                    ? () => openAppSettings()
                    : onRequestPermission,
                style: OutlinedButton.styleFrom(
                  foregroundColor: CameraColors.teal,
                  side: const BorderSide(color: CameraColors.teal),
                ),
                child: Text(
                  isPermanentlyDenied ? 'Open Settings' : 'Grant Permission',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
