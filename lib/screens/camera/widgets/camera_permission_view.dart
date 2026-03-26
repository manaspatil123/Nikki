import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white54,
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
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
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
