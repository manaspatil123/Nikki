import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nikki/core/constants/assets.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/theme/nikki_colors.dart';

class CameraBottomBar extends StatelessWidget {
  final bool isCaptured;
  final bool isTakingPicture;
  final VoidCallback onCapture;
  final VoidCallback onRetake;
  final VoidCallback onHistoryTap;

  const CameraBottomBar({
    super.key,
    required this.isCaptured,
    required this.isTakingPicture,
    required this.onCapture,
    required this.onRetake,
    required this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NikkiColors.of(context);
    return Stack(
      children: [
        // Capture / Retake button — centered
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: GestureDetector(
                  onTap: isCaptured ? onRetake : onCapture,
                  child: Container(
                    width: 85,
                    height: 85,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CameraColors.linen,
                      border: Border.all(
                        color: CameraColors.brown,
                        width: 4.5,
                      ),
                    ),
                    child: isTakingPicture
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(
                              color: CameraColors.teal,
                              strokeWidth: 2,
                            ),
                          )
                        : isCaptured
                            ? const Icon(
                                Icons.refresh,
                                color: CameraColors.teal,
                                size: 40,
                              )
                            : Padding(
                                padding: const EdgeInsets.all(16),
                                child: SvgPicture.asset(
                                  Assets.captureIcon,
                                  colorFilter: const ColorFilter.mode(
                                    CameraColors.teal,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // History button — right side
        Positioned(
          bottom: 0,
          right: 16,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 35),
              child: GestureDetector(
                onTap: onHistoryTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: CameraColors.teal,
                      width: 2.5,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'History',
                        style: TextStyle(
                          color: CameraColors.darkTeal,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.history,
                        color: CameraColors.darkTeal,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
