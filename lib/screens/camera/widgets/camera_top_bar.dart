import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/models/novel.dart';
import 'package:nikki/screens/camera/widgets/language_dropdown.dart';
import 'package:nikki/screens/camera/widgets/novel_selector.dart';

class CameraTopBar extends StatelessWidget {
  final String sourceLanguage;
  final List<Novel> novels;
  final Novel? selectedNovel;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<Novel> onNovelSelected;
  final VoidCallback onNewNovel;
  final VoidCallback onArrowTap;

  const CameraTopBar({
    super.key,
    required this.sourceLanguage,
    required this.novels,
    required this.selectedNovel,
    required this.onLanguageChanged,
    required this.onNovelSelected,
    required this.onNewNovel,
    required this.onArrowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Column(
          children: [
            // Status bar area
            Container(
              height: MediaQuery.of(context).padding.top,
              color: CameraColors.linen,
            ),
            // Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: CameraColors.linen,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LanguageDropdown(
                    sourceLanguage: sourceLanguage,
                    onLanguageChanged: onLanguageChanged,
                  ),
                  NovelSelector(
                    novels: novels,
                    selectedNovel: selectedNovel,
                    onNovelSelected: onNovelSelected,
                    onNewNovel: onNewNovel,
                  ),
                  // Arrow button
                  GestureDetector(
                    onTap: onArrowTap,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.black54,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
